import Foundation
import CoreGraphics
import PolygoCore

/// A point in the unit square used by the handwriting guides and captures.
/// Keeping guide coordinates independent from a device's pixel size lets the
/// same exercise work on an iPhone, iPad, or Mac window.
public struct HandwritingPoint: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = min(1, max(0, x))
        self.y = min(1, max(0, y))
    }

    public init(_ point: CGPoint, in size: CGSize) {
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        self.init(x: Double(point.x / width), y: Double(point.y / height))
    }

    public func point(in size: CGSize) -> CGPoint {
        CGPoint(x: x * size.width, y: y * size.height)
    }
}
/// One ordered stroke in a guide. The points are a teaching path, rather than
/// an outline or a font glyph. They are intentionally small and hand-authored
/// so the UI can reveal the order without pretending to perform OCR.
public struct HandwritingGuideStroke: Codable, Hashable, Sendable, Identifiable {
    public let id: Int
    public let points: [HandwritingPoint]
    public let label: String?

    public init(id: Int, points: [HandwritingPoint], label: String? = nil) {
        self.id = id
        self.points = points
        self.label = label
    }
}

/// A normalized, ordered guide for one Chinese character.
public struct HandwritingGuide: Codable, Hashable, Sendable, Identifiable {
    public let id: AssetID
    public let character: String
    public let viewBox: CGSizeValue
    public let strokes: [HandwritingGuideStroke]

    public init(
        id: AssetID,
        character: String,
        viewBox: CGSizeValue = CGSizeValue(width: 1, height: 1),
        strokes: [HandwritingGuideStroke]
    ) {
        self.id = id
        self.character = character
        self.viewBox = viewBox
        self.strokes = strokes.filter { $0.points.count >= 1 }
    }

    public var expectedStrokeCount: Int { strokes.count }
}

/// The first handwriting corpus shipped with the lesson content.
///
/// These are original, deliberately simplified teaching paths for the three
/// characters used by the current lessons. They are not copied font outlines
/// and are not intended to recognize arbitrary handwriting. The same data is
/// checked into Content/assets/handwriting as JSON so content can reference it
/// with a real SHA-256 hash.
public enum HandwritingGuideCatalog {
    public static let pendingAssetHash = "pending-writing-guide"

    public static func guide(for exercise: HandwritingExercise) -> HandwritingGuide? {
        guard exercise.guideAsset.kind == .handwritingGuide,
              exercise.guideAsset.sha256.caseInsensitiveCompare(pendingAssetHash) != .orderedSame else {
            return nil
        }
        guard let guide = guide(forCharacter: exercise.targetHanzi) else { return nil }
        guard guide.id == exercise.guideAsset.id else { return nil }
        return guide
    }

    public static func guide(forCharacter character: String) -> HandwritingGuide? {
        switch character {
        case "你": return ni
        case "我": return wo
        case "国": return guo
        default: return nil
        }
    }

    /// Decodes the checked-in guide format for integrations that resolve an
    /// AssetReference through ContentStore before constructing the view.
    public static func decode(data: Data) throws -> HandwritingGuide {
        try JSONDecoder().decode(HandwritingGuide.self, from: data)
    }

    private static let ni = HandwritingGuide(
        id: AssetID(rawValue: "guide-hanzi-ni")!,
        character: "你",
        strokes: [
            HandwritingGuideStroke(id: 1, points: [
                HandwritingPoint(x: 0.31, y: 0.16),
                HandwritingPoint(x: 0.25, y: 0.25),
                HandwritingPoint(x: 0.17, y: 0.37),
                HandwritingPoint(x: 0.12, y: 0.44)
            ], label: "撇"),
            HandwritingGuideStroke(id: 2, points: [
                HandwritingPoint(x: 0.30, y: 0.22),
                HandwritingPoint(x: 0.30, y: 0.42),
                HandwritingPoint(x: 0.30, y: 0.77)
            ], label: "竖"),
            HandwritingGuideStroke(id: 3, points: [
                HandwritingPoint(x: 0.54, y: 0.17),
                HandwritingPoint(x: 0.49, y: 0.24),
                HandwritingPoint(x: 0.42, y: 0.34)
            ], label: "撇"),
            HandwritingGuideStroke(id: 4, points: [
                HandwritingPoint(x: 0.43, y: 0.35),
                HandwritingPoint(x: 0.67, y: 0.35),
                HandwritingPoint(x: 0.72, y: 0.37),
                HandwritingPoint(x: 0.68, y: 0.44)
            ], label: "横钩"),
            HandwritingGuideStroke(id: 5, points: [
                HandwritingPoint(x: 0.58, y: 0.42),
                HandwritingPoint(x: 0.53, y: 0.51),
                HandwritingPoint(x: 0.45, y: 0.62)
            ], label: "撇"),
            HandwritingGuideStroke(id: 6, points: [
                HandwritingPoint(x: 0.64, y: 0.43),
                HandwritingPoint(x: 0.64, y: 0.63),
                HandwritingPoint(x: 0.65, y: 0.70),
                HandwritingPoint(x: 0.70, y: 0.73),
                HandwritingPoint(x: 0.77, y: 0.70)
            ], label: "竖弯钩"),
            HandwritingGuideStroke(id: 7, points: [
                HandwritingPoint(x: 0.80, y: 0.62),
                HandwritingPoint(x: 0.76, y: 0.72)
            ], label: "点")
        ]
    )

