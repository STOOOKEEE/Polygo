import Foundation

public enum ExerciseSpec: Codable, Hashable, Sendable, Identifiable {
    case choice(ChoiceExercise)
    case wordOrder(WordOrderExercise)
    case fillBlank(FillBlankExercise)
    case listeningChoice(ListeningChoiceExercise)
    case speaking(SpeakingExercise)
    case handwriting(HandwritingExercise)
    case flashcard(FlashcardExercise)

    public var id: ExerciseID {
        switch self {
        case .choice(let value): return value.header.id
        case .wordOrder(let value): return value.header.id
        case .fillBlank(let value): return value.header.id
        case .listeningChoice(let value): return value.header.id
        case .speaking(let value): return value.header.id
        case .handwriting(let value): return value.header.id
        case .flashcard(let value): return value.header.id
        }
    }

    public var header: ExerciseHeader {
        switch self {
        case .choice(let value): return value.header
        case .wordOrder(let value): return value.header
        case .fillBlank(let value): return value.header
        case .listeningChoice(let value): return value.header
        case .speaking(let value): return value.header
        case .handwriting(let value): return value.header
        case .flashcard(let value): return value.header
        }
    }

    private enum CodingKeys: String, CodingKey {
        case kind, value
        case header, choices, correctChoiceID
        case tokens, correctOrder
        case sentence, acceptedAnswers, caseSensitive
        case promptAudio, replayLimit
        case referenceText, referencePinyin, referenceAudio, acceptedTranscripts, allowSelfRating
        case targetHanzi, guideAsset, expectedStrokeCount
        case cardID
    }
    private enum Kind: String, Codable {
        case choice
        case wordOrder
        case fillBlank
        case listeningChoice
        case speaking
        case handwriting
        case flashcard

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            switch value {
            case "choice", "toneChoose", "meaningChoose": self = .choice
            case "wordOrder", "sentenceOrder": self = .wordOrder
            case "fillBlank": self = .fillBlank
            case "listeningChoice", "listenChoose": self = .listeningChoice
            case "speaking", "speakPrompt": self = .speaking
            case "handwriting", "writeCharacter": self = .handwriting
            case "flashcard", "reviewRecall": self = .flashcard
            default: throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Unknown exercise kind: \(value)")
            }
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .choice: self = .choice(container.contains(.value) ? try container.decode(ChoiceExercise.self, forKey: .value) : try ChoiceExercise(from: decoder))
        case .wordOrder: self = .wordOrder(container.contains(.value) ? try container.decode(WordOrderExercise.self, forKey: .value) : try WordOrderExercise(from: decoder))
        case .fillBlank: self = .fillBlank(container.contains(.value) ? try container.decode(FillBlankExercise.self, forKey: .value) : try FillBlankExercise(from: decoder))
        case .listeningChoice: self = .listeningChoice(container.contains(.value) ? try container.decode(ListeningChoiceExercise.self, forKey: .value) : try ListeningChoiceExercise(from: decoder))
        case .speaking: self = .speaking(container.contains(.value) ? try container.decode(SpeakingExercise.self, forKey: .value) : try SpeakingExercise(from: decoder))
        case .handwriting: self = .handwriting(container.contains(.value) ? try container.decode(HandwritingExercise.self, forKey: .value) : try HandwritingExercise(from: decoder))
        case .flashcard: self = .flashcard(container.contains(.value) ? try container.decode(FlashcardExercise.self, forKey: .value) : try FlashcardExercise(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .choice(let value):
            try container.encode(Kind.choice, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.choices, forKey: .choices); try container.encode(value.correctChoiceID, forKey: .correctChoiceID)
        case .wordOrder(let value):
            try container.encode(Kind.wordOrder, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.tokens, forKey: .tokens); try container.encode(value.correctOrder, forKey: .correctOrder)
        case .fillBlank(let value):
            try container.encode(Kind.fillBlank, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.sentence, forKey: .sentence); try container.encode(value.acceptedAnswers, forKey: .acceptedAnswers); try container.encode(value.caseSensitive, forKey: .caseSensitive)
        case .listeningChoice(let value):
            try container.encode(Kind.listeningChoice, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.promptAudio, forKey: .promptAudio); try container.encode(value.choices, forKey: .choices); try container.encode(value.correctChoiceID, forKey: .correctChoiceID); try container.encodeIfPresent(value.replayLimit, forKey: .replayLimit)
        case .speaking(let value):
            try container.encode(Kind.speaking, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.referenceText, forKey: .referenceText); try container.encode(value.referencePinyin, forKey: .referencePinyin); try container.encodeIfPresent(value.referenceAudio, forKey: .referenceAudio); try container.encode(value.acceptedTranscripts, forKey: .acceptedTranscripts); try container.encode(value.allowSelfRating, forKey: .allowSelfRating)
        case .handwriting(let value):
            try container.encode(Kind.handwriting, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.targetHanzi, forKey: .targetHanzi); try container.encode(value.guideAsset, forKey: .guideAsset); try container.encodeIfPresent(value.expectedStrokeCount, forKey: .expectedStrokeCount); try container.encode(value.allowSelfRating, forKey: .allowSelfRating)
        case .flashcard(let value):
            try container.encode(Kind.flashcard, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encode(value.cardID, forKey: .cardID)
        }
    }
}

public struct ExerciseHeader: Codable, Hashable, Sendable {
    public let id: ExerciseID
    public let prompt: LocalizedText
    public let instruction: LocalizedText
    public let objectiveIDs: [String]
    public let required: Bool

