import Foundation

public enum LessonBlock: Codable, Hashable, Sendable, Identifiable {
    case introduction(IntroductionBlock)
    case vocabulary(VocabularyBlock)
    case dialogue(DialogueBlock)
    case reading(ReadingBlock)
    case exercise(ExerciseBlock)
    case recap(RecapBlock)

    public var id: BlockID {
        switch self {
        case .introduction(let value): return value.id
        case .vocabulary(let value): return value.id
        case .dialogue(let value): return value.id
        case .reading(let value): return value.id
        case .exercise(let value): return value.id
        case .recap(let value): return value.id
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind, value, id, title, body, audio, vocabularyIDs, lines, storyID, level, paragraphs, comprehensionExerciseIDs, participation, spec, objectiveIDs
    }
    private enum Kind: String, Codable { case introduction, vocabulary, dialogue, reading, exercise, recap }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .introduction: self = .introduction(container.contains(.value) ? try container.decode(IntroductionBlock.self, forKey: .value) : try IntroductionBlock(from: decoder))
        case .vocabulary: self = .vocabulary(container.contains(.value) ? try container.decode(VocabularyBlock.self, forKey: .value) : try VocabularyBlock(from: decoder))
        case .dialogue: self = .dialogue(container.contains(.value) ? try container.decode(DialogueBlock.self, forKey: .value) : try DialogueBlock(from: decoder))
        case .reading: self = .reading(container.contains(.value) ? try container.decode(ReadingBlock.self, forKey: .value) : try ReadingBlock(from: decoder))
        case .exercise: self = .exercise(container.contains(.value) ? try container.decode(ExerciseBlock.self, forKey: .value) : try ExerciseBlock(from: decoder))
        case .recap: self = .recap(container.contains(.value) ? try container.decode(RecapBlock.self, forKey: .value) : try RecapBlock(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .introduction(let value):
            try container.encode(Kind.introduction, forKey: .kind); try container.encode(value.id, forKey: .id); try container.encode(value.title, forKey: .title); try container.encode(value.body, forKey: .body); try container.encodeIfPresent(value.audio, forKey: .audio)
        case .vocabulary(let value):
            try container.encode(Kind.vocabulary, forKey: .kind); try container.encode(value.id, forKey: .id); try container.encode(value.vocabularyIDs, forKey: .vocabularyIDs)
        case .dialogue(let value):
            try container.encode(Kind.dialogue, forKey: .kind); try container.encode(value.id, forKey: .id); try container.encode(value.lines, forKey: .lines); try container.encodeIfPresent(value.participation, forKey: .participation); try container.encode(value.comprehensionExerciseIDs, forKey: .comprehensionExerciseIDs)
        case .reading(let value):
            try container.encode(Kind.reading, forKey: .kind); try container.encode(value.id, forKey: .id); try container.encode(value.storyID, forKey: .storyID); try container.encodeIfPresent(value.level, forKey: .level); try container.encode(value.title, forKey: .title); try container.encode(value.paragraphs, forKey: .paragraphs); try container.encode(value.comprehensionExerciseIDs, forKey: .comprehensionExerciseIDs)
        case .exercise(let value):
            try container.encode(Kind.exercise, forKey: .kind); try container.encode(value.id, forKey: .id); try container.encode(value.spec, forKey: .spec)
        case .recap(let value):
            try container.encode(Kind.recap, forKey: .kind); try container.encode(value.id, forKey: .id); try container.encode(value.vocabularyIDs, forKey: .vocabularyIDs); try container.encode(value.objectiveIDs, forKey: .objectiveIDs)
        }
    }
}

public struct IntroductionBlock: Codable, Hashable, Sendable {
    public let id: BlockID
    public let title: LocalizedText
    public let body: LocalizedText
    public let audio: AssetReference?

    public init(id: BlockID, title: LocalizedText, body: LocalizedText, audio: AssetReference? = nil) {
        self.id = id; self.title = title; self.body = body; self.audio = audio
    }
}

public struct VocabularyBlock: Codable, Hashable, Sendable {
    public let id: BlockID
    public let vocabularyIDs: [VocabularyID]

    public init(id: BlockID, vocabularyIDs: [VocabularyID]) {
        self.id = id; self.vocabularyIDs = vocabularyIDs
    }
}

public struct DialogueBlock: Codable, Hashable, Sendable {
    public let id: BlockID
    public let lines: [DialogueLine]
    /// Optional authored comprehension references. The lesson UI can place
    /// the corresponding real exercise directly after the dialogue.
    public let comprehensionExerciseIDs: [ExerciseID]
    /// An authored listening/writing turn. `audioLineIndex` identifies the
    /// response the learner hears; accepted responses contain the preceding
    /// line they are asked to write.
    public let participation: DialogueParticipation?

