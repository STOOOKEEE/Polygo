import Foundation
import CoreGraphics
import PolygoCore

/// One learner stroke captured as normalized points. A stroke with one point
/// is retained so a short tap can represent a Chinese dot.
public struct HandwritingStroke: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let points: [HandwritingPoint]

    public init(id: UUID = UUID(), points: [HandwritingPoint]) {
        self.id = id
        self.points = points
    }

    public var isDrawable: Bool { !points.isEmpty }
}
/// Serializes the portable point capture used by the SwiftUI canvas.
public enum HandwritingCaptureCodec {
    public static func encode(strokes: [HandwritingStroke]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(strokes)
    }

    public static func decode(_ data: Data) throws -> [HandwritingStroke] {
        try JSONDecoder().decode([HandwritingStroke].self, from: data)
    }

    public static func makeCapture(
        drawingID: DrawingID,
        strokes: [HandwritingStroke],
        canvasSize: CGSize,
        createdAt: Date = Date()
    ) throws -> DrawingCapture {
        let usableStrokes = strokes.filter(\.isDrawable)
        guard !usableStrokes.isEmpty else {
            throw HandwritingPersistenceError.emptyDrawing
        }
        return DrawingCapture(
            drawingID: drawingID,
            format: .polygoStrokes,
            dataRepresentation: try encode(strokes: usableStrokes),
            strokeCount: usableStrokes.count,
            canvasSize: CGSizeValue(canvasSize),
            createdAt: createdAt
        )
    }
}