    private static let wo = HandwritingGuide(
        id: AssetID(rawValue: "guide-hanzi-wo")!,
        character: "我",
        strokes: [
            HandwritingGuideStroke(id: 1, points: [
                HandwritingPoint(x: 0.31, y: 0.15),
                HandwritingPoint(x: 0.25, y: 0.25),
                HandwritingPoint(x: 0.18, y: 0.35)
            ], label: "撇"),
            HandwritingGuideStroke(id: 2, points: [
                HandwritingPoint(x: 0.18, y: 0.35),
                HandwritingPoint(x: 0.54, y: 0.35)
            ], label: "横"),
            HandwritingGuideStroke(id: 3, points: [
                HandwritingPoint(x: 0.38, y: 0.25),
                HandwritingPoint(x: 0.38, y: 0.61),
                HandwritingPoint(x: 0.36, y: 0.72),
                HandwritingPoint(x: 0.30, y: 0.76),
                HandwritingPoint(x: 0.24, y: 0.73)
            ], label: "竖钩"),
            HandwritingGuideStroke(id: 4, points: [
                HandwritingPoint(x: 0.20, y: 0.53),
                HandwritingPoint(x: 0.31, y: 0.50),
                HandwritingPoint(x: 0.49, y: 0.43)
            ], label: "提"),
            HandwritingGuideStroke(id: 5, points: [
                HandwritingPoint(x: 0.59, y: 0.17),
                HandwritingPoint(x: 0.54, y: 0.25),
                HandwritingPoint(x: 0.49, y: 0.34)
            ], label: "撇"),
            HandwritingGuideStroke(id: 6, points: [
                HandwritingPoint(x: 0.47, y: 0.36),
                HandwritingPoint(x: 0.72, y: 0.36),
                HandwritingPoint(x: 0.83, y: 0.37),
                HandwritingPoint(x: 0.75, y: 0.55),
                HandwritingPoint(x: 0.66, y: 0.80)
            ], label: "横斜钩"),
            HandwritingGuideStroke(id: 7, points: [
                HandwritingPoint(x: 0.82, y: 0.62),
                HandwritingPoint(x: 0.77, y: 0.74)
            ], label: "点")
        ]
    )

    private static let guo = HandwritingGuide(
        id: AssetID(rawValue: "guide-hanzi-guo")!,
        character: "国",
        strokes: [
            HandwritingGuideStroke(id: 1, points: [
                HandwritingPoint(x: 0.19, y: 0.18),
                HandwritingPoint(x: 0.19, y: 0.42),
                HandwritingPoint(x: 0.19, y: 0.82)
            ], label: "竖"),
            HandwritingGuideStroke(id: 2, points: [
                HandwritingPoint(x: 0.19, y: 0.18),
                HandwritingPoint(x: 0.49, y: 0.18),
                HandwritingPoint(x: 0.81, y: 0.18),
                HandwritingPoint(x: 0.81, y: 0.48),
                HandwritingPoint(x: 0.81, y: 0.82)
            ], label: "横折"),
            HandwritingGuideStroke(id: 3, points: [
                HandwritingPoint(x: 0.19, y: 0.82),
                HandwritingPoint(x: 0.48, y: 0.82),
                HandwritingPoint(x: 0.81, y: 0.82)
            ], label: "横"),
            HandwritingGuideStroke(id: 4, points: [
                HandwritingPoint(x: 0.32, y: 0.34),
                HandwritingPoint(x: 0.50, y: 0.34),
                HandwritingPoint(x: 0.69, y: 0.34)
            ], label: "横"),
            HandwritingGuideStroke(id: 5, points: [
                HandwritingPoint(x: 0.50, y: 0.27),
                HandwritingPoint(x: 0.50, y: 0.45),
                HandwritingPoint(x: 0.50, y: 0.63)
            ], label: "竖"),
            HandwritingGuideStroke(id: 6, points: [
                HandwritingPoint(x: 0.34, y: 0.49),
                HandwritingPoint(x: 0.50, y: 0.49),
                HandwritingPoint(x: 0.66, y: 0.49)
            ], label: "横"),
            HandwritingGuideStroke(id: 7, points: [
                HandwritingPoint(x: 0.34, y: 0.64),
                HandwritingPoint(x: 0.50, y: 0.64),
                HandwritingPoint(x: 0.66, y: 0.64)
            ], label: "横"),
            HandwritingGuideStroke(id: 8, points: [
                HandwritingPoint(x: 0.62, y: 0.67),
                HandwritingPoint(x: 0.67, y: 0.73)
            ], label: "点")
        ]
    )
}
