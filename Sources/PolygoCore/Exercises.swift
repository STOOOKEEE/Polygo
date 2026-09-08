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
        case promptAudio, promptText, replayLimit
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
            try container.encode(Kind.listeningChoice, forKey: .kind); try container.encode(value.header, forKey: .header); try container.encodeIfPresent(value.promptAudio, forKey: .promptAudio); try container.encodeIfPresent(value.promptText, forKey: .promptText); try container.encode(value.choices, forKey: .choices); try container.encode(value.correctChoiceID, forKey: .correctChoiceID); try container.encodeIfPresent(value.replayLimit, forKey: .replayLimit)
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

    /// Returns the first accepted answer that is safe to send to a Mandarin
    /// synthesizer. The learner still sees the blank in `sentence`; this value
    /// is only used to build the audio target.
    public var canonicalSpeechAnswer: String? {
        acceptedAnswers.first { MandarinSpeechText.isTargetOnly($0) }
    }

    /// The five tap targets used by the lesson player for this exercise.
    /// Content remains encoded as `fillBlank` so old journals, evaluation,
    /// and resume checkpoints keep their existing `.text` answer shape.
    ///
    /// The first Mandarin-safe accepted answer is the canonical target. Other
    /// accepted variants are deliberately excluded from the distractor pool:
    /// a learner must see exactly one correct option. The remaining options
    /// come from a small corpus-backed bank of complete Hanzi characters or
    /// words with the same shape as the target. Their display position is
    /// rotated from a stable exercise-ID hash rather than fixed globally.
    public var choiceOptions: [Choice] {
        guard let answer = canonicalSpeechAnswer,
              !answer.isEmpty else { return [] }

        let accepted = Set(acceptedAnswers.map { TextNormalizer.normalize($0, caseSensitive: caseSensitive) })
        let targetLength = answer.count
        let bank = targetLength == 1 ? Self.singleCharacterChoiceBank : Self.wordChoiceBank
        var distractors: [String] = []
        var seen = accepted
        seen.insert(TextNormalizer.normalize(answer, caseSensitive: caseSensitive))

        guard !bank.isEmpty else { return [] }
        let bankOffset = Int(Self.stableHash("\(header.id.rawValue):distractors") % UInt64(bank.count))
        for step in 0..<bank.count {
            let candidate = bank[(bankOffset + step) % bank.count]
            guard candidate.count == targetLength else { continue }
            let normalized = TextNormalizer.normalize(candidate, caseSensitive: caseSensitive)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            distractors.append(candidate)
            if distractors.count == 4 { break }
        }

        guard distractors.count == 4 else { return [] }
        let values = [answer] + distractors
        let offset = Int(Self.stableHash("\(header.id.rawValue):position") % UInt64(values.count))
        let rotated = Array(values[offset...]) + Array(values[..<offset])

        return rotated.enumerated().map { displayIndex, value in
            let sourceIndex = (displayIndex + offset) % values.count
            return Choice(
                id: "\(header.id.rawValue)-choice-\(sourceIndex)",
                label: .unchecked(["zh-CN": value])
            )
        }
    }

    /// Completes the first authored underscore run and returns the Mandarin
    /// target for speech playback while keeping the exercise's visible
    /// sentence unchanged. Non-Mandarin text is removed by the speech
    /// normalizer, but the canonical answer must remain at the placeholder's
    /// position so an incomplete sentence can never be spoken accidentally.
    public var canonicalSpeechSentence: String? {
        guard let answer = canonicalSpeechAnswer,
              let placeholder = sentence.range(of: "_+", options: .regularExpression) else {
            return nil
        }
        let completed = sentence.replacingCharacters(in: placeholder, with: answer)
        if MandarinSpeechText.isTargetOnly(completed) {
            return completed
        }

        // Some authored examples contain non-Mandarin text around the
        // sentence (for example a Latin name). Keep that text out of the
        // Mandarin target, but only after proving that the canonical answer
        // survives normalization at the placeholder position.
        let prefix = String(sentence[..<placeholder.lowerBound])
        let suffix = String(sentence[placeholder.upperBound...])
        let target = MandarinSpeechText.target(from: completed)
        let expectedTarget = MandarinSpeechText.target(from: prefix)
            + answer
            + MandarinSpeechText.target(from: suffix)
        guard !target.isEmpty,
              MandarinSpeechText.isTargetOnly(target),
              target == expectedTarget else { return nil }
        return target
    }

    // These are the Hanzi answers already used by the shipped lesson corpus.
    // Keeping the bank in Core makes generated options available to every
    // client without loading a platform-specific content file or inventing a
    // distractor from a French gloss.
    private static let singleCharacterChoiceBank = [
        "不", "个", "了", "休", "伞", "位", "使", "元", "六", "刮", "到", "刻", "叫", "喝", "在", "地", "块", "好", "始", "就", "房", "才", "打", "把", "护", "拿", "换", "旧", "春", "样", "段", "河", "物", "用", "疼", "矮", "票", "箱", "糖", "结", "考", "舒", "药", "试", "课", "辆", "遍", "镜", "难", "雨", "雪"
    ]

    private static let wordChoiceBank = [
        "一共", "一样", "中国", "法国", "中间", "了解", "以前", "儿子", "决定", "几乎", "出来", "发现", "咖啡", "太阳", "妹妹", "容易", "影响", "忘记", "愿意", "所以", "放心", "果汁", "根据", "检查", "然后", "特别", "着急", "表演", "这条", "铅笔", "除了", "需要", "马上"
    ]

    private static func stableHash(_ value: String) -> UInt64 {
        // FNV-1a is small, deterministic across processes, and independent
        // of Swift's intentionally randomized Hasher seed.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}

public struct ListeningChoiceExercise: Codable, Hashable, Sendable {
    public let header: ExerciseHeader
    /// A delivered recording, when the content pack includes one.
    public let promptAudio: AssetReference?
    /// Mandarin text for local TTS when no recording has been delivered.
    public let promptText: String?
    public let choices: [Choice]
    public let correctChoiceID: String
    public let replayLimit: Int?

    public init(header: ExerciseHeader, promptAudio: AssetReference? = nil, promptText: String? = nil, choices: [Choice], correctChoiceID: String, replayLimit: Int? = nil) {
        self.header = header
        self.promptAudio = promptAudio
        let normalizedPromptText = promptText?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptText = normalizedPromptText?.isEmpty == false ? normalizedPromptText : nil
        self.choices = choices
        self.correctChoiceID = correctChoiceID
        self.replayLimit = replayLimit
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
    /// An explicit learner choice to leave an exercise without claiming a
    /// result. It is persisted as an answer-shaped event so older progress
    /// journals remain readable while the reducer can keep the exercise
    /// outside scored and answered counts.
    case skipped

    private enum CodingKeys: String, CodingKey { case kind, choiceID, tokenIDs, text, speech, handwriting, rating }
    private enum Kind: String, Codable { case choice, wordOrder, text, speech, handwriting, selfRating, skipped }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .choice: self = .choice(choiceID: try container.decode(String.self, forKey: .choiceID))
        case .wordOrder: self = .wordOrder(tokenIDs: try container.decode([String].self, forKey: .tokenIDs))
        case .text: self = .text(try container.decode(String.self, forKey: .text))
        case .speech: self = .speech(try container.decode(SpeechAnswer.self, forKey: .speech))
        case .handwriting: self = .handwriting(try container.decode(HandwritingAnswer.self, forKey: .handwriting))
        case .selfRating: self = .selfRating(try container.decode(SelfRating.self, forKey: .rating))
        case .skipped: self = .skipped
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
        case .skipped: try container.encode(Kind.skipped, forKey: .kind)
        }
    }
}

