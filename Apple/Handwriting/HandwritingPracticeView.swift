import Foundation
import SwiftUI
import PolygoCore
#if os(iOS)
import UIKit
#endif

public enum HandwritingPracticeMode: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case guided
    case free

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .guided: return "Guidé"
        case .free: return "Libre"
        }
    }
}

/// Portable handwriting exercise UI for iOS/iPadOS and native macOS.
///
/// The canvas is a SwiftUI `Canvas` with a zero-distance `DragGesture`. It
/// therefore accepts a finger or Apple Pencil on iOS and a mouse or trackpad
/// on macOS without a platform-specific PencilKit dependency.
public struct HandwritingPracticeView: View {
    public let exercise: HandwritingExercise
    @Binding public var answer: ExerciseAnswer?

    private let handwritingService: any HandwritingService
    private let suppliedGuide: HandwritingGuide?
    private let onDrawingCreated: ((DrawingID) -> Void)?

    @State private var mode: HandwritingPracticeMode = .guided
    @State private var strokes: [HandwritingStroke] = []
    @State private var activeStroke: [HandwritingPoint] = []
    @State private var canvasSize = CGSize(width: 1, height: 1)
    @State private var guideStep = 0
    @State private var isGuidePlaying = false
    @State private var guideTask: Task<Void, Never>?
    @State private var hintLevel = 0
    @State private var validation: HandwritingValidation?
    @State private var strokeValidation: HandwritingStrokeValidation?
    @State private var rejectedStroke: [HandwritingPoint] = []
    @State private var strokeError: String?
    @State private var savedDrawingID: DrawingID?
    @State private var isSaving = false
    @State private var statusMessage: String?

    private var canvasMaximumDimension: CGFloat {
        #if os(macOS)
        return 440
        #else
        return 520
        #endif
    }

    /// The two-argument initializer is the integration contract used by
    /// LessonView and the standalone writing page.
    public init(
        exercise: HandwritingExercise,
        answer: Binding<ExerciseAnswer?>
    ) {
        self.init(exercise: exercise, answer: answer, service: nil, guide: nil, onDrawingCreated: nil)
    }

    /// The optional dependencies let the app inject its configured local
    /// service or a guide decoded through ContentStore. Existing callers can
    /// keep using the two-argument initializer above.
    public init(
        exercise: HandwritingExercise,
        answer: Binding<ExerciseAnswer?>,
        service: (any HandwritingService)?,
        guide: HandwritingGuide? = nil,
        onDrawingCreated: ((DrawingID) -> Void)? = nil
    ) {
        self.exercise = exercise
        self._answer = answer
        self.handwritingService = service ?? LocalHandwritingService.shared
        self.suppliedGuide = guide
        self.onDrawingCreated = onDrawingCreated
    }

    private var guide: HandwritingGuide? {
        suppliedGuide ?? HandwritingGuideCatalog.guide(for: exercise)
    }

