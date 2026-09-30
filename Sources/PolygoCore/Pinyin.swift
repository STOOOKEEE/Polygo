import Foundation

/// The syllables of pinyin written by words, as the bundle writes it:
/// `Běijīng` is `Běi` + `jīng`, `Xī'ān` is `Xī` + `ān`.
public enum PinyinSyllables {
    private static let initials = ["zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h", "j", "q", "x", "z", "c", "s", "r", "y", "w"]
    // Folding the tone marks folds ü into u: nü, lüe parse as nu, lue.
    private static let finals: Set<String> = [
        "a", "o", "e", "ai", "ei", "ao", "ou", "an", "en", "ang", "eng", "ong", "er",
        "i", "ia", "ie", "iao", "iu", "ian", "in", "iang", "ing", "iong",
        "u", "ua", "uo", "uai", "ui", "uan", "un", "uang", "ue",
    ]

    /// The syllables of one run of letters, in its own spelling (tone marks and
    /// case kept), or nil when the run is no pinyin. Only the first syllable of
    /// a word may start with a vowel: inside a word, i, u and ü are written y or
    /// w, and a, o, e follow an apostrophe, which is not part of the run.
    public static func split(_ word: some StringProtocol) -> [String]? {
        let letters = Array(word)
        let plain = letters.map { character in
            String(character).lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        }
        guard !letters.isEmpty, plain.allSatisfy({ $0.count == 1 }) else { return nil }
        guard let lengths = parse(plain.joined(), from: 0) else { return nil }
        var start = 0
        return lengths.map { length in
            defer { start += length }
            return String(letters[start..<start + length])
        }
    }

    private static func parse(_ plain: String, from start: Int) -> [Int]? {
        let characters = Array(plain)
        if start == characters.count { return [] }
        let rest = String(characters[start...])
        let candidates = initials.filter { rest.hasPrefix($0) } + (start == 0 ? [""] : [])
        for initial in candidates {
            let after = start + initial.count
            for size in stride(from: min(4, characters.count - after), through: 1, by: -1) {
                guard finals.contains(String(characters[after..<after + size])),
                      let tail = parse(plain, from: after + size) else { continue }
                return [initial.count + size] + tail
            }
        }
        return nil
    }
}

/// Adds tone numbers to pinyin for an honest visual cue. Existing diacritics
/// are detected when no explicit tone list is supplied; no audio or score is
/// inferred from this formatting helper. Each syllable of a word gets its own
/// number: `Běijīng` reads `Běi³jīng¹`.
public enum MandarinToneMarkers {
    private static let toneDigits = ["⁰", "¹", "²", "³", "⁴", "⁵"]

    public static func annotated(_ pinyin: String, toneNumbers: [Int] = []) -> String {
        var index = 0
        func mark(_ syllable: String) -> String {
            defer { index += 1 }
            let detected = toneNumbers.indices.contains(index) ? toneNumbers[index] : tone(in: syllable)
            guard detected >= 0, detected <= 5, detected != 0 else { return syllable }
            return syllable + toneDigits[detected]
        }
        func marked(_ run: String) -> String {
            guard !run.isEmpty else { return "" }
            return (PinyinSyllables.split(run) ?? [run]).map(mark).joined()
        }
        return pinyin.split(whereSeparator: { $0.isWhitespace }).map { token in
            var result = ""
            var run = ""
            for character in token {
                if character.isLetter {
                    run.append(character)
                } else {
                    result += marked(run) + String(character)
                    run = ""
                }
            }
            return result + marked(run)
        }.joined(separator: " ")
    }

    static func tone(in syllable: String) -> Int {
        let firstTone = "āēīōūǖĀĒĪŌŪǕ"
        let secondTone = "áéíóúǘÁÉÍÓÚǗ"
        let thirdTone = "ǎěǐǒǔǚǍĚǏǑǓǙ"
        let fourthTone = "àèìòùǜÀÈÌÒÙǛ"
        if syllable.contains(where: { firstTone.contains($0) }) { return 1 }
        if syllable.contains(where: { secondTone.contains($0) }) { return 2 }
        if syllable.contains(where: { thirdTone.contains($0) }) { return 3 }
        if syllable.contains(where: { fourthTone.contains($0) }) { return 4 }
        return 0
    }
}
