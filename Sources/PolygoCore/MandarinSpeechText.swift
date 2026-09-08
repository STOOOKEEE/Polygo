import Foundation

/// A Mandarin sentence ready for a narrated reading or dialogue. Timing is
/// carried beside the text so the app can configure an Apple utterance delay
/// without adding artificial words or punctuation to learner content.
public struct MandarinSpeechSegment: Codable, Hashable, Sendable {
    public let text: String
    public let postUtteranceDelay: TimeInterval

    public init(text: String, postUtteranceDelay: TimeInterval = 0) {
        self.text = text
        self.postUtteranceDelay = min(max(0, postUtteranceDelay), 10)
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

    /// Returns the reading paragraphs in authored order, pausing briefly
    /// between sentences and a little longer between paragraph turns.
    public static func readingSegments(from reading: ReadingBlock) -> [MandarinSpeechSegment] {
        var items: [(paragraphIndex: Int, text: String)] = []
        for (paragraphIndex, paragraph) in reading.paragraphs.enumerated() {
            for sentence in sentences(from: paragraph.hanzi) {
                items.append((paragraphIndex, sentence))
            }
        }

        return items.enumerated().map { index, item in
            let isLast = index == items.count - 1
            let crossesParagraph = !isLast && items[index + 1].paragraphIndex != item.paragraphIndex
            return MandarinSpeechSegment(
                text: item.text,
                postUtteranceDelay: isLast ? 0 : (crossesParagraph ? 0.6 : 0.3)
            )
        }
    }

    /// Returns dialogue lines in authored order, using a longer pause when
    /// the next sentence belongs to another speaker.
    public static func dialogueSegments(from lines: [DialogueLine]) -> [MandarinSpeechSegment] {
        var items: [(speaker: String, text: String)] = []
        for line in lines {
            for sentence in sentences(from: line.hanzi) {
                items.append((line.speaker, sentence))
            }
        }

        return items.enumerated().map { index, item in
            let isLast = index == items.count - 1
            let changesSpeaker = !isLast && items[index + 1].speaker != item.speaker
            return MandarinSpeechSegment(
                text: item.text,
                postUtteranceDelay: isLast ? 0 : (changesSpeaker ? 0.6 : 0.3)
            )
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

    private static func isHanzi(_ scalar: UnicodeScalar) -> Bool {
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
