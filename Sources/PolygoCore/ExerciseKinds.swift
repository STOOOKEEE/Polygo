import Foundation

/// Pair four or five Chinese items with their meaning (or pinyin) by tapping.
public struct MatchingExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let pairs: [MatchPair]

    public init(header: ExerciseHeader, pairs: [MatchPair]) {
        self.header = header; self.pairs = pairs
    }

    /// The pairs in the order the right-hand column shows them. The order is
    /// derived from the exercise and pair identifiers, so it is stable across
    /// launches and restored sessions, and it never equals the authored order.
    public var rightColumn: [MatchPair] {
        let ranked = pairs.sorted { left, right in
            let leftRank = Self.rank("\(header.id.rawValue)/\(left.id)")
            let rightRank = Self.rank("\(header.id.rawValue)/\(right.id)")
            return leftRank == rightRank ? left.id < right.id : leftRank < rightRank
        }
        guard ranked.count > 1, ranked.map(\.id) == pairs.map(\.id) else { return ranked }
        return Array(ranked.dropFirst()) + [ranked[0]]
    }

    private static func rank(_ value: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

public struct MatchPair: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    /// The Chinese side: a word, or a sentence fragment.
    public let left: String
    /// Pinyin shown under `left` when the pairing does not ask for it.
    public let pinyin: String?
    /// The side to pair it with: a French meaning, or pinyin.
    public let right: LocalizedText

    public init(id: String, left: String, pinyin: String? = nil, right: LocalizedText) {
        self.id = id; self.left = left; self.pinyin = pinyin; self.right = right
    }
}

public enum DictationScript: String, Codable, Hashable, Sendable {
    case pinyin, hanzi
}

/// Listen to a word or a sentence, then pick how it is written.
public struct DictationExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    /// What the choices spell: their pinyin or their Hanzi.
    public let script: DictationScript
    public let promptAudio: AssetReference?
    /// Mandarin text for local TTS when no recording has been delivered.
    public let promptText: String?
    public let choices: [Choice]
    public let correctChoiceID: String
    public let replayLimit: Int?

    public init(header: ExerciseHeader, script: DictationScript, promptAudio: AssetReference? = nil, promptText: String? = nil, choices: [Choice], correctChoiceID: String, replayLimit: Int? = nil) {
        self.header = header; self.script = script; self.promptAudio = promptAudio; self.promptText = promptText
        self.choices = choices; self.correctChoiceID = correctChoiceID; self.replayLimit = replayLimit
    }
}

/// Listen to a syllable or a word, then pick its tone or tone pattern.
/// Choice identifiers spell the pattern: `t4` for one falling syllable,
/// `t42` for a falling then rising word, `t0` for a neutral syllable.
public struct ToneDiscriminationExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let promptAudio: AssetReference?
    public let promptText: String?
    public let choices: [Choice]
    public let correctChoiceID: String
    public let replayLimit: Int?

    public init(header: ExerciseHeader, promptAudio: AssetReference? = nil, promptText: String? = nil, choices: [Choice], correctChoiceID: String, replayLimit: Int? = nil) {
        self.header = header; self.promptAudio = promptAudio; self.promptText = promptText
        self.choices = choices; self.correctChoiceID = correctChoiceID; self.replayLimit = replayLimit
    }
}

/// Translate a French sentence by assembling Chinese tiles, some of which are
/// distractors that the answer must leave out.
public struct TranslationExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let tokens: [WordToken]
    /// The tiles of the expected sentence, in order. Distractor tiles are in
    /// `tokens` only.
    public let correctOrder: [String]
    /// Other complete tile sequences that are just as good a translation.
    public let acceptedOrders: [[String]]

    public init(header: ExerciseHeader, tokens: [WordToken], correctOrder: [String], acceptedOrders: [[String]] = []) {
        self.header = header; self.tokens = tokens; self.correctOrder = correctOrder; self.acceptedOrders = acceptedOrders
    }

    private enum CodingKeys: String, CodingKey { case header, tokens, correctOrder, acceptedOrders }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            header: try container.decode(ExerciseHeader.self, forKey: .header),
            tokens: try container.decode([WordToken].self, forKey: .tokens),
            correctOrder: try container.decode([String].self, forKey: .correctOrder),
            acceptedOrders: try container.decodeIfPresent([[String]].self, forKey: .acceptedOrders) ?? []
        )
    }
}

/// Rebuild a short dialogue by putting its shuffled lines back in order.
public struct DialogueOrderExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let lines: [DialogueOrderLine]
    public let correctOrder: [String]

    public init(header: ExerciseHeader, lines: [DialogueOrderLine], correctOrder: [String]) {
        self.header = header; self.lines = lines; self.correctOrder = correctOrder
    }
}

public struct DialogueOrderLine: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let speaker: String?
    public let hanzi: String
    public let pinyin: String?
    public let audio: AssetReference?

    public init(id: String, speaker: String? = nil, hanzi: String, pinyin: String? = nil, audio: AssetReference? = nil) {
        self.id = id; self.speaker = speaker; self.hanzi = hanzi; self.pinyin = pinyin; self.audio = audio
    }
}

/// A mini-conversation: hear the interlocutor's line, then pick the best reply.
public struct ConversationChoiceExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let speaker: String?
    public let promptAudio: AssetReference?
    public let promptText: String?
    public let replies: [ConversationReply]
    public let correctReplyID: String
    public let replayLimit: Int?

    public init(header: ExerciseHeader, speaker: String? = nil, promptAudio: AssetReference? = nil, promptText: String? = nil, replies: [ConversationReply], correctReplyID: String, replayLimit: Int? = nil) {
        self.header = header; self.speaker = speaker; self.promptAudio = promptAudio; self.promptText = promptText
        self.replies = replies; self.correctReplyID = correctReplyID; self.replayLimit = replayLimit
    }
}

public struct ConversationReply: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let hanzi: String
    public let pinyin: String?
    public let audio: AssetReference?

    public init(id: String, hanzi: String, pinyin: String? = nil, audio: AssetReference? = nil) {
        self.id = id; self.hanzi = hanzi; self.pinyin = pinyin; self.audio = audio
    }
}
