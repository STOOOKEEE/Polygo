import Foundation
import XCTest
@testable import PolygoCore

final class LessonFlowTests: XCTestCase {
    // MARK: Synthetic lessons

    func testTeachingBlocksPrecedeTheirFirstConsumerAndKeepAuthoredOrderOtherwise() {
        let flow = LessonFlow(
            blocks: [
                introduction("block-situation"),
                introduction("block-grammar", grammarPointID: "gram-le"),
                words("block-words", ["vocab-a", "vocab-b"]),
                dialogue("block-dialogue", lines: ["你好！", "你饿吗？"]),
                reading("block-reading", comprehension: ["ex-read"]),
                exercise("ex-discover"),
                exercise("ex-dialogue", listening: "你饿吗？"),
                exercise("ex-grammar", grammarPointID: "gram-le"),
                exercise("ex-read"),
                exercise("ex-grammar-2", grammarPointID: "gram-le"),
                recap("block-recap")
            ],
            vocabulary: [entry("vocab-a"), entry("vocab-b")]
        )

        XCTAssertEqual(stepIDs(flow), [
            "teaching.block-situation",
            "teaching.block-words",
            "exercise.ex-discover",
            "teaching.block-dialogue",
            "exercise.ex-dialogue",
            "teaching.block-grammar",
            "exercise.ex-grammar",
            "teaching.block-reading",
            "exercise.ex-read",
            "exercise.ex-grammar-2"
        ])
        XCTAssertEqual(flow.closingBlocks.map(\.id.rawValue), ["block-recap"])
        XCTAssertEqual(teachingKinds(flow), [.situation, .words, .dialogue, .grammar, .reading])
    }

    func testDialogueIsRecognisedFromTheLinesAnExerciseQuotes() {
        let lines = ["你好！", "你饿吗？", "我不饿。"]
        let quotingSpecs: [ExerciseSpec] = [
            .conversationChoice(ConversationChoiceExercise(
                header: header("ex"), promptText: "你饿吗", replies: [], correctReplyID: "a"
            )),
            .dialogueOrder(DialogueOrderExercise(
                header: header("ex"), lines: [DialogueOrderLine(id: "a", hanzi: "我不饿。")], correctOrder: ["a"]
            )),
            .fillBlank(FillBlankExercise(header: header("ex"), sentence: "我不___。", acceptedAnswers: ["饿"])),
            .speaking(SpeakingExercise(
                header: header("ex"), referenceText: "你好", referencePinyin: "nǐ hǎo", acceptedTranscripts: ["你好"]
            ))
        ]
        for spec in quotingSpecs {
            let flow = LessonFlow(
                blocks: [
                    dialogue("block-dialogue", lines: lines),
                    exercise("ex-first"),
                    .exercise(ExerciseBlock(id: BlockID(rawValue: "block-quoting")!, spec: spec))
                ],
                vocabulary: []
            )
            XCTAssertEqual(stepIDs(flow), ["exercise.ex-first", "teaching.block-dialogue", "exercise.ex"], "\(spec)")
        }

        let unrelated = LessonFlow(
            blocks: [dialogue("block-dialogue", lines: lines), exercise("ex-first"), exercise("ex-other", listening: "再见")],
            vocabulary: []
        )
        XCTAssertEqual(stepIDs(unrelated), ["teaching.block-dialogue", "exercise.ex-first", "exercise.ex-other"])
    }

    func testWordCardsDropUnknownAndRepeatedWordsAndSplitIntoSmallGroups() throws {
        let known = (1...5).map { entry("vocab-\($0)") }
        let flow = LessonFlow(
            blocks: [
                words("block-words", ["vocab-1", "vocab-2", "vocab-missing", "vocab-3", "vocab-2", "vocab-4", "vocab-5"]),
                words("block-empty", ["vocab-missing"]),
                exercise("ex-1")
            ],
            vocabulary: known
        )
        XCTAssertEqual(stepIDs(flow), ["teaching.block-words.1", "teaching.block-words.2", "exercise.ex-1"])
        let cards = flow.steps.compactMap { step -> [String]? in
            guard case .teaching(let teaching) = step, case .vocabulary(let block) = teaching.block else { return nil }
            return block.vocabularyIDs.map(\.rawValue)
        }
        XCTAssertEqual(cards, [["vocab-1", "vocab-2", "vocab-3"], ["vocab-4", "vocab-5"]])
    }

