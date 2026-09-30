import Foundation

/// One syllable the learner is expected to say, with the tone a native
/// speaker actually produces in this context.
public struct ExpectedSyllable: Codable, Hashable, Sendable {
    /// The syllable as authored, with its tone mark (`hǎo`).
    public let pinyin: String
    /// The character it belongs to, when the reference text lines up with
    /// the pinyin one character per syllable.
    public let hanzi: String?
    /// The dictionary tone written in the pinyin, 0 for a neutral syllable.
    public let citationTone: Int
    /// The tone expected in speech after sandhi, nil when it is not scored
    /// (neutral tone, or a context whose realisation varies).
    public let spokenTone: Int?
    /// Every tone accepted as correct; `spokenTone` is its first element.
    public let acceptedTones: [Int]
    /// Why the spoken tone differs from the written one, in French.
    public let sandhiNote: String?

    public init(pinyin: String, hanzi: String?, citationTone: Int, spokenTone: Int?, acceptedTones: [Int], sandhiNote: String?) {
        self.pinyin = pinyin
        self.hanzi = hanzi
        self.citationTone = citationTone
        self.spokenTone = spokenTone
        self.acceptedTones = acceptedTones
        self.sandhiNote = sandhiNote
    }
}

/// Expected syllables and spoken tones of a speaking reference: the authored
/// pinyin gives the dictionary tones; the rules of connected Mandarin then
/// give what a native speaker says (3-3 → 2-3, 不 and 一 before a tone).
public enum MandarinToneTargets {
    /// The expected syllables of `referencePinyin`, aligned with the Hanzi of
    /// `referenceText` when both count the same syllables. Punctuation in the
    /// pinyin separates phrases: a third-tone chain does not cross it.
    public static func syllables(referenceText: String, referencePinyin: String) -> [ExpectedSyllable] {
        let written = writtenSyllables(referencePinyin)
        let characters = referenceText.unicodeScalars
            .filter(MandarinSpeechText.isHanzi)
            .map { String($0) }
        let hanzi: [String?]
        if characters.count == written.count {
            hanzi = characters
        } else {
            hanzi = Array(repeating: nil, count: written.count)
        }

        var tones = written.map { MandarinToneMarkers.tone(in: $0.text) }
        var accepted: [[Int]?] = tones.map { $0 == 0 ? nil : [$0] }
        var notes: [String?] = Array(repeating: nil, count: written.count)

        func next(_ index: Int) -> Int? {
            let following = index + 1
            guard following < written.count, written[following].phrase == written[index].phrase else { return nil }
            return following
        }

        for index in written.indices {
            if hanzi[index] == "不", tones[index] == 4, let following = next(index), tones[following] == 4 {
                tones[index] = 2
                accepted[index] = [2]
                notes[index] = "不 devant un 4e ton se dit bú"
            } else if hanzi[index] == "一", tones[index] == 1 {
                let previous = index > 0 ? hanzi[index - 1] : nil
                guard previous != "第", previous != "十", let following = next(index) else { continue }
                switch tones[following] {
                case 4:
                    tones[index] = 2
                    accepted[index] = [2]
                    notes[index] = "一 devant un 4e ton se dit yí"
                case 1, 2, 3:
                    tones[index] = 4
                    accepted[index] = [4]
                    notes[index] = "一 devant un 1er, 2e ou 3e ton se dit yì"
                default:
                    accepted[index] = nil
                }
            }
        }

        var index = 0
        while index < written.count {
            guard tones[index] == 3 else {
                index += 1
                continue
            }
            var end = index
            while let following = next(end), tones[following] == 3 {
                end = following
            }
            // In a chain, the last third tone stays; the one before it rises;
            // earlier ones depend on the word grouping, so both are accepted.
            if end > index {
                for position in index..<end {
                    accepted[position] = position == end - 1 ? [2] : [2, 3]
                    notes[position] = "3e ton devant un autre 3e ton : il monte comme un 2e ton"
                }
            }
            index = end + 1
        }

        return written.indices.map { position in
            ExpectedSyllable(
                pinyin: written[position].text,
                hanzi: hanzi[position],
                citationTone: MandarinToneMarkers.tone(in: written[position].text),
                spokenTone: accepted[position]?.first,
                acceptedTones: accepted[position] ?? [],
                sandhiNote: notes[position]
            )
        }
    }

    /// Syllables of the pinyin in order, each with the index of its phrase.
    private static func writtenSyllables(_ pinyin: String) -> [(text: String, phrase: Int)] {
        var result: [(text: String, phrase: Int)] = []
        var phrase = 0
        var run = ""

        func flush() {
            defer { run = "" }
            guard !run.isEmpty else { return }
            if let parts = PinyinSyllables.split(run) {
                result += parts.map { ($0, phrase) }
            } else if run.count > 1, run.lowercased().hasSuffix("r"),
                      let parts = PinyinSyllables.split(run.dropLast()) {
                // Erhua (`diǎnr`): the r joins the last syllable.
                result += parts.enumerated().map { offset, part in
                    (offset == parts.count - 1 ? part + "r" : part, phrase)
                }
            }
        }

        for character in pinyin {
            if character.isLetter {
                run.append(character)
            } else {
                flush()
                if !character.isWhitespace, character != "'", character != "’", character != "-" {
                    phrase += 1
                }
            }
        }
        flush()
        return result
    }
}
