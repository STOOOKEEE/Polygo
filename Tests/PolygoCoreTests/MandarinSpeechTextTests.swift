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

    func testClauseSplitterPausesAtCommasAndKeepsPunctuation() {
        XCTAssertEqual(
            MandarinSpeechText.clauses(from: "你好，我叫安、林；他说：再见。"),
            ["你好，", "我叫安、", "林；", "他说：", "再见。"]
        )
        XCTAssertEqual(
            MandarinSpeechText.clauses(from: "“你好，”他说。"),
            ["“你好，”", "他说。"]
        )
        XCTAssertEqual(MandarinSpeechText.clauses(from: "我有1,000块。"), ["我有1,000块。"])
    }

    func testDialogueSegmentsPauseLongerForSentencesAndSpeakerChanges() {
        let segments = MandarinSpeechText.dialogueSegments(from: [
            line("A", "你好，我叫安。你呢？"),
            line("B", "我叫林。"),
            line("B", "Bonjour ，，"),
            line("A", "再见！")
        ])

        XCTAssertEqual(segments.map(\.text), ["你好，", "我叫安。", "你呢？", "我叫林。", "再见！"])
        XCTAssertEqual(segments.map(\.postUtteranceDelay), [0.35, 0.6, 1.0, 1.0, 0])
    }

    func testSingleDialogueLineKeepsItsInternalPausesOnly() {
        let segments = MandarinSpeechText.dialogueSegments(from: [line("A", "我叫安，你呢？")])

        XCTAssertEqual(segments.map(\.text), ["我叫安，", "你呢？"])
        XCTAssertEqual(segments.map(\.postUtteranceDelay), [0.35, 0])
    }

    func testDialogueSegmentsSkipLinesWithoutMandarin() {
        XCTAssertEqual(MandarinSpeechText.dialogueSegments(from: [line("A", "…，")]), [])
    }

    func testDialogueLineWithAClipIsOneSegmentWhileOthersAreSplitIntoClauses() throws {
        let clip = try asset("audio-line")
        let segments = MandarinSpeechText.dialogueSegments(from: [
            line("Tao", "你好！你饿吗？", audio: clip),
            line("Mina", "我不饿，你呢？"),
            line("Mina", "Bonjour", audio: clip)
        ])

        XCTAssertEqual(segments.map(\.text), ["你好！你饿吗？", "我不饿，", "你呢？"])
        XCTAssertEqual(segments.map(\.audio), [clip, nil, nil])
        XCTAssertEqual(segments.map(\.postUtteranceDelay), [1.0, 0.35, 0])
    }

    func testReadingParagraphClipsKeepTheLongPauseBetweenParagraphs() throws {
        let first = try asset("audio-p1")
        let reading = ReadingBlock(
            id: try XCTUnwrap(BlockID(rawValue: "reading")),
            storyID: try XCTUnwrap(StoryID(rawValue: "story")),
            level: "HSK 1",
            title: .unchecked(["fr": "Lecture"]),
            paragraphs: [
                ReadingParagraph(id: "p1", hanzi: "我是学生。我学中文。", pinyin: "", translation: .unchecked(["fr": "P1"]), audio: first),
                ReadingParagraph(id: "p2", hanzi: "他是老师。", pinyin: "", translation: .unchecked(["fr": "P2"]))
            ]
        )

        let segments = MandarinSpeechText.readingSegments(from: reading)

        XCTAssertEqual(segments.map(\.text), ["我是学生。我学中文。", "他是老师。"])
        XCTAssertEqual(segments.map(\.audio), [first, nil])
        XCTAssertEqual(segments.map(\.postUtteranceDelay), [1.0, 0])
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

    private func line(_ speaker: String, _ hanzi: String, audio: AssetReference? = nil) -> DialogueLine {
        DialogueLine(speaker: speaker, hanzi: hanzi, pinyin: "", translation: .unchecked(["fr": "Réplique"]), audio: audio)
    }

    private func asset(_ id: String) throws -> AssetReference {
        AssetReference(
            id: try XCTUnwrap(AssetID(rawValue: id)),
            kind: .audio,
            relativePath: "assets/audio/\(id).m4a",
            sha256: String(repeating: "0", count: 64)
        )
    }
}
