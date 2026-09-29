import Foundation
import XCTest
@testable import PolygoCore

final class LessonSessionTests: XCTestCase {
    // MARK: Phases

    func testStageDecodesIntoAnExercisePhaseAndUnknownStagesStayOptional() throws {
        let json = """
        [
          {"kind": "exercise", "id": "block-guided", "metadata": {"stage": "guided", "skill": ["recognition"]}, "spec": \(choiceJSON("ex-guided"))},
          {"kind": "exercise", "id": "block-editorial", "metadata": {"stage": "produire"}, "spec": \(choiceJSON("ex-editorial"))},
          {"kind": "exercise", "id": "block-bare", "spec": \(choiceJSON("ex-bare"))}
        ]
        """
        let blocks = try JSONDecoder().decode([LessonBlock].self, from: Data(json.utf8))
        let roundTripped = try JSONDecoder().decode([LessonBlock].self, from: JSONEncoder().encode(blocks))
        for value in [blocks, roundTripped] {
            let phases = value.map { block -> LessonPhase? in
                guard case .exercise(let exercise) = block else { return nil }
                return exercise.phase
            }
            XCTAssertEqual(phases, [.guided, nil, nil])
        }
    }

    func testTeachingStepsJoinThePhaseOfTheExerciseTheyPrepare() {
        let flow = LessonFlow(
            blocks: [
                introduction("block-situation"),
                words("block-words", ["vocab-a"]),
                exercise("ex-d1", phase: .discover),
                exercise("ex-d2", phase: .discover),
                introduction("block-grammar", grammarPointID: "gram"),
                exercise("ex-g1", phase: .guided, grammarPointID: "gram"),
                exercise("ex-g2", phase: .guided),
                exercise("ex-r1", phase: .reuse)
            ],
            vocabulary: [entry("vocab-a")]
        )
        // situation, words, d1, d2 | grammar, g1, g2 | r1
        XCTAssertEqual(flow.phaseSegments, [
            LessonPhaseSegment(phase: .discover, steps: 0..<4),
            LessonPhaseSegment(phase: .guided, steps: 4..<7),
            LessonPhaseSegment(phase: .reuse, steps: 7..<8)
        ])
        XCTAssertEqual(flow.steps.indices.map(flow.phase(ofStep:)), [.discover, .discover, .discover, .discover, .guided, .guided, .guided, .reuse])
        XCTAssertNil(flow.phase(ofStep: flow.steps.count), "Past the last step")

        XCTAssertEqual((0..<4).map(flow.phaseStarting(afterExercise:)), [nil, .guided, nil, .reuse])
        XCTAssertNil(flow.phaseStarting(afterExercise: 4), "The last exercise opens nothing")
        XCTAssertNil(flow.phaseStarting(afterExercise: -1))

        let guided = flow.phaseSegments[1]
        XCTAssertEqual(guided.completion(atStep: 2), 0, "Not reached yet")
        XCTAssertEqual(guided.completion(atStep: 4), 0, "Standing on its first step")
        XCTAssertEqual(guided.completion(atStep: 5), 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(guided.completion(atStep: 7), 1, "Left behind")
        XCTAssertEqual(guided.completion(atStep: flow.steps.count), 1)
    }

    func testALessonWithoutPhasesIsOneUnnamedSegment() {
        let flow = LessonFlow(blocks: [introduction("block-situation"), exercise("ex-1"), exercise("ex-2")], vocabulary: [])
        XCTAssertEqual(flow.phaseSegments, [LessonPhaseSegment(phase: nil, steps: 0..<3)])
        XCTAssertNil(flow.phaseStarting(afterExercise: 0))
        XCTAssertEqual(LessonFlow(blocks: [], vocabulary: []).phaseSegments, [])
    }

    func testShippedDailyLessonsRunThroughTheThreePhasesInOrder() throws {
        var phasedLessons = 0
        for lesson in try shippedLessons() {
            let flow = LessonFlow(lesson: lesson)
            XCTAssertEqual(flow.phaseSegments.map(\.steps.count).reduce(0, +), flow.steps.count, lesson.id.rawValue)
            XCTAssertEqual(flow.phaseSegments.first?.steps.lowerBound, flow.steps.isEmpty ? nil : 0, lesson.id.rawValue)
            let phases = flow.phaseSegments.map(\.phase)
            guard !phases.contains(nil) else {
                XCTAssertEqual(phases, [nil], "\(lesson.id.rawValue) has phases on only some exercises")
                continue
            }
            phasedLessons += 1
            XCTAssertEqual(phases, [.discover, .guided, .reuse], lesson.id.rawValue)
        }
        XCTAssertGreaterThan(phasedLessons, 80)
    }

    // MARK: First-try statistics

    func testFirstTriesGiveAccuracyAndStreaksInLessonOrder() {
        let exercises = ["ex-1", "ex-2", "ex-3", "ex-4", "ex-5", "ex-6", "ex-7"].map { exerciseBlock($0) }
        let stats = LessonSessionStats(exercises: exercises, firstAttempts: [
            id("ex-1"): true,
            id("ex-2"): true,
            id("ex-3"): false,
            // ex-4 skipped: neither extends nor breaks the run.
            id("ex-5"): true,
            id("ex-6"): true,
            id("ex-7"): true,
            id("ex-elsewhere"): false
        ])
        XCTAssertEqual(stats.firstTryAnsweredCount, 6)
        XCTAssertEqual(stats.firstTryCorrectCount, 5)
        XCTAssertEqual(try XCTUnwrap(stats.accuracy), 5.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(stats.bestStreak, 3)
        XCTAssertEqual((0..<7).map(stats.streak(throughExercise:)), [1, 2, 0, 0, 1, 2, 3])
        XCTAssertEqual(stats.streak(throughExercise: 99), 3, "Terminal position keeps the last run")
        XCTAssertEqual(stats.streak(throughExercise: -1), 0)

        let untouched = LessonSessionStats(exercises: exercises, firstAttempts: [:])
        XCTAssertNil(untouched.accuracy)
        XCTAssertEqual(untouched.bestStreak, 0)
        XCTAssertEqual(LessonSessionStats(exercises: [], firstAttempts: [:]).streak(throughExercise: 0), 0)
    }

    // MARK: Tavi

    func testTaviCelebratesCorrectAnswersWithLinesPickedByStep() throws {
        let correct = try evaluation(.correct, score: 1, accepted: true)
        let lines = (0..<TaviReaction.correctLines.count).compactMap {
            TaviReaction(evaluation: correct, stepIndex: $0, streak: 1, nextPhase: nil)
        }
        XCTAssertEqual(lines.map(\.message), TaviReaction.correctLines, "Consecutive steps vary the line")
        XCTAssertTrue(lines.allSatisfy { $0.mood == .celebration && $0.phaseAnnouncement == nil })
        XCTAssertEqual(
            TaviReaction(evaluation: correct, stepIndex: 12, streak: 1, nextPhase: nil),
            TaviReaction(evaluation: correct, stepIndex: 12, streak: 1, nextPhase: nil),
            "The same step always reads the same"
        )
        let selfReported = try XCTUnwrap(TaviReaction(evaluation: try evaluation(.selfReported, score: 0.6, accepted: true), stepIndex: 0, streak: 1, nextPhase: nil))
        XCTAssertEqual(selfReported.mood, .celebration)
    }

    func testTaviEncouragesAfterAMistakeAndAsksForAMissingAnswer() throws {
        let wrong = try XCTUnwrap(TaviReaction(evaluation: try evaluation(.incorrect, score: 0, accepted: false), stepIndex: 5, streak: 0, nextPhase: nil))
        XCTAssertEqual(wrong.mood, .encouragement)
        XCTAssertEqual(wrong.message, TaviReaction.retryLines[5 % TaviReaction.retryLines.count])

        let partial = try XCTUnwrap(TaviReaction(evaluation: try evaluation(.partial, score: 0.5, accepted: true), stepIndex: 0, streak: 0, nextPhase: nil))
        XCTAssertEqual(partial.mood, .encouragement, "Below the 80 % bar is not a success")

        let missing = try XCTUnwrap(TaviReaction(evaluation: try evaluation(.unavailable, score: 0, accepted: false), stepIndex: 5, streak: 0, nextPhase: nil))
        XCTAssertEqual(missing.mood, .encouragement)
        XCTAssertEqual(missing.message, TaviReaction.incompleteLine)

        XCTAssertNil(TaviReaction(evaluation: try evaluation(.skipped, score: 0, accepted: false), stepIndex: 5, streak: 0, nextPhase: .reuse))
    }

    func testTaviMarksStreakMilestonesAndAnnouncesTheNextPhase() throws {
        let correct = try evaluation(.correct, score: 1, accepted: true)
        XCTAssertEqual(TaviReaction(evaluation: correct, stepIndex: 0, streak: 3, nextPhase: nil)?.message, "3 bonnes réponses d’affilée, quelle série !")
        XCTAssertEqual(TaviReaction(evaluation: correct, stepIndex: 0, streak: 4, nextPhase: nil)?.message, TaviReaction.correctLines[0])

        let closing = try XCTUnwrap(TaviReaction(evaluation: correct, stepIndex: 9, streak: 1, nextPhase: .guided))
        XCTAssertEqual(closing.phaseAnnouncement, "Pratique guidée : on assemble des phrases !")
        let closingAfterMistake = try XCTUnwrap(TaviReaction(evaluation: try evaluation(.incorrect, score: 0, accepted: false), stepIndex: 9, streak: 0, nextPhase: .reuse))
        XCTAssertEqual(closingAfterMistake.phaseAnnouncement, LessonPhase.reuse.announcement)
    }

    func testTaviLinesNeverRepeatTheVerdictWords() throws {
        let correct = try evaluation(.correct, score: 1, accepted: true)
        let milestoneLines = TaviReaction.streakMilestones.compactMap {
            TaviReaction(evaluation: correct, stepIndex: 0, streak: $0, nextPhase: nil)?.message
        }
        let lines = TaviReaction.correctLines + TaviReaction.retryLines + [TaviReaction.incompleteLine]
            + LessonPhase.allCases.map(\.announcement) + milestoneLines
        for line in lines {
            for verdict in ["correct", "à revoir", "passé sans évaluation"] {
                XCTAssertNil(line.range(of: verdict, options: [.caseInsensitive, .diacriticInsensitive]), line)
            }
        }
    }

    // MARK: Words recap

    func testDailyLessonListsItsNewWordsAndReviewLessonsTheirRecap() throws {
        let lesson = try shippedLesson("lesson-11")
        let learned = try XCTUnwrap(LessonWordsRecap(lesson: lesson))
        XCTAssertEqual(learned.kind, .learned)
        XCTAssertEqual(learned.words.map(\.id), lesson.metadata?.newVocabularyIDs)
        XCTAssertEqual(learned.words.prefix(3).map(\.hanzi), ["很", "我们", "这"])

        let review = try shippedLesson("review-01")
        XCTAssertEqual(review.metadata?.newVocabularyIDs, [])
        let reviewed = try XCTUnwrap(LessonWordsRecap(lesson: review))
        XCTAssertEqual(reviewed.kind, .reviewed)
        let recapIDs = review.blocks.flatMap { block -> [VocabularyID] in
            guard case .recap(let recap) = block else { return [] }
            return recap.vocabularyIDs
        }
        XCTAssertEqual(reviewed.words.map(\.id), recapIDs)
    }

    func testWordsRecapSkipsUnknownAndRepeatedWords() {
        let lesson = LessonDocument(
            contentVersion: "test", id: LessonID(rawValue: "lesson-words")!, moduleID: ModuleID(rawValue: "module-test")!, order: 1,
            title: .unchecked(["fr": "Mots"]), summary: .unchecked(["fr": "Mots"]), estimatedMinutes: 5, objectives: [],
            vocabulary: [entry("vocab-a"), entry("vocab-b")],
            blocks: [.recap(RecapBlock(id: BlockID(rawValue: "block-recap")!, vocabularyIDs: ["vocab-b", "vocab-a"].map { VocabularyID(rawValue: $0)! }))],
            cards: [],
            metadata: LessonMetadata(newVocabularyIDs: ["vocab-b", "vocab-missing", "vocab-b"].map { VocabularyID(rawValue: $0)! })
        )
        XCTAssertEqual(LessonWordsRecap(lesson: lesson)?.words.map(\.id.rawValue), ["vocab-b"])

        let withoutMetadata = LessonDocument(
            contentVersion: "test", id: lesson.id, moduleID: lesson.moduleID, order: 1, title: lesson.title, summary: lesson.summary,
            estimatedMinutes: 5, objectives: [], vocabulary: lesson.vocabulary, blocks: lesson.blocks, cards: []
        )
        XCTAssertEqual(LessonWordsRecap(lesson: withoutMetadata)?.kind, .reviewed)
        XCTAssertEqual(LessonWordsRecap(lesson: withoutMetadata)?.words.map(\.id.rawValue), ["vocab-b", "vocab-a"])

        let empty = LessonDocument(
            contentVersion: "test", id: lesson.id, moduleID: lesson.moduleID, order: 1, title: lesson.title, summary: lesson.summary,
            estimatedMinutes: 5, objectives: [], vocabulary: [], blocks: [], cards: []
        )
        XCTAssertNil(LessonWordsRecap(lesson: empty))
    }

    // MARK: Helpers

    private func id(_ rawValue: String) -> ExerciseID { ExerciseID(rawValue: rawValue)! }

    private func evaluation(_ outcome: EvaluationOutcome, score: Double, accepted: Bool) throws -> ExerciseEvaluation {
        try ExerciseEvaluation(exerciseID: id("ex-tavi"), outcome: outcome, score: score, feedback: .unchecked(["fr": "Retour"]), accepted: accepted)
    }

    private func choiceJSON(_ id: String) -> String {
        """
        {"kind": "choice", "header": {"id": "\(id)", "prompt": {"fr": "?"}, "instruction": {"fr": "?"}, "objectiveIDs": [], "required": true},
         "choices": [{"id": "a", "label": {"fr": "a"}}], "correctChoiceID": "a"}
        """
    }

    private func exerciseBlock(_ id: String, phase: LessonPhase? = nil, grammarPointID: String? = nil) -> ExerciseBlock {
        ExerciseBlock(
            id: BlockID(rawValue: "block-\(id)")!,
            spec: .choice(ChoiceExercise(header: ExerciseHeader(id: self.id(id), prompt: .unchecked(["fr": "Question"])), choices: [], correctChoiceID: "a")),
            grammarPointID: grammarPointID,
            phase: phase
        )
    }

    private func exercise(_ id: String, phase: LessonPhase? = nil, grammarPointID: String? = nil) -> LessonBlock {
        .exercise(exerciseBlock(id, phase: phase, grammarPointID: grammarPointID))
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

    private func entry(_ id: String) -> VocabularyEntry {
        VocabularyEntry(id: VocabularyID(rawValue: id)!, hanzi: "字", pinyin: "zì", toneNumbers: [4], meaning: .unchecked(["fr": "caractère"]))
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
}
