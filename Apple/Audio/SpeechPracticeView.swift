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

            if let transcript {
                transcriptCard(transcript)
            }

            if isSelfEvaluationAvailable && exercise.allowSelfRating {
                selfEvaluationCard
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLiveRegion(.polite)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            // A lesson transition must never leave the microphone recording.
            captureTask?.cancel()
            captureTask = nil
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
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.referenceText)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .accessibilityAddTraits(.isHeader)
            Text(exercise.referencePinyin)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text("Repères de ton : \(MandarinToneMarkers.annotated(exercise.referencePinyin))")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Les repères et la transcription aident à comparer le texte. Ils ne mesurent pas tes phonèmes ni tes tons.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modelControls: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: playModel) {
                Label("Écouter le modèle", systemImage: "speaker.wave.2.fill")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Lit la phrase en mandarin, à la vitesse choisie")

            Button {
                audio.stopSpeaking()
                audio.stopPlayback()
                statusMessage = "Lecture du modèle arrêtée."
            } label: {
                Label("Arrêter le modèle", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)

            Picker("Vitesse", selection: $selectedRate) {
                Text("Normale").tag(SpeechRate.normal)
                Text("Lente").tag(SpeechRate.slow)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 230)
        }
    }

    private var recordingControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: isRecording ? stopRecording : startRecording) {
                    Label(
                        isRecording ? "Arrêter" : "Enregistrer",
                        systemImage: isRecording ? "stop.fill" : "mic.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(isRecording ? .red : .accentColor)
                .accessibilityHint(isRecording ? "Arrête et prépare la transcription" : "Demande l’accès au microphone puis démarre la capture")

                if let recording {
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
            } else if recording != nil {
                Text("Le fichier reste temporaire et sera supprimé en quittant cet exercice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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
            HStack(spacing: 8) {
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

    private func playModel() {
        statusMessage = nil
        Task { @MainActor in
            do {
                if let asset = exercise.referenceAudio {
                    do {
                        try await audio.play(asset: asset)
                    } catch {
                        // Content audio is optional. Every speaking exercise
                        // still has a direct AVSpeechSynthesizer fallback.
                        try await audio.speak(
                            text: exercise.referenceText,
                            localeIdentifier: "zh-CN",
                            rate: selectedRate
                        )
                    }
                } else {
                    try await audio.speak(
                        text: exercise.referenceText,
                        localeIdentifier: "zh-CN",
                        rate: selectedRate
                    )
                }
                statusMessage = "Modèle lu à vitesse \(selectedRate == .normal ? "normale" : "lente")."
            } catch {
                statusMessage = error.localizedDescription
            }
        }
    }

    private func startRecording() {
        guard !isRecording else { return }
        statusMessage = nil
        captureTask?.cancel()
        captureTask = Task { @MainActor in
            defer { captureTask = nil }
            let permission = await audio.requestMicrophonePermission()
            microphonePermission = permission
            guard permission == .authorized else {
                isSelfEvaluationAvailable = true
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
            do {
                let saved = try await audio.record(request)
                guard !Task.isCancelled else {
                    try? await audio.delete(recording: saved)
                    return
                }
                recording = saved
                isRecording = false
                recordingStartedAt = nil
                onRecordingCreated?(saved.id)
                await transcribe(saved)
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
            } catch {
                statusMessage = "Réécoute indisponible : \(error.localizedDescription)"
            }
        }
    }

    private func discardRecording() {
        guard let oldRecording = recording else { return }
        recording = nil
        transcript = nil
        answer = nil
        isSelfEvaluationAvailable = false
        Task {
            try? await audio.delete(recording: oldRecording)
        }
    }

    private func transcribe(_ recording: Recording) async {
        speechPermission = await audio.requestSpeechPermission()
        guard speechPermission == .authorized else {
            isSelfEvaluationAvailable = true
            statusMessage = speechMessage(for: speechPermission)
            return
        }
        do {
            let result = try await audio.transcribe(recording, localeIdentifier: "zh-CN")
            transcript = result
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
        } catch {
            isSelfEvaluationAvailable = true
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
