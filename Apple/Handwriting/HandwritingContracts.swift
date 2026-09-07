import Foundation
import CoreGraphics
import PolygoCore

/// The representation used when a learner draws a character.  The contract is
/// kept independent of PencilKit so the native macOS target can use the same
/// app model with a SwiftUI point capture.
public enum DrawingFormat: String, Codable, Hashable, Sendable {
    case pencilKit
    case polygoStrokes
}

public struct CGSizeValue: Codable, Hashable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = max(0, width)
        self.height = max(0, height)
    }

    public init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }

    public var cgSize: CGSize {
        CGSize(width: width, height: height)
    }
}

public struct DrawingCapture: Codable, Hashable, Sendable {
    public let drawingID: DrawingID
    public let format: DrawingFormat
    public let dataRepresentation: Data
    public let strokeCount: Int
    public let canvasSize: CGSizeValue
    public let createdAt: Date

    public init(
        drawingID: DrawingID,
        format: DrawingFormat,
        dataRepresentation: Data,
        strokeCount: Int,
        canvasSize: CGSizeValue,
        createdAt: Date = Date()
    ) {
        self.drawingID = drawingID
        self.format = format
        self.dataRepresentation = dataRepresentation
        self.strokeCount = max(0, strokeCount)
        self.canvasSize = canvasSize
        self.createdAt = createdAt
    }
}

public enum HandwritingRecognition: Codable, Hashable, Sendable {
    case recognized(text: String, confidence: Double?)
    case unsupported
    case failed(String)

    private enum CodingKeys: String, CodingKey {
        case kind, text, confidence, message
    }

    private enum Kind: String, Codable {
        case recognized, unsupported, failed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .recognized:
            let text = try container.decode(String.self, forKey: .text)
            let confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
            self = .recognized(text: text, confidence: confidence.map { min(1, max(0, $0)) })
        case .unsupported:
            self = .unsupported
        case .failed:
            self = .failed(try container.decode(String.self, forKey: .message))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .recognized(let text, let confidence):
            try container.encode(Kind.recognized, forKey: .kind)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(confidence, forKey: .confidence)
        case .unsupported:
            try container.encode(Kind.unsupported, forKey: .kind)
        case .failed(let message):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(message, forKey: .message)
        }
    }
}

public protocol HandwritingService: Sendable {
    func recognize(
        _ capture: DrawingCapture,
        target: HandwritingExercise
    ) async -> HandwritingRecognition

    func persist(_ capture: DrawingCapture) async throws -> DrawingID
    func delete(drawingID: DrawingID) async throws
}
