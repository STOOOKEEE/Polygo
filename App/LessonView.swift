import SwiftUI
import PolygoCore
import PolygoApple

public struct LessonView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    public let lessonID: LessonID
    @State private var lesson: LessonDocument?
    @State private var currentIndex = 0
    @State private var answer: ExerciseAnswer?
    @State private var evaluation: ExerciseEvaluation?
    @State private var answered: [ExerciseID: ExerciseEvaluation] = [:]
    @State private var didStart = false
    @State private var didRestore = false
    @State private var isEvaluating = false
    @State private var automaticEvaluationTask: Task<Void, Never>?
    @State private var isFinalizing = false
    @State private var finished = false
    @State private var preambleExpanded = false
    @State private var dialogueDrafts: [BlockID: String] = [:]
    @State private var dialogueResults: [BlockID: Bool] = [:]

    public init(lessonID: LessonID) { self.lessonID = lessonID }

    private var exercises: [(BlockID, ExerciseSpec)] {
        lesson?.blocks.compactMap { block in
            if case .exercise(let value) = block { return (value.id, value.spec) }
            return nil
        } ?? []
    }

    public var body: some View {
        Group {
            if let lesson {
                if finished { completionView(lesson) }
                else if exercises.isEmpty { ContentUnavailableView("Cette leçon n’a pas d’exercice", systemImage: "rectangle.and.pencil.and.ellipsis") }
                else if currentIndex < exercises.count { exerciseView(lesson, block: exercises[currentIndex]) }
                else { ProgressView("Enregistrement de la leçon…") }
            } else {
                ProgressView("Chargement de la leçon…")
            }
        }
        .background(SylluneColor.canvas)
        .navigationTitle(lesson?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        #endif
        .task {
            lesson = await model.loadLesson(lessonID)
            restoreSavedStateIfNeeded()
            autoEvaluateSpeechIfReady(answer)
            if !didStart {
                didStart = true
                // NavigationLink destinations already live inside a tab's
                // NavigationStack. Record the lesson event without asking the
                // shell to push the same destination a second time.
                _ = await model.startLesson(lessonID, persistRouteInNavigation: false)
            }
        }
        .onChange(of: answer) { _, newAnswer in
            // Controls are disabled while feedback is visible. Keeping this
            // observer persistence-only also lets restored answer and feedback
            // arrive in either SwiftUI update order without losing the latter.
            scheduleCheckpoint()
            autoEvaluateSpeechIfReady(newAnswer)
        }
        .onChange(of: evaluation) { _, _ in scheduleCheckpoint() }
        .onChange(of: currentIndex) { _, _ in scheduleCheckpoint() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .inactive || phase == .background else { return }
            scheduleCheckpoint()
        }
        .onDisappear {
            automaticEvaluationTask?.cancel()
            automaticEvaluationTask = nil
            scheduleCheckpoint()
        }
    }

    private func restoreSavedStateIfNeeded() {
        guard !didRestore, lesson != nil else { return }
        didRestore = true
        guard let progress = model.snapshot.lessonProgress[lessonID] else { return }

        let savedIndex = progress.currentExerciseIndex
        if let savedID = progress.currentExerciseID,
           let relocatedIndex = exercises.firstIndex(where: { $0.1.id == savedID }) {
            currentIndex = relocatedIndex
        } else {
            // Content updates can add or remove exercises. Keep the saved
            // position inside the new document and discard a pending answer
            // if the saved exercise no longer exists at that position.
            currentIndex = min(max(0, savedIndex), exercises.count)
        }

        answered = progress.lastEvaluations
        dialogueDrafts = progress.dialogueDrafts
        dialogueResults = progress.dialogueResults
        guard currentIndex < exercises.count else {
            answer = nil
            evaluation = nil
            // A terminal checkpoint can exist before the completion event (or
            // when the learner skipped a failed required answer). It is still
            // a resumable terminal screen, and must always offer a reset.
            finished = true
            return
        }

        let currentExercise = exercises[currentIndex].1
        let savedExerciseMatches = progress.currentExerciseID == nil || progress.currentExerciseID == currentExercise.id
        guard savedExerciseMatches else {
            answer = nil
            evaluation = nil
            return
        }
        answer = progress.pendingAnswer
        // New checkpoints carry the stable current exercise ID, so a nil
        // pending evaluation means the learner intentionally cleared feedback
        // (for example by tapping Réessayer). Only old snapshots without that
        // field may fall back to their last evaluation.
        evaluation = progress.pendingEvaluation ??
            (progress.currentExerciseID == nil ? progress.lastEvaluations[currentExercise.id] : nil)
        finished = progress.completedAt != nil
    }

    private func scheduleCheckpoint() {
        guard didRestore, lesson != nil else { return }
        let savedIndex = currentIndex
        let savedExerciseID = savedIndex < exercises.count ? exercises[savedIndex].1.id : nil
        let savedAnswer = answer
        let savedEvaluation = evaluation
        let savedDialogueDrafts = dialogueDrafts
        let savedDialogueResults = dialogueResults
        Task { @MainActor in
            _ = await model.saveLessonCheckpoint(
                lessonID,
                exerciseIndex: savedIndex,
                exerciseID: savedExerciseID,
                answer: savedAnswer,
                evaluation: savedEvaluation,
                dialogueDrafts: savedDialogueDrafts,
                dialogueResults: savedDialogueResults
            )
        }
    }

    @ViewBuilder private func exerciseView(_ lesson: LessonDocument, block: (BlockID, ExerciseSpec)) -> some View {
        let spec = block.1
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if currentIndex == 0 {
                    lessonPreamble(lesson, before: block.0)
                }
                HStack {
                    Text("\(currentIndex + 1) / \(exercises.count)").font(.callout.weight(.semibold)).foregroundStyle(SylluneColor.inkMuted)
                    Spacer()
                    ProgressView(value: Double(currentIndex), total: Double(max(1, exercises.count))).tint(SylluneColor.jade).frame(maxWidth: 180)
                }
                if case .speaking = spec {
                    // The speaking control already presents the target phrase
                    // and its pinyin. Keep the lesson shell to one short cue
                    // so the recording action remains visible on an iPhone.
                    Text("À toi de parler")
                        .font(.headline)
                        .foregroundStyle(SylluneColor.ink)
                } else {
                    ChineseSelectableText(
                        spec.header.prompt.resolve(preferred: model.preferredLanguageCodes) ?? "Exercice",
                        font: .title2.weight(.semibold),
                        wordInteractionEnabled: false
                    )
                        .foregroundStyle(SylluneColor.ink)
                    Text(spec.header.instruction.resolve(preferred: model.preferredLanguageCodes) ?? "")
                        .font(.body).foregroundStyle(SylluneColor.inkMuted)
                }

                answerControl(spec)
                    // Each exercise owns small control state (typed text,
                    // selected tiles, card reveal). Recreate that state when
                    // the stable exercise identity changes and keep controls
                    // read-only while its feedback is visible.
                    .id(spec.id)
                    .disabled(evaluation != nil || isEvaluating)

                if let evaluation {
                    FeedbackView(evaluation: evaluation)
                }

                // Recap blocks are authored after the exercise sequence. Keep
                // them in the lesson flow so the learner can see the bilan
                // before deciding whether to finish the lesson.
                if evaluation != nil, currentIndex == exercises.count - 1 {
                    lessonEpilogue(lesson, after: block.0)
                }

            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            exerciseActionBar(spec: spec, blockID: block.0)
        }
    }

    private func exerciseActionBar(spec: ExerciseSpec, blockID: BlockID) -> some View {
        HStack(spacing: 12) {
            if evaluation != nil {
                Button("Réessayer") {
                    self.evaluation = nil
                    self.answer = nil
                }
                .buttonStyle(.bordered)
                .disabled(evaluation?.accepted == true)
            }
            Spacer(minLength: 8)
            Button(actionTitle(for: spec)) { submitOrAdvance(spec: spec, blockID: blockID) }
                .buttonStyle(SyllunePrimaryButtonStyle())
                .disabled(isEvaluating || isFinalizing || !canSubmit(spec))
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder private func lessonPreamble(_ lesson: LessonDocument, before blockID: BlockID) -> some View {
        if let index = lesson.blocks.firstIndex(where: { $0.id == blockID }) {
            let precedingBlocks = Array(lesson.blocks.prefix(upTo: index))
            if !precedingBlocks.isEmpty {
                let dialogueBlocks = precedingBlocks.filter { block in
                    if case .dialogue = block { return true }
                    return false
                }
                let supportingBlocks = precedingBlocks.filter { block in
                    if case .dialogue = block { return false }
                    return true
                }
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(dialogueBlocks, id: \.id) { block in
                        PedagogicalBlockView(
                            block: block,
                            vocabulary: lesson.vocabulary,
                            objectives: lesson.objectives,
                            languageCodes: model.preferredLanguageCodes,
                            dialogueDraft: dialogueDraftBinding(for: block.id),
                            dialogueResult: dialogueResultBinding(for: block.id)
                        )
                    }
                }
                if !supportingBlocks.isEmpty {
                    DisclosureGroup(isExpanded: $preambleExpanded) {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(supportingBlocks, id: \.id) { block in
                                PedagogicalBlockView(
                                    block: block,
                                    vocabulary: lesson.vocabulary,
                                    objectives: lesson.objectives,
                                    languageCodes: model.preferredLanguageCodes,
                                    dialogueDraft: dialogueDraftBinding(for: block.id),
                                    dialogueResult: dialogueResultBinding(for: block.id)
                                )
                            }
                        }
                        .padding(.top, 12)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "book.closed")
                                .foregroundStyle(SylluneColor.jade)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Découvrir avant de répondre")
                                    .font(.headline)
                                    .foregroundStyle(SylluneColor.ink)
                                Text("Mots et lecture · facultatif")
                                    .font(.caption)
                                    .foregroundStyle(SylluneColor.inkMuted)
                            }
                            Spacer(minLength: 8)
                        }
                    }
                    .tint(SylluneColor.ink)
                    .padding(16)
                    .sylluneCard(radius: 14)
                }
            }
        }
    }

    @ViewBuilder private func lessonEpilogue(_ lesson: LessonDocument, after blockID: BlockID) -> some View {
        if let index = lesson.blocks.firstIndex(where: { $0.id == blockID }) {
            let trailingBlocks = lesson.blocks.dropFirst(index + 1).filter { block in
                if case .exercise = block { return false }
                return true
            }
            if !trailingBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(trailingBlocks), id: \.id) { block in
                        PedagogicalBlockView(
                            block: block,
                            vocabulary: lesson.vocabulary,
                            objectives: lesson.objectives,
                            languageCodes: model.preferredLanguageCodes,
                            objectiveResults: objectiveResults(for: block),
                            dialogueDraft: dialogueDraftBinding(for: block.id),
                            dialogueResult: dialogueResultBinding(for: block.id)
                        )
                    }
                }
            }
        }
    }

    private func objectiveResults(for block: LessonBlock) -> [String: Bool] {
        guard case .recap(let recap) = block else { return [:] }
        var results: [String: Bool] = [:]
        for objectiveID in recap.objectiveIDs {
            let relatedExercises = exercises.filter { $0.1.header.objectiveIDs.contains(objectiveID) }
            guard !relatedExercises.isEmpty else { continue }
            results[objectiveID] = relatedExercises.allSatisfy { evaluationCountsAsComplete(answered[$0.1.id]) }
        }
        return results
    }

    private func dialogueDraftBinding(for id: BlockID) -> Binding<String> {
        Binding(
            get: { dialogueDrafts[id] ?? "" },
            set: { newValue in
                dialogueDrafts[id] = newValue
                dialogueResults.removeValue(forKey: id)
                scheduleCheckpoint()
            }
        )
    }

    private func dialogueResultBinding(for id: BlockID) -> Binding<Bool?> {
        Binding(
            get: { dialogueResults[id] },
            set: { newValue in
                if let newValue { dialogueResults[id] = newValue }
                else { dialogueResults.removeValue(forKey: id) }
                scheduleCheckpoint()
            }
        )
    }

    @ViewBuilder private func answerControl(_ spec: ExerciseSpec) -> some View {
        switch spec {
        case .choice(let exercise): ChoiceAnswerView(exercise: exercise, answer: $answer)
        case .listeningChoice(let exercise): ListeningAnswerView(exercise: exercise, answer: $answer)
        case .wordOrder(let exercise): WordOrderAnswerView(exercise: exercise, answer: $answer)
        case .fillBlank(let exercise): FillAnswerView(exercise: exercise, answer: $answer)
        case .speaking(let exercise):
            SpeechPracticeView(
                exercise: exercise,
                audio: model.dependencies.audio,
                pronunciation: model.dependencies.pronunciation,
                answer: $answer,
                onRecordingCreated: { recordingID in
                    Task { await model.saveRecording(recordingID, exerciseID: exercise.header.id) }
                }
            )
        case .handwriting(let exercise):
            HandwritingPracticeView(
                exercise: exercise,
                answer: $answer,
                service: model.dependencies.handwriting,
                onDrawingCreated: { drawingID in
                    Task { _ = await model.saveDrawing(drawingID, exerciseID: exercise.header.id) }
                }
            )
        case .flashcard(let exercise): FlashcardAnswerView(exercise: exercise, card: model.reviewCard(for: exercise.cardID), answer: $answer)
        }
    }

    private func actionTitle(for spec: ExerciseSpec) -> String {
        if evaluation == nil {
            return answer == nil && canSkipWithoutEvaluation(spec)
                ? "Passer sans évaluer"
                : "Vérifier"
        }
        if evaluation?.accepted == true { return currentIndex + 1 < exercises.count ? "Continuer" : "Terminer" }
        return "Continuer malgré tout"
    }

    private func canSubmit(_ spec: ExerciseSpec) -> Bool {
        if evaluation != nil { return true }
        if answer != nil { return true }
        return canSkipWithoutEvaluation(spec)
    }

    private func submitOrAdvance(spec: ExerciseSpec, blockID: BlockID) {
        if let evaluation {
            if evaluation.accepted { advance() }
            else { advance() }
            return
        }
        guard !isEvaluating else { return }
        let answer = answer ?? .skipped
        isEvaluating = true
        Task { @MainActor in
            if let result = await model.evaluate(spec, answer: answer, lessonID: lessonID, blockID: blockID) {
                self.evaluation = result
                self.answered[spec.id] = result
            }
            self.isEvaluating = false
        }
    }

    private func canSkipWithoutEvaluation(_ spec: ExerciseSpec) -> Bool {
        if case .speaking = spec { return true }
        return false
    }

    private func autoEvaluateSpeechIfReady(_ candidate: ExerciseAnswer?) {
        guard evaluation == nil,
              !isEvaluating,
              currentIndex < exercises.count,
              let candidate,
              case .speaking = exercises[currentIndex].1,
              case .speech(let speech) = candidate,
              speech.pronunciationAssessment?.isEvaluable == true else {
            return
        }
        let spec = exercises[currentIndex].1
        let blockID = exercises[currentIndex].0
        automaticEvaluationTask?.cancel()
        isEvaluating = true
        automaticEvaluationTask = Task { @MainActor in
            defer {
                automaticEvaluationTask = nil
                isEvaluating = false
            }
            guard let result = await model.evaluate(spec, answer: candidate, lessonID: lessonID, blockID: blockID) else { return }
            guard self.answer == candidate, self.evaluation == nil else { return }
            self.evaluation = result
            self.answered[spec.id] = result
        }
    }

    private func advance() {
        if currentIndex + 1 < exercises.count {
            currentIndex += 1
            answer = nil
            evaluation = nil
            scheduleCheckpoint()
        } else {
            let required = exercises.filter { $0.1.header.required }.map(\.1.id)
            let complete = required.allSatisfy { evaluationCountsAsComplete(answered[$0]) }
            guard !isFinalizing else { return }
            // The terminal checkpoint must finish before the completion event
            // and before the recap becomes visible. This keeps a process kill
            // or a failed append from presenting an unrecorded finish screen.
            let terminalDrafts = dialogueDrafts
            let terminalResults = dialogueResults
            isFinalizing = true
            Task { @MainActor in
                let checkpointSaved = await model.saveLessonCheckpoint(
                    lessonID,
                    exerciseIndex: exercises.count,
                    exerciseID: nil,
                    answer: nil,
                    evaluation: nil,
                    dialogueDrafts: terminalDrafts,
                    dialogueResults: terminalResults
                )
                guard checkpointSaved else {
                    isFinalizing = false
                    return
                }
                if complete {
                    guard await model.completeLesson(lessonID) else {
                        isFinalizing = false
                        return
                    }
                }
                currentIndex = exercises.count
                answer = nil
                evaluation = nil
                finished = true
                isFinalizing = false
            }
        }
    }

    @ViewBuilder private func completionView(_ lesson: LessonDocument) -> some View {
        let successCount = answered.values.filter { evaluationCountsAsComplete($0) }.count
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: successCount == exercises.count ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                .font(.system(size: 48)).foregroundStyle(successCount == exercises.count ? SylluneColor.success : SylluneColor.coral)
            Text(successCount == exercises.count ? "Leçon terminée" : "Leçon enregistrée")
                .font(.largeTitle.weight(.semibold)).foregroundStyle(SylluneColor.ink)
            Text("\(successCount) / \(exercises.count) exercices réussis. Les erreurs restent disponibles pour une nouvelle tentative.")
                .font(.body).foregroundStyle(SylluneColor.inkMuted)
            Button("Recommencer cette leçon") {
                Task { @MainActor in
                    guard await model.restartLesson(lessonID, persistRouteInNavigation: false) else { return }
                    currentIndex = 0
                    answer = nil
                    evaluation = nil
                    answered = [:]
                    dialogueDrafts = [:]
                    dialogueResults = [:]
                    finished = false
                    preambleExpanded = false
                }
            }
            .buttonStyle(.bordered)
            if let next = model.nextLessonID, successCount == exercises.count {
                NavigationLink(destination: LessonView(lessonID: next)) { Text("Continuer le parcours") }
                    .buttonStyle(SyllunePrimaryButtonStyle())
            } else {
                NavigationLink(destination: LearningPathView()) { Text("Retour au parcours") }
                    .buttonStyle(SyllunePrimaryButtonStyle())
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
        .padding(24)
    }

    private func evaluationCountsAsComplete(_ value: ExerciseEvaluation?) -> Bool {
        guard let value, value.accepted else { return false }
        // Self-reported oral and handwriting answers do not carry an acoustic
        // or visual score. Their acceptance records a deliberate learner
        // decision; the SRS rating still controls when the item returns.
        return value.outcome == .selfReported || value.score >= 0.8
    }
}

