import SwiftUI
import PolygoCore

/// A complete speaking exercise control that can be embedded in a lesson or a
/// phrase detail screen. It owns only ephemeral UI state; the domain engine
/// remains responsible for evaluating the resulting ExerciseAnswer.
public struct SpeechPracticeView: View {
    public let exercise: SpeakingExercise
    public let audio: any AudioService
    public let pronunciation: any SpeechPronunciationService
    @Binding public var answer: ExerciseAnswer?
    public let onRecordingCreated: ((RecordingID) -> Void)?

    @State private var microphonePermission: PermissionState = .notDetermined
    @State private var speechPermission: PermissionState = .notDetermined
    @State private var recording: Recording?
    @State private var transcript: SpeechTranscript?
    @State private var pronunciationResult: SpeechPronunciationResult?
    @State private var isRecording = false
    @State private var isAnalyzing = false
    @State private var recordingStartedAt: Date?
    @State private var selectedRate: SpeechRate = .normal
    @State private var isModelPlaying = false
    @State private var modelTask: Task<Void, Never>?
    @State private var showEvaluationDetails = false
    @State private var statusMessage: String?
    @State private var captureTask: Task<Void, Never>?
    @State private var analysisTask: Task<Void, Never>?

    public init(
        exercise: SpeakingExercise,
        audio: any AudioService,
        answer: Binding<ExerciseAnswer?>,
        pronunciation: (any SpeechPronunciationService)? = nil,
        onRecordingCreated: ((RecordingID) -> Void)? = nil
    ) {
        self.exercise = exercise
        self.audio = audio
        self.pronunciation = pronunciation ?? UnconfiguredSpeechPronunciationService()
        self._answer = answer
        self.onRecordingCreated = onRecordingCreated
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            referenceCard
            modelControls
            recordingControls

            if transcript != nil || pronunciationResult != nil {
                DisclosureGroup("Voir les résultats", isExpanded: $showEvaluationDetails) {
                    VStack(alignment: .leading, spacing: 12) {
                        if let transcript {
                            transcriptCard(transcript)
                        }
                        if let pronunciationResult {
                            pronunciationResultCard(pronunciationResult)
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
        .onAppear(perform: synchronizeAnswerState)
        .onChange(of: answer) { _, _ in
            synchronizeAnswerState()
        }
        .onDisappear {
            // A lesson transition must never leave the microphone or model
            // voice running. The recording is intentionally temporary.
            modelTask?.cancel()
            modelTask = nil
            isModelPlaying = false
            captureTask?.cancel()
            captureTask = nil
            analysisTask?.cancel()
            analysisTask = nil
            audio.stopSpeaking()
            audio.stopRecording()
            audio.stopPlayback()

            let ephemeralRecording = recording
            recording = nil
            transcript = nil
            pronunciationResult = nil
            isAnalyzing = false
            showEvaluationDetails = false
            if let ephemeralRecording {
                Task {
                    try? await audio.delete(recording: ephemeralRecording)
                }
            }
        }
    }

    private var referenceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: speakReference) {
                VStack(spacing: 4) {
                    Text(mandarinReferenceText)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                    Text(exercise.referencePinyin)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .contentShape(Rectangle())
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(mandarinReferenceText), écouter la phrase cible en mandarin")
            .accessibilityHint("Lit la phrase cible avec la voix locale")

            DisclosureGroup("Comment comparer ma voix") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repères de ton : \(MandarinToneMarkers.annotated(exercise.referencePinyin))")
                    Text("Les repères et la transcription aident à comparer le texte. Ils ne mesurent pas tes phonèmes ni tes tons.")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
            .font(.caption.weight(.semibold))
            .tint(.secondary)
            .accessibilityLabel("Comment comparer ma voix. Les repères et la transcription aident à comparer le texte. Ils ne mesurent pas tes phonèmes ni tes tons.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modelControls: some View {
        HStack(alignment: .center, spacing: 8) {
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
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityIdentifier("model-audio-toggle")
            .accessibilityLabel(isModelPlaying ? "Arrêter le modèle" : "Écouter le modèle")
            .accessibilityHint("Lit uniquement la phrase cible en mandarin, à la vitesse choisie")

            Picker("Vitesse", selection: $selectedRate) {
                Text("Normale").tag(SpeechRate.normal)
                Text("Lente").tag(SpeechRate.slow)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)
            .accessibilityHint("Choisis une vitesse de lecture du modèle")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var recordingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ta voix")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    recordButton
                    recordingDescription
                }
                VStack(alignment: .leading, spacing: 8) {
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

            if isAnalyzing {
                Label("Analyse de prononciation en cours…", systemImage: "waveform")
                    .font(.callout)
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("speech-analysis-status")
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

    private func pronunciationResultCard(_ result: SpeechPronunciationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let report = result.report {
                Label(
                    pronunciationVerdictTitle(report.verdict),
                    systemImage: pronunciationVerdictIcon(report.verdict)
                )
                .font(.headline)
                .foregroundStyle(pronunciationVerdictColor(report.verdict))
                Text("Fournisseur : \(providerTitle(report.provider))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let providerScore = report.providerScore {
                    Text("Score fourni par le moteur : \(scoreLabel(providerScore))")
                        .font(.callout.weight(.medium))
                } else {
                    Text("Le moteur n’a pas fourni de score global.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !report.words.isEmpty {
                    Text("Mots")
                        .font(.subheadline.weight(.semibold))
                    ForEach(report.words) { word in
                        assessmentRow(
                            expected: word.expected,
                            observed: word.observed,
                            score: word.score
                        )
                    }
                }
                if !report.sounds.isEmpty {
                    Text("Sons")
                        .font(.subheadline.weight(.semibold))
                    ForEach(report.sounds) { sound in
                        assessmentRow(
                            expected: sound.expected,
                            observed: sound.observed,
                            score: sound.score
                        )
                    }
                }
                if !report.tones.isEmpty {
                    Text("Tons")
                        .font(.subheadline.weight(.semibold))
                    ForEach(report.tones) { tone in
                        HStack {
                            Text("Attendu \(tone.expected.map(String.init) ?? "non communiqué")")
                            Spacer()
                            Text("Observé \(tone.observed.map(String.init) ?? "non communiqué")")
                            Text(scoreLabel(tone.score))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }
                if report.verdict == .inconclusive {
                    Text("Le moteur ne permet pas de conclure. Aucun résultat n’est marqué comme correct.")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } else {
                Label(
                    pronunciationStatusTitle(result.status),
                    systemImage: pronunciationStatusIcon(result.status)
                )
                .font(.headline)
                .foregroundStyle(.orange)
                Text(result.message ?? "Aucune analyse exploitable n’est disponible. Tu peux passer cet exercice sans le noter.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Aucun score de prononciation n’est déduit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityIdentifier("speech-pronunciation-result")
        .accessibilityElement(children: .combine)
    }

    private func assessmentRow(expected: String, observed: String?, score: Double?) -> some View {
        HStack {
            Text(expected)
            Spacer()
            Text(observed ?? "non communiqué")
                .foregroundStyle(.secondary)
            Text(scoreLabel(score))
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private func scoreLabel(_ score: Double?) -> String {
        guard let score else { return "score non communiqué" }
        return "\(Int((score * 100).rounded())) %"
    }

    private func providerTitle(_ provider: SpeechPronunciationProvider) -> String {
        switch provider {
        case .iflytek: return "iFlytek"
        case .speechSuper: return "SpeechSuper"
        case .offline: return "Hors ligne"
        }
    }

    private func pronunciationVerdictTitle(_ verdict: SpeechPronunciationVerdict) -> String {
        switch verdict {
        case .pass: return "Prononciation réussie"
        case .needsPractice: return "Prononciation à corriger"
        case .inconclusive: return "Résultat incertain"
        }
    }

    private func pronunciationVerdictIcon(_ verdict: SpeechPronunciationVerdict) -> String {
        switch verdict {
        case .pass: return "checkmark.circle.fill"
        case .needsPractice: return "arrow.counterclockwise.circle.fill"
        case .inconclusive: return "questionmark.circle.fill"
        }
    }

    private func pronunciationVerdictColor(_ verdict: SpeechPronunciationVerdict) -> Color {
        switch verdict {
        case .pass: return .green
        case .needsPractice: return .orange
        case .inconclusive: return .orange
        }
    }

    private func pronunciationStatusTitle(_ status: SpeechPronunciationStatus) -> String {
        switch status {
        case .completed: return "Analyse terminée"
        case .unconfigured: return "Analyse non configurée"
        case .unavailable: return "Analyse indisponible"
        case .failed: return "Analyse impossible"
        }
    }

    private func pronunciationStatusIcon(_ status: SpeechPronunciationStatus) -> String {
        switch status {
        case .completed: return "questionmark.circle"
        case .unconfigured: return "gearshape"
        case .unavailable: return "wifi.slash"
        case .failed: return "exclamationmark.triangle"
        }
    }

    private var recordButton: some View {
        Button(action: isRecording ? stopRecording : startRecording) {
            VStack(spacing: 7) {
                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 27, weight: .semibold))
                Text(isRecording ? "Arrêter" : "Enregistrer")
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .foregroundStyle(.white)
            .frame(width: 100, height: 100)
            .background(isRecording ? Color.red : Color.accentColor, in: Circle())
            .shadow(color: .black.opacity(0.14), radius: 5, y: 3)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Arrêter" : "Enregistrer")
        .accessibilityHint(isRecording ? "Arrête la capture et prépare l’analyse" : "Demande l’accès au microphone puis démarre la capture")
    }

    private var recordingDescription: some View {
        Text(isRecording ? "Parle maintenant…" : (isAnalyzing ? "Analyse en cours…" : "Enregistre puis analyse."))
            .font(.callout.weight(.semibold))
            .foregroundStyle(.secondary)
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
        guard !isRecording, !isAnalyzing else { return }
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
                statusMessage = microphoneMessage(for: permission)
                return
            }
            guard !Task.isCancelled else { return }

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
                await analyze(saved)
            } catch is CancellationError {
                isRecording = false
                recordingStartedAt = nil
            } catch {
                isRecording = false
                recordingStartedAt = nil
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
        analysisTask?.cancel()
        analysisTask = nil
        isAnalyzing = false
        let oldRecording = recording
        recording = nil
        transcript = nil
        pronunciationResult = nil
        answer = nil
        showEvaluationDetails = false
        guard let oldRecording else { return }
        Task {
            try? await audio.delete(recording: oldRecording)
        }
    }

    private func synchronizeAnswerState() {
        switch answer {
        case .some(.speech(let savedAnswer)):
            let restoredTranscript = SpeechTranscript(
                rawText: savedAnswer.transcript,
                normalizedText: savedAnswer.normalizedTranscript,
                confidence: savedAnswer.confidence,
                isFinal: true,
                localeIdentifier: savedAnswer.localeIdentifier
            )
            // A restored SpeechAnswer contains the transcription metadata, but
            // its temporary recording may no longer exist. Rebuild only the
            // displayable result and leave `recording` untouched.
            transcript = restoredTranscript
            showEvaluationDetails = true
            if let assessment = savedAnswer.pronunciationAssessment {
                if pronunciationResult?.report?.persistedAssessment != assessment {
                    pronunciationResult = restoredResult(from: assessment)
                }
                statusMessage = assessment.verdict == .pass
                    ? "Résultat de prononciation restauré."
                    : "Résultat de prononciation restauré : à corriger."
            } else {
                pronunciationResult = nil
                statusMessage = "Transcription restaurée. Elle ne fournit pas de score de prononciation."
            }

        case .some(.selfRating):
            transcript = nil
            pronunciationResult = nil
            showEvaluationDetails = true
            statusMessage = "Ancienne auto-évaluation restaurée. Elle ne constitue pas une note de prononciation."

        default:
            if recording == nil && !isAnalyzing {
                transcript = nil
                pronunciationResult = nil
                showEvaluationDetails = false
                statusMessage = nil
            } else {
                showEvaluationDetails = transcript != nil || pronunciationResult != nil
            }
        }
    }

    private func restoredResult(from assessment: SpeechPronunciationAssessment) -> SpeechPronunciationResult {
        guard let provider = SpeechPronunciationProvider(rawValue: assessment.providerID) else {
            return .unavailable(message: "Le fournisseur de ce résultat n’est plus disponible.")
        }
        return .completed(SpeechPronunciationReport(
            provider: provider,
            verdict: assessment.verdict,
            providerScore: assessment.providerScore
        ))
    }

    private func analyze(_ recording: Recording) async {
        analysisTask?.cancel()
        isAnalyzing = true
        showEvaluationDetails = true
        statusMessage = nil
        analysisTask = Task { @MainActor in
            async let localTranscript = transcribe(recording)
            let result = await pronunciation.evaluate(recording: recording, exercise: exercise)
            let capturedTranscript = await localTranscript
            guard !Task.isCancelled else { return }
            transcript = capturedTranscript
            pronunciationResult = result
            isAnalyzing = false
            analysisTask = nil

            guard result.status == .completed,
                  let report = result.report,
                  report.isAutomaticallyEvaluable else {
                answer = nil
                statusMessage = result.message ?? analysisStatusMessage(result.status)
                return
            }
            answer = .speech(SpeechAnswer(
                transcript: capturedTranscript?.rawText ?? "",
                normalizedTranscript: capturedTranscript?.normalizedText ?? "",
                confidence: capturedTranscript?.confidence,
                localeIdentifier: capturedTranscript?.localeIdentifier ?? "zh-CN",
                recordingID: recording.id,
                pronunciationAssessment: report.persistedAssessment
            ))
            statusMessage = report.verdict == .pass
                ? "Prononciation réussie. Le résultat sera enregistré automatiquement."
                : "Prononciation à corriger. Le résultat sera enregistré automatiquement."
        }
        await analysisTask?.value
    }

    private func transcribe(_ recording: Recording) async -> SpeechTranscript? {
        guard !Task.isCancelled else { return nil }
        speechPermission = await audio.requestSpeechPermission()
        guard !Task.isCancelled else { return nil }
        guard speechPermission == .authorized else {
            return nil
        }
        do {
            let result = try await audio.transcribe(recording, localeIdentifier: "zh-CN")
            guard !Task.isCancelled else { return nil }
            return result
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private func analysisStatusMessage(_ status: SpeechPronunciationStatus) -> String {
        switch status {
        case .completed:
            return "Le fournisseur n’a pas permis de conclure. Tu peux passer cet exercice sans le noter."
        case .unconfigured:
            return "Aucun fournisseur de prononciation n’est configuré. Tu peux passer cet exercice sans le noter."
        case .unavailable:
            return "L’analyse de prononciation est indisponible. Tu peux passer cet exercice sans le noter."
        case .failed:
            return "L’analyse de prononciation a échoué. Tu peux passer cet exercice sans le noter."
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
            return "Microphone refusé. Autorise-le dans Réglages, ou passe cet exercice sans l’évaluer."
        case .restricted:
            return "Microphone restreint sur cet appareil. Passe cet exercice sans l’évaluer."
        case .unavailable:
            return "Microphone indisponible sur cet appareil. Passe cet exercice sans l’évaluer."
        default:
            return "Microphone non disponible. Passe cet exercice sans l’évaluer."
        }
    }

}
