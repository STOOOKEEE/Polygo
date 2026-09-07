import Foundation

public struct LocalizedText: Codable, Hashable, Sendable {
    public let values: [String: String]

    public init(values: [String: String]) throws {
        guard !values.isEmpty, values.values.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw DomainError.emptyLocalizedText
        }
        self.values = values
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        if let nested = try container.decodeIfPresent([String: String].self, forKey: AnyCodingKey(stringValue: "values")!) {
            try self.init(values: nested)
            return
        }
        var decoded: [String: String] = [:]
        for key in container.allKeys {
            decoded[key.stringValue] = try container.decode(String.self, forKey: key)
        }
        try self.init(values: decoded)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (language, value) in values {
            try container.encode(value, forKey: AnyCodingKey(stringValue: language)!)
        }
    }

    /// A non-throwing convenience used by built-in previews and UI labels.
    /// Content loaded from disk should use `init(values:)` so malformed text is
    /// rejected at the content boundary.
    public static func unchecked(_ values: [String: String]) -> LocalizedText {
        try! LocalizedText(values: values)
    }

    public func resolve(preferred: [String] = ["fr", "en"], fallback: String = "en") -> String? {
        for language in preferred {
            if let value = values[language] { return value }
            if let key = values.keys.sorted().first(where: { $0.hasPrefix(language + "-") }),
               let value = values[key] {
                return value
            }
        }
        return values[fallback] ?? values.values.first
    }
}

private struct AnyCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?
    init?(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.stringValue = String(intValue); self.intValue = intValue }
}

public struct CourseManifest: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let contentVersion: String
    public let id: CourseID
    public let slug: String
    public let title: LocalizedText
    public let description: LocalizedText
    public let alignment: [CurriculumTag]
    public let modules: [ModuleSummary]

    public init(
        schemaVersion: Int = 1,
        contentVersion: String,
        id: CourseID,
        slug: String,
        title: LocalizedText,
        description: LocalizedText,
        alignment: [CurriculumTag],
        modules: [ModuleSummary]
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.id = id
        self.slug = slug
        self.title = title
        self.description = description
        self.alignment = alignment
        self.modules = modules
    }
}

public struct ModuleSummary: Codable, Hashable, Sendable {
    public let id: ModuleID
    public let order: Int
    public let title: LocalizedText
    public let lessonIDs: [LessonID]

    public init(id: ModuleID, order: Int, title: LocalizedText, lessonIDs: [LessonID]) {
        self.id = id
        self.order = order
        self.title = title
        self.lessonIDs = lessonIDs
    }
}

public struct LessonDocument: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let contentVersion: String
    public let id: LessonID
    public let moduleID: ModuleID
    public let order: Int
    public let title: LocalizedText
    public let summary: LocalizedText
    public let estimatedMinutes: Int
    public let objectives: [LearningObjective]
    public let vocabulary: [VocabularyEntry]
    public let blocks: [LessonBlock]
    public let cards: [ReviewCard]

    public init(
        schemaVersion: Int = 1,
        contentVersion: String,
        id: LessonID,
        moduleID: ModuleID,
        order: Int,
        title: LocalizedText,
        summary: LocalizedText,
        estimatedMinutes: Int,
        objectives: [LearningObjective],
        vocabulary: [VocabularyEntry],
        blocks: [LessonBlock],
        cards: [ReviewCard]
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.id = id
        self.moduleID = moduleID
        self.order = order
        self.title = title
        self.summary = summary
        self.estimatedMinutes = estimatedMinutes
        self.objectives = objectives
        self.vocabulary = vocabulary
        self.blocks = blocks
        self.cards = cards
    }
}

public struct LearningObjective: Codable, Hashable, Sendable {
    public let id: String
    public let statement: LocalizedText
    public let required: Bool

    public init(id: String, statement: LocalizedText, required: Bool = true) {
        self.id = id
        self.statement = statement
        self.required = required
    }
}

public struct CurriculumTag: Codable, Hashable, Sendable {
    public let framework: String
    public let level: String

    public init(framework: String, level: String) {
        self.framework = framework
        self.level = level
    }
}

public enum ChineseScript: String, Codable, Hashable, Sendable, CaseIterable {
    case simplified
    case traditional
}