    private enum CodingKeys: String, CodingKey { case id, lines, comprehensionExerciseIDs, participation }

    public init(
        id: BlockID,
        lines: [DialogueLine],
        comprehensionExerciseIDs: [ExerciseID] = [],
        participation: DialogueParticipation? = nil
    ) {
        self.id = id
        self.lines = lines
        self.comprehensionExerciseIDs = comprehensionExerciseIDs
        self.participation = participation
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(BlockID.self, forKey: .id),
            lines: try c.decode([DialogueLine].self, forKey: .lines),
            comprehensionExerciseIDs: try c.decodeIfPresent([ExerciseID].self, forKey: .comprehensionExerciseIDs) ?? [],
            participation: try c.decodeIfPresent(DialogueParticipation.self, forKey: .participation)
        )
    }
}

public struct DialogueParticipation: Codable, Hashable, Sendable {
    public let prompt: LocalizedText
    public let audioLineIndex: Int
    public let acceptedResponses: [String]
    public let hint: LocalizedText?

    public init(
        prompt: LocalizedText,
        audioLineIndex: Int,
        acceptedResponses: [String],
        hint: LocalizedText? = nil
    ) {
        self.prompt = prompt
        self.audioLineIndex = max(0, audioLineIndex)
        self.acceptedResponses = acceptedResponses
        self.hint = hint
    }
}

public struct DialogueLine: Codable, Hashable, Sendable {
    public let speaker: String
    public let hanzi: String
    public let pinyin: String
    public let translation: LocalizedText
    public let audio: AssetReference?

    public init(speaker: String, hanzi: String, pinyin: String, translation: LocalizedText, audio: AssetReference? = nil) {
        self.speaker = speaker; self.hanzi = hanzi; self.pinyin = pinyin; self.translation = translation; self.audio = audio
    }
}

public struct ReadingBlock: Codable, Hashable, Sendable {
    public let id: BlockID
    public let storyID: StoryID
    /// Optional lesson or module level used when a reading is surfaced in the
    /// Explorer. Older reading blocks omit it and use the course fallback.
    public let level: String?
    public let title: LocalizedText
    public let paragraphs: [ReadingParagraph]
    public let comprehensionExerciseIDs: [ExerciseID]

    public init(id: BlockID, storyID: StoryID, level: String? = nil, title: LocalizedText, paragraphs: [ReadingParagraph], comprehensionExerciseIDs: [ExerciseID] = []) {
        self.id = id; self.storyID = storyID; self.level = level; self.title = title; self.paragraphs = paragraphs; self.comprehensionExerciseIDs = comprehensionExerciseIDs
    }
}

public struct ReadingParagraph: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let hanzi: String
    public let pinyin: String
    public let translation: LocalizedText
    public let segmentation: [TextSegment]
    public let audio: AssetReference?

    public init(id: String, hanzi: String, pinyin: String, translation: LocalizedText, segmentation: [TextSegment] = [], audio: AssetReference? = nil) {
        self.id = id; self.hanzi = hanzi; self.pinyin = pinyin; self.translation = translation; self.segmentation = segmentation; self.audio = audio
    }
}

public struct ExerciseBlock: Codable, Hashable, Sendable {
    public let id: BlockID
    public let spec: ExerciseSpec

    public init(id: BlockID, spec: ExerciseSpec) {
        self.id = id; self.spec = spec
    }
}

public struct RecapBlock: Codable, Hashable, Sendable {
    public let id: BlockID
    public let vocabularyIDs: [VocabularyID]
    public let objectiveIDs: [String]

    public init(id: BlockID, vocabularyIDs: [VocabularyID] = [], objectiveIDs: [String] = []) {
        self.id = id; self.vocabularyIDs = vocabularyIDs; self.objectiveIDs = objectiveIDs
    }
}

public enum UnlockPolicy: String, Codable, Hashable, Sendable {
    case sequentialLesson
    case allLessons
}

public struct LearningPath: Codable, Hashable, Sendable {
    public let courseID: CourseID
    public let orderedLessonIDs: [LessonID]
    public let policy: UnlockPolicy

    public init(courseID: CourseID, orderedLessonIDs: [LessonID], policy: UnlockPolicy = .sequentialLesson) {
        self.courseID = courseID; self.orderedLessonIDs = orderedLessonIDs; self.policy = policy
    }
}

public struct HomeState: Codable, Hashable, Sendable {
    public let path: LearningPath
    public let nextLessonID: LessonID?
    public let dueCardCount: Int
    public let completedLessonCount: Int
    public let streakDays: Int

    public init(path: LearningPath, nextLessonID: LessonID?, dueCardCount: Int, completedLessonCount: Int, streakDays: Int) {
        self.path = path; self.nextLessonID = nextLessonID; self.dueCardCount = dueCardCount; self.completedLessonCount = completedLessonCount; self.streakDays = streakDays
    }
}
