import SwiftUI
import PolygoCore
import PolygoApple

public struct LessonView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sylluneReduceMotion) private var reduceMotion
    public let lessonID: LessonID
    @State private var lesson: LessonDocument?
    /// The lesson as one sequence of teaching and exercise screens.
    @State private var flow: LessonFlow?
    @State private var currentStep = 0
    @State private var answer: ExerciseAnswer?
    @State private var evaluation: ExerciseEvaluation?
    @State private var answered: [ExerciseID: ExerciseEvaluation] = [:]
    @State private var didStart = false
    @State private var didRestore = false
    @State private var isEvaluating = false
    @State private var automaticEvaluationTask: Task<Void, Never>?
    @State private var isFinalizing = false
    @State private var finished = false
    @State private var earnedCoins: Int?
    @State private var readingReferenceExpanded = false
    @State private var dialogueDrafts: [BlockID: String] = [:]
    @State private var dialogueResults: [BlockID: Bool] = [:]

    public init(lessonID: LessonID) { self.lessonID = lessonID }

    private var exercises: [ExerciseBlock] { flow?.exercises ?? [] }

    /// Scroll target of the feedback card.
    private static let feedbackAnchor = "lesson.feedback"

    /// First-try results of the current attempt, as the journal records them.
    private func sessionStats(_ flow: LessonFlow) -> LessonSessionStats {
        LessonSessionStats(exercises: flow.exercises, firstAttempts: model.snapshot.lessonProgress[lessonID]?.firstAttemptResults ?? [:])
    }

    public var body: some View {
        Group {
            if let lesson, let flow {
                if finished { completionView(lesson, flow: flow) }
                else if flow.exercises.isEmpty { ContentUnavailableView("Cette leçon n’a pas d’exercice", systemImage: "rectangle.and.pencil.and.ellipsis") }
                else if currentStep < flow.steps.count { stepView(lesson, flow: flow) }
                else { ProgressView("Enregistrement de la leçon…") }
            } else {
                ProgressView("Chargement de la leçon…")
            }
        }
        .background(SylluneColor.canvas)
        .navigationTitle(lesson?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        // One exit for every step: the close control replaces the stack's
        // back button, and progress is checkpointed on disappear.
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .accessibilityLabel("Quitter la leçon")
                    .accessibilityHint("Ta progression est enregistrée.")
                    .accessibilityIdentifier("lesson.close")
            }
        }
        .task {
            let loaded = await model.loadLesson(lessonID)
            lesson = loaded
            flow = loaded.map(LessonFlow.init(lesson:))
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
        .onChange(of: currentStep) { _, _ in scheduleCheckpoint() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .inactive || phase == .background else { return }
            scheduleCheckpoint()
        }
        .onDisappear {
            automaticEvaluationTask?.cancel()
            automaticEvaluationTask = nil
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
            scheduleCheckpoint()
        }
        .sylluneFocusedExercise()
    }

    private func restoreSavedStateIfNeeded() {
        guard !didRestore, let flow else { return }
        didRestore = true
        guard let progress = model.snapshot.lessonProgress[lessonID] else { return }

        var exerciseIndex: Int
        if let savedID = progress.currentExerciseID,
           let relocatedIndex = flow.exercises.firstIndex(where: { $0.spec.id == savedID }) {
            exerciseIndex = relocatedIndex
        } else {
            // Content updates can add or remove exercises. Keep the saved
            // position inside the new document and discard a pending answer
            // if the saved exercise no longer exists at that position.
            exerciseIndex = min(max(0, progress.currentExerciseIndex), flow.exercises.count)
        }
        // A lesson only reaches its terminal position by advancing past an
        // evaluated last exercise, so an unfinished lesson saved there without
        // any evaluation was never worked through (older builds could write
        // one from another lesson's leaked view state). Start it again rather
        // than presenting an empty recap.
        if exerciseIndex >= flow.exercises.count, progress.completedAt == nil, progress.lastEvaluations.isEmpty {
            exerciseIndex = 0
        }

        answered = progress.lastEvaluations
        dialogueDrafts = progress.dialogueDrafts
        dialogueResults = progress.dialogueResults
        guard exerciseIndex < flow.exercises.count else {
            answer = nil
            evaluation = nil
            currentStep = flow.steps.count
            // A terminal checkpoint can exist before the completion event (or
            // when the learner skipped a failed required answer). It is still
            // a resumable terminal screen, and must always offer a reset.
            finished = true
            return
        }

        let currentExercise = flow.exercises[exerciseIndex].spec
        let savedExerciseMatches = progress.currentExerciseID == nil || progress.currentExerciseID == currentExercise.id
        if savedExerciseMatches {
            answer = progress.pendingAnswer
            // New checkpoints carry the stable current exercise ID, so a nil
            // pending evaluation means the learner intentionally cleared
            // feedback (for example by tapping Réessayer). Only old snapshots
            // without that field may fall back to their last evaluation.
            evaluation = progress.pendingEvaluation ??
                (progress.currentExerciseID == nil ? progress.lastEvaluations[currentExercise.id] : nil)
            finished = progress.completedAt != nil
        } else {
            answer = nil
            evaluation = nil
        }
        // Work in progress reopens the exercise; otherwise the learner resumes
        // on the teaching that prepares it.
        currentStep = flow.resumeStepIndex(exerciseIndex: exerciseIndex, hasPendingWork: answer != nil || evaluation != nil)
    }

    private func scheduleCheckpoint() {
        guard didRestore, let flow else { return }
        // Progress stays keyed by exercise: a teaching step is saved as the
        // exercise it prepares.
        let savedIndex = flow.exerciseIndex(forStep: currentStep)
        let savedExerciseID = savedIndex < flow.exercises.count ? flow.exercises[savedIndex].spec.id : nil
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

    /// Every step shares one chrome: the step header with progress over the
    /// whole lesson, the content, and one primary action at the bottom.
    @ViewBuilder private func stepView(_ lesson: LessonDocument, flow: LessonFlow) -> some View {
        let step = flow.steps[currentStep]
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch step {
                    case .teaching(let teaching): teachingContent(teaching, lesson: lesson)
                    case .exercise(let index, let block): exerciseContent(lesson, flow: flow, exerciseIndex: index, spec: block.spec)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: evaluation)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
            // The verdict and Tavi's reaction sit under the answers: bring
            // them into view once the new feedback is laid out.
            .onChange(of: evaluation) { _, newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.async {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                        proxy.scrollTo(Self.feedbackAnchor, anchor: .bottom)
                    }
                }
            }
        }
        // A new step starts at the top of its content.
        .id(step.id)
        .safeAreaInset(edge: .top, spacing: 0) {
            stepHeader(step, flow: flow)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            switch step {
            case .teaching: teachingActionBar()
            case .exercise(_, let block): exerciseActionBar(spec: block.spec, blockID: block.id)
            }
        }
    }

    /// Step counter with the current phase, the progress bar split into the
    /// lesson's phases, and the run of correct first tries once it counts.
    /// There are no lives: a mistake only resets the run.
    private func stepHeader(_ step: LessonStep, flow: LessonFlow) -> some View {
        let total = flow.steps.count
        let phase = flow.phase(ofStep: currentStep)
        let streak = sessionStats(flow).streak(throughExercise: flow.exerciseIndex(forStep: currentStep))
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(currentStep + 1) / \(total)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityLabel(stepAccessibilityLabel(step, total: total, phase: phase))
                    .accessibilityIdentifier(stepIdentifier(step))
                if let phase {
                    Text(phase.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SylluneColor.jadeDeep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(SylluneColor.jade.opacity(0.14), in: Capsule())
                        // Read with the step counter.
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                if streak >= TaviReaction.visibleStreak {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(SylluneColor.coral)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Série de \(streak) bonnes réponses d’affilée")
                        .accessibilityIdentifier("lesson.streak")
                        .transition(.opacity)
                }
            }
            LessonPhaseProgressBar(segments: flow.phaseSegments, currentStep: currentStep, totalSteps: total)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: currentStep)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: streak)
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func stepAccessibilityLabel(_ step: LessonStep, total: Int, phase: LessonPhase?) -> String {
        let position = "Étape \(currentStep + 1) sur \(total)"
        guard let phase else { return "\(position), \(stepKindName(step))" }
        return "\(position), \(phase.title), \(stepKindName(step))"
    }

    private func stepIdentifier(_ step: LessonStep) -> String {
        switch step {
        case .teaching(let teaching): return "lesson.step.teaching.\(teaching.id)"
        case .exercise(_, let block): return "lesson.exercise.\(block.spec.id.rawValue)"
        }
    }

    private func stepKindName(_ step: LessonStep) -> String {
        guard case .teaching(let teaching) = step else { return "exercice" }
        switch teaching.kind {
        case .situation: return "situation"
        case .words: return "nouveaux mots"
        case .grammar: return "point de grammaire"
        case .dialogue: return "dialogue"
        case .reading: return "lecture"
        }
    }

    private func teachingTitle(_ kind: LessonTeachingStep.Kind) -> String {
        switch kind {
        case .situation: return "Situation"
        case .words: return "Nouveaux mots"
        case .grammar: return "Point de grammaire"
        case .dialogue: return "Découvre le dialogue"
        case .reading: return "Lecture"
        }
    }

    private func teachingSymbol(_ kind: LessonTeachingStep.Kind) -> String {
        switch kind {
        case .situation: return "sparkles"
        case .words: return "character.book.closed"
        case .grammar: return "text.book.closed"
        case .dialogue: return "bubble.left.and.bubble.right"
        case .reading: return "book.pages"
        }
    }

    @ViewBuilder private func teachingContent(_ teaching: LessonTeachingStep, lesson: LessonDocument) -> some View {
        Label(teachingTitle(teaching.kind), systemImage: teachingSymbol(teaching.kind))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(SylluneColor.jadeDeep)
            .accessibilityAddTraits(.isHeader)
        PedagogicalBlockView(
            block: teaching.block,
            vocabulary: lesson.vocabulary,
            objectives: lesson.objectives,
            languageCodes: model.preferredLanguageCodes,
            dialogueDraft: dialogueDraftBinding(for: teaching.block.id),
            dialogueResult: dialogueResultBinding(for: teaching.block.id)
        )
    }

    @ViewBuilder private func exerciseContent(_ lesson: LessonDocument, flow: LessonFlow, exerciseIndex: Int, spec: ExerciseSpec) -> some View {
        if let reading = readingReference(in: lesson, for: spec.id) {
            readingReferenceDisclosure(reading)
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
            Text(instructionText(for: spec))
                .font(.body).foregroundStyle(SylluneColor.inkMuted)
        }

        answerControl(spec)
            // Each exercise owns small control state (selected
            // choices/tiles, card reveal). Recreate that state when
            // the stable exercise identity changes and keep controls
            // read-only while its feedback is visible.
            .id(spec.id)
            .disabled(evaluation != nil || isEvaluating)

        if let evaluation {
            FeedbackView(
                evaluation: evaluation,
                reaction: TaviReaction(
                    evaluation: evaluation,
                    stepIndex: currentStep,
                    streak: sessionStats(flow).streak(throughExercise: exerciseIndex),
                    nextPhase: flow.phaseStarting(afterExercise: exerciseIndex)
                )
            )
            .id(Self.feedbackAnchor)
            .transition(reduceMotion ? AnyTransition.identity : AnyTransition.opacity.combined(with: AnyTransition.scale(scale: 0.97, anchor: .top)))
        }
    }

    /// Teaching steps are read, not evaluated: one action moves on.
    private func teachingActionBar() -> some View {
        Button("Continuer") { advance() }
            .buttonStyle(SyllunePrimaryButtonStyle())
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("lesson.step.continue")
            .accessibilityHint("Passe à l’étape suivante de la leçon.")
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) { Divider() }
    }

    private func instructionText(for spec: ExerciseSpec) -> String {
        guard case .fillBlank(let exercise) = spec else {
            return spec.header.instruction.resolve(preferred: model.preferredLanguageCodes) ?? ""
        }

        let instruction: LocalizedText
        if exercise.canonicalSpeechSentence != nil {
            instruction = .unchecked([
                "fr": "Écoute et choisis le mot manquant.",
                "en": "Listen and choose the missing word."
            ])
        } else {
            instruction = .unchecked([
                "fr": "Choisis le mot manquant.",
                "en": "Choose the missing word."
            ])
        }
        return instruction.resolve(preferred: model.preferredLanguageCodes) ?? "Choisis le mot manquant."
    }

    private func readingReference(in lesson: LessonDocument, for exerciseID: ExerciseID) -> ReadingBlock? {
        lesson.blocks.compactMap { block in
            guard case .reading(let reading) = block,
                  reading.comprehensionExerciseIDs.contains(exerciseID) else { return nil }
            return reading
        }.first
    }

    private func readingReferenceDisclosure(_ reading: ReadingBlock) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                readingReferenceExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Label("Relire le texte", systemImage: "book.pages")
                        .font(.headline)
                        .foregroundStyle(SylluneColor.ink)
                    Spacer(minLength: 8)
                    Image(systemName: readingReferenceExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SylluneColor.inkMuted)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("lesson.reading.\(reading.id.rawValue)")
            .accessibilityValue(readingReferenceExpanded ? "Développé" : "Réduit")

            ReadingPlaybackControl(reading: reading)

            if readingReferenceExpanded {
                PedagogicalBlockView(
                    block: .reading(reading),
                    vocabulary: lesson?.vocabulary ?? [],
                    objectives: lesson?.objectives ?? [],
                    languageCodes: model.preferredLanguageCodes,
                    showsReadingAudioControl: false
                )
                .padding(.top, 12)
            }
        }
        .padding(16)
        .sylluneCard(radius: 14)
    }

    private func exerciseActionBar(spec: ExerciseSpec, blockID: BlockID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let evaluation {
                Label(
                    evaluation.outcome == .skipped ? "Passé sans évaluation" : (evaluation.accepted ? "Correct" : "À revoir"),
                    systemImage: evaluation.outcome == .skipped ? "forward.end.circle.fill" : (evaluation.accepted ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(evaluation.outcome == .skipped ? SylluneColor.inkMuted : (evaluation.accepted ? SylluneColor.success : SylluneColor.error))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 12) {
                if evaluation != nil {
                    Button("Réessayer") {
                        self.evaluation = nil
                        self.answer = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(evaluation?.accepted == true)
                }
                Button(actionTitle(for: spec)) { submitOrAdvance(spec: spec, blockID: blockID) }
                    .buttonStyle(SyllunePrimaryButtonStyle())
                    .disabled(isEvaluating || isFinalizing || !canSubmit(spec))
                    .frame(maxWidth: .infinity)
            }
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

    private func objectiveResults(for block: LessonBlock) -> [String: Bool] {
        guard case .recap(let recap) = block else { return [:] }
        var results: [String: Bool] = [:]
        for objectiveID in recap.objectiveIDs {
            let relatedExercises = exercises.filter { $0.spec.header.objectiveIDs.contains(objectiveID) }
            guard !relatedExercises.isEmpty else { continue }
            results[objectiveID] = relatedExercises.allSatisfy { evaluationCountsAsComplete(answered[$0.spec.id]) }
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
                answer: $answer,
                pronunciation: model.dependencies.pronunciation,
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
        case .matching(let exercise): MatchingAnswerView(exercise: exercise, answer: $answer)
        case .dictation(let exercise):
            ListeningAnswerView(
                exercise: ListeningChoiceExercise(
                    header: exercise.header, promptAudio: exercise.promptAudio, promptText: exercise.promptText,
                    choices: exercise.choices, correctChoiceID: exercise.correctChoiceID, replayLimit: exercise.replayLimit
                ),
                listenTitle: "Écouter l’audio",
                answer: $answer
            )
        case .toneDiscrimination(let exercise):
            ListeningAnswerView(
                exercise: ListeningChoiceExercise(
                    header: exercise.header, promptAudio: exercise.promptAudio, promptText: exercise.promptText,
                    choices: exercise.choices, correctChoiceID: exercise.correctChoiceID, replayLimit: exercise.replayLimit
                ),
                listenTitle: "Écouter l’audio",
                answer: $answer
            )
        case .translation(let exercise):
            WordOrderAnswerView(
                exercise: WordOrderExercise(header: exercise.header, tokens: exercise.tokens, correctOrder: exercise.correctOrder),
                answer: $answer
            )
        case .dialogueOrder(let exercise): DialogueOrderAnswerView(exercise: exercise, answer: $answer)
        case .conversationChoice(let exercise): ConversationAnswerView(exercise: exercise, answer: $answer)
        }
    }

    private func actionTitle(for spec: ExerciseSpec) -> String {
        if evaluation == nil {
            return continuesWithoutEvaluation(spec) ? "Continuer" : "Vérifier"
        }
        if evaluation?.accepted == true { return currentStep + 1 < (flow?.steps.count ?? 0) ? "Continuer" : "Terminer" }
        return "Continuer malgré tout"
    }

    private func canSubmit(_ spec: ExerciseSpec) -> Bool {
        if evaluation != nil { return true }
        // A matching is only submitted once every item is tied to another.
        if case .matching(let exercise) = spec {
            guard case .matching(let pairs) = answer else { return false }
            return pairs.count == exercise.pairs.count
        }
        if answer != nil { return true }
        return continuesWithoutEvaluation(spec)
    }

    private func submitOrAdvance(spec: ExerciseSpec, blockID: BlockID) {
        if let evaluation {
            if evaluation.accepted { advance() }
            else { advance() }
            return
        }
        guard !isEvaluating else { return }
        let skips = continuesWithoutEvaluation(spec)
        let answer: ExerciseAnswer = skips ? .skipped : (self.answer ?? .skipped)
        isEvaluating = true
        Task { @MainActor in
            if let result = await model.evaluate(spec, answer: answer, lessonID: lessonID, blockID: blockID) {
                self.answered[spec.id] = result
                // A speaking answer without an evaluable pronunciation
                // assessment is recorded as skipped and leaves in one tap:
                // there is no feedback to read.
                if skips { advance() } else { self.evaluation = result }
            }
            self.isEvaluating = false
        }
    }

    /// Speaking exercises have no scoring provider unless an evaluable
    /// pronunciation assessment exists; without one they are recorded as
    /// skipped instead of verified.
    private func continuesWithoutEvaluation(_ spec: ExerciseSpec) -> Bool {
        guard case .speaking = spec else { return false }
        if case .speech(let speech) = answer, speech.pronunciationAssessment?.isEvaluable == true { return false }
        return true
    }

    private func autoEvaluateSpeechIfReady(_ candidate: ExerciseAnswer?) {
        guard evaluation == nil,
              !isEvaluating,
              let flow,
              currentStep < flow.steps.count,
              case .exercise(_, let block) = flow.steps[currentStep],
              let candidate,
              case .speaking = block.spec,
              case .speech(let speech) = candidate,
              speech.pronunciationAssessment?.isEvaluable == true else {
            return
        }
        let spec = block.spec
        let blockID = block.id
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
        guard let flow else { return }
        if currentStep + 1 < flow.steps.count {
            currentStep += 1
            answer = nil
            evaluation = nil
            scheduleCheckpoint()
        } else {
            let required = exercises.filter { $0.spec.header.required }.map(\.spec.id)
            let complete = required.allSatisfy { evaluationCountsAsComplete(answered[$0]) }
            guard !isFinalizing else { return }
            // The terminal checkpoint must finish before the completion event
            // and before the recap becomes visible. This keeps a process kill
            // or a failed append from presenting an unrecorded finish screen.
            let terminalDrafts = dialogueDrafts
            let terminalResults = dialogueResults
            isFinalizing = true
            earnedCoins = nil
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
                    guard let result = await model.completeLesson(lessonID) else {
                        isFinalizing = false
                        return
                    }
                    earnedCoins = result.earnedCoins
                }
                currentStep = flow.steps.count
                answer = nil
                evaluation = nil
                finished = true
                isFinalizing = false
            }
        }
    }

    @ViewBuilder private func completionView(_ lesson: LessonDocument, flow: LessonFlow) -> some View {
        let successCount = answered.values.filter { evaluationCountsAsComplete($0) }.count
        let skippedCount = answered.values.filter { $0.outcome == .skipped }.count
        let progress = model.snapshot.lessonProgress[lessonID]
        let wordsRecap = LessonWordsRecap(lesson: lesson)
        // Offered once the lesson is recorded as completed, so the next one
        // is open.
        let nextLessonID = progress?.completedAt == nil ? nil : model.lesson(after: lessonID)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 14) {
                    TaviMascot(pose: successCount == exercises.count ? .celebration : .encouragement)
                        .frame(width: 84, height: 84)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(successCount == exercises.count ? "Leçon terminée" : "Leçon enregistrée")
                            .font(.largeTitle.weight(.semibold))
                            // « enregistrée » alone is wider than the column beside Tavi on an iPhone.
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(SylluneColor.ink)
                        Text("\(successCount) / \(exercises.count) exercices réussis. Les erreurs restent disponibles pour une nouvelle tentative.")
                            .font(.body)
                            .foregroundStyle(SylluneColor.inkMuted)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .sylluneCard(style: .quiet, radius: 20)

                if skippedCount > 0 {
                    Text(skippedCount == 1 ? "1 exercice passé sans évaluation" : "\(skippedCount) exercices passés sans évaluation")
                        .font(.body)
                        .foregroundStyle(SylluneColor.inkMuted)
                }

                completionStats(sessionStats(flow), timeSpent: progress?.timeSpent)

                if let earnedCoins, earnedCoins > 0 {
                    HStack(spacing: 10) {
                        SylluneCoinIcon()
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                        Text("+\(earnedCoins) pièces")
                            .font(.headline)
                            .foregroundStyle(SylluneColor.ink)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .sylluneCard(style: .interactive, radius: 16)
                    .accessibilityElement(children: .combine)
                }

                if let wordsRecap {
                    LessonWordsSection(recap: wordsRecap, languageCodes: model.preferredLanguageCodes)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { secondaryCompletionActions(hasWords: wordsRecap != nil) }
                    VStack(alignment: .leading, spacing: 10) { secondaryCompletionActions(hasWords: wordsRecap != nil) }
                }

                // The authored recap closes the lesson with its words and the
                // objectives the answers reached.
                ForEach(flow.closingBlocks, id: \.id) { block in
                    PedagogicalBlockView(
                        block: block,
                        vocabulary: lesson.vocabulary,
                        objectives: lesson.objectives,
                        languageCodes: model.preferredLanguageCodes,
                        objectiveResults: objectiveResults(for: block)
                    )
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        // The way on stays in reach under a long recap, like a step's action.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            completionActionBar(nextLessonID: nextLessonID)
        }
    }

    @ViewBuilder private func secondaryCompletionActions(hasWords: Bool) -> some View {
        if hasWords {
            Button("Revoir les mots") {
                // The lesson's cards join the review queue on completion.
                dismiss()
                model.persistRoute(.cards)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("lesson.completion.reviewWords")
        }
        Button("Recommencer cette leçon") {
            Task { @MainActor in
                guard await model.restartLesson(lessonID, persistRouteInNavigation: false) else { return }
                currentStep = 0
                answer = nil
                evaluation = nil
                answered = [:]
                dialogueDrafts = [:]
                dialogueResults = [:]
                earnedCoins = nil
                finished = false
            }
        }
        .buttonStyle(.bordered)
    }

    /// Continue to the next lesson when it is open, or go back to the path.
    /// The recap is left only on request.
    private func completionActionBar(nextLessonID: LessonID?) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { completionActions(nextLessonID: nextLessonID) }
            VStack(spacing: 10) { completionActions(nextLessonID: nextLessonID) }
        }
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder private func completionActions(nextLessonID: LessonID?) -> some View {
        if let nextLessonID {
            Button("Retour au parcours", action: returnToPath)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("lesson.completion.path")
            Button("Continuer vers la leçon suivante") {
                dismiss()
                model.persistRoute(.lesson(nextLessonID))
            }
            .buttonStyle(SyllunePrimaryButtonStyle())
            .accessibilityIdentifier("lesson.completion.next")
        } else {
            Button("Retour au parcours", action: returnToPath)
                .buttonStyle(SyllunePrimaryButtonStyle())
                .accessibilityIdentifier("lesson.completion.path")
        }
    }

    private func returnToPath() {
        dismiss()
        model.persistRoute(.path)
    }

    /// First-try accuracy, time and best run. Hidden when the attempt has no
    /// scored answer, as for a recap restored from an older journal.
    @ViewBuilder private func completionStats(_ stats: LessonSessionStats, timeSpent: TimeInterval?) -> some View {
        if let accuracy = stats.accuracy {
            let percent = Int((accuracy * 100).rounded())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                CompletionStatTile(
                    title: "Précision",
                    symbol: "target",
                    value: "\(percent) %",
                    detail: "au premier essai",
                    accessibilityValue: "\(percent) pour cent au premier essai"
                )
                if let timeSpent {
                    let minutes = Int((timeSpent / 60).rounded())
                    CompletionStatTile(
                        title: "Temps",
                        symbol: "clock",
                        value: minutes < 1 ? "< 1 min" : "\(minutes) min",
                        detail: nil,
                        accessibilityValue: minutes < 1 ? "moins d’une minute" : (minutes == 1 ? "1 minute" : "\(minutes) minutes")
                    )
                }
                CompletionStatTile(
                    title: "Meilleure série",
                    symbol: "flame.fill",
                    value: "\(stats.bestStreak)",
                    detail: stats.bestStreak == 1 ? "bonne réponse" : "bonnes réponses d’affilée",
                    accessibilityValue: stats.bestStreak == 1 ? "1 bonne réponse" : "\(stats.bestStreak) bonnes réponses d’affilée"
                )
            }
        }
    }

    private func evaluationCountsAsComplete(_ value: ExerciseEvaluation?) -> Bool {
        value?.countsAsCorrect == true
    }
}

private struct CompletionStatTile: View {
    let title: String
    let symbol: String
    let value: String
    let detail: String?
    let accessibilityValue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SylluneColor.inkMuted)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(SylluneColor.ink)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(radius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
    }
}