public struct VocabularyEntry: Codable, Hashable, Sendable, Identifiable {
    public let id: VocabularyID
    public let hanzi: String
    public let traditionalHanzi: String?
    public let pinyin: String
    public let toneNumbers: [Int]
    public let segmentation: [TextSegment]
    public let partOfSpeech: PartOfSpeech?
    public let grammarNotes: [GrammarNote]
    public let meaning: LocalizedText
    public let audio: AssetReference?
    public let example: ExampleSentence?
    public let memoryStory: LocalizedText?

    public init(
        id: VocabularyID,
        hanzi: String,
        traditionalHanzi: String? = nil,
        pinyin: String,
        toneNumbers: [Int],
        segmentation: [TextSegment] = [],
        partOfSpeech: PartOfSpeech? = nil,
        grammarNotes: [GrammarNote] = [],
        meaning: LocalizedText,
        audio: AssetReference? = nil,
        example: ExampleSentence? = nil,
        memoryStory: LocalizedText? = nil
    ) {
        self.id = id
        self.hanzi = hanzi
        self.traditionalHanzi = traditionalHanzi
        self.pinyin = pinyin
        self.toneNumbers = toneNumbers
        self.segmentation = segmentation
        self.partOfSpeech = partOfSpeech
        self.grammarNotes = grammarNotes
        self.meaning = meaning
        self.audio = audio
        self.example = example
        self.memoryStory = memoryStory
    }
}

public struct TextSegment: Codable, Hashable, Sendable {
    public let surface: String
    public let vocabularyID: VocabularyID?
    public let pinyin: String?
    public let partOfSpeech: PartOfSpeech?

    public init(surface: String, vocabularyID: VocabularyID? = nil, pinyin: String? = nil, partOfSpeech: PartOfSpeech? = nil) {
        self.surface = surface
        self.vocabularyID = vocabularyID
        self.pinyin = pinyin
        self.partOfSpeech = partOfSpeech
    }
}

public enum PartOfSpeech: String, Codable, Hashable, Sendable, CaseIterable {
    case noun, verb, adjective, adverb, pronoun, classifier
    case preposition, conjunction, particle, measureWord, interjection, other
}

public struct GrammarNote: Codable, Hashable, Sendable {
    public let pattern: String
    public let explanation: LocalizedText
    public let examples: [ExampleSentence]

    public init(pattern: String, explanation: LocalizedText, examples: [ExampleSentence] = []) {
        self.pattern = pattern
        self.explanation = explanation
        self.examples = examples
    }
}

public struct ExampleSentence: Codable, Hashable, Sendable {
    public let hanzi: String
    public let pinyin: String
    public let translation: LocalizedText
    public let audio: AssetReference?

    public init(hanzi: String, pinyin: String, translation: LocalizedText, audio: AssetReference? = nil) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.translation = translation
        self.audio = audio
    }
}

public struct ReviewCard: Codable, Hashable, Sendable, Identifiable {
    public let id: CardID
    public let vocabularyID: VocabularyID
    public let front: CardSide
    public let back: CardSide
    public let tags: [String]

    public init(id: CardID, vocabularyID: VocabularyID, front: CardSide, back: CardSide, tags: [String] = []) {
        self.id = id
        self.vocabularyID = vocabularyID
        self.front = front
        self.back = back
        self.tags = tags
    }
}

public struct CardSide: Codable, Hashable, Sendable {
    public let hanzi: String?
    public let pinyin: String?
    public let text: LocalizedText?
    public let audio: AssetReference?

    public init(hanzi: String? = nil, pinyin: String? = nil, text: LocalizedText? = nil, audio: AssetReference? = nil) {
        self.hanzi = hanzi
        self.pinyin = pinyin
        self.text = text
        self.audio = audio
    }
}

public struct AssetReference: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable, CaseIterable {
        case audio, image, handwritingGuide
    }

    public let id: AssetID
    public let kind: Kind
    public let relativePath: String
    public let sha256: String
    public let durationMilliseconds: Int?

    public init(id: AssetID, kind: Kind, relativePath: String, sha256: String, durationMilliseconds: Int? = nil) {
        self.id = id
        self.kind = kind
        self.relativePath = relativePath
        self.sha256 = sha256
        self.durationMilliseconds = durationMilliseconds
    }
}

public struct ContentIndex: Codable, Hashable, Sendable {
    public let schemaVersion: Int
    public let contentVersion: String
    public let courseIDs: [CourseID]
    public let defaultCourseID: CourseID

    public init(schemaVersion: Int = 1, contentVersion: String, courseIDs: [CourseID], defaultCourseID: CourseID) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.courseIDs = courseIDs
        self.defaultCourseID = defaultCourseID
    }
}