private struct FeedbackView: View {
    let evaluation: ExerciseEvaluation
    var body: some View {
        let isSkipped = evaluation.outcome == .skipped
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSkipped ? "forward.end.circle.fill" : (evaluation.accepted ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill"))
                .foregroundStyle(isSkipped ? SylluneColor.inkMuted : (evaluation.accepted ? SylluneColor.success : SylluneColor.error))
            VStack(alignment: .leading, spacing: 4) {
                Text(isSkipped ? "Passé sans évaluation" : (evaluation.accepted ? "Correct" : "À revoir")).font(.headline)
                Text(evaluation.feedback.resolve(preferred: ["fr", "en"]) ?? "").font(.body)
            }
        }
        .foregroundStyle(SylluneColor.ink)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).sylluneCard(radius: 12)
        .accessibilityElement(children: .combine)
    }
}

private struct DialogueBlockView: View {
    let value: DialogueBlock
    let vocabulary: [VocabularyEntry]
    let languageCodes: [String]
    @Binding var writtenResponse: String
    @Binding var responseResult: Bool?
    @EnvironmentObject private var model: AppModel
    @State private var isPlaying = false
    @State private var playingLineIndex: Int?
    @State private var playbackToken = UUID()
    @State private var playbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label("Dialogue", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                    .foregroundStyle(SylluneColor.ink)
                Spacer(minLength: 6)
                Button {
                    togglePlayback()
                } label: {
                    Label(
                        isPlaying ? "Arrêter" : "Tout écouter",
                        systemImage: isPlaying ? "stop.fill" : "play.fill"
                    )
                    .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(SylluneColor.sky)
                .frame(minHeight: 40)
                .accessibilityLabel(
                    isPlaying
                        ? "Arrêter le dialogue"
                        : "Écouter tout le dialogue en chinois"
                )
                .accessibilityHint("Lit chaque réplique dans l’ordre en mandarin.")
            }

            Text(sceneCaption)
                .font(.caption)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(value.lines.enumerated()), id: \.offset) { index, line in
                    dialogueLine(line, index: index)
                    if index < value.lines.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }

            if let playbackMessage {
                Text(playbackMessage)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let participation = value.participation,
               !value.lines.isEmpty {
                participationView(participation)
            }

            if !value.comprehensionExerciseIDs.isEmpty {
                Label(
                    "\(value.comprehensionExerciseIDs.count) question\(value.comprehensionExerciseIDs.count == 1 ? "" : "s") de compréhension dans la suite",
                    systemImage: "checklist"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(SylluneColor.inkMuted)
                .accessibilityHint("Les réponses sont évaluées parmi les exercices de la leçon.")
            }
        }
        .padding(14)
        .sylluneCard(radius: 16)
        .onDisappear {
            playbackToken = UUID()
            isPlaying = false
            playingLineIndex = nil
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
        }
    }

    private var sceneCaption: String {
        var speakers: [String] = []
        for line in value.lines where !speakers.contains(line.speaker) {
            speakers.append(line.speaker)
        }
        guard !speakers.isEmpty else { return "Échange court" }
        return "\(speakers.joined(separator: " et ")) · échange court"
    }

    private func dialogueLine(_ line: DialogueLine, index: Int) -> some View {
        HStack(alignment: .top, spacing: 8) {
            speakerBadge(line.speaker, index: index)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 8) {
                    Button {
                        playLine(line, index: index)
                    } label: {
                        Text(line.hanzi)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SylluneColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(line.hanzi)
                    .accessibilityHint("Écoute cette réplique en mandarin.")

                    lineAudioButton(line, index: index)
                }

                if !line.pinyin.isEmpty {
                    Text(line.pinyin)
                        .font(.caption)
                        .foregroundStyle(SylluneColor.jadeDeep)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Pinyin : \(line.pinyin)")
                }
                if let translation = line.translation.resolve(preferred: languageCodes),
                   !translation.isEmpty {
                    Text(translation)
                        .font(.callout)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Traduction : \(translation)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    private func speakerBadge(_ speaker: String, index: Int) -> some View {
        let accent = index.isMultiple(of: 2) ? SylluneColor.pathJade : SylluneColor.pathSky
        return VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 32, height: 32)
                Text(String(speaker.prefix(1)).uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
            }
            Text(speaker)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(SylluneColor.inkMuted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 52, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Locuteur \(speaker)")
    }

    private func lineAudioButton(_ line: DialogueLine, index: Int) -> some View {
        Button {
            playLine(line, index: index)
        } label: {
            Image(systemName: playingLineIndex == index ? "stop.fill" : "speaker.wave.2.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(SylluneColor.sky)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(
            playingLineIndex == index
                ? "Arrêter la réplique de \(line.speaker)"
                : "Écouter la réplique de \(line.speaker)"
        )
        .accessibilityHint("Lit cette réplique en mandarin.")
    }

    @ViewBuilder
    private func participationView(_ participation: DialogueParticipation) -> some View {
        let audioIndex = min(max(0, participation.audioLineIndex), value.lines.count - 1)
        let audioLine = value.lines[audioIndex]
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("À toi", systemImage: "pencil.and.outline")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SylluneColor.ink)
                Spacer(minLength: 8)
                Button {
                    playLine(audioLine, index: audioIndex)
                } label: {
                    Label("Écouter la réponse", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(SylluneColor.sky)
                .frame(minHeight: 40)
                .accessibilityHint("La réponse est lue en mandarin pour retrouver la réplique précédente.")
            }
            Text(participation.prompt.resolve(preferred: languageCodes) ?? "Écris la réplique précédente.")
                .font(.callout)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Réplique en caractères chinois", text: $writtenResponse)
                .textFieldStyle(.roundedBorder)
#if os(iOS)
                .textInputAutocapitalization(.never)
#endif
                .autocorrectionDisabled()
                .onChange(of: writtenResponse) { _, _ in responseResult = nil }
            Button("Vérifier ma réplique") {
                let normalized = TextNormalizer.normalize(writtenResponse)
                responseResult = !normalized.isEmpty && participation.acceptedResponses.contains {
                    TextNormalizer.normalize($0) == normalized
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(SylluneColor.jade)
            .disabled(writtenResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if let responseResult {
                Label(
                    responseResult ? "Bonne réplique." : "Relis le dialogue et réessaie.",
                    systemImage: responseResult ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(responseResult ? SylluneColor.success : SylluneColor.coral)
            }
            if let hint = participation.hint?.resolve(preferred: languageCodes) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func togglePlayback() {
        if isPlaying {
            playbackToken = UUID()
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
            isPlaying = false
            playingLineIndex = nil
            playbackMessage = "Lecture arrêtée."
            return
        }

        let token = UUID()
        playbackToken = token
        isPlaying = true
        playingLineIndex = nil
        playbackMessage = nil
        let text = value.lines.map(\.hanzi).joined(separator: " ")
        Task { @MainActor in
            do {
                // Synthesis receives only the authored Mandarin lines. This
                // prevents a French label or instruction from being read as
                // if it were part of the dialogue.
                try await model.dependencies.audio.speak(
                    text: text,
                    localeIdentifier: "zh-CN",
                    rate: .normal
                )
                guard playbackToken == token else { return }
                isPlaying = false
                playbackMessage = "Dialogue lu en mandarin."
            } catch is CancellationError {
                guard playbackToken == token else { return }
                isPlaying = false
                playbackMessage = "Lecture arrêtée."
            } catch {
                guard playbackToken == token else { return }
                isPlaying = false
                playbackMessage = "Audio indisponible hors ligne."
            }
        }
    }

    private func playLine(_ line: DialogueLine, index: Int) {
        let token = UUID()
        playbackToken = token
        isPlaying = true
        playingLineIndex = index
        playbackMessage = nil
        Task { @MainActor in
            do {
                if let audio = line.audio {
                    try await model.dependencies.audio.play(asset: audio)
                } else {
                    try await model.dependencies.audio.speak(
                        text: line.hanzi,
                        localeIdentifier: "zh-CN",
                        rate: .normal
                    )
                }
                guard playbackToken == token else { return }
                isPlaying = false
                playingLineIndex = nil
                playbackMessage = "Réplique de \(line.speaker) lue en mandarin."
            } catch is CancellationError {
                guard playbackToken == token else { return }
                isPlaying = false
                playingLineIndex = nil
                playbackMessage = "Lecture arrêtée."
            } catch {
                guard playbackToken == token else { return }
                isPlaying = false
                playingLineIndex = nil
                playbackMessage = "Audio indisponible hors ligne."
            }
        }
    }
}

private struct PedagogicalBlockView: View {

    let block: LessonBlock
    let vocabulary: [VocabularyEntry]
    let objectives: [LearningObjective]
    let languageCodes: [String]
    let objectiveResults: [String: Bool]
    let dialogueDraft: Binding<String>?
    let dialogueResult: Binding<Bool?>?
    @EnvironmentObject private var model: AppModel

    init(
        block: LessonBlock,
        vocabulary: [VocabularyEntry],
        objectives: [LearningObjective] = [],
        languageCodes: [String],
        objectiveResults: [String: Bool] = [:],
        dialogueDraft: Binding<String>? = nil,
        dialogueResult: Binding<Bool?>? = nil
    ) {
        self.block = block
        self.vocabulary = vocabulary
        self.objectives = objectives
        self.languageCodes = languageCodes
        self.objectiveResults = objectiveResults
        self.dialogueDraft = dialogueDraft
        self.dialogueResult = dialogueResult
    }

    var body: some View {
        switch block {
        case .introduction(let value):
            VStack(alignment: .leading, spacing: 7) {
                Label(value.title.resolve(preferred: languageCodes) ?? "Introduction", systemImage: "sparkles")
                    .font(.headline).foregroundStyle(SylluneColor.ink)
                Text(value.body.resolve(preferred: languageCodes) ?? "")
                    .font(.body).foregroundStyle(SylluneColor.inkMuted)
                if let audio = value.audio {
                    Button { Task { try? await model.dependencies.audio.play(asset: audio) } } label: {
                        Label("Écouter l’introduction", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered).tint(SylluneColor.sky)
                }
            }
            .padding(16).sylluneCard(radius: 14)

        case .vocabulary(let value):
            VStack(alignment: .leading, spacing: 10) {
                Text("Mots utiles").font(.headline).foregroundStyle(SylluneColor.ink)
                ForEach(value.vocabularyIDs, id: \.self) { id in
                    if let word = vocabulary.first(where: { $0.id == id }) {
                        // A word is a learning interaction, not a detour to
                        // another screen. The Chinese control speaks it (and
                        // may expose a detail action through the shared text
                        // component) while the compact row keeps the lesson
                        // moving.
                        ChineseSelectableText(
                            hanzi: word.hanzi,
                            font: .title3,
                            speechEnabled: true,
                            vocabulary: [word],
                            segmentation: word.segmentation,
                            pinyin: word.pinyin,
                            translation: word.meaning.resolve(preferred: languageCodes),
                            audio: word.audio,
                            wordInteractionEnabled: false
                        )
                        .foregroundStyle(SylluneColor.ink)
                    }
                }
            }
            .padding(16).sylluneCard(radius: 14)

        case .dialogue(let value):
            DialogueBlockView(
                value: value,
                vocabulary: vocabulary,
                languageCodes: languageCodes,
                writtenResponse: dialogueDraft ?? .constant(""),
                responseResult: dialogueResult ?? .constant(nil)
            )

        case .reading(let value):
            VStack(alignment: .leading, spacing: 10) {
                Label(value.title.resolve(preferred: languageCodes) ?? "Lecture", systemImage: "book.pages")
                    .font(.headline).foregroundStyle(SylluneColor.ink)
                ForEach(value.paragraphs) { paragraph in
                    VStack(alignment: .leading, spacing: 4) {
                        ChineseSelectableText(
                            hanzi: paragraph.hanzi,
                            font: .title3,
                            speechEnabled: true,
                            vocabulary: vocabulary,
                            segmentation: paragraph.segmentation,
                            pinyin: paragraph.pinyin,
                            translation: paragraph.translation.resolve(preferred: languageCodes),
                            audio: paragraph.audio,
                            wordInteractionEnabled: false
                        )
                        .foregroundStyle(SylluneColor.ink)
                        .textSelection(.enabled)
                    }
                }
            }
            .padding(16).sylluneCard(radius: 14)

        case .recap(let value):
            VStack(alignment: .leading, spacing: 8) {
                Label("À retenir", systemImage: "checklist").font(.headline).foregroundStyle(SylluneColor.ink)
                Text("Revois les mots de cette leçon avant de continuer.").font(.body).foregroundStyle(SylluneColor.inkMuted)
                Text("\(value.vocabularyIDs.count) mots · \(value.objectiveIDs.count) objectifs")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)

                if !value.vocabularyIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mots à revoir").font(.subheadline.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                        ForEach(value.vocabularyIDs, id: \.self) { id in
                            if let word = vocabulary.first(where: { $0.id == id }) {
                                ChineseSelectableText(
                                    hanzi: word.hanzi,
                                    font: .body,
                                    speechEnabled: true,
                                    vocabulary: [word],
                                    segmentation: word.segmentation,
                                    pinyin: word.pinyin,
                                    translation: word.meaning.resolve(preferred: languageCodes),
                                    audio: word.audio,
                                    wordInteractionEnabled: false
                                )
                                .foregroundStyle(SylluneColor.ink)
                            }
                        }
                    }
                }

                if !value.objectiveIDs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bilan des objectifs")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(SylluneColor.ink)
                        ForEach(value.objectiveIDs, id: \.self) { objectiveID in
                            let objective = objectives.first(where: { $0.id == objectiveID })
                            let isComplete = objectiveResults[objectiveID]
                            Label {
                                Text(objective?.statement.resolve(preferred: languageCodes) ?? objectiveID)
                                    .font(.body)
                            } icon: {
                                Image(systemName: isComplete == true ? "checkmark.circle.fill" : isComplete == false ? "arrow.counterclockwise.circle" : "circle")
                                    .foregroundStyle(isComplete == true ? SylluneColor.success : isComplete == false ? SylluneColor.coral : SylluneColor.inkMuted)
                            }
                            .accessibilityValue(isComplete == true ? "réussi" : isComplete == false ? "à revoir" : "non évalué")
                        }
                    }
                }
            }
            .padding(16).sylluneCard(radius: 14)

        case .exercise:
            EmptyView()
        }
    }
}

private struct ChoiceAnswerView: View {
    let exercise: ChoiceExercise
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(spacing: 10) {
            ForEach(exercise.choices) { choice in
                Button {
                    answer = .choice(choiceID: choice.id)
                    let target = PolygoCore.MandarinSpeechText.target(from: choice.label.resolve(preferred: ["fr", "en"]) ?? "")
                    guard !target.isEmpty else { return }
                    Task { try? await model.dependencies.audio.speak(text: target, localeIdentifier: "zh-CN", rate: .normal) }
                } label: {
                    HStack {
                        ChineseSelectableText(choice.label.resolve(preferred: ["fr", "en"]) ?? "", speechEnabled: false)
                        Spacer()
                        if case .choice(let selected) = answer, selected == choice.id { Image(systemName: "checkmark.circle.fill") }
                    }
                    .padding(16).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(SylluneColor.ink)
                .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SylluneColor.border, lineWidth: 1))
                .accessibilityLabel(choice.label.resolve(preferred: ["fr", "en"]) ?? "Réponse")
            }
        }
    }
}

private struct ListeningAnswerView: View {
    let exercise: ListeningChoiceExercise
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    @State private var audioMessage: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Task {
                    do { try await model.dependencies.audio.play(asset: exercise.promptAudio); audioMessage = "Lecture terminée." }
                    catch { audioMessage = "Audio indisponible. Le texte des réponses reste disponible." }
                }
            } label: { Label("Écouter le mot", systemImage: "speaker.wave.2.fill") }
                .buttonStyle(.borderedProminent).tint(SylluneColor.sky)
            if let audioMessage { Text(audioMessage).font(.caption).foregroundStyle(SylluneColor.inkMuted) }
            ChoiceAnswerView(exercise: ChoiceExercise(header: exercise.header, choices: exercise.choices, correctChoiceID: exercise.correctChoiceID), answer: $answer)
        }
    }
}

