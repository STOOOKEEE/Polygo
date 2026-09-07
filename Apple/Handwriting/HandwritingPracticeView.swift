import SwiftUI
import PolygoCore

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
    @State private var savedDrawingID: DrawingID?
    @State private var isSaving = false
    @State private var statusMessage: String?

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
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: mode) { _, newMode in
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
                }
                // The canvas lives inside the lesson's vertical ScrollView.
                // Give the drawing surface priority so a vertical stroke is
                // captured as handwriting instead of being consumed as a
                // scroll gesture by the parent.
                .contentShape(Rectangle())
                .allowsHitTesting(!isSaving)
                .highPriorityGesture(drawingGesture(for: proxy.size))
                .onAppear { canvasSize = proxy.size }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Zone de tracé pour \(exercise.targetHanzi)")
                .accessibilityValue("\(strokes.count) traits tracés")
                .accessibilityHint("Dessine avec le doigt, le Pencil, la souris ou le trackpad.")
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(minHeight: 280, maxHeight: 520)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.secondary.opacity(0.24), lineWidth: 1)
            }

            if let guide {
                Text(mode == .guided
                     ? "Le trait orange indique la prochaine direction. Répète le geste sur le modèle."
                     : "Mode libre : le guide est masqué pendant le tracé, mais reste disponible pour vérifier ensuite.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Le caractère cible reste visible comme repère. Il n’y a pas de prétendue correction géométrique sans guide.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Button("Enregistrer comme à refaire") { submitAnswer(selfChecked: false) }
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
            invalidatePreviousAnswer()
        }
        let point = HandwritingPoint(clamped: location, in: size)
        if let last = activeStroke.last, distance(last, point) < 0.002 {
            return
        }
        activeStroke.append(point)
    }

    private func finishStroke() {
        guard !activeStroke.isEmpty else { return }
        strokes.append(HandwritingStroke(points: activeStroke))
        activeStroke.removeAll(keepingCapacity: true)
        validation = nil
        statusMessage = nil
    }

    private func undo() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
        invalidatePreviousAnswer()
        statusMessage = "Dernier trait annulé."
    }

    private func clearCanvas() {
        guard hasDrawing else { return }
        strokes.removeAll()
        activeStroke.removeAll()
        validation = nil
        hintLevel = 0
        invalidatePreviousAnswer()
        statusMessage = "Tracé effacé."
    }

    private func validateDrawing() {
        guard hasDrawing else {
            statusMessage = "Trace au moins un trait avant de vérifier."
            return
        }
        finishStroke()
        let result = HandwritingGeometryValidator.validate(
            strokes: strokes,
            guide: guide,
            expectedStrokeCount: exercise.expectedStrokeCount
        )
        validation = result
        statusMessage = result.outcome == .noGuide
            ? "Aucun guide local : choisis une auto-évaluation après ton tracé."
            : "Comparaison terminée. Elle porte sur le nombre, la direction et la forme approximative des traits."
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

        if let guide {
            let shouldShowGuide = mode == .guided
            for (index, stroke) in guide.strokes.enumerated() {
                let isHint = index < hintLevel
                let isRevealed = shouldShowGuide && (!isGuidePlaying || index < guideStep)
                let isActive = shouldShowGuide && isGuidePlaying && index == guideStep
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
                    drawMarker(at: last.point(in: size), in: &context, color: .orange.opacity(0.60), radius: 4)
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
        case .wrongStrokeCount, .needsPractice: return "arrow.counterclockwise.circle"
        }
    }

    private func validationColor(_ value: HandwritingValidation) -> Color {
        switch value.outcome {
        case .approximateMatch: return .green
        case .noGuide: return .orange
        case .empty, .wrongStrokeCount, .needsPractice: return .orange
        }
    }

    private func validationExplanation(_ value: HandwritingValidation) -> String {
        switch value.outcome {
        case .empty:
            return "Trace le caractère avant de demander une vérification."
        case .noGuide:
            return "Le corpus local ne contient pas de guide vérifiable ici. Aucun score géométrique ni caractère reconnu n’est déduit."
        case .wrongStrokeCount:
            return "Le nombre de traits diffère du modèle. La comparaison ne reconnaît pas le caractère et ne mesure pas la qualité calligraphique."
        case .needsPractice:
            return "Certaines directions ou formes s’écartent du modèle. C’est un repère de pratique approximatif, pas une reconnaissance OCR."
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