    public init(id: ExerciseID, prompt: LocalizedText, instruction: LocalizedText? = nil, objectiveIDs: [String] = [], required: Bool = true) {
        self.id = id; self.prompt = prompt; self.instruction = instruction ?? prompt; self.objectiveIDs = objectiveIDs; self.required = required
    }
}

public struct ChoiceExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let choices: [Choice]
    public let correctChoiceID: String

    public init(header: ExerciseHeader, choices: [Choice], correctChoiceID: String) {
        self.header = header; self.choices = choices; self.correctChoiceID = correctChoiceID
    }
}

public struct Choice: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let label: LocalizedText
    public let audio: AssetReference?

    public init(id: String, label: LocalizedText, audio: AssetReference? = nil) {
        self.id = id; self.label = label; self.audio = audio
    }
}

public struct WordOrderExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let tokens: [WordToken]
    public let correctOrder: [String]

    public init(header: ExerciseHeader, tokens: [WordToken], correctOrder: [String]) {
        self.header = header; self.tokens = tokens; self.correctOrder = correctOrder
    }
}

public struct WordToken: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let hanzi: String
    public let pinyin: String?
    public let audio: AssetReference?

    public init(id: String, hanzi: String, pinyin: String? = nil, audio: AssetReference? = nil) {
        self.id = id; self.hanzi = hanzi; self.pinyin = pinyin; self.audio = audio
    }
}

public struct FillBlankExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let sentence: String
    public let acceptedAnswers: [String]
    public let caseSensitive: Bool

    public init(header: ExerciseHeader, sentence: String, acceptedAnswers: [String], caseSensitive: Bool = false) {
        self.header = header; self.sentence = sentence; self.acceptedAnswers = acceptedAnswers; self.caseSensitive = caseSensitive
    }
}

public struct ListeningChoiceExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let promptAudio: AssetReference
    public let choices: [Choice]
    public let correctChoiceID: String
    public let replayLimit: Int?

    public init(header: ExerciseHeader, promptAudio: AssetReference, choices: [Choice], correctChoiceID: String, replayLimit: Int? = nil) {
        self.header = header; self.promptAudio = promptAudio; self.choices = choices; self.correctChoiceID = correctChoiceID; self.replayLimit = replayLimit
    }
}

public struct SpeakingExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let referenceText: String
    public let referencePinyin: String
    public let referenceAudio: AssetReference?
    public let acceptedTranscripts: [String]
    public let allowSelfRating: Bool

    public init(header: ExerciseHeader, referenceText: String, referencePinyin: String, referenceAudio: AssetReference? = nil, acceptedTranscripts: [String] = [], allowSelfRating: Bool = true) {
        self.header = header; self.referenceText = referenceText; self.referencePinyin = referencePinyin; self.referenceAudio = referenceAudio; self.acceptedTranscripts = acceptedTranscripts; self.allowSelfRating = allowSelfRating
    }
}

public struct HandwritingExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let targetHanzi: String
    public let guideAsset: AssetReference
    public let expectedStrokeCount: Int?
    public let allowSelfRating: Bool

    public init(header: ExerciseHeader, targetHanzi: String, guideAsset: AssetReference, expectedStrokeCount: Int? = nil, allowSelfRating: Bool = true) {
        self.header = header; self.targetHanzi = targetHanzi; self.guideAsset = guideAsset; self.expectedStrokeCount = expectedStrokeCount; self.allowSelfRating = allowSelfRating
    }
}

