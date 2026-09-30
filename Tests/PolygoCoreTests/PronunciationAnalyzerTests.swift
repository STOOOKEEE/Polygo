import XCTest
@testable import PolygoCore

final class PronunciationAnalyzerTests: XCTestCase {
    // MARK: Expected tones

    private func accepted(_ text: String, _ pinyin: String) -> [[Int]] {
        MandarinToneTargets.syllables(referenceText: text, referencePinyin: pinyin).map(\.acceptedTones)
    }

    func testThirdToneChainsRiseBeforeTheLastThirdTone() {
        XCTAssertEqual(accepted("你好", "nǐ hǎo"), [[2], [3]])
        // In a chain of three, the first depends on word grouping.
        XCTAssertEqual(accepted("我很好", "Wǒ hěn hǎo."), [[2, 3], [2], [3]])
        // A comma ends the phrase: 好 keeps its third tone before 我.
        XCTAssertEqual(accepted("你好，我想买", "Nǐ hǎo, wǒ xiǎng mǎi"), [[2], [3], [2, 3], [2], [3]])
        // A neutral syllable interrupts the chain.
        XCTAssertEqual(accepted("我的", "wǒ de"), [[3], []])
    }

    func testBuAndYiFollowTheNextTone() {
        XCTAssertEqual(accepted("不是", "bù shì"), [[2], [4]])
        XCTAssertEqual(accepted("不好", "bù hǎo"), [[4], [3]])
        XCTAssertEqual(accepted("一个", "yī gè"), [[2], [4]])
        XCTAssertEqual(accepted("一天", "yī tiān"), [[4], [1]])
        XCTAssertEqual(accepted("第一", "dì yī"), [[4], [1]])
        XCTAssertEqual(accepted("星期一", "xīngqīyī"), [[1], [1], [1]])
        // Pinyin already written with the spoken tone is kept.
        XCTAssertEqual(accepted("一个", "yí gè"), [[2], [4]])
        // Without one character per syllable, 不 cannot be located.
        XCTAssertEqual(accepted("不是！", "bù shì ma"), [[4], [4], []])
    }

    func testSyllablesKeepTheirAuthoredSpellingAndNotes() {
        let syllables = MandarinToneTargets.syllables(referenceText: "你叫什么名字？", referencePinyin: "Nǐ jiào shénme míngzi?")
        XCTAssertEqual(syllables.map(\.pinyin), ["Nǐ", "jiào", "shén", "me", "míng", "zi"])
        XCTAssertEqual(syllables.map(\.hanzi), ["你", "叫", "什", "么", "名", "字"])
        XCTAssertEqual(syllables.map(\.spokenTone), [3, 4, 2, nil, 2, nil])
        let hao = MandarinToneTargets.syllables(referenceText: "你好", referencePinyin: "nǐ hǎo")[0]
        XCTAssertEqual(hao.citationTone, 3)
        XCTAssertNotNil(hao.sandhiNote)
        XCTAssertEqual(MandarinToneTargets.syllables(referenceText: "一点儿", referencePinyin: "yìdiǎnr").map(\.pinyin), ["yì", "diǎnr"])
    }

    // MARK: Pitch

    func testPitchTrackerFollowsLowAndHighVoices() throws {
        for base in [110.0, 220.0] {
            let signal = SyntheticSpeech(base: base).render([(1, 0.6)])
            let median = try XCTUnwrap(PitchTracker.track(samples: signal, sampleRate: 16_000).medianFrequency)
            let expected = base * pow(2, 2.5 / 12)
            XCTAssertEqual(median, expected, accuracy: expected * 0.02, "base \(base)")
        }
    }

    func testSilenceAndNoiseHaveNoPitch() {
        let silence = [Float](repeating: 0, count: 16_000)
        XCTAssertNil(PitchTracker.track(samples: silence, sampleRate: 16_000).medianFrequency)
        var noise = SyntheticSpeech.Noise(seed: 3)
        let hiss = (0..<16_000).map { _ in noise.next() * 0.3 }
        XCTAssertLessThan(PitchTracker.track(samples: hiss, sampleRate: 16_000).frames.filter { $0.frequency != nil }.count, 10)
    }

    // MARK: Tones

    private let analyzer = PronunciationAnalyzer()

    private func exercise(_ text: String, _ pinyin: String, accepted: [String] = []) -> SpeakingExercise {
        SpeakingExercise(
            header: ExerciseHeader(id: ExerciseID(rawValue: "speak-test")!, prompt: .unchecked(["fr": "Dis la phrase."]), required: false),
            referenceText: text,
            referencePinyin: pinyin,
            acceptedTranscripts: accepted
        )
    }

