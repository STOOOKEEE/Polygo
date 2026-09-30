import Foundation

/// A Mandarin sentence ready for a narrated reading or dialogue. Timing is
/// carried beside the text so the app can configure an Apple utterance delay
/// without adding artificial words or punctuation to learner content. When
/// `audio` is set, the segment is a whole bundled recording of `text`; the
/// text stays available for synthesis when the recording cannot be played.
public struct MandarinSpeechSegment: Codable, Hashable, Sendable {
    public let text: String
    public let postUtteranceDelay: TimeInterval
    public let audio: AssetReference?

    public init(text: String, postUtteranceDelay: TimeInterval = 0, audio: AssetReference? = nil) {
        self.text = text
        self.postUtteranceDelay = min(max(0, postUtteranceDelay), 10)
        self.audio = audio
    }
}

/// Keeps only the Hanzi and Mandarin-safe connectors from text that may also
/// contain a learner-facing instruction in another language. Apple speech
/// surfaces use this value before sending text to a zh-CN voice.
public enum MandarinSpeechText {
    private static let chinesePunctuation = CharacterSet(
        charactersIn: "，。！？、；：‘’“”（）《》【】…—·!?.,;:"
    )
    private static let sentenceEndings = CharacterSet(charactersIn: "。！？!?")
    private static let sentenceClosers = CharacterSet(charactersIn: "’”）〉》」』】〕］\"")
    private static let clauseEndings = CharacterSet(charactersIn: "，、；：,;:")

    /// Narration pauses, in seconds, after a clause inside a sentence, after
    /// a sentence of the same speaker or paragraph, and after a speaker or
    /// paragraph change.
    static let clausePause: TimeInterval = 0.35
    static let sentencePause: TimeInterval = 0.6
    static let turnPause: TimeInterval = 1.0

