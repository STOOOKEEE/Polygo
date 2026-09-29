import Foundation
import XCTest
@testable import PolygoCore

final class ExerciseKindsTests: XCTestCase {
    private let engine = DefaultExerciseEngine()

    private func header(_ rawValue: String) -> ExerciseHeader {
        ExerciseHeader(id: ExerciseID(rawValue: rawValue)!, prompt: .unchecked(["fr": "Réponds"]))
    }

    private func decode(_ json: String) throws -> ExerciseSpec {
        try JSONDecoder().decode(ExerciseSpec.self, from: Data(json.utf8))
    }

    private let headerJSON = #""header":{"id":"ex-test","prompt":{"fr":"Réponds"},"instruction":{"fr":"Réponds"},"objectiveIDs":[],"required":true}"#

    // MARK: Decoding

    func testEveryNewKindDecodesFromFlatContentJSONAndRoundTrips() throws {
        let documents = [
            #"{"kind":"matching","# + headerJSON + #","pairs":[{"id":"a","left":"茶","pinyin":"chá","right":{"fr":"thé"}},{"id":"b","left":"水","right":{"fr":"eau"}}]}"#,
            #"{"kind":"dictation","# + headerJSON + #","script":"pinyin","promptText":"茶","choices":[{"id":"a","label":{"fr":"chá"}},{"id":"b","label":{"fr":"shuǐ"}}],"correctChoiceID":"a"}"#,
            #"{"kind":"toneDiscrimination","# + headerJSON + #","promptText":"茶","choices":[{"id":"t1","label":{"fr":"Ton 1"}},{"id":"t2","label":{"fr":"Ton 2"}}],"correctChoiceID":"t2"}"#,
            #"{"kind":"translation","# + headerJSON + #","tokens":[{"id":"a","hanzi":"我","pinyin":"wǒ"},{"id":"b","hanzi":"喝","pinyin":"hē"},{"id":"c","hanzi":"吃","pinyin":"chī"}],"correctOrder":["a","b"],"acceptedOrders":[["b","a"]]}"#,
            #"{"kind":"dialogueOrder","# + headerJSON + #","lines":[{"id":"b","speaker":"Tao","hanzi":"喝。","pinyin":"hē."},{"id":"a","speaker":"Mina","hanzi":"你喝茶吗？"}],"correctOrder":["a","b"]}"#,
            #"{"kind":"conversationChoice","# + headerJSON + #","speaker":"Mina","promptText":"你喝茶吗？","replies":[{"id":"a","hanzi":"喝。","pinyin":"hē."},{"id":"b","hanzi":"再见。"}],"correctReplyID":"a"}"#,
        ]
        for document in documents {
            let spec = try decode(document)
            XCTAssertEqual(spec.id.rawValue, "ex-test")
            let encoded = try JSONEncoder().encode(spec)
            XCTAssertEqual(try JSONDecoder().decode(ExerciseSpec.self, from: encoded), spec)
        }
    }

