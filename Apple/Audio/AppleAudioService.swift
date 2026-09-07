import Foundation
import AVFoundation
import Speech
import PolygoCore

/// Apple-only audio adapter used by PolygoApp. All recordings are created in
/// the process temporary directory; callers must explicitly decide whether to
/// retain them and should call `delete(recording:)` when the exercise ends.
public final class AppleAudioService: NSObject, AudioService, AVAudioPlayerDelegate, AVAudioRecorderDelegate, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    public let contentRootURL: URL

    private let fileManager: FileManager
    private let synthesizer: AVSpeechSynthesizer
    private let streamLock = NSLock()
    private var streamContinuations: [UUID: AsyncStream<AudioPlaybackState>.Continuation] = [:]

    // AVFoundation objects are used on the main queue. The class is marked
    // unchecked Sendable because AudioService is injected through a Sendable
    // existential while its mutable platform state remains queue-confined.
    private var player: AVAudioPlayer?
    private var activeAssetID: AssetID?

    // AVAudioRecorder state is main-queue confined. The admission sets are
    // protected separately because cancellation may arrive while the request
    // is waiting for its initial DispatchQueue.main hop.
    private let recordingStateLock = NSLock()
    private var queuedRecordingRequestIDs: Set<UUID> = []
    private var cancelledRecordingRequestIDs: Set<UUID> = []
    private var recorder: AVAudioRecorder?
    private var recordingContinuation: CheckedContinuation<Recording, Error>?
    private var recordingID: RecordingID?
    private var recordingRequestID: UUID?
    private var deleteCancelledRecording = false

    // Speech callbacks can arrive after a view has disappeared. Keep the
    // active task and continuation on the main queue, while the two sets let
    // cancellation race safely with the initial main-queue hop.
    private let transcriptionStateLock = NSLock()
    private var queuedTranscriptionRequestIDs: Set<UUID> = []
    private var cancelledTranscriptionRequestIDs: Set<UUID> = []
    private var transcriptionTask: SFSpeechRecognitionTask?
    private var transcriptionContinuation: CheckedContinuation<SpeechTranscript, Error>?
    private var transcriptionRequestID: UUID?

    public init(contentRootURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.contentRootURL = (contentRootURL
            ?? Bundle.main.resourceURL?.appendingPathComponent("Content", isDirectory: true)
            ?? fileManager.temporaryDirectory.appendingPathComponent("missing-syllune-content", isDirectory: true))
            .standardizedFileURL
        self.synthesizer = AVSpeechSynthesizer()
        super.init()
        synthesizer.delegate = self
    }

    // MARK: Permissions

    public func requestMicrophonePermission() async -> PermissionState {
        #if os(iOS)
        let permission = AVAudioSession.sharedInstance().recordPermission
        switch permission {
        case .granted:
            return .authorized
        case .denied:
            return .denied
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted ? .authorized : .denied)
                }
            }
        @unknown default:
            return .unavailable
        }
        #elseif os(macOS)
        let permission = AVCaptureDevice.authorizationStatus(for: .audio)
        switch permission {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted ? .authorized : .denied)
                }
            }
        @unknown default:
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    public func requestSpeechPermission() async -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: Self.permissionState(for: status))
                }
            }
        @unknown default:
            return .unavailable
        }
    }

    private static func permissionState(for status: SFSpeechRecognizerAuthorizationStatus) -> PermissionState {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
    }

    // MARK: Speech synthesis

    public func speak(_ request: SpeechSynthesisRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            performOnMain { [weak self] in
                guard let self else {
                    continuation.resume(throwing: AudioServiceError.unavailable)
                    return
                }
                let text = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else {
                    continuation.resume(throwing: AudioServiceError.playbackFailed("Le texte à lire est vide"))
                    return
                }
                guard let voice = AVSpeechSynthesisVoice(language: request.localeIdentifier) else {
                    continuation.resume(throwing: AudioServiceError.voiceUnavailable(request.localeIdentifier))
                    return
                }
                do {
                    try self.prepareAudioForPlayback()
                    self.stopCurrentPlayer()
                    self.synthesizer.stopSpeaking(at: .immediate)
                    let utterance = AVSpeechUtterance(string: text)
                    utterance.voice = voice
                    utterance.rate = request.rate.avSpeechRate
                    self.synthesizer.speak(utterance)
                    // AVSpeechSynthesizer queues the utterance. The delegate
                    // reports completion separately; this method means that
                    // the request was accepted by the local synthesizer.
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: AudioServiceError.playbackFailed(error.localizedDescription))
                }
            }
        }
    }

    public func stopSpeaking() {
        performOnMain { [weak self] in
            self?.synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: Asset and recording playback

    public func play(asset: AssetReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            performOnMain { [weak self] in
                guard let self else {
                    continuation.resume(throwing: AudioServiceError.unavailable)
                    return
                }
                do {
                    let url = try self.assetURL(for: asset)
                    try self.prepareAudioForPlayback()
                    self.stopCurrentPlayer()
                    self.synthesizer.stopSpeaking(at: .immediate)
                    self.emit(.loading(asset.id))
                    let nextPlayer = try AVAudioPlayer(contentsOf: url)
                    nextPlayer.delegate = self
                    nextPlayer.prepareToPlay()
                    self.player = nextPlayer
                    self.activeAssetID = asset.id
                    guard nextPlayer.play() else {
                        self.player = nil
                        self.activeAssetID = nil
                        self.emit(.failed(AudioServiceError.playbackFailed("Le lecteur n’a pas démarré").localizedDescription))
                        continuation.resume(throwing: AudioServiceError.playbackFailed("Le lecteur n’a pas démarré"))
                        return
                    }
                    self.emit(.playing(asset.id, progress: 0))
                    continuation.resume()
                } catch let error as AudioServiceError {
                    self.emit(.failed(error.localizedDescription))
                    continuation.resume(throwing: error)
                } catch {
                    let wrapped = AudioServiceError.playbackFailed(error.localizedDescription)
                    self.emit(.failed(wrapped.localizedDescription))
                    continuation.resume(throwing: wrapped)
                }
            }
        }
    }

    public func stopPlayback() {
        performOnMain { [weak self] in
            guard let self else { return }
            self.stopCurrentPlayer()
            self.synthesizer.stopSpeaking(at: .immediate)
            self.emit(.stopped)
        }
    }

    public func playbackStates() -> AsyncStream<AudioPlaybackState> {
        let streamID = UUID()
        return AsyncStream { continuation in
            streamLock.lock()
            streamContinuations[streamID] = continuation
            streamLock.unlock()
            continuation.yield(.idle)
            continuation.onTermination = { [weak self] _ in
                self?.streamLock.lock()
                self?.streamContinuations.removeValue(forKey: streamID)
                self?.streamLock.unlock()
            }
        }
    }

    public func record(_ request: AudioRecordingRequest) async throws -> Recording {
        let requestID = UUID()
        recordingStateLock.lock()
        queuedRecordingRequestIDs.insert(requestID)
        recordingStateLock.unlock()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Recording, Error>) in
                performOnMain { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: AudioServiceError.unavailable)
                        return
                    }
                    self.beginRecording(request, requestID: requestID, continuation: continuation)
                }
            }
        }, onCancel: { [weak self] in
            self?.cancelRecording(requestID: requestID)
        })
    }

    public func stopRecording() {
        performOnMain { [weak self] in
            self?.stopRecordingOnMain()
        }
    }

    public func play(recording: Recording) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            performOnMain { [weak self] in
                guard let self else {
                    continuation.resume(throwing: AudioServiceError.unavailable)
                    return
                }
                do {
                    let url = try self.temporaryRecordingURL(for: recording.fileURL)
                    try self.prepareAudioForPlayback()
                    self.stopCurrentPlayer()
                    self.synthesizer.stopSpeaking(at: .immediate)
                    let nextPlayer = try AVAudioPlayer(contentsOf: url)
                    nextPlayer.delegate = self
                    nextPlayer.prepareToPlay()
                    self.player = nextPlayer
                    self.activeAssetID = nil
                    guard nextPlayer.play() else {
                        self.player = nil
                        continuation.resume(throwing: AudioServiceError.playbackFailed("Le lecteur n’a pas démarré"))
                        return
                    }
                    continuation.resume()
                } catch let error as AudioServiceError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: AudioServiceError.playbackFailed(error.localizedDescription))
                }
            }
        }
    }

    public func delete(recording: Recording) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            performOnMain { [weak self] in
                guard let self else {
                    continuation.resume(throwing: AudioServiceError.unavailable)
                    return
                }
                do {
                    let url = try self.temporaryRecordingURL(for: recording.fileURL)
                    if self.player?.url == url {
                        self.stopCurrentPlayer()
                    }
                    if self.fileManager.fileExists(atPath: url.path) {
                        try self.fileManager.removeItem(at: url)
                    }
                    continuation.resume()
                } catch let error as AudioServiceError {
                    continuation.resume(throwing: error)
                } catch {
                    continuation.resume(throwing: AudioServiceError.recordingFailed(error.localizedDescription))
                }
            }
        }
    }

    // MARK: On-device transcription

    public func transcribe(_ recording: Recording, localeIdentifier: String) async throws -> SpeechTranscript {
        let url = try temporaryRecordingURL(for: recording.fileURL)
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw AudioServiceError.permissionDenied(.speechRecognition)
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            throw AudioServiceError.transcriptionUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true

        let requestID = UUID()
        transcriptionStateLock.lock()
        queuedTranscriptionRequestIDs.insert(requestID)
        transcriptionStateLock.unlock()

        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SpeechTranscript, Error>) in
                performOnMain { [weak self] in
                    guard let self else {
                        continuation.resume(throwing: AudioServiceError.unavailable)
                        return
                    }
                    self.beginTranscription(
                        recognizer: recognizer,
                        request: request,
                        requestID: requestID,
                        localeIdentifier: localeIdentifier,
                        continuation: continuation
                    )
                }
            }
        }, onCancel: { [weak self] in
            self?.performOnMain { [weak self] in
                self?.cancelTranscription(requestID: requestID)
            }
        })
    }

    private func beginTranscription(
        recognizer: SFSpeechRecognizer,
        request: SFSpeechRecognitionRequest,
        requestID: UUID,
        localeIdentifier: String,
        continuation: CheckedContinuation<SpeechTranscript, Error>
    ) {
        transcriptionStateLock.lock()
        queuedTranscriptionRequestIDs.remove(requestID)
        let wasCancelled = cancelledTranscriptionRequestIDs.remove(requestID) != nil
        transcriptionStateLock.unlock()

        guard !wasCancelled else {
            continuation.resume(throwing: CancellationError())
            return
        }

        // A single audio adapter owns one Speech task. Starting a new
        // transcription replaces an abandoned one without leaving its caller
        // suspended forever.
        if let previousID = transcriptionRequestID {
            finishTranscription(
                requestID: previousID,
                result: .failure(AudioServiceError.transcriptionFailed("Une transcription est déjà en cours.")),
                cancelTask: true
            )
        }

        transcriptionRequestID = requestID
        transcriptionContinuation = continuation
        transcriptionTask = nil

        let task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.performOnMain { [weak self] in
                self?.handleTranscriptionResult(
                    result,
                    error: error,
                    requestID: requestID,
                    localeIdentifier: localeIdentifier
                )
            }
        }

        // Apple normally invokes the callback asynchronously, but guarding the
        // ID also handles a synchronous failure without retaining a stale task.
        guard transcriptionRequestID == requestID else {
            task.cancel()
            return
        }
        transcriptionTask = task
    }

    private func handleTranscriptionResult(
        _ result: SFSpeechRecognitionResult?,
        error: Error?,
        requestID: UUID,
        localeIdentifier: String
    ) {
        guard transcriptionRequestID == requestID else { return }
        if let error {
            finishTranscription(
                requestID: requestID,
                result: .failure(AudioServiceError.transcriptionFailed(error.localizedDescription)),
                cancelTask: true
            )
            return
        }
        guard let result, result.isFinal else { return }

        let transcription = result.bestTranscription
        let confidences = transcription.segments
            .map(\.confidence)
            .filter { $0 >= 0 }
        let confidence = confidences.isEmpty
            ? nil
            : Double(confidences.reduce(0, +)) / Double(confidences.count)
        finishTranscription(
            requestID: requestID,
            result: .success(SpeechTranscript(
                rawText: transcription.formattedString,
                confidence: confidence,
                isFinal: true,
                localeIdentifier: localeIdentifier
            )),
            cancelTask: false
        )
    }

    private func cancelTranscription(requestID: UUID) {
        if transcriptionRequestID == requestID {
            finishTranscription(
                requestID: requestID,
                result: .failure(CancellationError()),
                cancelTask: true
            )
            return
        }

        // The initial main-queue hop may not have started yet. Record the
        // cancellation for exactly this request; a later request is unaffected.
        transcriptionStateLock.lock()
        if queuedTranscriptionRequestIDs.remove(requestID) != nil {
            cancelledTranscriptionRequestIDs.insert(requestID)
        }
        transcriptionStateLock.unlock()
    }

    private func finishTranscription(
        requestID: UUID,
        result: Result<SpeechTranscript, Error>,
        cancelTask: Bool
    ) {
        guard transcriptionRequestID == requestID else { return }
        let task = transcriptionTask
        let continuation = transcriptionContinuation
        transcriptionTask = nil
        transcriptionContinuation = nil
        transcriptionRequestID = nil
        if cancelTask { task?.cancel() }

        switch result {
        case .success(let transcript): continuation?.resume(returning: transcript)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }

    // MARK: AVAudioRecorderDelegate

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        finishRecording(recorder, successfully: flag)
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let reason = error?.localizedDescription ?? "Erreur d’encodage"
        failRecording(
            recorder,
            with: AudioServiceError.recordingFailed(reason)
        )
    }

    // MARK: AVAudioPlayerDelegate

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard self.player === player else { return }
        self.player = nil
        if let activeAssetID {
            self.activeAssetID = nil
            emit(flag ? .idle : .failed("La lecture audio s’est interrompue."))
        }
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard self.player === player else { return }
        self.player = nil
        activeAssetID = nil
        emit(.failed(error?.localizedDescription ?? "Le fichier audio est illisible."))
    }

    // MARK: Private state and paths

    private func beginRecording(
        _ request: AudioRecordingRequest,
        requestID: UUID,
        continuation: CheckedContinuation<Recording, Error>
    ) {
        recordingStateLock.lock()
        queuedRecordingRequestIDs.remove(requestID)
        let wasCancelled = cancelledRecordingRequestIDs.remove(requestID) != nil
        recordingStateLock.unlock()

        guard !wasCancelled else {
            continuation.resume(throwing: CancellationError())
            return
        }

        guard recorder == nil else {
            continuation.resume(throwing: AudioServiceError.recordingInProgress)
            return
        }
        switch microphonePermissionState() {
        case .authorized:
            break
        case .denied, .restricted:
            continuation.resume(throwing: AudioServiceError.permissionDenied(.microphone))
            return
        default:
            continuation.resume(throwing: AudioServiceError.unavailable)
            return
        }

        var recordingURL: URL?
        do {
            deleteCancelledRecording = false
            try prepareAudioForRecording()
            stopCurrentPlayer()
            synthesizer.stopSpeaking(at: .immediate)
            let id = RecordingID(rawValue: UUID().uuidString)!
            let url = fileManager.temporaryDirectory
                .appendingPathComponent("syllune-recording-\(id.rawValue)", isDirectory: false)
                .appendingPathExtension("m4a")
            recordingURL = url
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            let nextRecorder = try AVAudioRecorder(url: url, settings: settings)
            nextRecorder.delegate = self
            // Install the continuation before asking AVFoundation to start.
            // This makes a synchronous delegate callback and a cancellation
            // observe the same active request and leaves one cleanup path.
            recorder = nextRecorder
            recordingContinuation = continuation
            recordingID = id
            recordingRequestID = requestID
            guard nextRecorder.record(forDuration: TimeInterval(request.maximumDurationSeconds)) else {
                failRecording(
                    nextRecorder,
                    with: AudioServiceError.recordingFailed("Le microphone n’a pas démarré")
                )
                return
            }
        } catch let error as AudioServiceError {
            if let recordingURL, fileManager.fileExists(atPath: recordingURL.path) {
                try? fileManager.removeItem(at: recordingURL)
            }
            deactivateAudioSession()
            continuation.resume(throwing: error)
        } catch {
            if let recordingURL, fileManager.fileExists(atPath: recordingURL.path) {
                try? fileManager.removeItem(at: recordingURL)
            }
            deactivateAudioSession()
            continuation.resume(throwing: AudioServiceError.recordingFailed(error.localizedDescription))
        }
    }

    private func cancelRecording(requestID: UUID) {
        // Mark a queued request synchronously, before posting to the main
        // queue. The begin closure will consume this admission and resume its
        // continuation without ever creating an AVAudioRecorder.
        recordingStateLock.lock()
        if queuedRecordingRequestIDs.remove(requestID) != nil {
            cancelledRecordingRequestIDs.insert(requestID)
        }
        recordingStateLock.unlock()

        performOnMain { [weak self] in
            guard let self, self.recordingRequestID == requestID else { return }
            self.deleteCancelledRecording = true
            self.stopRecordingOnMain()
        }
    }

    private func failRecording(_ recorder: AVAudioRecorder, with error: Error) {
        guard self.recorder === recorder else { return }
        let continuation = recordingContinuation
        self.recorder = nil
        recordingContinuation = nil
        recordingID = nil
        recordingRequestID = nil
        deleteCancelledRecording = false
        if fileManager.fileExists(atPath: recorder.url.path) {
            try? fileManager.removeItem(at: recorder.url)
        }
        deactivateAudioSession()
        continuation?.resume(throwing: error)
    }

    private func finishRecording(_ recorder: AVAudioRecorder, successfully: Bool) {
        guard self.recorder === recorder else { return }
        let continuation = recordingContinuation
        let id = recordingID
        let discard = deleteCancelledRecording
        self.recorder = nil
        recordingContinuation = nil
        recordingID = nil
        recordingRequestID = nil
        deleteCancelledRecording = false
        let duration = max(0, Int((recorder.currentTime * 1_000).rounded()))
        let fileURL = recorder.url
        let exists = fileManager.fileExists(atPath: fileURL.path)
        deactivateAudioSession()

        guard successfully, exists, let id, !discard else {
            if exists { try? fileManager.removeItem(at: fileURL) }
            continuation?.resume(throwing: discard ? CancellationError() : AudioServiceError.recordingFailed("Le fichier temporaire est vide"))
            return
        }
        continuation?.resume(returning: Recording(
            id: id,
            fileURL: fileURL,
            durationMilliseconds: duration
        ))
    }

    private func stopCurrentPlayer() {
        player?.stop()
        player = nil
        activeAssetID = nil
    }

    private func stopRecordingOnMain() {
        guard let recorder else { return }
        recorder.stop()
        // AVAudioRecorder normally calls its delegate synchronously for a
        // manual stop. The identity check handles platforms that deliver the
        // callback on a later main-queue turn.
        if self.recorder === recorder {
            finishRecording(recorder, successfully: true)
        }
    }

    private func emit(_ state: AudioPlaybackState) {
        streamLock.lock()
        let continuations = Array(streamContinuations.values)
        streamLock.unlock()
        continuations.forEach { _ = $0.yield(state) }
    }

    private func assetURL(for asset: AssetReference) throws -> URL {
        let relative = asset.relativePath
        guard !relative.isEmpty,
              !relative.hasPrefix("/"),
              !relative.contains("\\"),
              !relative.split(separator: "/").contains("..") else {
            throw AudioServiceError.invalidAssetURL
        }
        let root = contentRootURL.resolvingSymlinksInPath().standardizedFileURL
        let candidate = root.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPrefix),
              fileManager.fileExists(atPath: candidate.path) else {
            throw AudioServiceError.invalidAssetURL
        }
        return candidate
    }

    private func temporaryRecordingURL(for url: URL) throws -> URL {
        let root = fileManager.temporaryDirectory.resolvingSymlinksInPath().standardizedFileURL
        let candidate = url.resolvingSymlinksInPath().standardizedFileURL
        let rootPrefix = root.path.hasSuffix("/") ? root.path : root.path + "/"
        guard candidate.path.hasPrefix(rootPrefix), fileManager.fileExists(atPath: candidate.path) else {
            throw AudioServiceError.invalidRecordingURL
        }
        return candidate
    }

    private func performOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    // MARK: Platform-specific audio sessions

    private func prepareAudioForPlayback() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
        #endif
    }

    private func prepareAudioForRecording() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func microphonePermissionState() -> PermissionState {
        #if os(iOS)
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return .authorized
        case .denied: return .denied
        case .undetermined: return .notDetermined
        @unknown default: return .unavailable
        }
        #elseif os(macOS)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .unavailable
        }
        #else
        return .unavailable
        #endif
    }
}
