import Foundation

/// Errors raised by values at the boundary of the domain.
public enum DomainError: Error, Sendable, Equatable {
    case invalidIdentifier(String)
    case emptyLocalizedText
    case invalidScore(Double)
    case invalidValue(String)
    case eventProfileMismatch
}

/// Every content and progress identifier is deliberately a distinct type.
public protocol PolygoIdentifier: RawRepresentable, Codable, Hashable, Sendable where RawValue == String {}

public extension PolygoIdentifier {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = Self(rawValue: raw) else {
            throw DomainError.invalidIdentifier(raw)
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

private func validIdentifier(_ value: String) -> Bool {
    !value.isEmpty && value.count <= 128 && !value.contains(where: { $0.isWhitespace || $0 == "/" || $0 == "\\" }) && value != "." && value != ".."
}

public struct CourseID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct ModuleID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct LessonID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct BlockID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct ExerciseID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct VocabularyID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct CardID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct AssetID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct ProfileID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct EventID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct DeviceID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct RecordingID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct DrawingID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct StoryID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}

public struct ObjectiveID: PolygoIdentifier {
    public let rawValue: String
    public init?(rawValue: String) {
        guard validIdentifier(rawValue) else { return nil }
        self.rawValue = rawValue
    }
}
