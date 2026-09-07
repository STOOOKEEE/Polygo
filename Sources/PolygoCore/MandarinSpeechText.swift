import Foundation

/// Keeps only the Hanzi and Mandarin-safe connectors from text that may also
/// contain a learner-facing instruction in another language. Apple speech
/// surfaces use this value before sending text to a zh-CN voice.
public enum MandarinSpeechText {
    private static let chinesePunctuation = CharacterSet(
        charactersIn: "，。！？、；：‘’“”（）《》【】…—·!?.,;:"
    )

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
