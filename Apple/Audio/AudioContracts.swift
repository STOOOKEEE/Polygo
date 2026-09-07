import Foundation
import PolygoCore

/// A permission state that can be surfaced by the app without importing an
/// Apple framework into PolygoCore.
public enum PermissionState: String, Codable, Hashable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

public enum AudioPermissionKind: String, Codable, Hashable, Sendable {
    case microphone
    case speechRecognition
}

public enum AudioServiceError: Error, LocalizedError, Sendable {
    case permissionDenied(AudioPermissionKind)
    case unavailable
    case voiceUnavailable(String)
    case invalidAssetURL
    case invalidRecordingURL
    case recordingInProgress
    case noRecordingInProgress
    case recordingFailed(String)
    case playbackFailed(String)
    case transcriptionUnavailable
    case transcriptionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(.microphone):
            return "L’accès au microphone est refusé. Autorise-le dans Réglages pour enregistrer ta voix."
        case .permissionDenied(.speechRecognition):
            return "La reconnaissance vocale est refusée. Tu peux continuer avec une auto-évaluation."
        case .unavailable:
            return "L’audio est indisponible sur cet appareil."
        case .voiceUnavailable(let locale):
            return "Aucune voix Mandarin installée pour la langue \(locale)."
        case .invalidAssetURL:
            return "La ressource audio n’est pas accessible dans le contenu embarqué."
        case .invalidRecordingURL:
            return "Cet enregistrement temporaire n’est pas accessible."
        case .recordingInProgress:
            return "Un enregistrement est déjà en cours."
        case .noRecordingInProgress:
            return "Aucun enregistrement n’est en cours."
        case .recordingFailed(let reason):
            return "L’enregistrement n’a pas pu démarrer\(reason.isEmpty ? "." : " : \(reason)")."
        case .playbackFailed(let reason):
            return "La lecture audio a échoué\(reason.isEmpty ? "." : " : \(reason)")."
        case .transcriptionUnavailable:
            return "La transcription locale n’est pas disponible pour cette langue ou cet appareil."
        case .transcriptionFailed(let reason):
            return "La transcription n’a pas abouti\(reason.isEmpty ? "." : " : \(reason)")."
        }
    }
}

public struct AudioRecordingRequest: Codable, Hashable, Sendable {
    public let exerciseID: ExerciseID
    public let localeIdentifier: String
    public let maximumDurationSeconds: Int

    public init(
        exerciseID: ExerciseID,
        localeIdentifier: String = "zh-CN",
        maximumDurationSeconds: Int = 30
    ) {
        self.exerciseID = exerciseID
        self.localeIdentifier = localeIdentifier
        self.maximumDurationSeconds = min(max(1, maximumDurationSeconds), 300)
    }
}

public struct Recording: Codable, Hashable, Sendable, Identifiable {
    public let id: RecordingID
    public let fileURL: URL
    public let durationMilliseconds: Int
    public let createdAt: Date

    public init(id: RecordingID, fileURL: URL, durationMilliseconds: Int, createdAt: Date = Date()) {
        self.id = id
        self.fileURL = fileURL
        self.durationMilliseconds = max(0, durationMilliseconds)
        self.createdAt = createdAt
    }
}

public struct SpeechTranscript: Codable, Hashable, Sendable {
    public let rawText: String
    public let normalizedText: String
    /// This is Apple’s transcription confidence, when segment confidence is
    /// available. It is never a pronunciation, phoneme, or tone score.
    public let confidence: Double?
    public let isFinal: Bool
    public let localeIdentifier: String

    public init(
        rawText: String,
        normalizedText: String? = nil,
        confidence: Double? = nil,
        isFinal: Bool = true,
        localeIdentifier: String = "zh-CN"
    ) {
        self.rawText = rawText
        self.normalizedText = normalizedText ?? TextNormalizer.normalize(rawText)
        if let confidence {
            self.confidence = min(max(confidence, 0), 1)
        } else {
            self.confidence = nil
        }
        self.isFinal = isFinal
        self.localeIdentifier = localeIdentifier
    }
}

public enum AudioPlaybackState: Codable, Hashable, Sendable {
    case idle
    case loading(AssetID)
    case playing(AssetID, progress: Double)
    case stopped
    case failed(String)
}

public enum SpeechRate: String, Codable, Hashable, Sendable, CaseIterable {
    case normal
    case slow