    func testTeachingWithoutAFollowingExerciseClosesTheLesson() {
        let flow = LessonFlow(
            blocks: [exercise("ex-1"), introduction("block-outro"), recap("block-recap"), reading("block-reading", comprehension: [])],
            vocabulary: []
        )
        XCTAssertEqual(stepIDs(flow), ["exercise.ex-1"])
        XCTAssertEqual(flow.closingBlocks.map(\.id.rawValue), ["block-outro", "block-recap", "block-reading"])
    }

    func testResumeMapsSavedExercisesOntoSteps() {
        let flow = LessonFlow(
            blocks: [
                introduction("block-situation"),
                words("block-words", ["vocab-a"]),
                introduction("block-grammar", grammarPointID: "gram"),
                exercise("ex-0"),
                exercise("ex-1"),
                dialogue("block-dialogue", lines: ["好。"]),
                reading("block-reading", comprehension: ["ex-2"]),
                exercise("ex-2", listening: "好"),
                exercise("ex-3", grammarPointID: "gram")
            ],
            vocabulary: [entry("vocab-a")]
        )
        XCTAssertEqual(stepIDs(flow), [
            "teaching.block-situation", "teaching.block-words", "exercise.ex-0", "exercise.ex-1",
            "teaching.block-dialogue", "teaching.block-reading", "exercise.ex-2",
            "teaching.block-grammar", "exercise.ex-3"
        ])

        // A fresh or untouched position reopens the teaching that prepares it.
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 0, hasPendingWork: false), 0)
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 2, hasPendingWork: false), 4)
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 3, hasPendingWork: false), 7)
        // Without teaching in front, the exercise itself.
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 1, hasPendingWork: false), 3)
        // A composed answer or visible feedback reopens the exercise.
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 0, hasPendingWork: true), 2)
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 2, hasPendingWork: true), 6)
        // Terminal and out-of-range positions.
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 4, hasPendingWork: false), flow.steps.count)
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 99, hasPendingWork: true), flow.steps.count)

        // A teaching step is saved as the exercise it prepares, so saving and
        // resuming from any step never skips content.
        XCTAssertEqual((0..<flow.steps.count).map(flow.exerciseIndex(forStep:)), [0, 0, 0, 1, 2, 2, 2, 3, 3])
        XCTAssertEqual(flow.exerciseIndex(forStep: flow.steps.count), 4)
        for step in flow.steps.indices {
            let resumed = flow.resumeStepIndex(exerciseIndex: flow.exerciseIndex(forStep: step), hasPendingWork: false)
            XCTAssertLessThanOrEqual(resumed, step)
        }
    }

    func testGrammarLinksDecodeFromBlockMetadataAndRoundTrip() throws {
        let json = """
        [
          {"kind": "introduction", "id": "block-note", "title": {"fr": "Grammaire"}, "body": {"fr": "Phrase + 吗 ?"},
           "metadata": {"grammarPointID": "gram-ma", "stage": "introduce", "skill": ["recognition"]}},
          {"kind": "introduction", "id": "block-situation", "title": {"fr": "Situation"}, "body": {"fr": "Au café"},
           "metadata": {"stage": "observe"}},
          {"kind": "exercise", "id": "block-ex", "metadata": {"grammarPointID": "gram-ma", "stage": "guided"},
           "spec": {"kind": "choice", "header": {"id": "ex-ma", "prompt": {"fr": "?"}, "instruction": {"fr": "?"},
                    "objectiveIDs": [], "required": true},
                    "choices": [{"id": "a", "label": {"fr": "吗"}}], "correctChoiceID": "a"}}
        ]
        """
        let blocks = try JSONDecoder().decode([LessonBlock].self, from: Data(json.utf8))
        let decoded = try JSONDecoder().decode([LessonBlock].self, from: JSONEncoder().encode(blocks))
        for value in [blocks, decoded] {
            guard case .introduction(let note) = value[0], case .introduction(let situation) = value[1],
                  case .exercise(let exercise) = value[2] else { return XCTFail("Unexpected blocks \(value)") }
            XCTAssertEqual(note.grammarPointID, "gram-ma")
            XCTAssertNil(situation.grammarPointID)
            XCTAssertEqual(exercise.grammarPointID, "gram-ma")
        }
    }

    // MARK: Shipped content

    func testEveryShippedLessonKeepsItsExercisesAndTeachesJustInTime() throws {
        let lessons = try shippedLessons()
        XCTAssertGreaterThan(lessons.count, 80)
        for lesson in lessons {
            let flow = LessonFlow(lesson: lesson)
            let authoredExercises = lesson.blocks.compactMap { block -> String? in
                guard case .exercise(let exercise) = block else { return nil }
                return exercise.spec.id.rawValue
            }
            XCTAssertEqual(flow.exercises.map(\.spec.id.rawValue), authoredExercises, lesson.id.rawValue)
            XCTAssertEqual(stepIDs(flow).filter { $0.hasPrefix("exercise.") }, authoredExercises.map { "exercise.\($0)" }, lesson.id.rawValue)

            for (position, step) in flow.steps.enumerated() {
                guard case .teaching(let teaching) = step else { continue }
                let nextExercise = flow.exercises[flow.exerciseIndex(forStep: position)]
                switch teaching.block {
                case .introduction(let note) where note.grammarPointID != nil:
                    XCTAssertEqual(nextExercise.grammarPointID, note.grammarPointID, "\(lesson.id.rawValue): \(teaching.id) must precede its first exercise")
                    let earlier = flow.exercises.prefix(flow.exerciseIndex(forStep: position))
                    XCTAssertFalse(earlier.contains { $0.grammarPointID == note.grammarPointID }, "\(lesson.id.rawValue): \(teaching.id) comes too late")
                case .reading(let reading) where !reading.comprehensionExerciseIDs.isEmpty:
                    XCTAssertTrue(reading.comprehensionExerciseIDs.contains(nextExercise.spec.id), "\(lesson.id.rawValue): \(teaching.id)")
                default:
                    break
                }
            }
            XCTAssertTrue(flow.closingBlocks.allSatisfy { if case .recap = $0 { return true } else { return false } }, lesson.id.rawValue)
        }
    }

    func testLessonFivePlacesWordsDialogueGrammarAndReadingBeforeTheirExercises() throws {
        let flow = LessonFlow(lesson: try shippedLesson("lesson-05"))
        let ids = stepIDs(flow)
        XCTAssertEqual(Array(ids.prefix(4)), [
            "teaching.block-lesson-05-vocabulary.1", "teaching.block-lesson-05-vocabulary.2",
            "teaching.block-lesson-05-vocabulary.3", "exercise.ex-l5-meaning"
        ])
        XCTAssertEqual(next(after: "teaching.block-l5-dialogue", in: ids), "exercise.ex-l5-dict-sent-dia-1")
        XCTAssertEqual(next(after: "teaching.block-lesson-05-grammar-01", in: ids), "exercise.ex-l5-gram-1")
        XCTAssertEqual(next(after: "teaching.block-l5-reading", in: ids), "exercise.ex-l5-reading")
        XCTAssertEqual(flow.closingBlocks.map(\.id.rawValue), ["block-l5-recap"])
    }

    func testPinyinLessonWithoutDialogueTeachesEverythingUpFront() throws {
        let flow = LessonFlow(lesson: try shippedLesson("pinyin-01"))
        let kinds = teachingKinds(flow)
        XCTAssertFalse(kinds.contains(.dialogue))
        XCTAssertEqual(kinds.first, .situation)
        XCTAssertEqual(flow.stepIndex(ofExercise: 0), kinds.count, "All pinyin teaching comes before the first exercise")
        XCTAssertEqual(flow.resumeStepIndex(exerciseIndex: 0, hasPendingWork: false), 0)
    }

    func testReviewAndBossLessonsOpenOnTheirIntroductionAndShowTheDialogueBeforeQuotingIt() throws {
        for (name, firstQuoting) in [("review-01", "ex-review-01-dict-sent-dia-15"), ("boss-unit-02", "ex-boss-unit-02-dict-sent-dia-14")] {
            let flow = LessonFlow(lesson: try shippedLesson(name))
            let ids = stepIDs(flow)
            XCTAssertEqual(ids.first, "teaching.block-\(name)-intro", name)
            XCTAssertEqual(next(after: "teaching.block-\(name)-dialogue", in: ids), "exercise.\(firstQuoting)", name)
        }
    }

    func testStarterLessonsKeepTheirFirstExerciseAfterSituationAndWords() throws {
        for (number, firstExercise) in [(1, "ex-l1-tone"), (2, "ex-l2-tone"), (3, "ex-l3-tone"), (4, "ex-l4-script")] {
            let flow = LessonFlow(lesson: try shippedLesson("lesson-0\(number)"))
            let firstExerciseStep = try XCTUnwrap(flow.stepIndex(ofExercise: 0))
            XCTAssertEqual(stepIDs(flow)[firstExerciseStep], "exercise.\(firstExercise)")
            XCTAssertEqual(teachingKinds(flow).prefix(firstExerciseStep).first, .situation, "lesson-0\(number)")
            XCTAssertTrue(teachingKinds(flow).prefix(firstExerciseStep).dropFirst().allSatisfy { $0 == .words }, "lesson-0\(number)")
            let dialogueStep = try XCTUnwrap(stepIDs(flow).firstIndex(of: "teaching.block-l\(number)-dialogue"))
            XCTAssertGreaterThan(dialogueStep, firstExerciseStep, "lesson-0\(number) shows its dialogue when an exercise uses it")
        }
    }

    // MARK: Helpers

    private func stepIDs(_ flow: LessonFlow) -> [String] { flow.steps.map(\.id) }

    private func teachingKinds(_ flow: LessonFlow) -> [LessonTeachingStep.Kind] {
        flow.steps.compactMap { step in
            guard case .teaching(let teaching) = step else { return nil }
            return teaching.kind
        }
    }

    private func next(after id: String, in ids: [String]) -> String? {
        guard let index = ids.firstIndex(of: id), index + 1 < ids.count else { return nil }
        return ids[index + 1]
    }

    private var lessonsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Content/lessons", isDirectory: true)
    }

    private func shippedLesson(_ name: String) throws -> LessonDocument {
        let data = try Data(contentsOf: lessonsDirectory.appendingPathComponent("\(name).json"))
        return try JSONDecoder().decode(LessonDocument.self, from: data)
    }

    private func shippedLessons() throws -> [LessonDocument] {
        try FileManager.default.contentsOfDirectory(atPath: lessonsDirectory.path)
            .filter { $0.hasSuffix(".json") }
            .sorted()
            .map { try shippedLesson(String($0.dropLast(".json".count))) }
    }

    private func header(_ id: String) -> ExerciseHeader {
        ExerciseHeader(id: ExerciseID(rawValue: id)!, prompt: .unchecked(["fr": "Question"]))
    }

    private func exercise(_ id: String, grammarPointID: String? = nil, listening promptText: String? = nil) -> LessonBlock {
        let spec: ExerciseSpec = promptText.map {
            .listeningChoice(ListeningChoiceExercise(header: header(id), promptText: $0, choices: [], correctChoiceID: "a"))
        } ?? .choice(ChoiceExercise(header: header(id), choices: [], correctChoiceID: "a"))
        return .exercise(ExerciseBlock(id: BlockID(rawValue: "block-\(id)")!, spec: spec, grammarPointID: grammarPointID))
    }

    private func introduction(_ id: String, grammarPointID: String? = nil) -> LessonBlock {
        .introduction(IntroductionBlock(
            id: BlockID(rawValue: id)!, title: .unchecked(["fr": "Titre"]), body: .unchecked(["fr": "Texte"]),
            grammarPointID: grammarPointID
        ))
    }

    private func words(_ id: String, _ vocabularyIDs: [String]) -> LessonBlock {
        .vocabulary(VocabularyBlock(id: BlockID(rawValue: id)!, vocabularyIDs: vocabularyIDs.map { VocabularyID(rawValue: $0)! }))
    }

    private func dialogue(_ id: String, lines: [String]) -> LessonBlock {
        .dialogue(DialogueBlock(
            id: BlockID(rawValue: id)!,
            lines: lines.map { DialogueLine(speaker: "Mina", hanzi: $0, pinyin: "pinyin", translation: .unchecked(["fr": "traduction"])) }
        ))
    }

    private func reading(_ id: String, comprehension: [String]) -> LessonBlock {
        .reading(ReadingBlock(
            id: BlockID(rawValue: id)!, storyID: StoryID(rawValue: "story-\(id)")!, title: .unchecked(["fr": "Lecture"]),
            paragraphs: [], comprehensionExerciseIDs: comprehension.map { ExerciseID(rawValue: $0)! }
        ))
    }

    private func recap(_ id: String) -> LessonBlock {
        .recap(RecapBlock(id: BlockID(rawValue: id)!))
    }

    private func entry(_ id: String) -> VocabularyEntry {
        VocabularyEntry(id: VocabularyID(rawValue: id)!, hanzi: "字", pinyin: "zì", toneNumbers: [4], meaning: .unchecked(["fr": "caractère"]))
    }
}