    func testTheFourTonesAreHeardForLowAndHighVoices() {
        for base in [110.0, 220.0] {
            let signal = SyntheticSpeech(base: base).render([(1, 0.3), (2, 0.3), (3, 0.3), (4, 0.3)])
            let result = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("妈麻马骂", "mā má mǎ mà"), transcript: nil)
            XCTAssertNil(result.issue, "base \(base)")
            XCTAssertEqual(result.syllables.map(\.heardTone), [1, 2, 3, 4], "base \(base)")
            XCTAssertEqual(result.verdict, .pass, "base \(base)")
            XCTAssertNil(result.words)
            XCTAssertEqual(result.score, result.toneScore)
        }
    }

    func testWrongTonesNeedPracticeAndSayWhatWasHeard() throws {
        let signal = SyntheticSpeech(base: 180).render([(4, 0.3), (4, 0.3), (4, 0.3), (1, 0.3)])
        let result = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("妈麻马骂", "mā má mǎ mà"), transcript: nil)
        XCTAssertEqual(result.verdict, .needsPractice)
        XCTAssertEqual(result.syllables.map(\.isCorrect), [false, false, false, false])
        XCTAssertLessThan(try XCTUnwrap(result.toneScore), PronunciationAnalyzer.minimumToneScore)
        XCTAssertEqual(result.syllables[2].feedback, "mǎ : attendu ton 3 (bas, descend-remonte), entendu ton 4 (descend)")
    }

    func testSandhiToneIsExpectedInsteadOfTheWrittenOne() {
        let hello = exercise("你好", "nǐ hǎo")
        let risingThenLow = SyntheticSpeech(base: 200).render([(2, 0.3), (3, 0.4)])
        XCTAssertEqual(analyzer.analyze(samples: risingThenLow, sampleRate: 16_000, exercise: hello, transcript: nil).syllables.map(\.isCorrect), [true, true])

        // 不是 is said bú shì: the written fourth tone on 不 is now a mistake.
        let notBe = exercise("不是", "bù shì")
        let spoken = SyntheticSpeech(base: 120).render([(2, 0.3), (4, 0.3)])
        XCTAssertEqual(analyzer.analyze(samples: spoken, sampleRate: 16_000, exercise: notBe, transcript: nil).syllables.map(\.isCorrect), [true, true])
        let citation = SyntheticSpeech(base: 120).render([(4, 0.3), (4, 0.3)])
        let result = analyzer.analyze(samples: citation, sampleRate: 16_000, exercise: notBe, transcript: nil)
        XCTAssertEqual(result.syllables.map(\.isCorrect), [false, true])
        XCTAssertEqual(result.syllables.first?.feedback, "bù : attendu ton 2 (monte), entendu ton 4 (descend) — 不 devant un 4e ton se dit bú")
    }

    func testNeutralSyllablesAreSegmentedButNotScored() {
        let signal = SyntheticSpeech(base: 150).render([(3, 0.3), (4, 0.3), (2, 0.3), (0, 0.15)])
        let result = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("你叫什么", "Nǐ jiào shénme"), transcript: nil)
        XCTAssertEqual(result.syllables.map(\.isCorrect), [true, true, true, nil])
        XCTAssertEqual(result.syllables.last?.feedback, "me : ton neutre, non noté")
    }

    // MARK: Segmentation

    func testSyllablesJoinedWithoutPausesAreStillSeparated() {
        let signal = SyntheticSpeech(base: 120, gap: .dip).render([(1, 0.3), (2, 0.3), (3, 0.3), (4, 0.3)])
        let result = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("妈麻马骂", "mā má mǎ mà"), transcript: nil)
        XCTAssertNil(result.issue)
        XCTAssertEqual(result.syllables.map(\.heardTone), [1, 2, 3, 4])
    }

    func testRecordingsThatCannotHoldTheSentenceAreInconclusive() {
        let sentence = exercise("你喝茶吗？我妹妹不喝茶。", "Nǐ hē chá ma? Wǒ mèimei bù hē chá.")
        let oneSyllable = SyntheticSpeech(base: 200).render([(4, 0.12)])
        let short = analyzer.analyze(samples: oneSyllable, sampleRate: 16_000, exercise: sentence, transcript: nil)
        XCTAssertEqual(short.verdict, .inconclusive)
        XCTAssertNil(short.score)
        XCTAssertTrue(short.syllables.isEmpty)

        let quiet = SyntheticSpeech(base: 200, amplitude: 0.001).render([(1, 0.3), (2, 0.3)])
        XCTAssertEqual(analyzer.analyze(samples: quiet, sampleRate: 16_000, exercise: exercise("你好", "nǐ hǎo"), transcript: nil).issue, .tooQuiet)

        var noise = SyntheticSpeech.Noise(seed: 9)
        let hiss = (0..<24_000).map { _ in noise.next() * 0.2 }
        XCTAssertEqual(analyzer.analyze(samples: hiss, sampleRate: 16_000, exercise: exercise("你好", "nǐ hǎo"), transcript: nil).issue, .noVoice)
    }

    func testFarMoreSpeechThanExpectedIsInconclusive() {
        // Eight clearly separated syllables with long pauses for a two-syllable word.
        let signal = SyntheticSpeech(base: 200, gap: .pause(0.35)).render(Array(repeating: (4, 0.25), count: 8))
        let result = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("你好", "nǐ hǎo"), transcript: nil)
        XCTAssertEqual(result.verdict, .inconclusive)
        XCTAssertEqual(result.issue, .segmentation)
    }

    // MARK: Words and verdict

    func testWordCheckListsMissingAndExtraCharacters() throws {
        let check = try XCTUnwrap(PronunciationAnalyzer.checkWords(transcript: "我喝咖啡。", references: ["我喝茶。"]))
        XCTAssertEqual(check.missing, ["茶"])
        XCTAssertEqual(check.extra, ["咖啡"])
        XCTAssertEqual(check.score, 2 * 2 / 7, accuracy: 0.001)

        XCTAssertEqual(PronunciationAnalyzer.checkWords(transcript: "你好！", references: ["你好", "nǐ hǎo"])?.score, 1)
        XCTAssertEqual(PronunciationAnalyzer.checkWords(transcript: "我有1个", references: ["我有一个"])?.score, 1)
        XCTAssertNil(PronunciationAnalyzer.checkWords(transcript: " ", references: ["你好"]))
    }

    func testWrongWordsFailEvenWithGoodTones() throws {
        let signal = SyntheticSpeech(base: 200).render([(1, 0.3), (2, 0.3), (3, 0.3), (4, 0.3)])
        let right = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("妈麻马骂", "mā má mǎ mà"), transcript: "妈麻马骂")
        XCTAssertEqual(right.verdict, .pass)
        XCTAssertEqual(right.words?.score, 1)
        XCTAssertEqual(try XCTUnwrap(right.score), (try XCTUnwrap(right.toneScore) + 1) / 2, accuracy: 0.0001)

        let wrong = analyzer.analyze(samples: signal, sampleRate: 16_000, exercise: exercise("妈麻马骂", "mā má mǎ mà"), transcript: "你好")
        XCTAssertEqual(wrong.verdict, .needsPractice)
        XCTAssertEqual(wrong.words?.missing, ["妈麻马骂"])
    }
}