    func testTranslationWithoutAcceptedOrdersDecodesWithNone() throws {
        let spec = try decode(#"{"kind":"translation","# + headerJSON + #","tokens":[{"id":"a","hanzi":"我"},{"id":"b","hanzi":"你"}],"correctOrder":["a"]}"#)
        guard case .translation(let exercise) = spec else { return XCTFail("Expected a translation") }
        XCTAssertEqual(exercise.acceptedOrders, [])
        XCTAssertNil(exercise.tokens[0].pinyin)
    }

    func testUnknownKindStillFailsAndLegacyAliasesStillDecode() throws {
        XCTAssertThrowsError(try decode(#"{"kind":"crossword","# + headerJSON + "}"))
        let legacy = try decode(#"{"kind":"sentenceOrder","# + headerJSON + #","tokens":[{"id":"a","hanzi":"我"}],"correctOrder":["a"]}"#)
        guard case .wordOrder = legacy else { return XCTFail("Expected the wordOrder alias") }
    }

    func testMatchingAnswerRoundTrips() throws {
        let answer = ExerciseAnswer.matching(pairs: ["a": "b", "b": "a"])
        let decoded = try JSONDecoder().decode(ExerciseAnswer.self, from: JSONEncoder().encode(answer))
        XCTAssertEqual(decoded, answer)
    }

    // MARK: Matching

    private func matching(pairCount: Int = 4) -> ExerciseSpec {
        let pairs = (0..<pairCount).map { index in
            MatchPair(id: "p\(index)", left: "字\(index)", right: .unchecked(["fr": "sens \(index)"]))
        }
        return .matching(MatchingExercise(header: header("ex-match"), pairs: pairs))
    }

    func testMatchingAcceptsOnlyEveryPairCorrect() {
        let result = engine.evaluate(spec: matching(), answer: .matching(pairs: ["p0": "p0", "p1": "p1", "p2": "p2", "p3": "p3"]))
        XCTAssertEqual(result.outcome, .correct)
        XCTAssertTrue(result.accepted)
        XCTAssertEqual(result.score, 1)
    }

    func testMatchingPartialAnswerIsRejectedWithProportionalScore() {
        let swapped = engine.evaluate(spec: matching(), answer: .matching(pairs: ["p0": "p1", "p1": "p0", "p2": "p2", "p3": "p3"]))
        XCTAssertEqual(swapped.outcome, .partial)
        XCTAssertFalse(swapped.accepted)
        XCTAssertEqual(swapped.score, 0.5, accuracy: 0.000_001)

        let incomplete = engine.evaluate(spec: matching(), answer: .matching(pairs: ["p0": "p0", "p1": "p1"]))
        XCTAssertEqual(incomplete.outcome, .partial)
        XCTAssertFalse(incomplete.accepted)
        XCTAssertEqual(incomplete.score, 0.5, accuracy: 0.000_001)
    }

    func testMatchingWithNoCorrectPairAndWrongAnswerShapeAreIncorrect() {
        let allWrong = engine.evaluate(spec: matching(pairCount: 2), answer: .matching(pairs: ["p0": "p1", "p1": "p0"]))
        XCTAssertEqual(allWrong.outcome, .incorrect)
        XCTAssertEqual(allWrong.score, 0)
        XCTAssertEqual(engine.evaluate(spec: matching(), answer: .choice(choiceID: "p0")).outcome, .incorrect)
    }

    func testMatchingRightColumnIsStableAndNeverInAuthoredOrder() {
        for count in 2...5 {
            guard case .matching(let exercise) = matching(pairCount: count) else { return XCTFail("Expected matching") }
            XCTAssertNotEqual(exercise.rightColumn.map(\.id), exercise.pairs.map(\.id), "\(count) pairs")
            XCTAssertEqual(exercise.rightColumn, exercise.rightColumn)
            XCTAssertEqual(Set(exercise.rightColumn.map(\.id)), Set(exercise.pairs.map(\.id)))
        }
    }

    // MARK: Choice-shaped kinds

    private func choices() -> [Choice] {
        [Choice(id: "a", label: .unchecked(["fr": "chá"])), Choice(id: "b", label: .unchecked(["fr": "shuǐ"]))]
    }

    func testDictationToneAndConversationAcceptOnlyTheCorrectChoice() {
        let specs: [ExerciseSpec] = [
            .dictation(DictationExercise(header: header("ex-dict"), script: .pinyin, promptText: "茶", choices: choices(), correctChoiceID: "a")),
            .toneDiscrimination(ToneDiscriminationExercise(header: header("ex-tone"), promptText: "茶", choices: choices(), correctChoiceID: "a")),
            .conversationChoice(ConversationChoiceExercise(
                header: header("ex-talk"), speaker: "Mina", promptText: "你喝茶吗？",
                replies: [ConversationReply(id: "a", hanzi: "喝。"), ConversationReply(id: "b", hanzi: "再见。")],
                correctReplyID: "a"
            )),
        ]
        for spec in specs {
            let right = engine.evaluate(spec: spec, answer: .choice(choiceID: "a"))
            XCTAssertEqual(right.outcome, .correct, "\(spec.id.rawValue)")
            XCTAssertTrue(right.accepted)
            let wrong = engine.evaluate(spec: spec, answer: .choice(choiceID: "b"))
            XCTAssertEqual(wrong.outcome, .incorrect, "\(spec.id.rawValue)")
            XCTAssertFalse(wrong.accepted)
            XCTAssertEqual(engine.evaluate(spec: spec, answer: .text("a")).outcome, .incorrect)
            XCTAssertEqual(engine.evaluate(spec: spec, answer: .skipped).outcome, .skipped)
        }
    }

    // MARK: Tile-based kinds

    private func translation(accepted: [[String]] = []) -> ExerciseSpec {
        .translation(TranslationExercise(
            header: header("ex-translate"),
            tokens: [
                WordToken(id: "a", hanzi: "我", pinyin: "wǒ"), WordToken(id: "b", hanzi: "喝", pinyin: "hē"),
                WordToken(id: "c", hanzi: "茶", pinyin: "chá"), WordToken(id: "d", hanzi: "吃", pinyin: "chī"),
            ],
            correctOrder: ["a", "b", "c"],
            acceptedOrders: accepted
        ))
    }

    func testTranslationRequiresExactTilesInOrderAndRejectsDistractors() {
        XCTAssertTrue(engine.evaluate(spec: translation(), answer: .wordOrder(tokenIDs: ["a", "b", "c"])).accepted)
        for wrong in [["a", "c", "b"], ["a", "b"], ["a", "b", "c", "d"], ["a", "b", "d"], []] {
            let result = engine.evaluate(spec: translation(), answer: .wordOrder(tokenIDs: wrong))
            XCTAssertEqual(result.outcome, .incorrect, "\(wrong)")
            XCTAssertFalse(result.accepted)
        }
        XCTAssertEqual(engine.evaluate(spec: translation(), answer: .choice(choiceID: "a")).outcome, .incorrect)
    }

    func testTranslationAcceptsAuthoredAlternativeOrders() {
        let spec = translation(accepted: [["b", "c", "a"]])
        XCTAssertTrue(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["b", "c", "a"])).accepted)
        XCTAssertTrue(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["a", "b", "c"])).accepted)
        XCTAssertFalse(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["c", "b", "a"])).accepted)
    }

    func testDialogueOrderNeedsTheWholeDialogueInOrder() {
        let spec = ExerciseSpec.dialogueOrder(DialogueOrderExercise(
            header: header("ex-dialogue"),
            lines: [
                DialogueOrderLine(id: "b", speaker: "Tao", hanzi: "喝。"),
                DialogueOrderLine(id: "c", speaker: "Mina", hanzi: "好。"),
                DialogueOrderLine(id: "a", speaker: "Mina", hanzi: "你喝茶吗？"),
            ],
            correctOrder: ["a", "b", "c"]
        ))
        XCTAssertTrue(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["a", "b", "c"])).accepted)
        XCTAssertFalse(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["b", "a", "c"])).accepted)
        XCTAssertFalse(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["a", "b"])).accepted)
    }

    func testWordOrderKeepsItsStrictBehaviour() {
        let spec = ExerciseSpec.wordOrder(WordOrderExercise(
            header: header("ex-order"),
            tokens: [WordToken(id: "a", hanzi: "我"), WordToken(id: "b", hanzi: "好")],
            correctOrder: ["a", "b"]
        ))
        XCTAssertTrue(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["a", "b"])).accepted)
        XCTAssertFalse(engine.evaluate(spec: spec, answer: .wordOrder(tokenIDs: ["b", "a"])).accepted)
    }
}
