import SwiftUI
import PolygoCore
import PolygoApple

public struct OralView: View {
    @EnvironmentObject private var model: AppModel
    public let exerciseID: ExerciseID
    @State private var exercise: SpeakingExercise?
    @State private var lessonID: LessonID?
    @State private var blockID: BlockID?
    @State private var answer: ExerciseAnswer?
    @State private var evaluation: ExerciseEvaluation?
    @State private var message: String?

    public init(exerciseID: ExerciseID) { self.exerciseID = exerciseID }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let exercise {
                    ChineseSelectableText(
                        exercise.header.prompt.resolve(preferred: model.preferredLanguageCodes) ?? "Oral",
                        font: .largeTitle.weight(.semibold),
                        speechEnabled: false
                    )
                        .foregroundStyle(SylluneColor.ink)
                    SpeechPracticeView(
                        exercise: exercise,
                        audio: model.dependencies.audio,
                        answer: $answer,
                        onRecordingCreated: { recordingID in
                            Task { await model.saveRecording(recordingID, exerciseID: exerciseID) }
                        }
                    )
                    if let evaluation { FeedbackViewForPractice(evaluation: evaluation) }
                    Button(evaluation == nil ? "Vérifier" : "Terminer") { submit() }
                        .buttonStyle(SyllunePrimaryButtonStyle()).disabled(answer == nil || lessonID == nil || blockID == nil)
                } else if let message { ContentUnavailableView("Exercice oral indisponible", systemImage: "mic.slash", description: Text(message)) }
                else { ProgressView("Chargement de l’exercice…") }
            }
            .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .background(SylluneColor.canvas).navigationTitle("Oral")
        .task { await findExercise() }
    }

    private func findExercise() async {
        for id in model.orderedLessonIDs {
            guard let lesson = await model.loadLesson(id) else { continue }
            for block in lesson.blocks {
                guard case .exercise(let exerciseBlock) = block, exerciseBlock.spec.id == exerciseID else { continue }
                if case .speaking(let speaking) = exerciseBlock.spec { exercise = speaking; lessonID = id; blockID = block.id; return }
            }
        }
        message = "La phrase orale n’est pas fournie par le contenu local."
    }

    private func submit() {
        if let evaluation { _ = evaluation; return }
        guard let exercise, let answer, let lessonID, let blockID else { return }
        Task { evaluation = await model.evaluate(.speaking(exercise), answer: answer, lessonID: lessonID, blockID: blockID) }
    }
}

public struct WritingView: View {
    @EnvironmentObject private var model: AppModel
    public let exerciseID: ExerciseID
    @State private var exercise: HandwritingExercise?
    @State private var lessonID: LessonID?
    @State private var blockID: BlockID?
    @State private var answer: ExerciseAnswer?
    @State private var evaluation: ExerciseEvaluation?
    @State private var message: String?

    public init(exerciseID: ExerciseID) { self.exerciseID = exerciseID }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let exercise {
                    HandwritingPracticeView(
                        exercise: exercise,
                        answer: $answer,
                        service: model.dependencies.handwriting,
                        onDrawingCreated: { drawingID in
                            Task { _ = await model.saveDrawing(drawingID, exerciseID: exerciseID) }
                        }
                    )
                    if let evaluation { FeedbackViewForPractice(evaluation: evaluation) }
                    Button(evaluation == nil ? "Vérifier" : "Terminer") { submit() }.buttonStyle(SyllunePrimaryButtonStyle()).disabled(answer == nil || lessonID == nil || blockID == nil)
                } else if let message { ContentUnavailableView("Exercice d’écriture indisponible", systemImage: "pencil.slash", description: Text(message)) }
                else { ProgressView("Chargement de l’exercice…") }
            }
            .frame(maxWidth: 680, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading).padding(20)
        }
        .background(SylluneColor.canvas).navigationTitle("Écriture")
        .task { await findExercise() }
    }

    private func findExercise() async {
        for id in model.orderedLessonIDs {
            guard let lesson = await model.loadLesson(id) else { continue }
            for block in lesson.blocks {
                guard case .exercise(let exerciseBlock) = block, exerciseBlock.spec.id == exerciseID else { continue }
                if case .handwriting(let handwriting) = exerciseBlock.spec { exercise = handwriting; lessonID = id; blockID = block.id; return }
            }
        }
        message = "Le caractère n’est pas fourni par le contenu local."
    }

    private func submit() {
        if evaluation != nil { return }
        guard let exercise, let answer, let lessonID, let blockID else { return }
        Task { evaluation = await model.evaluate(.handwriting(exercise), answer: answer, lessonID: lessonID, blockID: blockID) }
    }
}

private struct FeedbackViewForPractice: View {
    let evaluation: ExerciseEvaluation
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: evaluation.accepted ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill").foregroundStyle(evaluation.accepted ? SylluneColor.success : SylluneColor.error)
            VStack(alignment: .leading, spacing: 4) { Text(evaluation.accepted ? "Réponse enregistrée" : "À revoir").font(.headline); Text(evaluation.feedback.resolve(preferred: ["fr", "en"]) ?? "").font(.body) }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).sylluneCard(radius: 12)
    }
}