public struct SpeechAnswer: Codable, Hashable, Sendable {
    public let transcript: String
    public let normalizedTranscript: String
    public let confidence: Double?
    public let localeIdentifier: String
    public let recordingID: RecordingID?
    /// Optional provider output added after the original speech answer
    /// contract. Its absence preserves the legacy transcript-only behavior.
    public let pronunciationAssessment: SpeechPronunciationAssessment?

    private enum CodingKeys: String, CodingKey {
        case transcript
        case normalizedTranscript
        case confidence
        case localeIdentifier
        case recordingID
        case pronunciationAssessment
    }

    public init(
        transcript: String,
        normalizedTranscript: String? = nil,
        confidence: Double? = nil,
        localeIdentifier: String = "zh-CN",
        recordingID: RecordingID? = nil,
        pronunciationAssessment: SpeechPronunciationAssessment? = nil
    ) {
        self.transcript = transcript
        self.normalizedTranscript = normalizedTranscript ?? TextNormalizer.normalize(transcript)
        self.confidence = confidence
        self.localeIdentifier = localeIdentifier
        self.recordingID = recordingID
        self.pronunciationAssessment = pronunciationAssessment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let transcript = try container.decode(String.self, forKey: .transcript)
        let normalizedTranscript = try container.decodeIfPresent(String.self, forKey: .normalizedTranscript)
        let confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        let localeIdentifier = try container.decodeIfPresent(String.self, forKey: .localeIdentifier) ?? "zh-CN"
        let recordingID = try container.decodeIfPresent(RecordingID.self, forKey: .recordingID)
        let pronunciationAssessment = try container.decodeIfPresent(SpeechPronunciationAssessment.self, forKey: .pronunciationAssessment)
        self.init(
            transcript: transcript,
            normalizedTranscript: normalizedTranscript,
            confidence: confidence,
            localeIdentifier: localeIdentifier,
            recordingID: recordingID,
            pronunciationAssessment: pronunciationAssessment
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(transcript, forKey: .transcript)
        try container.encode(normalizedTranscript, forKey: .normalizedTranscript)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encode(localeIdentifier, forKey: .localeIdentifier)
        try container.encodeIfPresent(recordingID, forKey: .recordingID)
        try container.encodeIfPresent(pronunciationAssessment, forKey: .pronunciationAssessment)
    }
}

/// Provider-neutral, compact speech assessment metadata that can be carried
/// by a persisted `SpeechAnswer`. Detailed word, sound, and tone rows remain
/// in the Apple-side report so progress journals stay small and portable.
public struct SpeechPronunciationAssessment: Codable, Hashable, Sendable {
    public let providerID: String
    public let verdict: SpeechPronunciationVerdict
    public let providerScore: Double?

    public init(
        providerID: String,
        verdict: SpeechPronunciationVerdict,
        providerScore: Double?
    ) {
        self.providerID = providerID
        self.verdict = verdict
        self.providerScore = providerScore.map { min(1, max(0, $0)) }
    }

    /// Only a provider-completed pass or retry with its own score can be sent
    /// to the exercise engine. Inconclusive and malformed reports remain
    /// outside the answer path.
    public var isEvaluable: Bool {
        providerScore != nil && (verdict == .pass || verdict == .needsPractice)
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

public enum SpeechPronunciationVerdict: String, Codable, Hashable, Sendable {
    case pass
    case needsPractice
    case inconclusive
}

public enum EvaluationOutcome: String, Codable, Hashable, Sendable {
    case correct, incorrect, partial, selfReported, unavailable, skipped
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