public struct FlashcardExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    public let cardID: CardID

    public init(header: ExerciseHeader, cardID: CardID) {
        self.header = header; self.cardID = cardID
    }
}

public enum ExerciseAnswer: Codable, Hashable, Sendable {
    case choice(choiceID: String)
    case wordOrder(tokenIDs: [String])
    case text(String)
    case speech(SpeechAnswer)
    case handwriting(HandwritingAnswer)
    case selfRating(SelfRating)

    private enum CodingKeys: String, CodingKey { case kind, choiceID, tokenIDs, text, speech, handwriting, rating }
    private enum Kind: String, Codable { case choice, wordOrder, text, speech, handwriting, selfRating }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .choice: self = .choice(choiceID: try container.decode(String.self, forKey: .choiceID))
        case .wordOrder: self = .wordOrder(tokenIDs: try container.decode([String].self, forKey: .tokenIDs))
        case .text: self = .text(try container.decode(String.self, forKey: .text))
        case .speech: self = .speech(try container.decode(SpeechAnswer.self, forKey: .speech))
        case .handwriting: self = .handwriting(try container.decode(HandwritingAnswer.self, forKey: .handwriting))
        case .selfRating: self = .selfRating(try container.decode(SelfRating.self, forKey: .rating))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .choice(let value): try container.encode(Kind.choice, forKey: .kind); try container.encode(value, forKey: .choiceID)
        case .wordOrder(let value): try container.encode(Kind.wordOrder, forKey: .kind); try container.encode(value, forKey: .tokenIDs)
        case .text(let value): try container.encode(Kind.text, forKey: .kind); try container.encode(value, forKey: .text)
        case .speech(let value): try container.encode(Kind.speech, forKey: .kind); try container.encode(value, forKey: .speech)
        case .handwriting(let value): try container.encode(Kind.handwriting, forKey: .kind); try container.encode(value, forKey: .handwriting)
        case .selfRating(let value): try container.encode(Kind.selfRating, forKey: .kind); try container.encode(value, forKey: .rating)
        }
    }
}

public struct SpeechAnswer: Codable, Hashable, Sendable {
    public let transcript: String
    public let normalizedTranscript: String
    public let confidence: Double?
    public let localeIdentifier: String
    public let recordingID: RecordingID?

    public init(transcript: String, normalizedTranscript: String? = nil, confidence: Double? = nil, localeIdentifier: String = "zh-CN", recordingID: RecordingID? = nil) {
        self.transcript = transcript
        self.normalizedTranscript = normalizedTranscript ?? TextNormalizer.normalize(transcript)
        self.confidence = confidence
        self.localeIdentifier = localeIdentifier
        self.recordingID = recordingID
    }
}

public struct HandwritingAnswer: Codable, Hashable, Sendable {
    public let drawingID: DrawingID?
    public let recognizedText: String?
    public let strokeCount: Int
    public let selfChecked: Bool

    public init(drawingID: DrawingID? = nil, recognizedText: String? = nil, strokeCount: Int, selfChecked: Bool) {
        self.drawingID = drawingID; self.recognizedText = recognizedText; self.strokeCount = strokeCount; self.selfChecked = selfChecked
    }
}

public enum SelfRating: String, Codable, Hashable, Sendable, CaseIterable {
    case again, hard, good, easy
}

public enum EvaluationOutcome: String, Codable, Hashable, Sendable {
    case correct, incorrect, partial, selfReported, unavailable
}

public struct ExerciseEvaluation: Codable, Hashable, Sendable {
    public let exerciseID: ExerciseID
    public let outcome: EvaluationOutcome
    public let score: Double
    public let feedback: LocalizedText
    public let accepted: Bool
    public let normalizedAnswer: String?

    public init(exerciseID: ExerciseID, outcome: EvaluationOutcome, score: Double, feedback: LocalizedText, accepted: Bool, normalizedAnswer: String? = nil) throws {
        guard score >= 0, score <= 1 else { throw DomainError.invalidScore(score) }
        self.exerciseID = exerciseID; self.outcome = outcome; self.score = score; self.feedback = feedback; self.accepted = accepted; self.normalizedAnswer = normalizedAnswer
    }
}

public protocol ExerciseEngine: Sendable {
    func evaluate(spec: ExerciseSpec, answer: ExerciseAnswer) -> ExerciseEvaluation
}
