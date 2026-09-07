import Foundation

/// The result of the deliberately narrow handwriting check.
///
/// This is a comparison with the ordered teaching paths shipped for an
/// exercise. It is not an OCR result, a character classifier, or a measure of
/// calligraphic quality.
public enum HandwritingValidationOutcome: String, Codable, Hashable, Sendable {
    case empty
    case noGuide
    case wrongStrokeCount
    case needsPractice
    case approximateMatch
}

public struct HandwritingValidation: Codable, Hashable, Sendable {
    public let outcome: HandwritingValidationOutcome
    public let observedStrokeCount: Int
    public let expectedStrokeCount: Int?
    public let strokeCountMatches: Bool?
    /// A coarse 0...1 comparison of the direction of corresponding strokes.
    public let directionScore: Double?
    /// A coarse 0...1 comparison of the sampled path shapes.
    public let shapeScore: Double?
    /// A combined comparison score. It is intentionally not presented as a
    /// learner percentage by the UI.
    public let score: Double?

    public init(
        outcome: HandwritingValidationOutcome,
        observedStrokeCount: Int,
        expectedStrokeCount: Int? = nil,
        strokeCountMatches: Bool? = nil,
        directionScore: Double? = nil,
        shapeScore: Double? = nil,
        score: Double? = nil
    ) {
        self.outcome = outcome
        self.observedStrokeCount = max(0, observedStrokeCount)
        self.expectedStrokeCount = expectedStrokeCount.map { max(0, $0) }
        self.strokeCountMatches = strokeCountMatches
        self.directionScore = directionScore.map(Self.clamp)
        self.shapeScore = shapeScore.map(Self.clamp)
        self.score = score.map(Self.clamp)
    }

    public var hasGuide: Bool { outcome != .noGuide }
    public var isApproximateMatch: Bool { outcome == .approximateMatch }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}

/// A small, deterministic geometry check for the original guide corpus.
///
/// The validator compares strokes by index. It tolerates translation and
/// scale of the complete drawing, but still checks stroke direction and the
/// sampled shape of each corresponding path. It intentionally does not try to
/// infer a character when no guide is available.
public enum HandwritingGeometryValidator {
    private static let sampleCount = 16
    private static let shapeTolerance = 0.22
    private static let minimumDirectionScore = 0.55
    private static let minimumShapeScore = 0.50

    public static func validate(
        strokes: [HandwritingStroke],
        guide: HandwritingGuide?,
        expectedStrokeCount: Int?
    ) -> HandwritingValidation {
        let usableStrokes = strokes.filter { !$0.points.isEmpty }
        guard !usableStrokes.isEmpty else {
            return HandwritingValidation(
                outcome: .empty,
                observedStrokeCount: 0,
                expectedStrokeCount: guide?.expectedStrokeCount ?? expectedStrokeCount
            )
        }

        guard let guide, !guide.strokes.isEmpty else {
            return HandwritingValidation(
                outcome: .noGuide,
                observedStrokeCount: usableStrokes.count,
                expectedStrokeCount: expectedStrokeCount,
                strokeCountMatches: expectedStrokeCount.map { usableStrokes.count == $0 }
            )
        }

        let expected = guide.strokes.count
        let countMatches = usableStrokes.count == expected
        let pairedCount = min(usableStrokes.count, expected)

        guard pairedCount > 0 else {
            return HandwritingValidation(
                outcome: .wrongStrokeCount,
                observedStrokeCount: usableStrokes.count,
                expectedStrokeCount: expected,
                strokeCountMatches: false,
                directionScore: 0,
                shapeScore: 0,
                score: 0
            )
        }

        let fittedStrokes = fit(usableStrokes, to: guide)
        var directions: [Double] = []
        var shapes: [Double] = []

        for index in 0..<pairedCount {
            let userPath = fittedStrokes[index].points
            let guidePath = guide.strokes[index].points
            directions.append(directionScore(for: userPath, comparedWith: guidePath))
            shapes.append(shapeScore(for: userPath, comparedWith: guidePath))
        }

        let direction = average(directions)
        let shape = average(shapes)
        let countScore = countMatches ? 1.0 : Double(pairedCount) / Double(expected)
        let combined = 0.35 * countScore + 0.30 * direction + 0.35 * shape
        let approximateMatch = countMatches
            && direction >= minimumDirectionScore
            && shape >= minimumShapeScore

        return HandwritingValidation(
            outcome: approximateMatch ? .approximateMatch : (countMatches ? .needsPractice : .wrongStrokeCount),
            observedStrokeCount: usableStrokes.count,
            expectedStrokeCount: expected,
            strokeCountMatches: countMatches,
            directionScore: direction,
            shapeScore: shape,
            score: combined
        )
    }

