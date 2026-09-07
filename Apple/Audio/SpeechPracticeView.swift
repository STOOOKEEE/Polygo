import SwiftUI
import PolygoCore

/// A complete speaking exercise control that can be embedded in a lesson or a
/// phrase detail screen. It owns only ephemeral UI state; the domain engine
/// remains responsible for evaluating the resulting ExerciseAnswer.
public struct SpeechPracticeView: View {
    public let exercise: SpeakingExercise
    public let audio: any AudioService
    @Binding public var answer: ExerciseAnswer?
    public let onRecordingCreated: ((RecordingID) -> Void)?

    @State private var microphonePermission: PermissionState = .notDetermined
    @State private var speechPermission: PermissionState = .notDetermined
    @State private var recording: Recording?
    @State private var transcript: SpeechTranscript?
    @State private var isRecording = false
    @State private var recordingStartedAt: Date?
    @State private var isSelfEvaluationAvailable = false
    @State private var selectedRate: SpeechRate = .normal
    @State private var isModelPlaying = false
    @State private var modelTask: Task<Void, Never>?
    @State private var showEvaluationDetails = false
    @State private var statusMessage: String?
    @State private var captureTask: Task<Void, Never>?

    public init(
        exercise: SpeakingExercise,
        audio: any AudioService,
        answer: Binding<ExerciseAnswer?>,
        onRecordingCreated: ((RecordingID) -> Void)? = nil
    ) {
        self.exercise = exercise
        self.audio = audio
        self._answer = answer
        self.onRecordingCreated = onRecordingCreated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            referenceCard
            modelControls
            recordingControls

            if transcript != nil || (isSelfEvaluationAvailable && exercise.allowSelfRating) {
                DisclosureGroup("Voir les résultats", isExpanded: $showEvaluationDetails) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let transcript {
                            transcriptCard(transcript)
                        }

                        if isSelfEvaluationAvailable && exercise.allowSelfRating {
                            selfEvaluationCard
                        }
                    }
                    .padding(.top, 8)
                }
                .font(.headline)
                .accessibilityIdentifier("speech-evaluation-details")
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("speech-practice-status")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: selectedRate) { _, _ in
            // A rate change must not leave the old model utterance playing at
            // a different speed from the selected control.
            if isModelPlaying {
                stopModelPlayback(message: "Lecture du modèle arrêtée.")
            }
        }
        .onDisappear {
            // A lesson transition must never leave the microphone or model
            // voice running. The recording is intentionally temporary.
            modelTask?.cancel()
            modelTask = nil
            isModelPlaying = false
            captureTask?.cancel()
            captureTask = nil
            audio.stopSpeaking()
            audio.stopRecording()
            audio.stopPlayback()

            let ephemeralRecording = recording
            recording = nil
            transcript = nil
            if let ephemeralRecording {
                Task {
                    try? await audio.delete(recording: ephemeralRecording)
                }
            }
        }
    }

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Phrase cible", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button(action: speakReference) {
                Text(mandarinReferenceText)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .accessibilityAddTraits(.isHeader)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mandarinReferenceText), écouter la phrase cible en mandarin")
            .accessibilityHint("Lit la phrase cible avec la voix locale")

            VStack(alignment: .leading, spacing: 4) {
                Text("Pinyin")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(exercise.referencePinyin)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text("Repères de ton : \(MandarinToneMarkers.annotated(exercise.referencePinyin))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Les repères et la transcription aident à comparer le texte. Ils ne mesurent pas tes phonèmes ni tes tons.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var modelControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Modèle")
                .font(.headline)

            Button {
                if isModelPlaying {
                    stopModelPlayback(message: "Lecture du modèle arrêtée.")
                } else {
                    playModel()
                }
            } label: {
                Label(
                    isModelPlaying ? "Arrêter" : "Écouter",
                    systemImage: isModelPlaying ? "stop.fill" : "speaker.wave.2.fill"
                )
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("model-audio-toggle")
            .accessibilityLabel(isModelPlaying ? "Arrêter le modèle" : "Écouter le modèle")
            .accessibilityHint("Lit uniquement la phrase cible en mandarin, à la vitesse choisie")

            Picker("Vitesse", selection: $selectedRate) {
                Text("Normale").tag(SpeechRate.normal)
                Text("Lente").tag(SpeechRate.slow)
            }
            .pickerStyle(.segmented)
            .accessibilityHint("Choisis une vitesse de lecture du modèle")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recordingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ta voix")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 16) {
                    recordButton
                    recordingDescription
                }
                VStack(alignment: .leading, spacing: 10) {
                    recordButton
                    recordingDescription
                }
            }

            if isRecording {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Label(
                        "\(Int(context.date.timeIntervalSince(recordingStartedAt ?? context.date))) s · Enregistrement en cours…",
                        systemImage: "waveform"
                    )
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.red)
                }
            }

            if let recording {
                HStack(spacing: 10) {
                    Button {
                        replay(recording)
                    } label: {
                        Label("Réécouter", systemImage: "arrow.clockwise.circle")
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive, action: discardRecording) {
                        Label("Supprimer", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Text("Le fichier reste temporaire et sera supprimé en quittant cet exercice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transcriptCard(_ transcript: SpeechTranscript) -> some View {
        let matches = transcriptMatches(transcript)
        return VStack(alignment: .leading, spacing: 8) {
            Label("Transcription locale", systemImage: "text.quote")
                .font(.headline)
            Text(transcript.rawText.isEmpty ? "Aucun texte reconnu." : transcript.rawText)
                .font(.body)
            if let confidence = transcript.confidence {
                Text("Confiance de transcription Apple : \(Int((confidence * 100).rounded())) %")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Confiance de transcription non fournie par Apple.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(matches
                 ? "Le texte reconnu correspond à la phrase attendue. Cela compare l’orthographe transcrite uniquement ; aucune note de prononciation ou de ton n’est calculée."
                 : "Le texte reconnu diffère de la phrase attendue. Réécoute le modèle et réessaie ; cette comparaison ne mesure ni les phonèmes ni les tons.")
                .font(.callout)
                .foregroundStyle(matches ? .green : .orange)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var selfEvaluationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Auto-évaluation")
                .font(.headline)
            Text("La transcription locale n’est pas disponible ou ne confirme pas la phrase. Choisis ton ressenti ; aucun score de ton n’est déduit.")
                .font(.callout)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(SelfRating.allCases, id: \.self) { rating in
                    Button(selfRatingLabel(rating)) {
                        answer = .selfRating(rating)
                        statusMessage = "Auto-évaluation enregistrée : \(selfRatingLabel(rating))."
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recordButton: some View {
        Button(action: isRecording ? stopRecording : startRecording) {
            VStack(spacing: 7) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 27, weight: .semibold))
                Text(isRecording ? "Arrêter" : "Enregistrer")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(.white)
            .frame(width: 116, height: 116)
            .background(isRecording ? Color.red : Color.accentColor, in: Circle())
            .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Arrêter" : "Enregistrer")
        .accessibilityHint(isRecording ? "Arrête la capture et prépare la transcription" : "Demande l’accès au microphone puis démarre la capture")
    }

    private var recordingDescription: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isRecording ? "Parle maintenant…" : "Enregistre la phrase cible")
                .font(.body.weight(.semibold))
            Text(isRecording
                 ? "Tu peux arrêter quand tu as fini."
                 : "Tu pourras réécouter ta voix et demander une transcription locale.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mandarinReferenceText: String {
        let target = PolygoCore.MandarinSpeechText.target(from: exercise.referenceText)
        return target.isEmpty ? exercise.referenceText.trimmingCharacters(in: .whitespacesAndNewlines) : target
    }

    private func speakReference() {
        if isModelPlaying {
            stopModelPlayback(message: "Lecture du modèle arrêtée.")
        } else {
            playModel()
        }
    }

    private func playModel() {
        guard !isModelPlaying else { return }
        let target = PolygoCore.MandarinSpeechText.target(from: exercise.referenceText)
        guard !target.isEmpty else {
            statusMessage = "Aucun texte mandarin à lire."
            return
        }

        modelTask?.cancel()
        audio.stopSpeaking()
        audio.stopPlayback()
        statusMessage = nil
        isModelPlaying = true

        modelTask = Task { @MainActor in
            do {
                if let asset = exercise.referenceAudio, selectedRate == .normal {
                    do {
                        try await audio.play(asset: asset)
                        guard !Task.isCancelled else {
                            isModelPlaying = false
                            modelTask = nil
                            return
                        }
                        // AudioService.play starts an AVAudioPlayer and returns
                        // once it is accepted. Keep the toggle in its stop
                        // state until the learner taps it or leaves the view.
                        statusMessage = "Modèle lancé à vitesse normale."
                        modelTask = nil
                        return
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        // Bundled audio is optional. Fall back to the local
                        // Mandarin voice when the asset is unavailable.
                    }
                }

                try await audio.speak(
                    text: target,
                    localeIdentifier: "zh-CN",
                    rate: selectedRate
                )
                guard !Task.isCancelled else {
                    isModelPlaying = false
                    modelTask = nil
                    return
                }
                isModelPlaying = false
                modelTask = nil
                statusMessage = "Modèle lu à vitesse \(selectedRate == .normal ? "normale" : "lente")."
            } catch is CancellationError {
                if isModelPlaying {
                    statusMessage = "Lecture du modèle arrêtée."
                }
                isModelPlaying = false
                modelTask = nil
            } catch {
                isModelPlaying = false
                modelTask = nil
                statusMessage = error.localizedDescription
            }
        }
    }

    private func stopModelPlayback(message: String? = nil) {
        modelTask?.cancel()
        modelTask = nil
        audio.stopSpeaking()
        audio.stopPlayback()
        isModelPlaying = false
        if let message {
            statusMessage = message
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        stopModelPlayback()
        statusMessage = nil
        captureTask?.cancel()
        captureTask = Task { @MainActor in
            defer { captureTask = nil }
            guard !Task.isCancelled else { return }
            let permission = await audio.requestMicrophonePermission()
            // Leaving the exercise while the system permission prompt is
            // visible must not fall through into recorder setup when the
            // prompt eventually completes.
            guard !Task.isCancelled else { return }
            microphonePermission = permission
            guard permission == .authorized else {
                isSelfEvaluationAvailable = true
                showEvaluationDetails = true
                statusMessage = microphoneMessage(for: permission)
                return
            }
            guard !Task.isCancelled else { return }

            isSelfEvaluationAvailable = false
            discardRecording()
            isRecording = true
            recordingStartedAt = Date()
            let request = AudioRecordingRequest(
                exerciseID: exercise.header.id,
                localeIdentifier: "zh-CN",
                maximumDurationSeconds: 30
            )
            // Keep this check immediately before the async adapter call. The
            // adapter also has a request admission token for cancellation that
            // races this check with its main-queue setup.
            guard !Task.isCancelled else {
                isRecording = false
                recordingStartedAt = nil
                return
            }
            do {
                let saved = try await audio.record(request)
                guard !Task.isCancelled else {
                    isRecording = false
                    recordingStartedAt = nil
                    try? await audio.delete(recording: saved)
                    return
                }
                recording = saved
                isRecording = false
                recordingStartedAt = nil
                onRecordingCreated?(saved.id)
                await transcribe(saved)
            } catch is CancellationError {
                isRecording = false
                recordingStartedAt = nil
            } catch {
                isRecording = false
                recordingStartedAt = nil
                isSelfEvaluationAvailable = true
                statusMessage = error.localizedDescription
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }
        statusMessage = "Arrêt de l’enregistrement…"
        audio.stopRecording()
    }

    private func replay(_ recording: Recording) {
        Task { @MainActor in
            do {
                try await audio.play(recording: recording)
                statusMessage = "Réécoute lancée."
            } catch is CancellationError {
                statusMessage = "Réécoute arrêtée."
            } catch {
                statusMessage = "Réécoute indisponible : \(error.localizedDescription)"
            }
        }
    }

    private func discardRecording() {
        let oldRecording = recording
        recording = nil
        transcript = nil
        answer = nil
        isSelfEvaluationAvailable = false
        guard let oldRecording else { return }
        Task {
            try? await audio.delete(recording: oldRecording)
        }
    }

    private func transcribe(_ recording: Recording) async {
        guard !Task.isCancelled else { return }
        speechPermission = await audio.requestSpeechPermission()
        guard !Task.isCancelled else { return }
        guard speechPermission == .authorized else {
            isSelfEvaluationAvailable = true
            statusMessage = speechMessage(for: speechPermission)
            return
        }
        do {
            let result = try await audio.transcribe(recording, localeIdentifier: "zh-CN")
            guard !Task.isCancelled else { return }
            transcript = result
            showEvaluationDetails = true
            answer = .speech(SpeechAnswer(
                transcript: result.rawText,
                normalizedTranscript: result.normalizedText,
                confidence: result.confidence,
                localeIdentifier: result.localeIdentifier,
                recordingID: recording.id
            ))
            isSelfEvaluationAvailable = result.rawText.isEmpty || !transcriptMatches(result)
            statusMessage = result.rawText.isEmpty
                ? "Aucun texte n’a été reconnu. Tu peux choisir une auto-évaluation."
                : "Transcription prête à comparer."
        } catch is CancellationError {
            // The capture task is cancelled when the exercise disappears.
        } catch {
            guard !Task.isCancelled else { return }
            isSelfEvaluationAvailable = true
            showEvaluationDetails = true
            statusMessage = error.localizedDescription + " Tu peux choisir une auto-évaluation."
        }
    }

    private func transcriptMatches(_ transcript: SpeechTranscript) -> Bool {
        let candidate = TextNormalizer.normalize(transcript.normalizedText.isEmpty ? transcript.rawText : transcript.normalizedText)
        guard !candidate.isEmpty else { return false }
        let expected = exercise.acceptedTranscripts.isEmpty
            ? [exercise.referenceText]
            : exercise.acceptedTranscripts
        return expected.contains { TextNormalizer.normalize($0) == candidate }
    }

    private func microphoneMessage(for permission: PermissionState) -> String {
        switch permission {
        case .denied:
            return "Microphone refusé. Autorise-le dans Réglages, ou utilise l’auto-évaluation."
        case .restricted:
            return "Microphone restreint sur cet appareil. Utilise l’auto-évaluation."
        case .unavailable:
            return "Microphone indisponible sur cet appareil. Utilise l’auto-évaluation."
        default:
            return "Microphone non disponible. Utilise l’auto-évaluation."
        }
    }

    private func speechMessage(for permission: PermissionState) -> String {
        switch permission {
        case .denied:
            return "Reconnaissance vocale refusée. Utilise l’auto-évaluation ; aucun score de ton ne sera inventé."
        case .restricted:
            return "Reconnaissance vocale restreinte. Utilise l’auto-évaluation."
        case .unavailable:
            return "Transcription locale indisponible. Utilise l’auto-évaluation."
        default:
            return "Transcription locale indisponible. Utilise l’auto-évaluation."
        }
    }

    private func selfRatingLabel(_ rating: SelfRating) -> String {
        switch rating {
        case .again: return "À retravailler"
        case .hard: return "Difficile"
        case .good: return "À l’aise"
        case .easy: return "Très à l’aise"
        }
    }
}