/// The lesson's words as chips: each one plays the word and opens its fiche.
private struct LessonWordsSection: View {
    let recap: LessonWordsRecap
    let languageCodes: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recap.kind == .learned ? "Mots appris" : "Mots revus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(SylluneColor.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Touche un mot pour l’écouter et ouvrir sa fiche.")
                .font(.callout)
                .foregroundStyle(SylluneColor.inkMuted)
            SylluneFlowLayout(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(recap.words, id: \.id) { word in
                    LessonWordChip(word: word, meaning: word.meaning.resolve(preferred: languageCodes) ?? "")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sylluneCard(radius: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lesson.completion.words")
    }
}

private struct LessonWordChip: View {
    let word: VocabularyEntry
    let meaning: String
    @EnvironmentObject private var model: AppModel
    @Environment(\.sylluneShellWordNavigation) private var shellWordNavigation
    @State private var showsWord = false

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.hanzi)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SylluneColor.ink)
                Text(word.pinyin)
                    .font(.callout)
                    .foregroundStyle(SylluneColor.jadeDeep)
                if !meaning.isEmpty {
                    Text(meaning)
                        .font(.caption)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minWidth: 88, minHeight: 44, alignment: .leading)
            .background(SylluneColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(meaning.isEmpty ? "\(word.hanzi), \(word.pinyin)" : "\(word.hanzi), \(word.pinyin), \(meaning)")
        .accessibilityHint("Écoute ce mot en mandarin et ouvre sa fiche.")
        .accessibilityIdentifier("lesson.completion.word.\(word.id.rawValue)")
        .navigationDestination(isPresented: $showsWord) {
            // The chip has already started the word's audio.
            WordDetailView(vocabularyID: word.id, autoPlayAudio: false)
        }
    }

    private func open() {
        let target = PolygoCore.MandarinSpeechText.target(from: word.hanzi)
        if !target.isEmpty {
            Task { @MainActor in
                try? await model.dependencies.audio.speak(text: target, localeIdentifier: "zh-CN", rate: .normal, asset: word.audio)
            }
        }
        if let shellWordNavigation {
            shellWordNavigation(word.id)
        } else {
            showsWord = true
        }
    }
}

