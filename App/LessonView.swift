import SwiftUI
import PolygoCore
import PolygoApple

public struct LessonView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
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
    @State private var earnedCoins: Int?
    @State private var preambleExpanded = false
    @State private var readingReferenceExpanded = false
    @State private var dialogueDrafts: [BlockID: String] = [:]
    @State private var dialogueResults: [BlockID: Bool] = [:]
    /// Shows the lesson preamble on its own screen before the first exercise.
    @State private var showsIntro = true

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
                else if showsIntro, currentIndex == 0, hasPreamble(lesson) { introView(lesson, firstExercise: exercises[0].0) }
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
            model.dependencies.audio.stopSpeaking()
            model.dependencies.audio.stopPlayback()
            scheduleCheckpoint()
        }
        .sylluneFocusedExercise()
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
        // A lesson only reaches its terminal position by advancing past an
        // evaluated last exercise, so an unfinished lesson saved there without
        // any evaluation was never worked through (older builds could write
        // one from another lesson's leaked view state). Start it again rather
        // than presenting an empty recap.
        if currentIndex >= exercises.count, progress.completedAt == nil, progress.lastEvaluations.isEmpty {
            currentIndex = 0
        }
        showsIntro = currentIndex == 0

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
        // A learner who already answered the first exercise has seen the intro.
        showsIntro = currentIndex == 0 && answer == nil && evaluation == nil
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
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("\(currentIndex + 1) / \(exercises.count)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityIdentifier("lesson.exercise.\(spec.id.rawValue)")
                Spacer()
                ProgressView(value: Double(currentIndex), total: Double(max(1, exercises.count)))
                    .tint(SylluneColor.jade)
                    .frame(maxWidth: 180)
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) { Divider() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            exerciseActionBar(spec: spec, blockID: block.0)
        }
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

    private func hasPreamble(_ lesson: LessonDocument) -> Bool {
        guard let first = exercises.first,
              let index = lesson.blocks.firstIndex(where: { $0.id == first.0 }) else { return false }
        return index > 0
    }

    @ViewBuilder private func introView(_ lesson: LessonDocument, firstExercise: BlockID) -> some View {
        let hasDialogue = lesson.blocks.contains { block in
            if case .dialogue = block { return true }
            return false
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(hasDialogue ? "Découvre le dialogue" : "Découvre la leçon")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SylluneColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("Écoute l’échange à ton rythme, puis commence les exercices.")
                    .font(.body)
                    .foregroundStyle(SylluneColor.inkMuted)
                lessonPreamble(lesson, before: firstExercise)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Text("Intro")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(SylluneColor.inkMuted)
                    .accessibilityIdentifier("lesson.intro")
                Spacer()
                ProgressView(value: 0, total: Double(max(1, exercises.count)))
                    .tint(SylluneColor.jade)
                    .frame(maxWidth: 180)
            }
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) { Divider() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button("Commencer les exercices") { showsIntro = false }
                .buttonStyle(SyllunePrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("lesson.intro.start")
                .accessibilityHint("Affiche le premier exercice de la leçon.")
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) { Divider() }
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
        }
    }

    private func actionTitle(for spec: ExerciseSpec) -> String {
        if evaluation == nil {
            return continuesWithoutEvaluation(spec) ? "Continuer" : "Vérifier"
        }
        if evaluation?.accepted == true { return currentIndex + 1 < exercises.count ? "Continuer" : "Terminer" }
        return "Continuer malgré tout"
    }

    private func canSubmit(_ spec: ExerciseSpec) -> Bool {
        if evaluation != nil { return true }
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
        let skippedCount = answered.values.filter { $0.outcome == .skipped }.count
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

                Button("Recommencer cette leçon") {
                    Task { @MainActor in
                        guard await model.restartLesson(lessonID, persistRouteInNavigation: false) else { return }
                        currentIndex = 0
                        answer = nil
                        evaluation = nil
                        answered = [:]
                        dialogueDrafts = [:]
                        dialogueResults = [:]
                        earnedCoins = nil
                        finished = false
                        preambleExpanded = false
                        showsIntro = true
                    }
                }
                .buttonStyle(.bordered)
                Button("Retour au parcours") {
                    // Leave the recap only on request and persist the path root,
                    // rather than automatically opening the next lesson.
                    dismiss()
                    model.persistRoute(.path)
                }
                .buttonStyle(SyllunePrimaryButtonStyle())
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
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
            Spacer(minLength: 0)
            TaviMascot(pose: .encouragement)
                .frame(width: 60, height: 60)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
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
    /// Hanzi of the learner's last participation choice, persisted with the
    /// lesson checkpoint.
    @Binding var writtenResponse: String
    @Binding var responseResult: Bool?
    @EnvironmentObject private var model: AppModel
    @State private var isPlaying = false
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
                Text("Touche une réplique pour voir le pinyin et la traduction.")
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
                        Button {
                            if isRevealed { revealedLines.remove(index) } else { revealedLines.insert(index) }
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
            if isLeading { Spacer(minLength: 40) }
        }
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

    private func speechSegments(for lines: [DialogueLine]) -> [SpeechSynthesisSegment] {
        MandarinSpeechText.dialogueSegments(from: lines).map {
            SpeechSynthesisSegment(
                text: $0.text,
                localeIdentifier: "zh-CN",
                rate: .normal,
                postUtteranceDelay: $0.postUtteranceDelay
            )
        }
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
                if let audio = line.audio {
                    try await model.dependencies.audio.play(asset: audio)
                } else {
                    // Speak the line as segments so its internal comma
                    // pauses are honoured like in full playback.
                    try await model.dependencies.audio.speakSequence(speechSegments(for: [line]))
                }
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
    @State private var playbackToken = UUID()
    @State private var playbackMessage = "Prêt à écouter."
    @State private var playbackTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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

        let segments = MandarinSpeechText.readingSegments(from: reading).map {
            SpeechSynthesisSegment(
                text: $0.text,
                localeIdentifier: "zh-CN",
                rate: .normal,
                postUtteranceDelay: $0.postUtteranceDelay
            )
        }
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
                        VStack(alignment: .leading, spacing: 6) {
                            // A word is a learning interaction, not a detour
                            // to another screen. The Chinese control speaks
                            // the lexeme while the compact row keeps the
                            // lesson moving.
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

                            if let example = word.example {
                                let exampleTranslation = example.translation.resolve(preferred: languageCodes) ?? ""
                                // The example is a full Mandarin phrase, so
                                // the shared text control sends the complete
                                // phrase to the local zh-CN TTS. Its pinyin
                                // and translation stay attached to the
                                // example while the row above retains the
                                // lexeme's own pinyin and meaning.
                                ChineseSelectableText(
                                    hanzi: example.hanzi,
                                    font: .body,
                                    speechEnabled: true,
                                    pinyin: example.pinyin,
                                    translation: exampleTranslation,
                                    audio: example.audio,
                                    wordInteractionEnabled: false
                                )
                                .foregroundStyle(SylluneColor.inkMuted)
                                .padding(.leading, 10)
                                .accessibilityLabel("Exemple : \(example.hanzi), \(example.pinyin), \(exampleTranslation)")
                            }
                        }
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
    @Binding var answer: ExerciseAnswer?
    @EnvironmentObject private var model: AppModel
    @State private var audioMessage: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                Task {
                    do {
                        if let promptAudio = exercise.promptAudio {
                            try await model.dependencies.audio.play(asset: promptAudio)
                        } else if let promptText = exercise.promptText {
                            try await model.dependencies.audio.speak(text: promptText, localeIdentifier: "zh-CN", rate: .normal)
                        } else {
                            audioMessage = "Aucune source audio n’est fournie. Le texte des réponses reste disponible."
                            return
                        }
                        audioMessage = "Lecture terminée."
                    } catch {
                        audioMessage = "Audio indisponible. Le texte des réponses reste disponible."
                    }
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