/// Voiced syllables built from harmonics following a tone contour, with a
/// low noise floor, so tests know exactly which tone was "said".
private struct SyntheticSpeech {
    enum Gap {
        case pause(Double)
        /// Voicing continues through a 12 dB loudness dip, as across a nasal.
        case dip
    }

    struct Noise {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> Float {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Float(Int64(bitPattern: state >> 11) % 2_000_000) / 1_000_000 - 1
        }
    }

    let base: Double
    var gap: Gap = .pause(0.08)
    var amplitude: Float = 0.3
    let rate = 16_000.0

    /// Pitch in semitones from `base` at relative time x (0…1) of a syllable.
    private func semitones(tone: Int, at x: Double) -> Double {
        switch tone {
        case 1: return 2.5
        case 2: return -1 + 4.5 * x * x
        case 3: return -2.5 - 2 * sin(Double.pi * x) + 1.5 * x
        case 4: return 4.5 - 8.5 * x
        default: return -1 - 1.5 * x
        }
    }

    func render(_ syllables: [(tone: Int, duration: Double)]) -> [Float] {
        var noise = Noise(seed: UInt64(base))
        var output = [Float](repeating: 0, count: Int(0.15 * rate))
        var phase = 0.0
        for (index, syllable) in syllables.enumerated() {
            let count = Int(syllable.duration * rate)
            for sample in 0..<count {
                let x = Double(sample) / Double(count)
                let frequency = base * pow(2, semitones(tone: syllable.tone, at: x) / 12)
                phase += 2 * Double.pi * frequency / rate
                var value = 0.0
                for harmonic in 1...8 { value += sin(Double(harmonic) * phase) / Double(harmonic) }
                var envelope = min(1, min(x, 1 - x) * syllable.duration / 0.02)
                if case .dip = gap {
                    // Loud centre, quieter edges that still carry voicing.
                    envelope = 0.25 + 0.75 * sin(Double.pi * x)
                }
                output.append(amplitude * Float(value * envelope) * 0.5)
            }
            if case .pause(let seconds) = gap, index < syllables.count - 1 {
                output += [Float](repeating: 0, count: Int(seconds * rate))
            }
        }
        output += [Float](repeating: 0, count: Int(0.15 * rate))
        return output.map { $0 + noise.next() * amplitude * 0.01 }
    }
}