/// The answer's verdict and explanation, then Tavi's reaction. One
/// VoiceOver element reads everything once; the artwork is decorative.
private struct FeedbackView: View {
    let evaluation: ExerciseEvaluation
    let reaction: TaviReaction?

    var body: some View {
        let isSkipped = evaluation.outcome == .skipped
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isSkipped ? "forward.end.circle.fill" : (evaluation.accepted ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill"))
                    .foregroundStyle(isSkipped ? SylluneColor.inkMuted : (evaluation.accepted ? SylluneColor.success : SylluneColor.error))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(isSkipped ? "Passé sans évaluation" : (evaluation.accepted ? "Correct" : "À revoir")).font(.headline)
                    Text(evaluation.feedback.resolve(preferred: ["fr", "en"]) ?? "").font(.body)
                }
                Spacer(minLength: 0)
            }
            if let reaction {
                HStack(alignment: .center, spacing: 10) {
                    TaviMascot(pose: reaction.mood == .celebration ? .celebration : .encouragement)
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reaction.message)
                            .font(.callout.weight(.semibold))
                        if let announcement = reaction.phaseAnnouncement {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Image(systemName: "arrow.forward.circle.fill")
                                    .accessibilityHidden(true)
                                Text(announcement)
                            }
                            .font(.callout)
                            .foregroundStyle(SylluneColor.jadeDeep)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(SylluneColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .foregroundStyle(SylluneColor.ink)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).sylluneCard(radius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("lesson.feedback")
    }
}

/// The lesson's progress bar, split into its phases: each segment is as wide
/// as its share of the steps and fills as the learner moves through it.
private struct LessonPhaseProgressBar: View {
    let segments: [LessonPhaseSegment]
    let currentStep: Int
    let totalSteps: Int