private struct WordOrderAnswerView: View {
    let exercise: WordOrderExercise
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    @State private var selected: [String] = []
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ChineseSelectableText(selected.isEmpty ? "Choisis les tuiles dans l’ordre." : selected.compactMap { id in exercise.tokens.first(where: { $0.id == id })?.hanzi }.joined(separator: " "), font: .title3)
                .foregroundStyle(SylluneColor.ink).frame(maxWidth: .infinity, alignment: .leading).padding(16).sylluneCard(radius: 12)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(exercise.tokens) { token in
                    Button {
                        if let index = selected.firstIndex(of: token.id) { selected.remove(at: index) }
                        else { selected.append(token.id) }
                        answer = .wordOrder(tokenIDs: selected)
                        Task {
                            try? await model.dependencies.audio.speak(text: token.hanzi, localeIdentifier: "zh-CN", rate: .normal)
                        }
                    } label: {
                        VStack(spacing: 3) { ChineseSelectableText(token.hanzi, font: .title3, speechEnabled: false); if let pinyin = token.pinyin { Text(pinyin).font(.caption) } }
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.bordered).tint(selected.contains(token.id) ? SylluneColor.jade : SylluneColor.inkMuted)
                    .accessibilityLabel("\(token.hanzi), position \(selected.firstIndex(of: token.id).map { String($0 + 1) } ?? "non choisie")")
                }
            }
        }
        .onAppear { syncFromAnswer() }
        .onChange(of: answer) { _, _ in syncFromAnswer() }
    }

    private func syncFromAnswer() {
        if case .wordOrder(let tokenIDs) = answer {
            selected = tokenIDs
        } else {
            selected = []
        }
    }
}

