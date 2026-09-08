import XCTest
@testable import PolygoCore

final class MandarinSpeechTextTests: XCTestCase {
    func testMandarinTargetDropsFrenchInstruction() {
        XCTAssertEqual(
            MandarinSpeechText.target(from: "Dis 你好 à la personne en face de toi."),
            "你好"
        )
    }

    func testMandarinTargetKeepsDigitsInsideChinesePhrase() {
        XCTAssertEqual(MandarinSpeechText.target(from: "我20岁"), "我20岁")
        XCTAssertEqual(MandarinSpeechText.target(from: "20岁"), "20岁")
    }

    func testMandarinTargetReturnsEmptyWhenNoHanziExists() {
        XCTAssertEqual(MandarinSpeechText.target(from: "Écoute le modèle."), "")
        XCTAssertFalse(MandarinSpeechText.containsHanzi("Bonjour"))
    }

    func testMandarinTargetPreservesChinesePunctuation() {
        XCTAssertEqual(
            MandarinSpeechText.target(from: "你好！你叫什么名字？"),
            "你好！你叫什么名字？"
        )
        XCTAssertTrue(MandarinSpeechText.isTargetOnly("你好！"))
        XCTAssertFalse(MandarinSpeechText.isTargetOnly("Dis 你好！"))
    }

    func testSentenceSplitterKeepsClosingQuoteWithItsMandarinSentence() {
        XCTAssertEqual(
            MandarinSpeechText.sentences(from: "“你好！”再见。"),
            ["“你好！”", "再见。"]
        )
    }

    func testFillBlankCanonicalSpeechCompletesHanziWhileKeepingTheVisibleBlank() throws {
        let exercise = FillBlankExercise(
            header: ExerciseHeader(
                id: ExerciseID(rawValue: "fill-speech-test")!,
                prompt: .unchecked(["fr": "Complète"])
            ),
            sentence: "我___安。",
            // A pinyin-only variant is not safe as the canonical Mandarin
            // source. The first Hanzi answer is selected instead.
            acceptedAnswers: ["jiao", "叫"]
        )

        XCTAssertEqual(exercise.canonicalSpeechAnswer, "叫")
        XCTAssertEqual(exercise.canonicalSpeechSentence, "我叫安。")
        XCTAssertEqual(exercise.sentence, "我___安。")
        XCTAssertTrue(MandarinSpeechText.isTargetOnly(try XCTUnwrap(exercise.canonicalSpeechSentence)))
    }

    func testFillBlankCanonicalSpeechRejectsPinyinAndMixedLanguageAnswers() {
        let header = ExerciseHeader(
            id: ExerciseID(rawValue: "fill-speech-invalid")!,
            prompt: .unchecked(["fr": "Complète"])
        )
        XCTAssertNil(
            FillBlankExercise(
                header: header,
                sentence: "我___安。",
                acceptedAnswers: ["jiao"]
            ).canonicalSpeechSentence
        )
        XCTAssertNil(
            FillBlankExercise(
                header: header,
                sentence: "我___安。",
                acceptedAnswers: ["叫 (jiao)"]
            ).canonicalSpeechSentence
        )
        XCTAssertNil(
            FillBlankExercise(
                header: header,
                sentence: "我安。",
                acceptedAnswers: ["叫"]
            ).canonicalSpeechSentence
        )
    }
}