    private static let gap: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let available = max(0, proxy.size.width - Self.gap * CGFloat(max(0, segments.count - 1)))
            HStack(spacing: Self.gap) {
                ForEach(segments, id: \.steps.lowerBound) { segment in
                    let width = available * CGFloat(segment.steps.count) / CGFloat(max(1, totalSteps))
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(SylluneColor.progressTrack)
                        Capsule()
                            .fill(SylluneColor.jade)
                            .frame(width: width * segment.completion(atStep: currentStep))
                    }
                    .frame(width: width)
                }
            }
        }
        // GeometryReader otherwise takes all the vertical space it is given.
        .frame(height: 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progression")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let percent = "\(Int(Double(currentStep) / Double(max(1, totalSteps)) * 100)) pour cent"
        let phased = segments.filter { $0.phase != nil }
        guard let position = phased.firstIndex(where: { $0.steps.contains(currentStep) }),
              let phase = phased[position].phase else { return percent }
        return "\(percent), phase \(position + 1) sur \(phased.count) : \(phase.title)"
    }
}

private struct DialogueBlockView: View {
    let value: DialogueBlock
    let languageCodes: [String]
    /// Hanzi of the learner's last participation choice, persisted with the
    /// lesson checkpoint.
    @Binding var writtenResponse: String
    @Binding var responseResult: Bool?
    @EnvironmentObject private var model: AppModel
    @State private var isPlaying = false
    @AppStorage(SlowAudioToggle.storageKey) private var slowAudio = false
    @State private var playingLineIndex: Int?
    @State private var playbackToken = UUID()
    @State private var playbackMessage: String?
    @State private var playbackTask: Task<Void, Never>?
    /// Lines whose pinyin and translation are shown; Hanzi only by default.
    @State private var revealedLines: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Dialogue", systemImage: "bubble.left.and.bubble.right")
                        .font(.headline)
                        .foregroundStyle(SylluneColor.ink)
                    Text(sceneCaption)
                        .font(.caption)
                        .foregroundStyle(SylluneColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                SlowAudioToggle()
                Button {
                    togglePlayback()
                } label: {
                    Label(
                        isPlaying ? "Arrêter" : "Écouter le dialogue",
                        systemImage: isPlaying ? "stop.fill" : "play.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .frame(minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(SylluneColor.sky)
                .accessibilityIdentifier("dialogue.play")
                .accessibilityLabel(
                    isPlaying
                        ? "Arrêter le dialogue"
                        : "Écouter tout le dialogue en chinois"
                )
                .accessibilityHint("Lit chaque réplique dans l’ordre en mandarin.")
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Touche un mot pour sa fiche, ou une réplique pour son pinyin et sa traduction.")
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Button(allRevealed ? "Tout masquer" : "Tout afficher") {
                    revealedLines = allRevealed ? [] : Set(revealableLines)
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
                .tint(SylluneColor.sky)
                .accessibilityIdentifier("dialogue.revealAll")
                .accessibilityHint(
                    allRevealed
                        ? "Masque le pinyin et la traduction de toutes les répliques."
                        : "Affiche le pinyin et la traduction de toutes les répliques."
                )
            }

            VStack(spacing: 10) {
                ForEach(Array(value.lines.enumerated()), id: \.offset) { index, line in
                    dialogueBubble(line, index: index)
                }
            }

            if let playbackMessage {
                Text(playbackMessage)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let participation = value.participation,
               let answerIndex = answerLineIndex {
                participationView(participation, answerIndex: answerIndex)
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
        .onChange(of: value.id) { _, _ in revealedLines = [] }
        .onDisappear {
            playbackTask?.cancel()
            playbackTask = nil
            playbackToken = UUID()
            isPlaying = false
            playingLineIndex = nil
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
        }
    }

    private var speakers: [String] {
        var speakers: [String] = []
        for line in value.lines where !speakers.contains(line.speaker) {
            speakers.append(line.speaker)
        }
        return speakers
    }

    private var sceneCaption: String {
        guard !speakers.isEmpty else { return "Échange court" }
        return "\(speakers.joined(separator: " et ")) · échange court"
    }

    /// The line the learner must find: the first line matching an accepted
    /// response, otherwise the line just before the audio cue.
    private var answerLineIndex: Int? {
        guard let participation = value.participation, !value.lines.isEmpty else { return nil }
        let accepted = Set(participation.acceptedResponses.map { TextNormalizer.normalize($0) })
        if let index = value.lines.firstIndex(where: { accepted.contains(TextNormalizer.normalize($0.hanzi)) }) {
            return index
        }
        return min(max(0, participation.audioLineIndex - 1), value.lines.count - 1)
    }

    private var isSolved: Bool { responseResult == true }

    /// Lines the learner can reveal: every line except the missing one
    /// until the participation is solved.
    private var revealableLines: [Int] {
        value.lines.indices.filter { isSolved || $0 != answerLineIndex }
    }

    private var allRevealed: Bool {
        let lines = revealableLines
        return !lines.isEmpty && lines.allSatisfy { revealedLines.contains($0) }
    }

    private func dialogueBubble(_ line: DialogueLine, index: Int) -> some View {
        let isLeading = line.speaker == speakers.first
        let isMasked = !isSolved && index == answerLineIndex
        let isCurrent = playingLineIndex == index
        let accent = isLeading ? SylluneColor.pathJade : SylluneColor.pathSky
        let alignment: HorizontalAlignment = isLeading ? .leading : .trailing
        let textAlignment: TextAlignment = isLeading ? .leading : .trailing
        return HStack(spacing: 0) {
            if !isLeading { Spacer(minLength: 40) }
            VStack(alignment: alignment, spacing: 4) {
                Text(line.speaker)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityLabel("Locuteur \(line.speaker)")
                if isMasked {
                    VStack(alignment: alignment, spacing: 4) {
                        Text("？？？")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SylluneColor.inkMuted)
                            .accessibilityHidden(true)
                        Text("Réplique manquante")
                            .font(.caption)
                            .foregroundStyle(SylluneColor.inkMuted)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("dialogue.line.\(index)")
                } else {
                    let isRevealed = revealedLines.contains(index)
                    let translation = line.translation.resolve(preferred: languageCodes) ?? ""
                    HStack(alignment: .top, spacing: 6) {
                        // The whole line reveals its pinyin and translation;
                        // words stay plain text so no tap opens a fiche.
                        Button {
                            toggleReveal(index)
                        } label: {
                            VStack(alignment: alignment, spacing: 4) {
                                Text(line.hanzi)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(SylluneColor.ink)
                                if isRevealed && !line.pinyin.isEmpty {
                                    Text(line.pinyin)
                                        .font(.caption)
                                        .foregroundStyle(SylluneColor.jadeDeep)
                                }
                                if isRevealed && !translation.isEmpty {
                                    Text(translation)
                                        .font(.callout)
                                        .foregroundStyle(SylluneColor.inkMuted)
                                }
                            }
                            .multilineTextAlignment(textAlignment)
                            .fixedSize(horizontal: false, vertical: true)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("dialogue.line.\(index)")
                        .accessibilityLabel(
                            isRevealed
                                ? [line.hanzi, "Pinyin : \(line.pinyin)", "Traduction : \(translation)"].joined(separator: ". ")
                                : line.hanzi
                        )
                        .accessibilityHint("Affiche le pinyin et la traduction")
                        .accessibilityValue(isRevealed ? "Pinyin et traduction affichés" : "Pinyin et traduction masqués")

                        lineAudioButton(line, index: index)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(accent.opacity(isCurrent ? 0.3 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrent ? accent : Color.clear, lineWidth: 2)
            )
            // The speaker name and padding reveal the line too; its buttons
            // keep their own taps.
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture { if !isMasked { toggleReveal(index) } }
            if isLeading { Spacer(minLength: 40) }
        }
    }

    private func toggleReveal(_ index: Int) {
        if revealedLines.contains(index) { revealedLines.remove(index) } else { revealedLines.insert(index) }
    }

    private func lineAudioButton(_ line: DialogueLine, index: Int) -> some View {
        Button {
            playLine(line, index: index)
        } label: {
            Image(systemName: playingLineIndex == index ? "stop.fill" : "speaker.wave.2.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(SylluneColor.sky)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityIdentifier("dialogue.line.\(index).play")
        .accessibilityLabel(
            playingLineIndex == index
                ? "Arrêter la réplique de \(line.speaker)"
                : "Écouter la réplique de \(line.speaker)"
        )
        .accessibilityHint("Lit cette réplique en mandarin.")
    }

    /// Correct line plus up to two distinct distractors from the same
    /// dialogue, in a stable order derived from the block identifier.
    private func choiceIndices(answerIndex: Int, audioIndex: Int) -> [Int] {
        let seed = value.id.rawValue.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        var seen: Set<String> = [TextNormalizer.normalize(value.lines[answerIndex].hanzi)]
        var candidates: [Int] = []
        for index in value.lines.indices where index != answerIndex && index != audioIndex {
            if seen.insert(TextNormalizer.normalize(value.lines[index].hanzi)).inserted {
                candidates.append(index)
            }
        }
        if !candidates.isEmpty {
            let shift = seed % candidates.count
            candidates = Array(candidates[shift...] + candidates[..<shift])
        }
        let choices = [answerIndex] + candidates.prefix(2)
        let shift = (seed / 7) % choices.count
        return Array(choices[shift...] + choices[..<shift])
    }

    @ViewBuilder
    private func participationView(_ participation: DialogueParticipation, answerIndex: Int) -> some View {
        let audioIndex = min(max(0, participation.audioLineIndex), value.lines.count - 1)
        let audioLine = value.lines[audioIndex]
        let answerLine = value.lines[answerIndex]
        let choices = choiceIndices(answerIndex: answerIndex, audioIndex: audioIndex)
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 2)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("À toi", systemImage: "hand.point.up.left")
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
                .accessibilityIdentifier("dialogue.participation.listen")
                .accessibilityHint("La réponse est lue en mandarin pour retrouver la réplique manquante.")
            }
            Text("Quelle réplique de \(answerLine.speaker) manque ? Écoute la réponse de \(audioLine.speaker), puis choisis.")
                .font(.callout)
                .foregroundStyle(SylluneColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(choices.enumerated()), id: \.element) { position, lineIndex in
                choiceButton(value.lines[lineIndex], position: position, isCorrect: lineIndex == answerIndex)
            }
            if let responseResult {
                Label(
                    responseResult ? "Bonne réplique." : "Ce n’est pas celle-ci, réessaie.",
                    systemImage: responseResult ? "checkmark.circle.fill" : "arrow.counterclockwise.circle"
                )
                .font(.callout.weight(.semibold))
                .foregroundStyle(responseResult ? SylluneColor.success : SylluneColor.coral)
                .accessibilityIdentifier("dialogue.participation.result")
            }
            if responseResult == false,
               let hint = participation.hint?.resolve(preferred: languageCodes) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(SylluneColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func choiceButton(_ line: DialogueLine, position: Int, isCorrect: Bool) -> some View {
        let isSelected = responseResult != nil && writtenResponse == line.hanzi
        let tint: Color = isSelected ? (isCorrect ? SylluneColor.success : SylluneColor.coral) : SylluneColor.inkMuted
        return Button {
            writtenResponse = line.hanzi
            responseResult = isCorrect
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(line.hanzi)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SylluneColor.ink)
                    if !line.pinyin.isEmpty {
                        Text(line.pinyin)
                            .font(.caption)
                            .foregroundStyle(SylluneColor.jadeDeep)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(isSelected ? 1 : 0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isSolved)
        .accessibilityIdentifier("dialogue.choice.\(position)")
        .accessibilityLabel("Choisir \(line.hanzi), \(line.pinyin)")
        .accessibilityValue(isSelected ? (isCorrect ? "Bonne réplique" : "Incorrect") : "")
    }

    /// Each line with a bundled clip plays it in its speaker's voice; the
    /// others are synthesized clause by clause.
    private func speechSegments(for lines: [DialogueLine]) -> [SpeechSynthesisSegment] {
        SpeechSynthesisSegment.narration(
            MandarinSpeechText.dialogueSegments(from: lines),
            rate: SlowAudioToggle.rate(slow: slowAudio)
        )
    }

    private func togglePlayback() {
        if isPlaying {
            playbackTask?.cancel()
            playbackTask = nil
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
        let segments = speechSegments(for: value.lines)
        playbackTask?.cancel()
        model.dependencies.audio.stopSpeaking()
        model.dependencies.audio.stopPlayback()
        playbackTask = Task { @MainActor in
            do {
                // Synthesis receives only the authored Mandarin lines. The
                // audio service queues each sentence so the learner hears a
                // short breath between phrases and a longer one when the
                // speaker changes.
                try await model.dependencies.audio.speakSequence(segments)
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playbackMessage = "Dialogue lu en mandarin."
            } catch is CancellationError {
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playbackMessage = "Lecture arrêtée."
            } catch {
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playbackMessage = "Audio indisponible hors ligne."
            }
        }
    }

    private func playLine(_ line: DialogueLine, index: Int) {
        playbackTask?.cancel()
        playbackTask = nil
        model.dependencies.audio.stopSpeaking()
        model.dependencies.audio.stopPlayback()
        let token = UUID()
        playbackToken = token
        isPlaying = true
        playingLineIndex = index
        playbackMessage = nil
        playbackTask = Task { @MainActor in
            do {
                try await model.dependencies.audio.speakSequence(speechSegments(for: [line]))
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playingLineIndex = nil
                playbackMessage = "Réplique de \(line.speaker) lue en mandarin."
            } catch is CancellationError {
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playingLineIndex = nil
                playbackMessage = "Lecture arrêtée."
            } catch {
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playingLineIndex = nil
                playbackMessage = "Audio indisponible hors ligne."
            }
        }
    }
}

private struct ReadingPlaybackControl: View {
    let reading: ReadingBlock
    @EnvironmentObject private var model: AppModel
    @State private var isPlaying = false
    @AppStorage(SlowAudioToggle.storageKey) private var slowAudio = false
    @State private var playbackToken = UUID()
    @State private var playbackMessage = "Prêt à écouter."
    @State private var playbackTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button(action: togglePlayback) {
                    Label(
                        isPlaying ? "Arrêter" : "Écouter tout le texte",
                        systemImage: isPlaying ? "stop.fill" : "speaker.wave.2.fill"
                    )
                }
                .buttonStyle(.bordered)
                .tint(SylluneColor.skyButton)
                .frame(minHeight: 40)
                .accessibilityIdentifier("lesson.reading.\(reading.id.rawValue).playAll")
                .accessibilityLabel(isPlaying ? "Arrêter la lecture du texte" : "Écouter tout le texte")
                .accessibilityValue(isPlaying ? "Lecture en cours" : "Prêt à écouter")
                .accessibilityHint("Lit toutes les phrases chinoises dans l’ordre avec une courte pause entre elles.")
                SlowAudioToggle()
            }

            Text(playbackMessage)
                .font(.caption)
                .foregroundStyle(SylluneColor.inkMuted)
                .accessibilityIdentifier("lesson.reading.\(reading.id.rawValue).playbackStatus")
        }
        .onDisappear {
            stopPlayback(message: "Lecture arrêtée.")
        }
    }

    private func togglePlayback() {
        if isPlaying {
            stopPlayback(message: "Lecture arrêtée.")
            return
        }

        let segments = SpeechSynthesisSegment.narration(
            MandarinSpeechText.readingSegments(from: reading),
            rate: SlowAudioToggle.rate(slow: slowAudio)
        )
        guard !segments.isEmpty else {
            playbackMessage = "Le texte chinois est indisponible."
            return
        }

        let token = UUID()
        playbackToken = token
        isPlaying = true
        playbackMessage = "Lecture en cours…"
        playbackTask?.cancel()
        model.dependencies.audio.stopSpeaking()
        model.dependencies.audio.stopPlayback()
        playbackTask = Task { @MainActor in
            do {
                try await model.dependencies.audio.speakSequence(segments)
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playbackMessage = "Lecture terminée."
            } catch is CancellationError {
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playbackMessage = "Lecture arrêtée."
            } catch {
                guard playbackToken == token else { return }
                playbackTask = nil
                isPlaying = false
                playbackMessage = "Lecture impossible."
            }
        }
    }

    private func stopPlayback(message: String) {
        playbackTask?.cancel()
        playbackTask = nil
        playbackToken = UUID()
        model.dependencies.audio.stopSpeaking()
        model.dependencies.audio.stopPlayback()
        isPlaying = false
        playbackMessage = message
    }
}

private struct PedagogicalBlockView: View {

    let block: LessonBlock
    let vocabulary: [VocabularyEntry]
    let objectives: [LearningObjective]
    let languageCodes: [String]
    let objectiveResults: [String: Bool]
    let showsReadingAudioControl: Bool
    let dialogueDraft: Binding<String>?
    let dialogueResult: Binding<Bool?>?
    @EnvironmentObject private var model: AppModel

    init(
        block: LessonBlock,
        vocabulary: [VocabularyEntry],
        objectives: [LearningObjective] = [],
        languageCodes: [String],
        objectiveResults: [String: Bool] = [:],
        showsReadingAudioControl: Bool = true,
        dialogueDraft: Binding<String>? = nil,
        dialogueResult: Binding<Bool?>? = nil
    ) {
        self.block = block
        self.vocabulary = vocabulary
        self.objectives = objectives
        self.languageCodes = languageCodes
        self.objectiveResults = objectiveResults
        self.showsReadingAudioControl = showsReadingAudioControl
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
                    Button { Task { try? await model.dependencies.audio.play(asset: audio, rate: .normal) } } label: {
                        Label("Écouter l’introduction", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered).tint(SylluneColor.sky)
                }
            }
            .padding(16).sylluneCard(radius: 14)

        case .vocabulary(let value):
            // A word card per word: the lexeme with its audio, pinyin and
            // meaning, then its example. Every word is tappable for its fiche.
            VStack(alignment: .leading, spacing: 14) {
                ForEach(value.vocabularyIDs, id: \.self) { id in
                    if let word = vocabulary.first(where: { $0.id == id }) {
                        VStack(alignment: .leading, spacing: 10) {
                            ChineseSelectableText(
                                hanzi: word.hanzi,
                                font: .largeTitle.weight(.semibold),
                                speechEnabled: true,
                                vocabulary: [word],
                                segmentation: word.segmentation,
                                pinyin: word.pinyin,
                                translation: word.meaning.resolve(preferred: languageCodes),
                                audio: word.audio
                            )
                            .foregroundStyle(SylluneColor.ink)

                            if let example = word.example {
                                Divider()
                                // The example is a full Mandarin phrase, so
                                // the shared text control sends the complete
                                // phrase to the local zh-CN TTS. Its pinyin
                                // and translation stay attached to the
                                // example while the row above retains the
                                // lexeme's own pinyin and meaning.
                                ChineseSelectableText(
                                    hanzi: example.hanzi,
                                    font: .title3,
                                    speechEnabled: true,
                                    vocabulary: vocabulary,
                                    segmentation: example.segmentation,
                                    pinyin: example.pinyin,
                                    translation: example.translation.resolve(preferred: languageCodes),
                                    audio: example.audio
                                )
                                .foregroundStyle(SylluneColor.inkMuted)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .sylluneCard(radius: 16)
                    }
                }
            }

        case .dialogue(let value):
            DialogueBlockView(
                value: value,
                languageCodes: languageCodes,
                writtenResponse: dialogueDraft ?? .constant(""),
                responseResult: dialogueResult ?? .constant(nil)
            )

        case .reading(let value):
            VStack(alignment: .leading, spacing: 10) {
                Label(value.title.resolve(preferred: languageCodes) ?? "Lecture", systemImage: "book.pages")
                    .font(.headline).foregroundStyle(SylluneColor.ink)
                if showsReadingAudioControl {
                    ReadingPlaybackControl(reading: value)
                }
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
                            audio: paragraph.audio
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
                let isSelected = answer.map { value in
                    if case .choice(let selected) = value { return selected == choice.id }
                    return false
                } ?? false
                Button {
                    answer = .choice(choiceID: choice.id)
                    let target = PolygoCore.MandarinSpeechText.target(from: choice.label.resolve(preferred: ["fr", "en"]) ?? "")
                    guard !target.isEmpty else { return }
                    Task { try? await model.dependencies.audio.speak(text: target, localeIdentifier: "zh-CN", rate: .normal) }
                } label: {
                    HStack {
                        ChineseSelectableText(choice.label.resolve(preferred: ["fr", "en"]) ?? "", font: .title3, speechEnabled: false)
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(SylluneColor.jade)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(SylluneColor.ink)
                .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? SylluneColor.jade : SylluneColor.border, lineWidth: isSelected ? 2 : 1)
                )
                .accessibilityLabel(choice.label.resolve(preferred: ["fr", "en"]) ?? "Réponse")
                .accessibilityValue(isSelected ? "Sélectionnée" : "Non sélectionnée")
            }
        }
    }
}

private struct ListeningAnswerView: View {
    let exercise: ListeningChoiceExercise
    var listenTitle = "Écouter le mot"
    @Binding var answer: ExerciseAnswer?
    @State private var audioMessage: String?
    @AppStorage(SlowAudioToggle.storageKey) private var slowAudio = false
    @EnvironmentObject private var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button {
                    guard let promptText = exercise.promptText else {
                        audioMessage = "Aucune source audio n’est fournie. Le texte des réponses reste disponible."
                        return
                    }
                    Task {
                        do {
                            try await model.dependencies.audio.speak(
                                text: promptText,
                                localeIdentifier: "zh-CN",
                                rate: SlowAudioToggle.rate(slow: slowAudio),
                                asset: exercise.promptAudio
                            )
                            audioMessage = "Lecture terminée."
                        } catch is CancellationError {
                            audioMessage = "Lecture arrêtée."
                        } catch {
                            audioMessage = "Audio indisponible. Le texte des réponses reste disponible."
                        }
                    }
                } label: { Label(listenTitle, systemImage: "speaker.wave.2.fill") }
                    .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).listen")
                    .buttonStyle(.borderedProminent).tint(SylluneColor.sky)
                SlowAudioToggle()
            }
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
                    let isSelected = selected.contains(token.id)
                    Button {
                        if let index = selected.firstIndex(of: token.id) { selected.remove(at: index) }
                        else { selected.append(token.id) }
                        answer = .wordOrder(tokenIDs: selected)
                        Task {
                            try? await model.dependencies.audio.speak(text: token.hanzi, localeIdentifier: "zh-CN", rate: .normal)
                        }
                    } label: {
                        VStack(spacing: 3) {
                            ChineseSelectableText(token.hanzi, font: .title3, speechEnabled: false)
                            if let pinyin = token.pinyin { Text(pinyin).font(.callout) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SylluneColor.ink)
                    .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? SylluneColor.jade : SylluneColor.border, lineWidth: isSelected ? 2 : 1)
                    )
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
    @State private var selectedChoiceID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ChineseSelectableText(
                exercise.sentence,
                font: .title3,
                speechEnabled: true,
                speechText: exercise.canonicalSpeechSentence
            )
            .foregroundStyle(SylluneColor.ink)
            .padding(16)
            .sylluneCard(radius: 12)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                spacing: 8
            ) {
                ForEach(exercise.choiceOptions) { choice in
                    let value = choice.label.resolve(preferred: ["zh-CN", "zh", "en", "fr"]) ?? ""
                    let isSelected = selectedChoiceID == choice.id
                    Button {
                        selectedChoiceID = choice.id
                        answer = .text(value)
                    } label: {
                        HStack {
                            ChineseSelectableText(
                                value,
                                font: .title3,
                                speechEnabled: false,
                                wordInteractionEnabled: false
                            )
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(SylluneColor.jade)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SylluneColor.ink)
                    .background(SylluneColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(isSelected ? SylluneColor.jade : SylluneColor.border, lineWidth: isSelected ? 2 : 1)
                    )
                    .accessibilityLabel(value.isEmpty ? "Réponse" : value)
                    .accessibilityValue(isSelected ? "Sélectionnée" : "Non sélectionnée")
                    .accessibilityHint("Choisis cette proposition.")
                    .accessibilityIdentifier("lesson.exercise.\(exercise.header.id.rawValue).choice.\(choice.id)")
                }
            }
        }
        .onAppear {
            syncFromAnswer()
        }
        .onChange(of: answer) { _, _ in syncFromAnswer() }
    }

    private func syncFromAnswer() {
        guard case .text(let value) = answer else {
            selectedChoiceID = nil
            return
        }
        let normalized = TextNormalizer.normalize(value)
        selectedChoiceID = exercise.choiceOptions.first { choice in
            let candidate = choice.label.resolve(preferred: ["zh-CN", "zh", "en", "fr"]) ?? ""
            return TextNormalizer.normalize(candidate) == normalized
        }?.id
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
                    ReviewCardFaceView(card: card, revealed: revealed)
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
    private func ratingLabel(_ value: SelfRating) -> String { switch value { case .again: return "À refaire"; case .hard: return "Difficile"; case .good: return "Bien"; case .easy: return "Facile" } }
}