private struct FillAnswerView: View {
    let exercise: FillBlankExercise
    @Binding var answer: ExerciseAnswer?
    @State private var text = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChineseSelectableText(exercise.sentence, font: .title3, speechEnabled: true).foregroundStyle(SylluneColor.ink).padding(16).sylluneCard(radius: 12)
            TextField("Mot manquant", text: $text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { _, value in answer = .text(value) }
        }
        .onAppear { syncFromAnswer() }
        .onChange(of: answer) { _, _ in syncFromAnswer() }
    }

    private func syncFromAnswer() {
        if case .text(let value) = answer { text = value }
        else { text = "" }
    }
}

private struct FlashcardAnswerView: View {
    let exercise: FlashcardExercise
    let card: ReviewCard?
    @Binding var answer: ExerciseAnswer?
    @State private var revealed = false
    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 8) {
                Text("Carte \(exercise.cardID.rawValue)").font(.caption).foregroundStyle(SylluneColor.inkMuted)
                if let card {
                    ChineseSelectableText(display(card.front), font: .system(size: 44, weight: .semibold, design: .rounded), speechEnabled: true).foregroundStyle(SylluneColor.ink)
                    if revealed {
                        Divider()
                        ChineseSelectableText(display(card.back), font: .title3, speechEnabled: true).foregroundStyle(SylluneColor.jadeDeep)
                        if let meaning = card.back.text?.resolve(preferred: ["fr", "en"]) { Text(meaning).font(.body).foregroundStyle(SylluneColor.inkMuted) }
                    }
                } else {
                    Text("Carte indisponible dans le contenu local.").font(.body).foregroundStyle(SylluneColor.inkMuted)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 160).padding(18).sylluneCard(radius: 18)
            if !revealed { Button("Révéler") { revealed = true }.buttonStyle(.borderedProminent).tint(SylluneColor.jade).disabled(card == nil) }
            else {
                HStack { ForEach(SelfRating.allCases, id: \.self) { rating in Button(ratingLabel(rating)) { answer = .selfRating(rating) }.buttonStyle(.bordered) } }
            }
        }
        .onAppear { revealed = answer != nil }
        .onChange(of: answer) { _, value in
            if case .selfRating = value { revealed = true }
            else if value == nil { revealed = false }
        }
    }
    private func display(_ side: CardSide) -> String { side.hanzi ?? side.pinyin ?? side.text?.resolve(preferred: ["fr", "en"]) ?? "—" }
    private func ratingLabel(_ value: SelfRating) -> String { switch value { case .again: return "À refaire"; case .hard: return "Difficile"; case .good: return "Bien"; case .easy: return "Facile" } }
}