    private var hasDrawing: Bool {
        !strokes.isEmpty || !activeStroke.isEmpty
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading
            modePicker
            canvasSection
            drawingControls
            validationSection
            answerSection

            if let statusMessage {
                Text(statusMessage)
                    .font(.callout)
                    .foregroundStyle(strokeError == nil ? .secondary : .red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: mode) { _, newMode in
            rejectedStroke.removeAll(keepingCapacity: true)
            strokeValidation = nil
            strokeError = nil
            validation = nil
            if newMode == .guided {
                playGuide()
            } else {
                stopGuide()
            }
        }
        .task(id: exercise.header.id.rawValue) {
            if mode == .guided { playGuide() }
        }
        .onDisappear {
            guideTask?.cancel()
            guideTask = nil
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(exercise.targetHanzi)
                .font(.system(size: 54, weight: .semibold, design: .serif))
                .accessibilityAddTraits(.isHeader)
            Text(exercise.header.instruction.resolve(preferred: ["fr", "en"]) ?? "Trace le caractère.")
                .font(.body)
                .foregroundStyle(.secondary)
            if let guide {
                Text("Guide local : \(guide.expectedStrokeCount) traits dans l’ordre.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Guide de traits indisponible pour ce caractère. Le résultat sera une auto-évaluation explicite.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var modePicker: some View {
        Picker("Mode de tracé", selection: $mode) {
            ForEach(HandwritingPracticeMode.allCases) { value in
                Text(value.title).tag(value)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Le mode guidé affiche les traits du modèle. Le mode libre masque le guide pendant le tracé.")
    }

    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack {
                    if mode == .free || guide == nil {
                        Text(exercise.targetHanzi)
                            .font(.system(size: min(proxy.size.width * 0.70, 300), weight: .regular, design: .serif))
                            .foregroundStyle(.primary.opacity(0.09))
                            .allowsHitTesting(false)
                    }

                    Canvas { context, size in
                        renderCanvas(context: &context, size: size)
                    }

                    #if os(iOS)
                    // A SwiftUI DragGesture attached below a Canvas can lose
                    // the touch to the UIScrollView used by the lesson. This
                    // UIKit surface owns a real UIPanGestureRecognizer and
                    // lets that recognizer coordinate with the ancestor
                    // scroll pan.
                    HandwritingTouchSurface(
                        strokeCount: strokes.count,
                        isEnabled: !isSaving,
                        accessibilityLabel: "Zone de tracé pour \(exercise.targetHanzi)",
                        onChanged: appendPoint,
                        onEnded: finishStroke
                    )
                    #else
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .highPriorityGesture(drawingGesture(for: proxy.size))
                    #endif
                }
                // The canvas lives inside the lesson's vertical ScrollView.
                // Give the drawing surface priority so a vertical stroke is
                // captured as handwriting instead of being consumed as a
                // scroll gesture by the parent.
                .allowsHitTesting(!isSaving)
                .onAppear { canvasSize = proxy.size }
#if !os(iOS)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Zone de tracé pour \(exercise.targetHanzi)")
                .accessibilityValue("\(strokes.count) traits tracés")
                .accessibilityHint("Dessine avec le doigt, le Pencil, la souris ou le trackpad.")
#endif
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(minHeight: 260, idealHeight: 360, maxHeight: canvasMaximumDimension)
            .frame(maxWidth: canvasMaximumDimension)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
            }

            if let guide {
                Text(mode == .guided
                     ? guideCaption(for: guide)
                     : "Mode libre : le guide est masqué pendant le tracé, mais reste disponible pour vérifier ensuite.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Le caractère cible reste visible comme repère. Il n’y a pas de prétendue correction géométrique sans guide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let strokeError {
                Label(strokeError, systemImage: "xmark.circle.fill")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.red)
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var drawingControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: undo) {
                    Label("Annuler", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(strokes.isEmpty || isSaving)

                Button(role: .destructive, action: clearCanvas) {
                    Label("Effacer", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(!hasDrawing || isSaving)

                Button(action: validateDrawing) {
                    Label("Vérifier le tracé", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasDrawing || isSaving)
            }

            if let guide {
                HStack(spacing: 10) {
                    Button(action: playGuide) {
                        Label(isGuidePlaying ? "Ordre en cours…" : "Rejouer l’ordre", systemImage: "play.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isGuidePlaying)

                    Button(action: revealHint) {
                        Label(hintTitle(for: guide), systemImage: "lightbulb")
                    }
                    .buttonStyle(.bordered)
                    .disabled(hintLevel >= guide.expectedStrokeCount)
                }
            }
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if let validation {
            VStack(alignment: .leading, spacing: 8) {
                Label(validationTitle(validation), systemImage: validationIcon(validation))
                    .font(.headline)
                    .foregroundStyle(validationColor(validation))
                Text(validationExplanation(validation))
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if validation.hasGuide {
                    HStack(spacing: 12) {
                        metric("Traits", value: strokeCountValue(validation))
                        metric("Directions", value: qualityLabel(validation.directionScore))
                        metric("Formes", value: qualityLabel(validation.shapeScore))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var answerSection: some View {
        if validation?.outcome == .noGuide {
            if exercise.allowSelfRating {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-évaluation")
                        .font(.headline)
                    Text("Le guide manque pour ce caractère. Choisis explicitement ce que tu ressens après avoir tracé.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button("À refaire") { submitAnswer(selfChecked: false) }
                            .buttonStyle(.bordered)
                            .disabled(isSaving)
                        Button("Je suis à l’aise") { submitAnswer(selfChecked: true) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            } else {
                Text("L’auto-évaluation est désactivée et aucun guide n’est disponible : cette réponse ne peut pas être validée.")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } else if validation?.isApproximateMatch == true {
            Button(action: { submitAnswer(selfChecked: true) }) {
                Label(isSaving ? "Enregistrement…" : "Enregistrer ce tracé", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        } else if validation != nil {
            HStack(spacing: 10) {
                Button("Recommencer", action: clearCanvas)
                    .buttonStyle(.bordered)
                if exercise.allowSelfRating {
                    Button("À refaire") { submitAnswer(selfChecked: false) }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                }
            }
        }

        if answer != nil {
            Label("Réponse manuscrite prête à être évaluée.", systemImage: "checkmark.seal")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
    }

    private func drawingGesture(for size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                appendPoint(value.location, in: size)
            }
            .onEnded { _ in
                finishStroke()
            }
    }

    private func appendPoint(_ location: CGPoint, in size: CGSize) {
        canvasSize = size
        if activeStroke.isEmpty {
            prepareForStroke()
        }
        let point = HandwritingPoint(clamped: location, in: size)
        if let last = activeStroke.last, distance(last, point) < 0.002 {
            return
        }
        activeStroke.append(point)
    }

    private func finishStroke() {
        guard !activeStroke.isEmpty else { return }
        let candidate = HandwritingStroke(points: activeStroke)
        activeStroke.removeAll(keepingCapacity: true)

        guard mode == .guided, let guide else {
            strokes.append(candidate)
            rejectedStroke.removeAll(keepingCapacity: true)
            strokeValidation = nil
            validation = nil
            strokeError = nil
            statusMessage = nil
            return
        }

        let expectedIndex = strokes.count
        guard expectedIndex < guide.strokes.count else {
            rejectedStroke = candidate.points
            strokeValidation = nil
            validation = nil
            strokeError = "Les \(guide.expectedStrokeCount) traits sont déjà validés. Recommence le dernier trait si besoin."
            statusMessage = nil
            return
        }

        let check = HandwritingGeometryValidator.validateStroke(
            candidate,
            against: guide.strokes[expectedIndex],
            expectedStrokeIndex: expectedIndex
        )
        guard check.isValid else {
            rejectedStroke = candidate.points
            strokeValidation = check
            validation = nil
            let label = guide.strokes[expectedIndex].label.map { " (\($0))" } ?? ""
            strokeError = "Trait \(expectedIndex + 1)/\(guide.expectedStrokeCount)\(label) à refaire : commence au point orange et suis la flèche jusqu’au bout."
            statusMessage = nil
            return
        }

        strokes.append(candidate)
        rejectedStroke.removeAll(keepingCapacity: true)
        strokeValidation = check
        validation = nil
        strokeError = nil
        guideStep = strokes.count
        statusMessage = "Trait \(strokes.count)/\(guide.expectedStrokeCount) validé."
    }

    private func prepareForStroke() {
        invalidatePreviousAnswer()
        rejectedStroke.removeAll(keepingCapacity: true)
        strokeValidation = nil
        strokeError = nil
        if isGuidePlaying {
            guideTask?.cancel()
            guideTask = nil
            isGuidePlaying = false
            guideStep = strokes.count
        }
    }

    private func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        invalidatePreviousAnswer()
        rejectedStroke.removeAll(keepingCapacity: true)
        strokeValidation = nil
        strokeError = nil
        if mode == .guided { guideStep = strokes.count }
        statusMessage = "Dernier trait annulé."
    }

    private func clearCanvas() {
        guard hasDrawing else { return }
        strokes.removeAll()
        activeStroke.removeAll()
        validation = nil
        rejectedStroke.removeAll()
        strokeValidation = nil
        strokeError = nil
        hintLevel = 0
        guideStep = 0
        guideTask?.cancel()
        guideTask = nil
        isGuidePlaying = false
        invalidatePreviousAnswer()
        statusMessage = "Tracé effacé."
    }

    private func validateDrawing() {
        guard hasDrawing else {
            statusMessage = "Trace au moins un trait avant de vérifier."
            return
        }
        let hadActiveStroke = !activeStroke.isEmpty
        finishStroke()
        if hadActiveStroke, strokeError != nil { return }
        let result = HandwritingGeometryValidator.validate(
            strokes: strokes,
            guide: guide,
            expectedStrokeCount: exercise.expectedStrokeCount
        )
        validation = result
        statusMessage = result.outcome == .noGuide
            ? "Aucun guide local : choisis une auto-évaluation après ton tracé."
            : "Vérification terminée : \(strokeCountValue(result)) traits, directions \(qualityLabel(result.directionScore)), formes \(qualityLabel(result.shapeScore))."
    }

    private func revealHint() {
        guard let guide else { return }
        hintLevel = min(guide.expectedStrokeCount, hintLevel + 1)
        statusMessage = "Indice \(hintLevel) affiché : \(hintLevel) \(hintLevel == 1 ? "trait" : "traits") du modèle."
    }

    @MainActor
    private func playGuide() {
        guard let guide else { return }
        guideTask?.cancel()
        guideStep = 0
        isGuidePlaying = true
        guideTask = Task { @MainActor in
            for nextStep in 1...guide.expectedStrokeCount {
                try? await Task.sleep(nanoseconds: 560_000_000)
                guard !Task.isCancelled else { return }
                guideStep = nextStep
            }
            isGuidePlaying = false
            guideTask = nil
        }
    }

    private func stopGuide() {
        guideTask?.cancel()
        guideTask = nil
        isGuidePlaying = false
        if let guide { guideStep = guide.expectedStrokeCount }
    }

    private func invalidatePreviousAnswer() {
        answer = nil
        validation = nil
        guard savedDrawingID != nil else { return }
        self.savedDrawingID = nil
        // A drawing that has already been handed to the app model belongs to
        // the append-only history. Keep its local capture available when the
        // learner starts a new attempt instead of leaving a dangling event.
    }

    private func submitAnswer(selfChecked: Bool) {
        guard hasDrawing, answer == nil, !isSaving else { return }
        finishStroke()
        guard !strokes.isEmpty else { return }
        isSaving = true
        statusMessage = nil

        let drawingID = DrawingID(rawValue: "drawing-\(UUID().uuidString.lowercased())")!
        let capture: DrawingCapture
        do {
            capture = try HandwritingCaptureCodec.makeCapture(
                drawingID: drawingID,
                strokes: strokes,
                canvasSize: canvasSize
            )
        } catch {
            isSaving = false
            statusMessage = error.localizedDescription
            return
        }

        Task { @MainActor in
            do {
                let persistedID = try await handwritingService.persist(capture)
                savedDrawingID = persistedID
                onDrawingCreated?(persistedID)
                answer = .handwriting(HandwritingAnswer(
                    drawingID: persistedID,
                    recognizedText: nil,
                    strokeCount: strokes.count,
                    selfChecked: selfChecked
                ))
                statusMessage = "Tracé enregistré localement. Aucune reconnaissance OCR n’a été effectuée."
            } catch {
                // A service may deliberately be unavailable in a preview. A
                // real drawing can still be handed to the engine without a
                // DrawingID, while the UI states that persistence failed.
                answer = .handwriting(HandwritingAnswer(
                    drawingID: nil,
                    recognizedText: nil,
                    strokeCount: strokes.count,
                    selfChecked: selfChecked
                ))
                statusMessage = "Réponse préparée, mais le dessin n’a pas pu être conservé localement : \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private func renderCanvas(context: inout GraphicsContext, size: CGSize) {
        drawGrid(in: &context, size: size)

        if mode == .guided, let guide {
            for (index, stroke) in guide.strokes.enumerated() {
                let isHint = index < hintLevel
                let isRevealed = !isGuidePlaying
                    ? index < strokes.count
                    : index < guideStep
                let activeIndex = isGuidePlaying
                    ? guideStep
                    : (strokes.count < guide.expectedStrokeCount ? strokes.count : nil)
                let isActive = activeIndex == index
                let color: Color
                let style: StrokeStyle
                if isActive {
                    color = .orange.opacity(0.86)
                    style = StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                } else if isHint || isRevealed {
                    color = .accentColor.opacity(isHint ? 0.62 : 0.38)
                    style = StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                } else {
                    color = .secondary.opacity(0.16)
                    style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round, dash: [6, 6])
                }
                context.stroke(path(for: stroke.points, in: size), with: .color(color), style: style)
                if isActive, let first = stroke.points.first, let last = stroke.points.last {
                    drawMarker(at: first.point(in: size), in: &context, color: .orange, radius: 5)
                    let previous = stroke.points.dropLast().last ?? first
                    drawArrow(
                        from: previous.point(in: size),
                        to: last.point(in: size),
                        in: &context,
                        color: .orange
                    )
                }
            }
        }

        for stroke in strokes {
            context.stroke(
                path(for: stroke.points, in: size),
                with: .color(.primary.opacity(0.86)),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
        }
        if !rejectedStroke.isEmpty {
            context.stroke(
                path(for: rejectedStroke, in: size),
                with: .color(.red.opacity(0.92)),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
        }
        if !activeStroke.isEmpty {
            context.stroke(
                path(for: activeStroke, in: size),
                with: .color(.orange),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        var grid = Path()
        for fraction in [0.25, 0.5, 0.75] {
            let x = size.width * fraction
            let y = size.height * fraction
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: size.height))
            grid.move(to: CGPoint(x: 0, y: y))
            grid.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(
            grid,
            with: .color(.secondary.opacity(0.14)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 5])
        )
    }

    private func drawMarker(at point: CGPoint, in context: inout GraphicsContext, color: Color, radius: CGFloat) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    private func drawArrow(
        from start: CGPoint,
        to end: CGPoint,
        in context: inout GraphicsContext,
        color: Color
    ) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 1 else {
            drawMarker(at: end, in: &context, color: color.opacity(0.60), radius: 4)
            return
        }
        let angle = atan2(dy, dx)
        let headLength = min(18, max(10, length * 0.18))
        let spread = CGFloat.pi / 7
        var arrow = Path()
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(
            x: end.x - cos(angle - spread) * headLength,
            y: end.y - sin(angle - spread) * headLength
        ))
        arrow.move(to: end)
        arrow.addLine(to: CGPoint(
            x: end.x - cos(angle + spread) * headLength,
            y: end.y - sin(angle + spread) * headLength
        ))
        context.stroke(
            arrow,
            with: .color(color),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }

    private func path(for points: [HandwritingPoint], in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first.point(in: size))
        for point in points.dropFirst() {
            path.addLine(to: point.point(in: size))
        }
        return path
    }

    private func strokeCountValue(_ value: HandwritingValidation) -> String {
        guard let expected = value.expectedStrokeCount else { return "\(value.observedStrokeCount)" }
        return "\(value.observedStrokeCount)/\(expected)"
    }

    private func hintTitle(for guide: HandwritingGuide) -> String {
        if hintLevel == 0 { return "Indice" }
        if hintLevel >= guide.expectedStrokeCount { return "Tous les indices" }
        return "Indice \(hintLevel + 1)/\(guide.expectedStrokeCount)"
    }

    private func guideCaption(for guide: HandwritingGuide) -> String {
        guard mode == .guided else {
            return "Mode libre : le guide est masqué pendant le tracé, mais reste disponible pour vérifier ensuite."
        }
        guard strokes.count < guide.expectedStrokeCount else {
            return "Tous les traits sont validés. Vérifie le tracé pour enregistrer ta réponse."
        }
        let next = guide.strokes[strokes.count]
        let label = next.label.map { " · \($0)" } ?? ""
        return "Trait \(strokes.count + 1)/\(guide.expectedStrokeCount)\(label) : commence au point orange et suis la flèche."
    }

    private func validationTitle(_ value: HandwritingValidation) -> String {
        switch value.outcome {
        case .empty: return "Aucun tracé"
        case .noGuide: return "Guide indisponible"
        case .wrongStrokeCount: return "Nombre de traits à revoir"
        case .needsPractice: return "Tracé à revoir"
        case .approximateMatch: return "Ressemblance approximative au guide"
        }
    }

    private func validationIcon(_ value: HandwritingValidation) -> String {
        switch value.outcome {
        case .approximateMatch: return "checkmark.circle"
        case .noGuide: return "questionmark.circle"
        case .empty: return "pencil.slash"
        case .wrongStrokeCount, .needsPractice: return "xmark.circle"
        }
    }

    private func validationColor(_ value: HandwritingValidation) -> Color {
        switch value.outcome {
        case .approximateMatch: return .green
        case .noGuide: return .orange
        case .empty: return .orange
        case .wrongStrokeCount, .needsPractice: return .red
        }
    }

    private func validationExplanation(_ value: HandwritingValidation) -> String {
        switch value.outcome {
        case .empty:
            return "Trace le caractère avant de demander une vérification."
        case .noGuide:
            return "Le corpus local ne contient pas de guide vérifiable ici. Aucun score géométrique ni caractère reconnu n’est déduit."
        case .wrongStrokeCount:
            let expected = value.expectedStrokeCount.map(String.init) ?? "le bon nombre de"
            return "Le modèle attend \(expected) traits ; le tracé en compte \(value.observedStrokeCount). Recommence le ou les traits indiqués."
        case .needsPractice:
            return "Le nombre est bon, mais les directions (\(qualityLabel(value.directionScore))) ou les formes (\(qualityLabel(value.shapeScore))) demandent une reprise."
        case .approximateMatch:
            return "Le nombre, la direction et la forme des traits ressemblent au guide. Ce contrôle reste approximatif et ne reconnaît pas un caractère général."
        }
    }

    private func qualityLabel(_ score: Double?) -> String {
        guard let score else { return "—" }
        switch score {
        case ..<0.40: return "à revoir"
        case ..<0.70: return "partielle"
        default: return "proche"
        }
    }

    private func distance(_ first: HandwritingPoint, _ second: HandwritingPoint) -> Double {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return (dx * dx + dy * dy).squareRoot()
    }
}

#if os(iOS)
/// A transparent UIKit touch surface for handwriting inside a SwiftUI
/// ScrollView. UIKit's recognizer relationship is explicit here because a
/// SwiftUI DragGesture can otherwise be cancelled by the ancestor scroll pan
/// before it receives its first changed value.
private struct HandwritingTouchSurface: UIViewRepresentable {
    let strokeCount: Int
    let isEnabled: Bool
    let accessibilityLabel: String
    let onChanged: (CGPoint, CGSize) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.pan.delegate = context.coordinator
        view.pan.addTarget(context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: TouchView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        uiView.isUserInteractionEnabled = isEnabled
        uiView.pan.isEnabled = isEnabled
        uiView.isAccessibilityElement = true
        uiView.accessibilityLabel = accessibilityLabel
        uiView.accessibilityValue = "\(strokeCount) traits tracés"
        uiView.accessibilityHint = "Dessine avec le doigt, le Pencil, la souris ou le trackpad."
        uiView.installScrollPriority()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var view: TouchView?
        var onChanged: ((CGPoint, CGSize) -> Void)?
        var onEnded: (() -> Void)?

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view else { return }
            switch recognizer.state {
            case .began, .changed:
                onChanged?(recognizer.location(in: view), view.bounds.size)
            case .ended, .cancelled, .failed:
                onEnded?()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // Keep the callback alive even if a platform scroll recognizer
            // still begins during a vertical stroke.
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // The ancestor scroll pan must wait for this surface. The custom
            // pan begins as soon as the touch moves, so normal scrolling is
            // unaffected once the user starts outside the surface.
            otherGestureRecognizer.view is UIScrollView
        }
    }

    final class TouchView: UIView {
        let pan: UIPanGestureRecognizer
        private var installedScrollViews: [UIScrollView] = []

        override init(frame: CGRect) {
            pan = UIPanGestureRecognizer()
            super.init(frame: frame)
            backgroundColor = .clear
            isOpaque = false
            pan.minimumNumberOfTouches = 1
            pan.maximumNumberOfTouches = 1
            pan.cancelsTouchesInView = true
            addGestureRecognizer(pan)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            installScrollPriority()
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installScrollPriority()
        }

        func installScrollPriority() {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView, !installedScrollViews.contains(where: { $0 === scroll }) {
                    scroll.panGestureRecognizer.require(toFail: pan)
                    installedScrollViews.append(scroll)
                }
                ancestor = view.superview
            }
        }
    }
}
#endif

private extension HandwritingPoint {
    init(clamped point: CGPoint, in size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        self.init(
            x: Double(min(max(point.x, 0), size.width) / width),
            y: Double(min(max(point.y, 0), size.height) / height)
        )
    }
}