    var avSpeechRate: Float {
        // AVSpeechUtterance rates are deliberately kept inside Apple’s
        // documented useful range. Slow is a teaching aid, not a pitch shift.
        switch self {
        case .normal: return 0.50
        case .slow: return 0.34
        }
    }
}

/// A visual hint attached to a synthesis request. AVSpeechSynthesizer reads
/// the Mandarin text; these markers are retained for the UI and never imply
/// that Apple evaluated the learner’s tone.
public struct ToneMarker: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let tone: Int

    public init(syllableIndex: Int, tone: Int) {
        self.id = max(0, syllableIndex)
        self.tone = min(max(tone, 0), 5)
    }

    public var syllableIndex: Int { id }
}

public struct SpeechSynthesisRequest: Codable, Hashable, Sendable {
    public let text: String
    public let localeIdentifier: String
    public let rate: SpeechRate
    public let toneMarkers: [ToneMarker]

    public init(
        text: String,
        localeIdentifier: String = "zh-CN",
        rate: SpeechRate = .normal,
        toneMarkers: [ToneMarker] = []
    ) {
        self.text = text
        self.localeIdentifier = localeIdentifier
        self.rate = rate
        self.toneMarkers = toneMarkers
    }
}

public protocol AudioService: Sendable {
    func requestMicrophonePermission() async -> PermissionState
    func requestSpeechPermission() async -> PermissionState

    func speak(_ request: SpeechSynthesisRequest) async throws
    func stopSpeaking()

    func play(asset: AssetReference) async throws
    func stopPlayback()
    func playbackStates() -> AsyncStream<AudioPlaybackState>

    /// Starts a temporary capture and returns when the user stops it or the
    /// request reaches its maximum duration. Call `stopRecording()` from the
    /// stop button; cancelling the surrounding task also stops the recorder.
    func record(_ request: AudioRecordingRequest) async throws -> Recording
    func stopRecording()
    func play(recording: Recording) async throws
    func delete(recording: Recording) async throws
    func transcribe(_ recording: Recording, localeIdentifier: String) async throws -> SpeechTranscript
}

public extension AudioService {
    func speak(_ request: SpeechSynthesisRequest) async throws {
        throw AudioServiceError.unavailable
    }

    func stopSpeaking() {}

    func stopRecording() {}

    func play(recording: Recording) async throws {
        throw AudioServiceError.unavailable
    }

    func delete(recording: Recording) async throws {}

    func speak(
        text: String,
        localeIdentifier: String = "zh-CN",
        rate: SpeechRate = .normal,
        toneMarkers: [ToneMarker] = []
    ) async throws {
        try await speak(SpeechSynthesisRequest(
            text: text,
            localeIdentifier: localeIdentifier,
            rate: rate,
            toneMarkers: toneMarkers
        ))
    }
}

/// Adds tone numbers to pinyin for an honest visual cue. Existing diacritics
/// are detected when no explicit tone list is supplied; no audio or score is
/// inferred from this formatting helper.
public enum MandarinToneMarkers {
    private static let toneDigits = ["⁰", "¹", "²", "³", "⁴", "⁵"]

    public static func annotated(_ pinyin: String, toneNumbers: [Int] = []) -> String {
        pinyin.split(whereSeparator: { $0.isWhitespace }).enumerated().map { index, token in
            let syllable = String(token)
            let detected = toneNumbers.indices.contains(index) ? toneNumbers[index] : tone(in: syllable)
            guard detected >= 0, detected <= 5, detected != 0 else { return syllable }
            return syllable + toneDigits[detected]
        }.joined(separator: " ")
    }

    private static func tone(in syllable: String) -> Int {
        let firstTone = "āēīōūǖĀĒĪŌŪǕ"
        let secondTone = "áéíóúǘÁÉÍÓÚǗ"
        let thirdTone = "ǎěǐǒǔǚǍĚǏǑǓǙ"
        let fourthTone = "àèìòùǜÀÈÌÒÙǛ"
        if syllable.contains(where: { firstTone.contains($0) }) { return 1 }
        if syllable.contains(where: { secondTone.contains($0) }) { return 2 }
        if syllable.contains(where: { thirdTone.contains($0) }) { return 3 }
        if syllable.contains(where: { fourthTone.contains($0) }) { return 4 }
        return 0
    }
}
