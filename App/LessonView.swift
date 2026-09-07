import SwiftUI
import PolygoCore
import PolygoApple

public struct LessonView: View {
    @EnvironmentObject private var model: AppModel
    public let lessonID: LessonID
    @State private var lesson: LessonDocument?
    @State private var currentIndex = 0
    @State private var answer: ExerciseAnswer?
    @State private var evaluation: ExerciseEvaluation?
    @State private var answered: [ExerciseID: ExerciseEvaluation] = [:]
    @State private var didStart = false
    @State private var finished = false

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
                else { completionView(lesson) }
            } else {
                ProgressView("Chargement de la leçon…")
            }
        }
        .background(SylluneColor.canvas)
        .navigationTitle(lesson?.title.resolve(preferred: model.preferredLanguageCodes) ?? "Leçon")
        .task {
            lesson = await model.loadLesson(lessonID)
            if !didStart { didStart = true; await model.startLesson(lessonID) }
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
                ChineseSelectableText(spec.header.prompt.resolve(preferred: model.preferredLanguageCodes) ?? "Exercice", font: .title2.weight(.semibold))
                    .foregroundStyle(SylluneColor.ink)
                Text(spec.header.instruction.resolve(preferred: model.preferredLanguageCodes) ?? "")
                    .font(.body).foregroundStyle(SylluneColor.inkMuted)

                answerControl(spec)

                if let evaluation {
                    FeedbackView(evaluation: evaluation)
                }

                // Recap blocks are authored after the exercise sequence. Keep
                // them in the lesson flow so the learner can see the bilan
                // before deciding whether to finish the lesson.
                if evaluation != nil, currentIndex == exercises.count - 1 {
                    lessonEpilogue(lesson, after: block.0)
                }

                HStack(spacing: 12) {
                    if evaluation != nil {
                        Button("Réessayer") { self.evaluation = nil; self.answer = nil }
                            .buttonStyle(.bordered)
                            .disabled(evaluation?.accepted == true)
                    }
                    Spacer()
                    Button(actionTitle) { submitOrAdvance(spec: spec, blockID: block.0) }
                        .buttonStyle(SyllunePrimaryButtonStyle())
                        .disabled(!canSubmit(spec))
                        .frame(maxWidth: 240)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    @ViewBuilder private func lessonPreamble(_ lesson: LessonDocument, before blockID: BlockID) -> some View {
        if let index = lesson.blocks.firstIndex(where: { $0.id == blockID }) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(lesson.blocks.prefix(upTo: index)), id: \.id) { block in
                    PedagogicalBlockView(
                        block: block,
                        vocabulary: lesson.vocabulary,
                        objectives: lesson.objectives,
                        languageCodes: model.preferredLanguageCodes
                    )
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
                            objectiveResults: objectiveResults(for: block)
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

    private var actionTitle: String {
        if evaluation == nil { return "Vérifier" }
        if evaluation?.accepted == true { return currentIndex + 1 < exercises.count ? "Continuer" : "Terminer" }
        return "Continuer malgré tout"
    }

    private func canSubmit(_ spec: ExerciseSpec) -> Bool {
        if evaluation != nil { return true }
        guard answer != nil else { return false }
        if case .flashcard = spec { return true }
        return true
    }

    private func submitOrAdvance(spec: ExerciseSpec, blockID: BlockID) {
        if let evaluation {
            if evaluation.accepted { advance() }
            else { advance() }
            return
        }
        guard let answer else { return }
        Task {
            if let result = await model.evaluate(spec, answer: answer, lessonID: lessonID, blockID: blockID) {
                self.evaluation = result
                self.answered[spec.id] = result
            }
        }
    }

    private func advance() {
        if currentIndex + 1 < exercises.count {
            currentIndex += 1; answer = nil; evaluation = nil
        } else {
            let required = exercises.filter { $0.1.header.required }.map(\.1.id)
            let complete = required.allSatisfy { evaluationCountsAsComplete(answered[$0]) }
            if complete {
                Task { await model.completeLesson(lessonID); finished = true }
            } else {
                finished = true
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: evaluation.accepted ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                .foregroundStyle(evaluation.accepted ? SylluneColor.success : SylluneColor.error)
            VStack(alignment: .leading, spacing: 4) {
                Text(evaluation.accepted ? "Correct" : "À revoir").font(.headline)
                Text(evaluation.feedback.resolve(preferred: ["fr", "en"]) ?? "").font(.body)
            }
        }
        .foregroundStyle(SylluneColor.ink)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).sylluneCard(radius: 12)
        .accessibilityElement(children: .combine)
    }
}

private struct PedagogicalBlockView: View {
    let block: LessonBlock
    let vocabulary: [VocabularyEntry]
    let objectives: [LearningObjective]
    let languageCodes: [String]
    let objectiveResults: [String: Bool]
    @EnvironmentObject private var model: AppModel

    init(
        block: LessonBlock,
        vocabulary: [VocabularyEntry],
        objectives: [LearningObjective] = [],
        languageCodes: [String],
        objectiveResults: [String: Bool] = [:]
    ) {
        self.block = block
        self.vocabulary = vocabulary
        self.objectives = objectives
        self.languageCodes = languageCodes
        self.objectiveResults = objectiveResults
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
                        NavigationLink(destination: WordDetailView(vocabularyID: word.id)) {
                            HStack(spacing: 12) {
                                Text(word.hanzi).font(.title3).foregroundStyle(SylluneColor.ink)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(word.pinyin).font(.body).foregroundStyle(SylluneColor.jadeDeep)
                                    Text(word.meaning.resolve(preferred: languageCodes) ?? "—").font(.caption).foregroundStyle(SylluneColor.inkMuted)
                                }
                                Spacer(); Image(systemName: "chevron.right").foregroundStyle(SylluneColor.inkMuted)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16).sylluneCard(radius: 14)

        case .dialogue(let value):
            VStack(alignment: .leading, spacing: 8) {
                Text("Dialogue").font(.headline).foregroundStyle(SylluneColor.ink)
                ForEach(Array(value.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(line.speaker).font(.caption.weight(.semibold)).foregroundStyle(SylluneColor.inkMuted).frame(width: 56, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            ChineseSelectableText(
                                hanzi: line.hanzi,
                                font: .body,
                                speechEnabled: true,
                                vocabulary: vocabulary,
                                pinyin: line.pinyin,
                                translation: line.translation.resolve(preferred: languageCodes),
                                audio: line.audio
                            )
                            .foregroundStyle(SylluneColor.ink)
                        }
                    }
                }
            }
            .padding(16).sylluneCard(radius: 14)

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
                            wordInteractionEnabled: true
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
                                NavigationLink(destination: WordDetailView(vocabularyID: word.id)) {
                                    HStack(spacing: 8) {
                                        ChineseSelectableText(
                                            hanzi: word.hanzi,
                                            font: .body,
                                            speechEnabled: false,
                                            vocabulary: [word],
                                            segmentation: word.segmentation,
                                            pinyin: word.pinyin,
                                            translation: word.meaning.resolve(preferred: languageCodes),
                                            audio: word.audio,
                                            wordInteractionEnabled: false
                                        )
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(SylluneColor.inkMuted)
                                    }
                                }
                                .buttonStyle(.plain)
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
    var body: some View {
        VStack(spacing: 10) {
            ForEach(exercise.choices) { choice in
                Button {
                    answer = .choice(choiceID: choice.id)
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
                    } label: {
                        VStack(spacing: 3) { ChineseSelectableText(token.hanzi, font: .title3, speechEnabled: false); if let pinyin = token.pinyin { Text(pinyin).font(.caption) } }
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(.bordered).tint(selected.contains(token.id) ? SylluneColor.jade : SylluneColor.inkMuted)
                    .accessibilityLabel("\(token.hanzi), position \(selected.firstIndex(of: token.id).map { String($0 + 1) } ?? "non choisie")")
                }
            }
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
    }
    private func display(_ side: CardSide) -> String { side.hanzi ?? side.pinyin ?? side.text?.resolve(preferred: ["fr", "en"]) ?? "—" }
    private func ratingLabel(_ value: SelfRating) -> String { switch value { case .again: return "À refaire"; case .hard: return "Difficile"; case .good: return "Bien"; case .easy: return "Facile" } }
}