    private static func fit(_ strokes: [HandwritingStroke], to guide: HandwritingGuide) -> [HandwritingStroke] {
        let userPoints = strokes.flatMap(\.points)
        let guidePoints = guide.strokes.flatMap(\.points)
        guard let userBounds = bounds(of: userPoints), let guideBounds = bounds(of: guidePoints) else {
            return strokes
        }

        let userWidth = max(userBounds.width, 0.0001)
        let userHeight = max(userBounds.height, 0.0001)
        let guideWidth = guideBounds.width
        let guideHeight = guideBounds.height

        return strokes.map { stroke in
            let points = stroke.points.map { point in
                HandwritingPoint(
                    x: guideBounds.minX + ((point.x - userBounds.minX) / userWidth) * guideWidth,
                    y: guideBounds.minY + ((point.y - userBounds.minY) / userHeight) * guideHeight
                )
            }
            return HandwritingStroke(id: stroke.id, points: points)
        }
    }

    private static func directionScore(
        for userPath: [HandwritingPoint],
        comparedWith guidePath: [HandwritingPoint]
    ) -> Double {
        guard let userStart = userPath.first, let userEnd = userPath.last,
              let guideStart = guidePath.first, let guideEnd = guidePath.last else {
            return 0
        }
        let userVector = Vector(from: userStart, to: userEnd)
        let guideVector = Vector(from: guideStart, to: guideEnd)
        guard userVector.length > 0.0001, guideVector.length > 0.0001 else {
            // A tap can be a legitimate final dot. There is no meaningful
            // direction to compare, so let the shape comparison decide.
            return 1
        }
        let cosine = (userVector.dx * guideVector.dx + userVector.dy * guideVector.dy)
            / (userVector.length * guideVector.length)
        return min(1, max(0, (cosine + 1) / 2))
    }

    private static func shapeScore(
        for userPath: [HandwritingPoint],
        comparedWith guidePath: [HandwritingPoint]
    ) -> Double {
        let user = resample(userPath, count: sampleCount)
        let guide = resample(guidePath, count: sampleCount)
        guard user.count == guide.count, !user.isEmpty else { return 0 }
        let meanDistance = zip(user, guide)
            .map { distance($0.0, $0.1) }
            .reduce(0, +) / Double(user.count)
        return min(1, max(0, 1 - meanDistance / shapeTolerance))
    }

    private static func resample(_ points: [HandwritingPoint], count: Int) -> [HandwritingPoint] {
        guard count > 0, !points.isEmpty else { return [] }
        guard count > 1, points.count > 1 else { return Array(repeating: points[0], count: count) }

        var cumulative: [Double] = [0]
        for index in 1..<points.count {
            cumulative.append(cumulative[index - 1] + distance(points[index - 1], points[index]))
        }
        let total = cumulative.last ?? 0
        guard total > 0.0001 else { return Array(repeating: points[0], count: count) }

        var result: [HandwritingPoint] = []
        result.reserveCapacity(count)
        for sample in 0..<count {
            let target = total * Double(sample) / Double(count - 1)
            var upper = cumulative.firstIndex(where: { $0 >= target }) ?? cumulative.count - 1
            if upper == 0 { result.append(points[0]); continue }
            if upper >= cumulative.count { upper = cumulative.count - 1 }
            let lower = upper - 1
            let segmentLength = cumulative[upper] - cumulative[lower]
            let fraction = segmentLength > 0.0001
                ? (target - cumulative[lower]) / segmentLength
                : 0
            result.append(interpolate(points[lower], points[upper], fraction: fraction))
        }
        return result
    }

    private static func interpolate(_ first: HandwritingPoint, _ second: HandwritingPoint, fraction: Double) -> HandwritingPoint {
        HandwritingPoint(
            x: first.x + (second.x - first.x) * fraction,
            y: first.y + (second.y - first.y) * fraction
        )
    }

    private static func distance(_ first: HandwritingPoint, _ second: HandwritingPoint) -> Double {
        let dx = first.x - second.x
        let dy = first.y - second.y
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private struct Vector {
        let dx: Double
        let dy: Double

        init(from first: HandwritingPoint, to second: HandwritingPoint) {
            dx = second.x - first.x
            dy = second.y - first.y
        }

        var length: Double { (dx * dx + dy * dy).squareRoot() }
    }

    private struct Bounds {
        let minX: Double
        let maxX: Double
        let minY: Double
        let maxY: Double

        var width: Double { maxX - minX }
        var height: Double { maxY - minY }
    }

    private static func bounds(of points: [HandwritingPoint]) -> Bounds? {
        guard let first = points.first else { return nil }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return Bounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }
}
