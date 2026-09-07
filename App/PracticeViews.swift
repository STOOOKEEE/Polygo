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
                    ChineseSelectableText(exercise.header.prompt.resolve(preferred: model.preferredLanguageCodes) ?? "Oral", font: .largeTitle.weight(.semibold))
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
    @State private var strokeCount = 0
    @State private var points: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []

    public init(exerciseID: ExerciseID) { self.exerciseID = exerciseID }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let exercise {
                    Text(exercise.header.prompt.resolve(preferred: model.preferredLanguageCodes) ?? "Écriture")
                        .font(.largeTitle.weight(.semibold)).foregroundStyle(SylluneColor.ink)
                    ZStack {
                    ChineseSelectableText(exercise.targetHanzi, font: .system(size: 150, design: .serif)).foregroundStyle(SylluneColor.ink.opacity(0.12))
                        Canvas { context, _ in
                            for stroke in points where stroke.count > 1 {
                                var path = Path(); path.move(to: stroke[0]); for point in stroke.dropFirst() { path.addLine(to: point) }
                                context.stroke(path, with: .color(SylluneColor.ink), lineWidth: 4)
                            }
                            if currentStroke.count > 1 {
                                var path = Path(); path.move(to: currentStroke[0]); for point in currentStroke.dropFirst() { path.addLine(to: point) }
                                context.stroke(path, with: .color(SylluneColor.coral), lineWidth: 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .background(SylluneColor.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(SylluneColor.border, lineWidth: 1))
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in if currentStroke.isEmpty { currentStroke = [value.location] } else { currentStroke.append(value.location) } }.onEnded { _ in if currentStroke.count > 1 { points.append(currentStroke); strokeCount += 1 }; currentStroke = [] })
                    .accessibilityLabel("Grille d’écriture pour \(exercise.targetHanzi). \(strokeCount) traits tracés.")
                    HStack {
                        Button("Effacer") { points.removeAll(); currentStroke.removeAll(); strokeCount = 0; answer = nil }.buttonStyle(.bordered)
                        Button("Voir le modèle") { points.removeAll(); currentStroke.removeAll() }.buttonStyle(.bordered)
                    }
                    Text("Le tracé est conservé localement et peut être auto-évalué quand la reconnaissance n’est pas disponible.").font(.caption).foregroundStyle(SylluneColor.inkMuted)
                    HStack {
                        Button("À refaire") { answer = .handwriting(HandwritingAnswer(strokeCount: strokeCount, selfChecked: false)) }.buttonStyle(.bordered)
                        Button("Bien") { answer = .handwriting(HandwritingAnswer(strokeCount: strokeCount, selfChecked: true)) }.buttonStyle(.borderedProminent).tint(SylluneColor.jade)
                    }
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