    public static func target(from value: String) -> String {
        var result = ""
        var pendingConnectors: [UnicodeScalar] = []
        var inChineseRun = false
        var mayHaveTargetPrefix = true

        for scalar in value.unicodeScalars {
            if isHanzi(scalar) {
                if !inChineseRun {
                    // Digits at the beginning of a Chinese phrase (20岁) are
                    // useful, while digits in a French instruction ("20 ...
                    // 你好") must stay out. A non-connector marks that
                    // boundary, so only a prefix from the start is retained.
                    if mayHaveTargetPrefix {
                        result.unicodeScalars.append(contentsOf: pendingConnectors)
                    }
                    pendingConnectors.removeAll(keepingCapacity: true)
                }
                result.unicodeScalars.append(scalar)
                inChineseRun = true
                mayHaveTargetPrefix = false
            } else if isMandarinConnector(scalar) {
                if inChineseRun {
                    result.unicodeScalars.append(scalar)
                } else {
                    pendingConnectors.append(scalar)
                }
            } else {
                inChineseRun = false
                pendingConnectors.removeAll(keepingCapacity: true)
                mayHaveTargetPrefix = false
            }
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func containsHanzi(_ value: String) -> Bool {
        value.unicodeScalars.contains(where: isHanzi)
    }

    /// Splits authored Mandarin into complete sentence utterances while
    /// retaining its punctuation and removing any surrounding Latin labels.
    public static func sentences(from value: String) -> [String] {
        let target = target(from: value)
        let scalars = Array(target.unicodeScalars)
        guard !scalars.isEmpty else { return [] }

        var sentences: [String] = []
        var current = String.UnicodeScalarView()
        var sentenceEndingIsPending = false
        for index in scalars.indices {
            let scalar = scalars[index]
            current.append(scalar)

            if sentenceEndings.contains(scalar) {
                // Keep the sentence open through runs such as "？！". A
                // closing quote is handled on its own iteration so it stays
                // attached to the sentence that it closes.
                sentenceEndingIsPending = true
                let nextScalar = scalars.indices.contains(index + 1) ? scalars[index + 1] : nil
                let continuesEnding = nextScalar.map {
                    sentenceEndings.contains($0) || sentenceClosers.contains($0)
                } ?? false
                if !continuesEnding {
                    let sentence = String(current).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sentence.isEmpty { sentences.append(sentence) }
                    current.removeAll()
                    sentenceEndingIsPending = false
                }
                continue
            }

            guard sentenceEndingIsPending, sentenceClosers.contains(scalar) else {
                continue
            }

            let nextScalar = scalars.indices.contains(index + 1) ? scalars[index + 1] : nil
            let continuesEnding = nextScalar.map {
                sentenceEndings.contains($0) || sentenceClosers.contains($0)
            } ?? false
            if !continuesEnding {
                let sentence = String(current).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { sentences.append(sentence) }
                current.removeAll()
                sentenceEndingIsPending = false
            }
        }

        let trailing = String(current).trimmingCharacters(in: .whitespacesAndNewlines)
        if !trailing.isEmpty { sentences.append(trailing) }
        return sentences
    }

    /// Splits one sentence into spoken clauses at `，、；：` and ASCII `,;:`,
    /// keeping the punctuation and any closing quote attached to the clause.
    /// A fragment without Hanzi is merged into its neighbour so no segment
    /// is only punctuation or digits.
    static func clauses(from sentence: String) -> [String] {
        let scalars = Array(sentence.unicodeScalars)
        var pieces: [String] = []
        var current = String.UnicodeScalarView()
        var clauseEndingIsPending = false
        for index in scalars.indices {
            let scalar = scalars[index]
            current.append(scalar)
            if clauseEndings.contains(scalar) {
                clauseEndingIsPending = true
            } else if !(clauseEndingIsPending && sentenceClosers.contains(scalar)) {
                continue
            }

            let nextScalar = scalars.indices.contains(index + 1) ? scalars[index + 1] : nil
            let continuesEnding = nextScalar.map {
                clauseEndings.contains($0) || sentenceClosers.contains($0)
            } ?? false
            // Keep digit groups such as "1,000" in one clause.
            let isDigit = { (scalar: UnicodeScalar?) in
                scalar.map { CharacterSet.decimalDigits.contains($0) } ?? false
            }
            let separatesDigits = isDigit(nextScalar) && index > 0 && isDigit(scalars[index - 1])
            if !continuesEnding && !separatesDigits {
                pieces.append(String(current))
                current.removeAll()
                clauseEndingIsPending = false
            }
        }
        pieces.append(String(current))

        var clauses: [String] = []
        var carried = ""
        for piece in pieces {
            let text = carried + piece
            if containsHanzi(text) {
                clauses.append(text)
                carried = ""
            } else {
                carried = text
            }
        }
        if let last = clauses.indices.last {
            clauses[last] += carried
        }
        return clauses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Returns the reading paragraphs in authored order, pausing after each
    /// clause, longer after each sentence, and longest between paragraphs.
    /// A paragraph with a bundled recording is one segment carrying it;
    /// the others are split into clauses for synthesis.
    public static func readingSegments(from reading: ReadingBlock) -> [MandarinSpeechSegment] {
        narrationSegments(reading.paragraphs.enumerated().map { (owner: $0.offset, text: $0.element.hanzi, audio: $0.element.audio) })
    }

    /// Returns dialogue lines in authored order, pausing after each clause,
    /// longer after each sentence, and longest when the next sentence
    /// belongs to another speaker. A line with a bundled recording is one
    /// segment carrying it; the others are split into clauses. A single
    /// line yields only its own internal pauses, ending with no pause.
    public static func dialogueSegments(from lines: [DialogueLine]) -> [MandarinSpeechSegment] {
        narrationSegments(lines.map { (owner: $0.speaker, text: $0.hanzi, audio: $0.audio) })
    }

    private static func narrationSegments<Owner: Equatable>(
        _ turns: [(owner: Owner, text: String, audio: AssetReference?)]
    ) -> [MandarinSpeechSegment] {
        var items: [(owner: Owner, sentence: Int, text: String, audio: AssetReference?)] = []
        var sentenceIndex = 0
        for turn in turns {
            let turnSentences = sentences(from: turn.text)
            if let audio = turn.audio, !turnSentences.isEmpty {
                // The recording already contains the turn's own pauses.
                items.append((turn.owner, sentenceIndex, turnSentences.joined(), audio))
                sentenceIndex += 1
                continue
            }
            for sentence in turnSentences {
                for clause in clauses(from: sentence) {
                    items.append((turn.owner, sentenceIndex, clause, nil))
                }
                sentenceIndex += 1
            }
        }

        return items.enumerated().map { index, item in
            guard index + 1 < items.count else {
                return MandarinSpeechSegment(text: item.text, audio: item.audio)
            }
            let next = items[index + 1]
            let pause = next.owner != item.owner
                ? turnPause
                : (next.sentence != item.sentence ? sentencePause : clausePause)
            return MandarinSpeechSegment(text: item.text, postUtteranceDelay: pause, audio: item.audio)
        }
    }

    /// Returns true for text that contains only Hanzi, Mandarin-safe
    /// punctuation, decimal digits, and whitespace. This lets an audio asset
    /// be used only when it describes the same target the learner sees.
    public static func isTargetOnly(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsHanzi(trimmed) else { return false }
        return trimmed.unicodeScalars.allSatisfy(isMandarinCharacter)
    }

    private static func isMandarinCharacter(_ scalar: UnicodeScalar) -> Bool {
        isHanzi(scalar) || isMandarinConnector(scalar)
    }

    static func isHanzi(_ scalar: UnicodeScalar) -> Bool {
        (0x3400...0x4DBF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value)
            || (0x20000...0x2FA1F).contains(scalar.value)
    }

    private static func isMandarinConnector(_ scalar: UnicodeScalar) -> Bool {
        chinesePunctuation.contains(scalar)
            || CharacterSet.decimalDigits.contains(scalar)
            || CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
