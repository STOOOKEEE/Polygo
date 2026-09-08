import Foundation
import XCTest
@testable import PolygoCore

final class ContentContractTests: XCTestCase {
    private let expectedLessonIDs: [LessonID] = [
        LessonID(rawValue: "lesson-01")!,
        LessonID(rawValue: "lesson-02")!,
        LessonID(rawValue: "lesson-03")!,
        LessonID(rawValue: "lesson-04")!
    ]

    private let expectedExerciseCounts = [6, 7, 7, 7]
    private let expectedNewVocabularyCounts = [5, 5, 6, 1]
    private let expectedCycle = ["observer", "recuperer", "produire", "transferer"]
    private let expectedContentVersion = "2026.09.0"

    private var contentRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Content", isDirectory: true)
    }

    private func store() -> JSONContentStore {
        JSONContentStore(rootURL: contentRoot)
    }

    private func rawJSON(relativePath: String) throws -> [String: Any] {
        let url = contentRoot.appendingPathComponent(relativePath, isDirectory: false)
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw NSError(domain: "ContentContractTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Expected a JSON object at \(relativePath)"
            ])
        }
        return dictionary
    }

    private func rawLesson(_ lessonID: LessonID) throws -> [String: Any] {
        try rawJSON(relativePath: "lessons/\(lessonID.rawValue).json")
    }

    private func editorialMetadata(in block: [String: Any]) -> [String: Any]? {
        if let metadata = block["metadata"] as? [String: Any] {
            return metadata
        }
        if let spec = block["spec"] as? [String: Any],
           let metadata = spec["metadata"] as? [String: Any] {
            return metadata
        }
        if let spec = block["spec"] as? [String: Any],
           let header = spec["header"] as? [String: Any],
           let metadata = header["metadata"] as? [String: Any] {
            return metadata
        }
        return nil
    }

    private func exerciseBlocks(in lesson: LessonDocument) -> [ExerciseBlock] {
        lesson.blocks.compactMap { block in
            guard case .exercise(let exercise) = block else { return nil }
            return exercise
        }
    }

    private func readingBlocks(in lesson: LessonDocument) -> [ReadingBlock] {
        lesson.blocks.compactMap { block in
            guard case .reading(let reading) = block else { return nil }
            return reading
        }
    }

    func testBundledCourseDecodesFourLessonsTwentySevenExercisesAndFourStories() async throws {
        let content = store()
        let index = try await content.index()

        XCTAssertEqual(index.schemaVersion, 1)
        XCTAssertEqual(index.contentVersion, expectedContentVersion)
        XCTAssertEqual(index.courseIDs, [CourseID(rawValue: "mandarin-starter")!])
        XCTAssertEqual(index.defaultCourseID, CourseID(rawValue: "mandarin-starter")!)

        let course = try await content.course(id: index.defaultCourseID)
        let lessonIDs = course.modules
            .sorted { $0.order < $1.order }
            .flatMap(\.lessonIDs)
        XCTAssertEqual(lessonIDs, expectedLessonIDs)

        var allExerciseIDs = Set<ExerciseID>()
        var allStoryIDs = Set<StoryID>()

        for (index, lessonID) in expectedLessonIDs.enumerated() {
            let lesson = try await content.lesson(id: lessonID)
            let exercises = exerciseBlocks(in: lesson)
            let readings = readingBlocks(in: lesson)

            XCTAssertEqual(lesson.id, lessonID)
            XCTAssertEqual(lesson.schemaVersion, 1)
            XCTAssertEqual(lesson.contentVersion, expectedContentVersion)
            XCTAssertEqual(exercises.count, expectedExerciseCounts[index])
            XCTAssertEqual(readings.count, 1)
            XCTAssertFalse(lesson.objectives.isEmpty)
            XCTAssertFalse(lesson.vocabulary.isEmpty)
            XCTAssertFalse(lesson.cards.isEmpty)

            for exercise in exercises {
                XCTAssertTrue(allExerciseIDs.insert(exercise.spec.id).inserted, "Duplicate exercise ID \(exercise.spec.id.rawValue)")
            }
            for reading in readings {
                XCTAssertTrue(allStoryIDs.insert(reading.storyID).inserted, "Duplicate story ID \(reading.storyID.rawValue)")
                XCTAssertFalse(reading.paragraphs.isEmpty)
            }
        }

        XCTAssertEqual(allExerciseIDs.count, 27)
        XCTAssertEqual(allStoryIDs.count, 4)

        let stories = try await content.stories()
        XCTAssertEqual(stories.count, 4)
        XCTAssertEqual(Set(stories.map(\.id)), allStoryIDs)
        XCTAssertEqual(stories.flatMap { $0.paragraphs }.count, 16)
        XCTAssertTrue(stories.allSatisfy { !$0.paragraphs.isEmpty && !$0.level.isEmpty })
    }

    func testEveryLessonKeepsOralPracticeOptionalForOfflineProgression() async throws {
        let content = store()

        for lessonID in expectedLessonIDs {
            let lesson = try await content.lesson(id: lessonID)
            let speaking = exerciseBlocks(in: lesson).filter { block in
                if case .speaking = block.spec { return true }
                return false
            }

            XCTAssertEqual(speaking.count, 1, "Chaque leçon doit conserver une activité orale")
            XCTAssertTrue(
                speaking.allSatisfy { !$0.spec.header.required },
                "L’activité orale de \(lessonID.rawValue) ne doit pas bloquer la progression quand le service est indisponible"
            )
        }
    }

    func testContentReferencesAndExerciseShapesAreClosedAndStable() async throws {
        let content = store()
        let course = try await content.course(id: CourseID(rawValue: "mandarin-starter")!)
        let expectedLessonSet = Set(expectedLessonIDs)
        let courseLessonIDs = Set(course.modules.flatMap(\.lessonIDs))
        XCTAssertEqual(courseLessonIDs, expectedLessonSet)
        XCTAssertEqual(course.modules.flatMap(\.lessonIDs).count, courseLessonIDs.count)

        var globalCardIDs = Set<CardID>()
        let lessons = try await expectedLessonIDs.asyncMap { try await content.lesson(id: $0) }
        let globalVocabularyIDs = Set(lessons.flatMap(\.vocabulary).map(\.id))
        for lesson in lessons {
            let vocabularyIDs = Set(lesson.vocabulary.map(\.id))
            let objectiveIDs = Set(lesson.objectives.map(\.id))
            let exercises = exerciseBlocks(in: lesson)
            let exerciseIDs = Set(exercises.map { $0.spec.id })
            XCTAssertEqual(exerciseIDs.count, exercises.count)
            XCTAssertEqual(Set(lesson.cards.map(\.vocabularyID)), vocabularyIDs)
            XCTAssertTrue(lesson.objectives.allSatisfy { objective in
                exercises.contains { $0.spec.header.objectiveIDs.contains(objective.id) }
            }, "Every objective needs exercise evidence in \(lesson.id.rawValue)")

            for block in lesson.blocks {
                switch block {
                case .vocabulary(let vocabularyBlock):
                    XCTAssertFalse(vocabularyBlock.vocabularyIDs.isEmpty)
                    XCTAssertTrue(vocabularyBlock.vocabularyIDs.allSatisfy(vocabularyIDs.contains))
                case .reading(let reading):
                    XCTAssertTrue(reading.comprehensionExerciseIDs.allSatisfy(exerciseIDs.contains))
                    XCTAssertTrue(reading.paragraphs.allSatisfy { paragraph in
                        !paragraph.id.isEmpty && !paragraph.hanzi.isEmpty && !paragraph.pinyin.isEmpty &&
                            !paragraph.segmentation.isEmpty && paragraph.segmentation.allSatisfy { segment in
                                !segment.surface.isEmpty && (segment.vocabularyID == nil || globalVocabularyIDs.contains(segment.vocabularyID!))
                            }
                    }, "Invalid reading paragraph in \(reading.storyID.rawValue)")
                case .exercise(let exerciseBlock):
                    let spec = exerciseBlock.spec
                    XCTAssertFalse(spec.header.prompt.values.isEmpty)
                    XCTAssertFalse(spec.header.objectiveIDs.isEmpty)
                    XCTAssertTrue(spec.header.objectiveIDs.allSatisfy(objectiveIDs.contains))
                    assertValidShape(spec, cardIDs: Set(lesson.cards.map(\.id)))
                case .recap(let recap):
                    XCTAssertTrue(recap.vocabularyIDs.allSatisfy(vocabularyIDs.contains))
                    XCTAssertTrue(recap.objectiveIDs.allSatisfy(objectiveIDs.contains))
                case .introduction, .dialogue:
                    break
                }
            }

            for card in lesson.cards {
                XCTAssertTrue(globalCardIDs.insert(card.id).inserted, "Duplicate card ID \(card.id.rawValue)")
                XCTAssertTrue(vocabularyIDs.contains(card.vocabularyID))
                XCTAssertFalse(card.front.hanzi?.isEmpty ?? true)
                XCTAssertFalse(card.back.pinyin?.isEmpty ?? true)
                XCTAssertFalse(card.back.text?.values.isEmpty ?? true)
            }
        }
        XCTAssertEqual(globalCardIDs.count, 17)
    }

    func testEditorialMetadataDeclaresVocabularyCapReuseCycleVersionsAndGrammarEvidence() async throws {
        let content = store()
        let courseJSON = try rawJSON(relativePath: "courses/mandarin-starter.json")
        let courseMetadata = try XCTUnwrap(courseJSON["metadata"] as? [String: Any])
        XCTAssertEqual(courseMetadata["standardID"] as? String, "HSK-3.0")
        XCTAssertEqual(courseMetadata["standardVersion"] as? String, "2025-11")
        XCTAssertEqual(courseMetadata["legacyStandardID"] as? String, "HSK-legacy-2.0")
        XCTAssertEqual(courseMetadata["legacyStandardVersion"] as? String, "2.0")
        XCTAssertEqual(courseMetadata["transitionStatus"] as? String, "both-references-kept-separate")

        let alignments = try XCTUnwrap(courseJSON["alignment"] as? [[String: Any]])
        let alignmentReferences = Set(alignments.compactMap { alignment -> String? in
            guard let standardID = alignment["standardID"] as? String,
                  let standardVersion = alignment["standardVersion"] as? String else { return nil }
            return "\(standardID)/\(standardVersion)"
        })
        XCTAssertTrue(alignmentReferences.contains("HSK-3.0/2025-11"))
        XCTAssertTrue(alignmentReferences.contains("HSK-legacy-2.0/2.0"))

        let lessons = try await expectedLessonIDs.asyncMap { try await content.lesson(id: $0) }
        var vocabularyIntroducedEarlier = Set<String>()
        var allNewVocabularyIDs = Set<String>()

        for (index, pair) in zip(expectedLessonIDs, lessons).enumerated() {
            let (lessonID, lesson) = pair
            let raw = try rawLesson(lessonID)
            let metadata = try XCTUnwrap(raw["metadata"] as? [String: Any])

            XCTAssertEqual(metadata["standardID"] as? String, "HSK-3.0")
            XCTAssertEqual(metadata["standardVersion"] as? String, "2025-11")
            XCTAssertEqual(metadata["legacyStandardID"] as? String, "HSK-legacy-2.0")
            XCTAssertEqual(metadata["legacyStandardVersion"] as? String, "2.0")
            XCTAssertEqual(metadata["levelID"] as? String, "level-01")
            XCTAssertEqual(metadata["sectionID"] as? String, "section-01")
            XCTAssertEqual(metadata["unitID"] as? String, "unit-01")
            XCTAssertEqual(metadata["cycle"] as? [String], expectedCycle)

            let newVocabularyIDs = try XCTUnwrap(metadata["newVocabularyIDs"] as? [String])
            XCTAssertEqual(newVocabularyIDs.count, expectedNewVocabularyCounts[index])
            XCTAssertLessThanOrEqual(newVocabularyIDs.count, 6)
            XCTAssertEqual(metadata["newVocabularyCount"] as? Int, expectedNewVocabularyCounts[index])
            XCTAssertEqual(Set(newVocabularyIDs), Set(lesson.vocabulary.map(\.id.rawValue)))
            XCTAssertEqual(newVocabularyIDs.count, Set(newVocabularyIDs).count)
            XCTAssertTrue(allNewVocabularyIDs.isDisjoint(with: newVocabularyIDs))

            let reusedVocabularyIDs = try XCTUnwrap(metadata["reusedVocabularyIDs"] as? [String])
            XCTAssertEqual(reusedVocabularyIDs.count, Set(reusedVocabularyIDs).count)
            XCTAssertTrue(Set(reusedVocabularyIDs).isDisjoint(with: newVocabularyIDs))
            XCTAssertTrue(reusedVocabularyIDs.allSatisfy(vocabularyIntroducedEarlier.contains),
                          "Reused vocabulary in \(lessonID.rawValue) must have been introduced earlier")

            let blocks = try XCTUnwrap(raw["blocks"] as? [[String: Any]])
            let stages = blocks.compactMap { editorialMetadata(in: $0)?["stage"] as? String }
            XCTAssertEqual(stages.count, blocks.count, "Every block needs a pedagogical stage")
            XCTAssertEqual(Set(stages), Set(expectedCycle))

            let grammarPoints = try XCTUnwrap(raw["grammarPoints"] as? [[String: Any]])
            XCTAssertFalse(grammarPoints.isEmpty)
            for grammarPoint in grammarPoints {
                XCTAssertFalse((grammarPoint["id"] as? String)?.isEmpty ?? true)
                XCTAssertFalse((grammarPoint["pattern"] as? String)?.isEmpty ?? true)
                XCTAssertFalse((grammarPoint["function"] as? String)?.isEmpty ?? true)
                XCTAssertFalse((grammarPoint["acceptedVariants"] as? [String] ?? []).isEmpty)
                XCTAssertFalse((grammarPoint["errors"] as? [String] ?? []).isEmpty)
                let skills = (grammarPoint["skills"] as? [String]) ?? (grammarPoint["skill"] as? [String]) ?? []
                XCTAssertFalse(skills.isEmpty)
                XCTAssertEqual(grammarPoint["standardID"] as? String, "HSK-3.0")
                XCTAssertEqual(grammarPoint["standardVersion"] as? String, "2025-11")
            }

            vocabularyIntroducedEarlier.formUnion(newVocabularyIDs)
            allNewVocabularyIDs.formUnion(newVocabularyIDs)
        }

        XCTAssertEqual(allNewVocabularyIDs.count, 17)
        XCTAssertEqual(allNewVocabularyIDs.count, lessons.flatMap(\.vocabulary).count)
    }

    func testPinyinTonesAndSimplifiedTraditionalPairsMatchTheStarterVocabulary() async throws {
        let content = store()
        let lessons = try await expectedLessonIDs.asyncMap { try await content.lesson(id: $0) }
        let entries = lessons.flatMap(\.vocabulary)

        XCTAssertTrue(entries.allSatisfy { entry in
            !entry.hanzi.isEmpty &&
                !(entry.traditionalHanzi?.isEmpty ?? true) &&
                !entry.pinyin.isEmpty &&
                !entry.toneNumbers.isEmpty &&
                entry.toneNumbers.allSatisfy { (0...4).contains($0) } &&
                !entry.segmentation.isEmpty &&
                entry.segmentation.allSatisfy { !$0.surface.isEmpty }
        })

        let expectedPairs: [String: (traditional: String, pinyin: String, tones: [Int])] = [
            "你好": ("你好", "nǐ hǎo", [3, 3]),
            "早": ("早", "zǎo", [3]),
            "再见": ("再見", "zàijiàn", [4, 4]),
            "谢谢": ("謝謝", "xièxie", [4, 0]),
            "不客气": ("不客氣", "bú kèqi", [2, 4, 0]),
            "你": ("你", "nǐ", [3]),
            "我": ("我", "wǒ", [3]),
            "叫": ("叫", "jiào", [4]),
            "什么": ("什麼", "shénme", [2, 0]),
            "名字": ("名字", "míngzi", [2, 0]),
            "是": ("是", "shì", [4]),
            "哪": ("哪", "nǎ", [3]),
            "国": ("國", "guó", [2]),
            "法国": ("法國", "Fǎguó", [3, 2]),
            "中国": ("中國", "Zhōngguó", [1, 2]),
            "人": ("人", "rén", [2]),
            "呢": ("呢", "ne", [0])
        ]

        XCTAssertEqual(entries.count, expectedPairs.count)
        XCTAssertEqual(Set(entries.map(\.id)).count, entries.count)
        let actualHanzi = Set(entries.map(\.hanzi))
        XCTAssertEqual(actualHanzi, Set(expectedPairs.keys))
        XCTAssertEqual(Set(entries.flatMap(\.toneNumbers)), Set(0...4))
        for (hanzi, expected) in expectedPairs {
            let matches = entries.filter { $0.hanzi == hanzi }
            XCTAssertFalse(matches.isEmpty, "Missing vocabulary \(hanzi)")
            XCTAssertTrue(matches.allSatisfy { entry in
                entry.traditionalHanzi == expected.traditional &&
                    entry.pinyin == expected.pinyin &&
                    entry.toneNumbers == expected.tones
            })
        }
    }

    func testV1AudioIsAbsentAndHandwritingGuidesResolveToDeliveredAssets() async throws {
        let content = store()
        let lessons = try await expectedLessonIDs.asyncMap { try await content.lesson(id: $0) }
        var audioReferences: [AssetReference] = []
        var guideReferences: [AssetReference] = []

        for lesson in lessons {
            for entry in lesson.vocabulary {
                if let audio = entry.audio { audioReferences.append(audio) }
                if let audio = entry.example?.audio { audioReferences.append(audio) }
            }
            for card in lesson.cards {
                if let audio = card.front.audio { audioReferences.append(audio) }
                if let audio = card.back.audio { audioReferences.append(audio) }
            }
            for block in lesson.blocks {
                switch block {
                case .introduction(let value):
                    if let audio = value.audio { audioReferences.append(audio) }
                case .dialogue(let value):
                    audioReferences.append(contentsOf: value.lines.compactMap(\.audio))
                case .reading(let value):
                    audioReferences.append(contentsOf: value.paragraphs.compactMap(\.audio))
                case .exercise(let value):
                    switch value.spec {
                    case .listeningChoice(let exercise): audioReferences.append(exercise.promptAudio)
                    case .speaking(let exercise):
                        if let audio = exercise.referenceAudio { audioReferences.append(audio) }
                    case .handwriting(let exercise): guideReferences.append(exercise.guideAsset)
                    default: break
                    }
                case .vocabulary, .recap:
                    break
                }
            }
        }

        XCTAssertTrue(audioReferences.isEmpty, "V1 audio must remain absent until a real asset is shipped")
        XCTAssertEqual(Set(guideReferences.map(\.id)), Set([
            AssetID(rawValue: "guide-hanzi-ni")!,
            AssetID(rawValue: "guide-hanzi-wo")!,
            AssetID(rawValue: "guide-hanzi-guo")!
        ]))
        XCTAssertTrue(guideReferences.allSatisfy {
            $0.kind == .handwritingGuide &&
                $0.relativePath.hasPrefix("assets/handwriting/") &&
                $0.relativePath.hasSuffix(".json") &&
                !$0.sha256.isEmpty &&
                $0.sha256 != "pending-writing-guide"
        })

        for reference in guideReferences {
            do {
                let resolved = try await content.assetURL(for: reference)
                XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
                XCTAssertFalse(try Data(contentsOf: resolved).isEmpty)
            } catch {
                XCTFail("Delivered guide \(reference.id.rawValue) could not be verified: \(error)")
            }
        }
    }

    func testEveryDeliveredExerciseHasAnAnswerAcceptedByTheEngine() async throws {
        let content = store()
        let engine = DefaultExerciseEngine()
        var evaluatedCount = 0

        for lessonID in expectedLessonIDs {
            let lesson = try await content.lesson(id: lessonID)
            for block in exerciseBlocks(in: lesson) {
                let evaluation = engine.evaluate(spec: block.spec, answer: answerFor(block.spec))
                XCTAssertTrue(evaluation.accepted, "The canonical answer for \(block.spec.id.rawValue) was rejected")
                XCTAssertEqual(evaluation.score, 1, accuracy: 0.000_001)
                XCTAssertEqual(evaluation.exerciseID, block.spec.id)
                evaluatedCount += 1
            }
        }

        XCTAssertEqual(evaluatedCount, 27)
    }

    private func assertValidShape(_ spec: ExerciseSpec, cardIDs: Set<CardID>) {
        switch spec {
        case .choice(let exercise):
            XCTAssertFalse(exercise.choices.isEmpty)
            XCTAssertEqual(Set(exercise.choices.map(\.id)).count, exercise.choices.count)
            XCTAssertTrue(exercise.choices.contains { $0.id == exercise.correctChoiceID })
        case .wordOrder(let exercise):
            let tokenIDs = exercise.tokens.map(\.id)
            XCTAssertFalse(tokenIDs.isEmpty)
            XCTAssertEqual(Set(tokenIDs).count, tokenIDs.count)
            XCTAssertEqual(Set(tokenIDs), Set(exercise.correctOrder))
            XCTAssertEqual(tokenIDs.count, exercise.correctOrder.count)
            XCTAssertTrue(exercise.tokens.allSatisfy { !$0.hanzi.isEmpty })
        case .fillBlank(let exercise):
            XCTAssertFalse(exercise.sentence.isEmpty)
            XCTAssertFalse(exercise.acceptedAnswers.isEmpty)
        case .listeningChoice(let exercise):
            XCTAssertFalse(exercise.promptAudio.relativePath.isEmpty)
            XCTAssertFalse(exercise.choices.isEmpty)
            XCTAssertTrue(exercise.choices.contains { $0.id == exercise.correctChoiceID })
        case .speaking(let exercise):
            XCTAssertFalse(exercise.referenceText.isEmpty)
            XCTAssertFalse(exercise.referencePinyin.isEmpty)
            XCTAssertFalse(exercise.acceptedTranscripts.isEmpty)
        case .handwriting(let exercise):
            XCTAssertFalse(exercise.targetHanzi.isEmpty)
            XCTAssertFalse(exercise.guideAsset.relativePath.isEmpty)
            XCTAssertTrue(exercise.expectedStrokeCount ?? 0 > 0)
            if exercise.guideAsset.kind != .handwritingGuide {
                XCTFail("Handwriting guide has an incompatible asset kind")
            }
        case .flashcard(let exercise):
            XCTAssertTrue(cardIDs.contains(exercise.cardID))
        }
    }

    private func answerFor(_ spec: ExerciseSpec) -> ExerciseAnswer {
        switch spec {
        case .choice(let exercise):
            return .choice(choiceID: exercise.correctChoiceID)
        case .wordOrder(let exercise):
            return .wordOrder(tokenIDs: exercise.correctOrder)
        case .fillBlank(let exercise):
            return .text(exercise.acceptedAnswers[0])
        case .listeningChoice(let exercise):
            return .choice(choiceID: exercise.correctChoiceID)
        case .speaking(let exercise):
            return .speech(SpeechAnswer(transcript: exercise.acceptedTranscripts[0]))
        case .handwriting(let exercise):
            return .handwriting(HandwritingAnswer(strokeCount: exercise.expectedStrokeCount ?? 0, selfChecked: true))
        case .flashcard:
            return .selfRating(.easy)
        }
    }
}

private extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for element in self {
            result.append(try await transform(element))
        }
        return result
    }
}
