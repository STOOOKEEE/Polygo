import Foundation
import XCTest
@testable import PolygoCore

/// Contract tests for every content pack shipped with the application.
///
/// The first four lessons retain a small compatibility fixture because the
/// starter journey and the platform UI tests refer to those stable IDs. All
/// other assertions discover courses, modules, lessons, and exercises from the
/// bundled manifests so adding a level does not turn a content count into a
/// hidden migration step.
final class ContentContractTests: XCTestCase {
    private let starterLessonIDs: [LessonID] = [
        LessonID(rawValue: "lesson-01")!,
        LessonID(rawValue: "lesson-02")!,
        LessonID(rawValue: "lesson-03")!,
        LessonID(rawValue: "lesson-04")!
    ]

    private let starterExerciseIDs: [[ExerciseID]] = [
        [
            ExerciseID(rawValue: "ex-l1-tone")!,
            ExerciseID(rawValue: "ex-l1-meaning")!,
            ExerciseID(rawValue: "ex-l1-order")!,
            ExerciseID(rawValue: "ex-l1-reading-last-word")!,
            ExerciseID(rawValue: "ex-l1-speak")!,
            ExerciseID(rawValue: "ex-l1-write")!
        ],
        [
            ExerciseID(rawValue: "ex-l2-tone")!,
            ExerciseID(rawValue: "ex-l2-meaning")!,
            ExerciseID(rawValue: "ex-l2-order")!,
            ExerciseID(rawValue: "ex-l2-fill")!,
            ExerciseID(rawValue: "ex-l2-reading-name")!,
            ExerciseID(rawValue: "ex-l2-speak")!,
            ExerciseID(rawValue: "ex-l2-write")!
        ],
        [
            ExerciseID(rawValue: "ex-l3-tone")!,
            ExerciseID(rawValue: "ex-l3-meaning")!,
            ExerciseID(rawValue: "ex-l3-order")!,
            ExerciseID(rawValue: "ex-l3-card")!,
            ExerciseID(rawValue: "ex-l3-reading-country")!,
            ExerciseID(rawValue: "ex-l3-speak")!,
            ExerciseID(rawValue: "ex-l3-write")!
        ],
        [
            ExerciseID(rawValue: "ex-l4-script")!,
            ExerciseID(rawValue: "ex-l4-ne")!,
            ExerciseID(rawValue: "ex-l4-order")!,
            ExerciseID(rawValue: "ex-l4-fill")!,
            ExerciseID(rawValue: "ex-l4-reading-ne")!,
            ExerciseID(rawValue: "ex-l4-speak")!,
            ExerciseID(rawValue: "ex-l4-card")!
        ]
    ]

    private struct CourseSnapshot {
        let manifest: CourseManifest
        let lessons: [LessonDocument]
    }

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

    private func rawCourse(_ courseID: CourseID) throws -> [String: Any] {
        try rawJSON(relativePath: "courses/\(courseID.rawValue).json")
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

    private func allCourseSnapshots() async throws -> (ContentIndex, [CourseSnapshot]) {
        let content = store()
        let index = try await content.index()
        let snapshots = try await index.courseIDs.asyncMap { courseID in
            let manifest = try await content.course(id: courseID)
            let lessonIDs = manifest.modules
                .sorted { lhs, rhs in
                    lhs.order == rhs.order ? lhs.id.rawValue < rhs.id.rawValue : lhs.order < rhs.order
                }
                .flatMap(\.lessonIDs)
            let lessons = try await lessonIDs.asyncMap { try await content.lesson(id: $0) }
            return CourseSnapshot(manifest: manifest, lessons: lessons)
        }
        return (index, snapshots)
    }

    private func assertNonEmpty(_ text: LocalizedText, _ message: String) {
        XCTAssertFalse(text.values.isEmpty, "\(message) must have a translation")
        XCTAssertTrue(
            text.values.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            "\(message) contains an empty translation"
        )
    }

    private func assertNonEmpty(_ value: String?, _ message: String) {
        XCTAssertFalse(value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "\(message) must not be empty")
    }

    // MARK: Discovery, ordering, and global identifier invariants

    func testBundledCourseDecodesEveryDiscoveredLessonAndStory() async throws {
        let (index, snapshots) = try await allCourseSnapshots()

        XCTAssertEqual(index.schemaVersion, 1)
        XCTAssertFalse(index.contentVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(index.courseIDs.isEmpty)
        XCTAssertTrue(index.courseIDs.contains(index.defaultCourseID))
        XCTAssertEqual(Set(index.courseIDs).count, index.courseIDs.count)
        XCTAssertEqual(snapshots.count, index.courseIDs.count)

        var allLessonIDs = Set<LessonID>()
        var allBlockIDs = Set<BlockID>()
        var allExerciseIDs = Set<ExerciseID>()
        var allStoryIDs = Set<StoryID>()
        var allParagraphIDs = Set<String>()
        var allVocabulary: [VocabularyID: VocabularyEntry] = [:]
        var allCards: [CardID: ReviewCard] = [:]

        for snapshot in snapshots {
            let course = snapshot.manifest
            XCTAssertEqual(course.schemaVersion, index.schemaVersion)
            XCTAssertEqual(course.contentVersion, index.contentVersion)
            XCTAssertFalse(course.modules.isEmpty, "\(course.id.rawValue) must contain a module")

            let moduleOrders = course.modules.map(\.order)
            XCTAssertEqual(Set(moduleOrders).count, moduleOrders.count, "Module orders must be unique in \(course.id.rawValue)")
            XCTAssertTrue(moduleOrders.allSatisfy { $0 > 0 }, "Module orders must be positive")

            let courseLessonIDs = course.modules.flatMap(\.lessonIDs)
            XCTAssertFalse(courseLessonIDs.isEmpty, "\(course.id.rawValue) must contain a lesson")
            XCTAssertEqual(Set(courseLessonIDs).count, courseLessonIDs.count, "A lesson may occur in only one module")
            XCTAssertEqual(Set(courseLessonIDs), Set(snapshot.lessons.map(\.id)))

            for module in course.modules.sorted(by: { $0.order < $1.order }) {
                let moduleLessons = module.lessonIDs.compactMap { lessonID in
                    snapshot.lessons.first(where: { $0.id == lessonID })
                }
                XCTAssertEqual(moduleLessons.count, module.lessonIDs.count, "Every module lesson reference must resolve")
                XCTAssertTrue(moduleLessons.allSatisfy { $0.moduleID == module.id }, "Lesson module references must resolve")
                let lessonOrders = moduleLessons.map(\.order)
                XCTAssertEqual(lessonOrders, lessonOrders.sorted(), "Lesson order must follow the module order")
                XCTAssertEqual(Set(lessonOrders).count, lessonOrders.count, "Lesson orders must be unique in \(module.id.rawValue)")
            }

            for lesson in snapshot.lessons {
                XCTAssertTrue(allLessonIDs.insert(lesson.id).inserted, "Duplicate lesson ID \(lesson.id.rawValue)")
                XCTAssertEqual(lesson.schemaVersion, index.schemaVersion)
                XCTAssertEqual(lesson.contentVersion, index.contentVersion)
                assertNonEmpty(lesson.title, "\(lesson.id.rawValue) title")
                assertNonEmpty(lesson.summary, "\(lesson.id.rawValue) summary")
                XCTAssertGreaterThan(lesson.estimatedMinutes, 0, "\(lesson.id.rawValue) needs an estimate")
                XCTAssertFalse(lesson.blocks.isEmpty, "\(lesson.id.rawValue) must contain blocks")
                XCTAssertFalse(lesson.objectives.isEmpty, "\(lesson.id.rawValue) must contain objectives")
                XCTAssertFalse(lesson.vocabulary.isEmpty, "\(lesson.id.rawValue) must contain vocabulary")

                for objective in lesson.objectives {
                    assertNonEmpty(objective.id, "objective ID")
                    assertNonEmpty(objective.statement, "objective \(objective.id)")
                }

                for entry in lesson.vocabulary {
                    if let previous = allVocabulary[entry.id] {
                        XCTAssertEqual(previous, entry, "Vocabulary \(entry.id.rawValue) must keep one canonical object when reused")
                    } else {
                        allVocabulary[entry.id] = entry
                    }
                }

                for card in lesson.cards {
                    if let previous = allCards[card.id] {
                        XCTAssertEqual(previous, card, "Card \(card.id.rawValue) must keep one canonical object when reused")
                    } else {
                        allCards[card.id] = card
                    }
                }

                for block in lesson.blocks {
                    XCTAssertTrue(allBlockIDs.insert(block.id).inserted, "Duplicate block ID \(block.id.rawValue)")
                    if case .exercise(let exerciseBlock) = block {
                        XCTAssertTrue(
                            allExerciseIDs.insert(exerciseBlock.spec.id).inserted,
                            "Duplicate exercise ID \(exerciseBlock.spec.id.rawValue)"
                        )
                    }
                    if case .reading(let reading) = block {
                        XCTAssertTrue(allStoryIDs.insert(reading.storyID).inserted, "Duplicate story ID \(reading.storyID.rawValue)")
                        XCTAssertFalse(reading.paragraphs.isEmpty, "Story \(reading.storyID.rawValue) needs paragraphs")
                        for paragraph in reading.paragraphs {
                            XCTAssertTrue(allParagraphIDs.insert(paragraph.id).inserted, "Duplicate paragraph ID \(paragraph.id)")
                        }
                    }
                }
            }
        }

        XCTAssertFalse(allLessonIDs.isEmpty)
        XCTAssertFalse(allBlockIDs.isEmpty)
        XCTAssertFalse(allExerciseIDs.isEmpty)
        XCTAssertFalse(allVocabulary.isEmpty)
        XCTAssertFalse(allCards.isEmpty)
        XCTAssertFalse(allStoryIDs.isEmpty)

        let stories = try await store().stories()
        var storyIDs = Set<StoryID>()
        var storyParagraphIDs = Set<String>()
        for story in stories {
            XCTAssertTrue(storyIDs.insert(story.id).inserted, "Duplicate story catalogue ID \(story.id.rawValue)")
            assertNonEmpty(story.level, "story \(story.id.rawValue) level")
            XCTAssertGreaterThan(story.estimatedMinutes, 0)
            assertNonEmpty(story.title, "story \(story.id.rawValue) title")
            assertNonEmpty(story.summary, "story \(story.id.rawValue) summary")
            XCTAssertFalse(story.paragraphs.isEmpty, "Story \(story.id.rawValue) needs paragraphs")
            for paragraph in story.paragraphs {
                XCTAssertTrue(storyParagraphIDs.insert(paragraph.id).inserted, "Duplicate story paragraph ID \(paragraph.id)")
            }
        }
        XCTAssertTrue(allStoryIDs.isSubset(of: storyIDs), "Every reading block must be represented in the story catalogue")
    }

    /// The platform journeys keep these four lesson and exercise IDs stable.
    /// Their canonical answers are still evaluated through the real engine.
    func testStarterFixtureRetainsFirstFourLessonAndExerciseIDs() async throws {
        let content = store()
        let index = try await content.index()
        let course = try await content.course(id: index.defaultCourseID)
        let orderedLessonIDs = course.modules
            .sorted { $0.order < $1.order }
            .flatMap(\.lessonIDs)

        XCTAssertGreaterThanOrEqual(orderedLessonIDs.count, starterLessonIDs.count)
        XCTAssertEqual(Array(orderedLessonIDs.prefix(starterLessonIDs.count)), starterLessonIDs)

        let engine = DefaultExerciseEngine()
        for (offset, lessonID) in starterLessonIDs.enumerated() {
            let lesson = try await content.lesson(id: lessonID)
            let exercises = exerciseBlocks(in: lesson)
            XCTAssertEqual(exercises.map { $0.spec.id }, starterExerciseIDs[offset])
            for exercise in exercises {
                guard let answer = canonicalAnswer(for: exercise.spec) else {
                    XCTFail("Starter exercise \(exercise.spec.id.rawValue) has no evaluable canonical answer")
                    continue
                }
                let evaluation = engine.evaluate(spec: exercise.spec, answer: answer)
                XCTAssertTrue(evaluation.accepted, "Starter answer for \(exercise.spec.id.rawValue) must be accepted")
                XCTAssertEqual(evaluation.score, 1, accuracy: 0.000_001)
            }
        }
    }

    func testEveryLessonKeepsOralPracticeOptionalForOfflineProgression() async throws {
        let (_, snapshots) = try await allCourseSnapshots()

        for lesson in snapshots.flatMap(\.lessons) {
            let speaking = exerciseBlocks(in: lesson).compactMap { block -> SpeakingExercise? in
                guard case .speaking(let exercise) = block.spec else { return nil }
                return exercise
            }
            XCTAssertTrue(
                speaking.allSatisfy { !$0.header.required },
                "Oral activities in \(lesson.id.rawValue) must not block offline progression"
            )
            XCTAssertTrue(
                speaking.allSatisfy { $0.allowSelfRating || !$0.acceptedTranscripts.isEmpty },
                "An oral activity needs self-rating or an accepted transcript"
            )
        }
    }

    // MARK: Closed references and content shape

    func testContentReferencesAndExerciseShapesAreClosedAndStable() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        let allLessons = snapshots.flatMap(\.lessons)
        let globalVocabularyIDs = Set(allLessons.flatMap(\.vocabulary).map(\.id))
        let globalExerciseIDs = Set(allLessons.flatMap { exerciseBlocks(in: $0).map { $0.spec.id } })
        let globalCardIDs = Set(allLessons.flatMap(\.cards).map(\.id))
        let allObjectiveIDs = Set(allLessons.flatMap(\.objectives).map(\.id))

        XCTAssertFalse(globalVocabularyIDs.isEmpty)
        XCTAssertFalse(globalExerciseIDs.isEmpty)
        XCTAssertFalse(globalCardIDs.isEmpty)

        for lesson in allLessons {
            let vocabularyIDs = Set(lesson.vocabulary.map(\.id))
            let objectiveIDs = Set(lesson.objectives.map(\.id))
            let exercises = exerciseBlocks(in: lesson)
            let exerciseIDs = Set(exercises.map { $0.spec.id })

            XCTAssertEqual(vocabularyIDs.count, lesson.vocabulary.count, "Duplicate vocabulary in \(lesson.id.rawValue)")
            XCTAssertEqual(exerciseIDs.count, exercises.count, "Duplicate exercises in \(lesson.id.rawValue)")
            XCTAssertEqual(Set(lesson.cards.map(\.vocabularyID)), vocabularyIDs, "Every lesson vocabulary entry needs a review card")
            XCTAssertTrue(
                lesson.objectives.allSatisfy { objective in
                    exercises.contains { $0.spec.header.objectiveIDs.contains(objective.id) }
                },
                "Every objective needs exercise evidence in \(lesson.id.rawValue)"
            )
            XCTAssertTrue(objectiveIDs.isSubset(of: allObjectiveIDs))

            for block in lesson.blocks {
                switch block {
                case .introduction(let value):
                    assertNonEmpty(value.title, "\(block.id.rawValue) title")
                    assertNonEmpty(value.body, "\(block.id.rawValue) body")
                case .vocabulary(let value):
                    XCTAssertFalse(value.vocabularyIDs.isEmpty, "\(block.id.rawValue) needs vocabulary references")
                    XCTAssertTrue(value.vocabularyIDs.allSatisfy(vocabularyIDs.contains), "Vocabulary block \(block.id.rawValue) has a closed reference")
                case .dialogue(let value):
                    XCTAssertFalse(value.lines.isEmpty, "\(block.id.rawValue) needs dialogue lines")
                    for line in value.lines {
                        assertNonEmpty(line.speaker, "dialogue speaker")
                        assertNonEmpty(line.hanzi, "dialogue hanzi")
                        assertNonEmpty(line.pinyin, "dialogue pinyin")
                        assertNonEmpty(line.translation, "dialogue translation")
                    }
                    XCTAssertTrue(value.comprehensionExerciseIDs.allSatisfy(exerciseIDs.contains))
                    if let participation = value.participation {
                        XCTAssertTrue(value.lines.indices.contains(participation.audioLineIndex))
                        XCTAssertFalse(participation.acceptedResponses.isEmpty)
                        assertNonEmpty(participation.prompt, "dialogue participation prompt")
                    }
                case .reading(let reading):
                    assertNonEmpty(reading.title, "\(reading.storyID.rawValue) title")
                    XCTAssertFalse(reading.paragraphs.isEmpty, "\(reading.storyID.rawValue) needs paragraphs")
                    XCTAssertTrue(reading.comprehensionExerciseIDs.allSatisfy(exerciseIDs.contains))
                    for paragraph in reading.paragraphs {
                        assertNonEmpty(paragraph.id, "reading paragraph ID")
                        assertNonEmpty(paragraph.hanzi, "reading paragraph hanzi")
                        assertNonEmpty(paragraph.pinyin, "reading paragraph pinyin")
                        assertNonEmpty(paragraph.translation, "reading paragraph translation")
                        XCTAssertTrue(paragraph.segmentation.allSatisfy { segment in
                            assertNonEmpty(segment.surface, "reading segment surface")
                            if let vocabularyID = segment.vocabularyID {
                                return globalVocabularyIDs.contains(vocabularyID)
                            }
                            return true
                        })
                    }
                case .exercise(let exerciseBlock):
                    let spec = exerciseBlock.spec
                    assertNonEmpty(spec.header.prompt, "\(spec.id.rawValue) prompt")
                    assertNonEmpty(spec.header.instruction, "\(spec.id.rawValue) instruction")
                    XCTAssertFalse(spec.header.objectiveIDs.isEmpty, "\(spec.id.rawValue) needs objective evidence")
                    XCTAssertTrue(spec.header.objectiveIDs.allSatisfy(objectiveIDs.contains))
                    assertValidShape(spec, cardIDs: globalCardIDs)
                case .recap(let recap):
                    XCTAssertTrue(recap.vocabularyIDs.allSatisfy(vocabularyIDs.contains))
                    XCTAssertTrue(recap.objectiveIDs.allSatisfy(objectiveIDs.contains))
                }
            }

            for card in lesson.cards {
                XCTAssertTrue(globalCardIDs.contains(card.id))
                XCTAssertTrue(vocabularyIDs.contains(card.vocabularyID))
                assertNonEmpty(card.front.hanzi, "\(card.id.rawValue) front hanzi")
                assertNonEmpty(card.back.hanzi, "\(card.id.rawValue) back hanzi")
                assertNonEmpty(card.back.pinyin, "\(card.id.rawValue) pinyin")
                if let text = card.back.text {
                    assertNonEmpty(text, "\(card.id.rawValue) translation")
                } else {
                    XCTFail("\(card.id.rawValue) is missing its translation")
                }
            }
        }
    }

    /// Newly authored lessons get cards from the shared catalogue rather than
    /// copying one of the four protected starter fixtures. Keep the review
    /// surface explicit here: the front must expose only Hanzi, while the
    /// revealed back must carry the pronunciation and French meaning.
    func testGeneratedDailyCardsKeepAnswersOnTheRevealedBack() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        let protectedCardIDs = Set(
            snapshots
                .flatMap(\.lessons)
                .filter { starterLessonIDs.contains($0.id) }
                .flatMap(\.cards)
                .map(\.id)
        )
        XCTAssertEqual(
            protectedCardIDs.count,
            17,
            "The four starter fixtures must retain exactly the protected card set"
        )

        // Discover the authored surface from the course plan itself. This
        // keeps the contract tied to the learner-facing progression and also
        // covers the first planned sessions, whose metadata intentionally
        // carries no build-allocation marker.
        var plannedLessons: [LessonDocument] = []
        for snapshot in snapshots {
            guard let plan = snapshot.manifest.plan else { continue }
            let lessonsByID = Dictionary(uniqueKeysWithValues: snapshot.lessons.map { ($0.id, $0) })
            for session in plan.orderedSessions {
                guard let lesson = lessonsByID[session.lessonID] else {
                    XCTFail("Plan day \(session.day) references missing lesson \(session.lessonID.rawValue)")
                    continue
                }
                plannedLessons.append(lesson)
            }
        }

        XCTAssertFalse(plannedLessons.isEmpty, "The bundled course must include authored daily lessons")

        let authoredCards = plannedLessons
            .flatMap(\.cards)
            .filter { !protectedCardIDs.contains($0.id) }
        XCTAssertFalse(authoredCards.isEmpty, "Planned lessons must contain authored cards")

        for card in authoredCards {
            assertNonEmpty(card.front.hanzi, "\(card.id.rawValue) front hanzi")
            XCTAssertNil(card.front.pinyin, "\(card.id.rawValue) must keep pinyin hidden on the front")
            XCTAssertNil(card.front.text, "\(card.id.rawValue) must keep the meaning hidden on the front")
            assertNonEmpty(card.back.pinyin, "\(card.id.rawValue) back pinyin")
            if let text = card.back.text {
                assertNonEmpty(text.values["fr"], "\(card.id.rawValue) back French translation")
            } else {
                XCTFail("\(card.id.rawValue) is missing its French translation on the back")
            }
        }
    }

    // MARK: Editorial metadata and curriculum alignment

    func testAuthoredDailyPlanUsesRealProgressionFifteenMinuteBudgetAndCanonicalMilestones() async throws {
        let (index, snapshots) = try await allCourseSnapshots()
        let defaultSnapshot = try XCTUnwrap(
            snapshots.first(where: { $0.manifest.id == index.defaultCourseID }),
            "The default course must be loaded"
        )
        XCTAssertNotNil(
            defaultSnapshot.manifest.plan,
            "The default course must carry the authored 90-day programme"
        )
        for snapshot in snapshots {
            guard let plan = snapshot.manifest.plan else { continue }

            XCTAssertEqual(plan.targetMinutes, 15, "\(snapshot.manifest.id.rawValue) daily target")
            let sessions = plan.orderedSessions
            XCTAssertEqual(sessions.count, 90, "\(snapshot.manifest.id.rawValue) must author 90 daily sessions")
            let days = sessions.map(\.day)
            XCTAssertEqual(days, Array(1...sessions.count), "Plan days must be contiguous and start at one")
            XCTAssertEqual(Set(sessions.map(\.lessonID)).count, sessions.count, "A lesson may occur in only one plan day")

            let courseLessonIDs = Set(snapshot.manifest.modules.flatMap(\.lessonIDs))
            XCTAssertTrue(sessions.allSatisfy { courseLessonIDs.contains($0.lessonID) })
            XCTAssertTrue(Set(sessions.map(\.lessonID)).isDisjoint(with: Set(starterLessonIDs)), "Protected starter lessons stay before the daily programme")
            XCTAssertTrue(sessions.allSatisfy { session in
                session.courseMinutes > 0 &&
                    session.reviewMinutes > 0 &&
                    session.plannedMinutes == plan.targetMinutes
            })

            let first = try XCTUnwrap(sessions.first)
            XCTAssertEqual(plan.nextSession(completedLessonIDs: [])?.lessonID, first.lessonID)
            if sessions.count > 1 {
                let second = sessions[1]
                XCTAssertEqual(plan.nextSession(completedLessonIDs: [first.lessonID])?.lessonID, second.lessonID)
                let laterLessons = Set(sessions.dropFirst().map(\.lessonID))
                XCTAssertEqual(plan.nextSession(completedLessonIDs: laterLessons)?.lessonID, first.lessonID, "The next day follows progression, not the wall calendar")
            }

            let catalog = try canonicalCatalog()
            let milestoneDays = plan.milestones.map(\.day)
            XCTAssertEqual(Set(milestoneDays).count, milestoneDays.count, "Milestone days must be unique")
            for day in [30, 90] {
                let milestone = try XCTUnwrap(
                    plan.milestones.first(where: { $0.day == day }),
                    "Missing day \(day) milestone"
                )
                let coverage = try XCTUnwrap(milestone.coverage, "Day \(day) needs canonical coverage")
                XCTAssertEqual(coverage.catalogID, catalog.id)
                XCTAssertEqual(coverage.catalogVersion, catalog.version)
                XCTAssertTrue(coverage.canonicalOnly)
                XCTAssertEqual(
                    coverage.vocabularyTarget,
                    day == 30 ? 300 : 600,
                    "The milestone target must be the authored HSK reference target"
                )
                if let reference = milestone.reference {
                    XCTAssertEqual(reference.framework.lowercased(), "hsk")
                    XCTAssertEqual(reference.standardID, "HSK-legacy-2.0")
                    XCTAssertEqual(reference.standardVersion, "2.0")
                } else {
                    XCTFail("Day \(day) must carry the HSK-legacy-2.0 reference")
                }

                // The daily plan starts after the protected four-lesson
                // introduction. Coverage is cumulative for the whole
                // course, so include that baseline before counting the
                // programme sessions through this milestone.
                let coverageLessonIDs = starterLessonIDs + sessions
                    .filter { $0.day <= day }
                    .map(\.lessonID)
                let covered = try canonicalIDs(
                    in: coverageLessonIDs,
                    snapshots: snapshots,
                    catalog: catalog
                )
                // The target is a cumulative HSK level boundary. A lesson
                // may use a higher-level lexeme for a natural scene before
                // the boundary, so the total delivered set can exceed the
                // target; every lexeme through the boundary must be present.
                let targetLexemes = day == 30
                    ? Set(catalog.lexemeKeysByRank.filter { (1...300).contains($0.key) }.map(\.value))
                    : catalog.lexemeKeys
                XCTAssertEqual(
                    targetLexemes.intersection(covered).count,
                    coverage.vocabularyTarget,
                    "Day \(day) coverage must include every canonical catalogue lexeme through the HSK boundary"
                )
                XCTAssertGreaterThanOrEqual(
                    covered.count,
                    coverage.vocabularyTarget,
                    "Day \(day) coverage must count canonical catalogue IDs actually delivered"
                )
                XCTAssertTrue(covered.isSubset(of: catalog.lexemeKeys))
            }

            for milestone in plan.milestones {
                XCTAssertGreaterThanOrEqual(milestone.day, 1)
                XCTAssertLessThanOrEqual(milestone.day, sessions.count)
                assertNonEmpty(milestone.id, "milestone ID")
                assertNonEmpty(milestone.title, "milestone \(milestone.id) title")
                for claim in milestone.claims {
                    let normalized = claim.lowercased()
                    if normalized.contains("acquis") || normalized.contains("maîtris") || normalized.contains("niveau atteint") {
                        XCTAssertTrue(
                            normalized.contains("pas") || normalized.contains("ne ") || normalized.contains("sans") || normalized.contains("aucun"),
                            "A milestone claim must not infer mastery from the calendar"
                        )
                    }
                }
            }
        }
    }

    private struct CanonicalCatalog {
        let id: String
        let version: String
        let entryIDs: Set<String>
        let lexemeKeyByEntryID: [String: String]
        let lexemeKeysByRank: [Int: String]
        let lexemeKeys: Set<String>
        let mappings: [String: String]

        func canonicalKey(for rawID: String) -> String? {
            let normalizedID = rawID.hasPrefix("vocab-") ? String(rawID.dropFirst("vocab-".count)) : rawID
            return lexemeKeyByEntryID[normalizedID] ?? (lexemeKeys.contains(rawID) ? rawID : nil)
        }
    }

    private func canonicalCatalog() throws -> CanonicalCatalog {
        let raw = try rawJSON(relativePath: "authoring/hsk-legacy-600.json")
        let standard = try XCTUnwrap(raw["standard"] as? [String: Any])
        _ = try XCTUnwrap(standard["id"] as? String)
        // The catalogue release version is separate from the standard's
        // normative version (2.0). Plans refer to this content version.
        let version = try XCTUnwrap(raw["contentVersion"] as? String)
        let entries = try XCTUnwrap(raw["entries"] as? [[String: Any]])
        let entryIDs = Set(entries.compactMap { $0["id"] as? String })
        let lexemeKeyByEntryID = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (String, String)? in
            guard let entryID = entry["id"] as? String,
                  let lexemeKey = entry["lexemeKey"] as? String else { return nil }
            return (entryID, lexemeKey)
        })
        let lexemeKeysByRank = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (Int, String)? in
            guard let rank = entry["rank"] as? Int,
                  let lexemeKey = entry["lexemeKey"] as? String else { return nil }
            return (rank, lexemeKey)
        })
        let lexemeKeys = Set(lexemeKeyByEntryID.values)
        let mappings = Dictionary(uniqueKeysWithValues: (raw["existingCourseMappings"] as? [[String: Any]] ?? []).compactMap { mapping -> (String, String)? in
            guard let existing = mapping["existingVocabularyID"] as? String,
                  let canonical = mapping["canonicalLexemeID"] as? String else { return nil }
            return (existing, canonical)
        })
        return CanonicalCatalog(
            id: try XCTUnwrap(raw["id"] as? String),
            version: version,
            entryIDs: entryIDs,
            lexemeKeyByEntryID: lexemeKeyByEntryID,
            lexemeKeysByRank: lexemeKeysByRank,
            lexemeKeys: lexemeKeys,
            mappings: mappings
        )
    }

    private func canonicalIDs(
        in lessonIDs: [LessonID],
        snapshots: [CourseSnapshot],
        catalog: CanonicalCatalog
    ) throws -> Set<String> {
        let lessonsByID = Dictionary(uniqueKeysWithValues: snapshots.flatMap(\.lessons).map { ($0.id, $0) })
        var result = Set<String>()
        for lessonID in lessonIDs {
            let lesson = try XCTUnwrap(lessonsByID[lessonID], "Plan lesson \(lessonID.rawValue) must resolve")
            let raw = try rawLesson(lesson.id)
            let rawVocabulary = try XCTUnwrap(raw["vocabulary"] as? [[String: Any]])
            for entry in rawVocabulary {
                guard let vocabularyID = entry["id"] as? String else { continue }
                if let canonicalID = entry["canonicalID"] as? String,
                   catalog.lexemeKeys.contains(canonicalID) {
                    result.insert(canonicalID)
                } else if let canonicalID = catalog.canonicalKey(for: vocabularyID) {
                    result.insert(canonicalID)
                } else if let mappedID = catalog.mappings[vocabularyID],
                          let canonicalID = catalog.canonicalKey(for: mappedID) {
                    result.insert(canonicalID)
                }
            }
        }
        return result
    }

    func testEditorialMetadataDeclaresDynamicVocabularyReuseStagesAndVersions() async throws {
        let (index, snapshots) = try await allCourseSnapshots()
        var allStandardReferences: [(id: String, version: String)] = []

        for courseID in index.courseIDs {
            let courseJSON = try rawCourse(courseID)
            allStandardReferences.append(contentsOf: standardReferences(in: courseJSON))
            if let alignment = courseJSON["alignment"] as? [[String: Any]] {
                for reference in alignment {
                    let id = try XCTUnwrap(reference["standardID"] as? String)
                    let version = try XCTUnwrap(reference["standardVersion"] as? String)
                    assertNonEmpty(id, "course standard ID")
                    assertNonEmpty(version, "course standard version")
                }
            }
        }

        let hskReferences = allStandardReferences.filter {
            $0.id.lowercased().contains("hsk")
        }
        XCTAssertFalse(hskReferences.isEmpty, "The curriculum must declare an HSK reference with its version")
        let hasClassicReference = hskReferences.contains {
            let id = $0.id.lowercased()
            return (id.contains("classic") || id.contains("legacy")) && $0.version.contains("2.0")
        }
        XCTAssertTrue(hasClassicReference, "The HSK-classic/legacy 2.0 reference must remain explicit")
        let hasNewReference = hskReferences.contains {
            $0.id.lowercased().contains("3.0") && !$0.id.lowercased().contains("legacy")
        }
        XCTAssertTrue(hasNewReference, "The newer HSK 3.0 reference must remain distinct")

        for snapshot in snapshots {
            var introducedVocabulary = Set<VocabularyID>()
            for lesson in snapshot.lessons {
                let raw = try rawLesson(lesson.id)
                let metadata = try XCTUnwrap(raw["metadata"] as? [String: Any], "\(lesson.id.rawValue) needs editorial metadata")
                let references = standardReferences(in: metadata)
                XCTAssertFalse(references.isEmpty, "\(lesson.id.rawValue) needs an explicit standard and version")
                for reference in references {
                    assertNonEmpty(reference.id, "\(lesson.id.rawValue) standard ID")
                    assertNonEmpty(reference.version, "\(lesson.id.rawValue) standard version")
                }

                if metadata["standardID"] != nil || metadata["standardVersion"] != nil {
                    XCTAssertNotNil(metadata["standardID"] as? String)
                    XCTAssertNotNil(metadata["standardVersion"] as? String)
                }
                if metadata["legacyStandardID"] != nil || metadata["legacyStandardVersion"] != nil {
                    XCTAssertNotNil(metadata["legacyStandardID"] as? String)
                    XCTAssertNotNil(metadata["legacyStandardVersion"] as? String)
                }

                assertNonEmpty(metadata["levelID"] as? String, "\(lesson.id.rawValue) level")
                assertNonEmpty(metadata["sectionID"] as? String, "\(lesson.id.rawValue) section")
                assertNonEmpty(metadata["unitID"] as? String, "\(lesson.id.rawValue) unit")

                let newIDs = Set(try XCTUnwrap(metadata["newVocabularyIDs"] as? [String]).compactMap(VocabularyID.init(rawValue:)))
                let reusedIDs = Set(try XCTUnwrap(metadata["reusedVocabularyIDs"] as? [String]).compactMap(VocabularyID.init(rawValue:)))
                let localVocabularyIDs = Set(lesson.vocabulary.map(\.id))
                let extraIDs = Set((metadata["extraVocabularyIDs"] as? [String] ?? []).compactMap(VocabularyID.init(rawValue:)))
                XCTAssertEqual(metadata["newVocabularyCount"] as? Int, newIDs.count)
                XCTAssertTrue(newIDs.isSubset(of: localVocabularyIDs), "New vocabulary must be delivered by \(lesson.id.rawValue)")
                XCTAssertTrue(newIDs.isDisjoint(with: introducedVocabulary), "A vocabulary ID can be introduced only once")
                XCTAssertTrue(reusedIDs.isDisjoint(with: newIDs))
                XCTAssertTrue(reusedIDs.isSubset(of: introducedVocabulary), "Reused vocabulary in \(lesson.id.rawValue) must have appeared earlier")
                XCTAssertTrue(
                    localVocabularyIDs.subtracting(newIDs).subtracting(extraIDs).isSubset(of: introducedVocabulary),
                    "A non-new vocabulary object in \(lesson.id.rawValue) must be an actual earlier reuse or a declared extra"
                )
                introducedVocabulary.formUnion(newIDs)

                let blocks = try XCTUnwrap(raw["blocks"] as? [[String: Any]])
                var observedStages: [String] = []
                for block in blocks {
                    let blockMetadata = try XCTUnwrap(editorialMetadata(in: block), "\(lesson.id.rawValue) block needs metadata")
                    let stage = try XCTUnwrap(blockMetadata["stage"] as? String)
                    assertNonEmpty(stage, "\(lesson.id.rawValue) block stage")
                    observedStages.append(stage)
                    if let skills = blockMetadata["skill"] as? [String] {
                        XCTAssertFalse(skills.isEmpty)
                    } else if let skill = blockMetadata["skill"] as? String {
                        assertNonEmpty(skill, "\(lesson.id.rawValue) block skill")
                    }
                }
                XCTAssertEqual(observedStages.count, blocks.count)

                if let grammarPoints = raw["grammarPoints"] as? [[String: Any]] {
                    for grammarPoint in grammarPoints {
                        assertNonEmpty(grammarPoint["id"] as? String, "\(lesson.id.rawValue) grammar ID")
                        assertNonEmpty(grammarPoint["pattern"] as? String, "\(lesson.id.rawValue) grammar pattern")
                        if let function = grammarPoint["function"] as? String {
                            assertNonEmpty(function, "\(lesson.id.rawValue) grammar function")
                        }
                        if let variants = grammarPoint["acceptedVariants"] as? [String] {
                            XCTAssertFalse(variants.isEmpty)
                        }
                        if let errors = grammarPoint["errors"] as? [String] {
                            XCTAssertFalse(errors.isEmpty)
                        }
                        if let skills = grammarPoint["skills"] as? [String] {
                            XCTAssertFalse(skills.isEmpty)
                        } else if let skill = grammarPoint["skill"] as? [String] {
                            XCTAssertFalse(skill.isEmpty)
                        }
                    }
                }
            }
        }
    }

    private func standardReferences(in object: [String: Any]) -> [(id: String, version: String)] {
        var references: [(id: String, version: String)] = []
        func append(_ dictionary: [String: Any]) {
            if let id = dictionary["standardID"] as? String,
               let version = dictionary["standardVersion"] as? String {
                references.append((id: id, version: version))
            }
        }
        append(object)
        if let metadata = object["metadata"] as? [String: Any] {
            append(metadata)
        }
        for key in ["alignment", "alignments", "standards", "standardReferences"] {
            if let values = object[key] as? [[String: Any]] {
                values.forEach(append)
            }
        }
        return references
    }

    // MARK: Linguistic completeness

    func testEveryVocabularyEntryHasPinyinTonesScriptsMeaningAndAlignedSegments() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        var vocabularyByID: [VocabularyID: VocabularyEntry] = [:]
        for lesson in snapshots.flatMap(\.lessons) {
            for entry in lesson.vocabulary {
                if let previous = vocabularyByID[entry.id] {
                    XCTAssertEqual(previous, entry, "Reused vocabulary \(entry.id.rawValue) changed its canonical data")
                } else {
                    vocabularyByID[entry.id] = entry
                }
            }
        }

        XCTAssertFalse(vocabularyByID.isEmpty)
        for entry in vocabularyByID.values {
            assertNonEmpty(entry.id.rawValue, "vocabulary ID")
            assertNonEmpty(entry.hanzi, "\(entry.id.rawValue) hanzi")
            assertNonEmpty(entry.traditionalHanzi, "\(entry.id.rawValue) traditional hanzi")
            assertNonEmpty(entry.pinyin, "\(entry.id.rawValue) pinyin")
            XCTAssertFalse(entry.toneNumbers.isEmpty, "\(entry.id.rawValue) needs tone numbers")
            XCTAssertTrue(entry.toneNumbers.allSatisfy { (0...4).contains($0) }, "\(entry.id.rawValue) has an invalid tone")
            XCTAssertFalse(entry.segmentation.isEmpty, "\(entry.id.rawValue) needs segmentation")
            XCTAssertTrue(entry.segmentation.allSatisfy { !$0.surface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            assertNonEmpty(entry.meaning, "\(entry.id.rawValue) meaning")
            if let example = entry.example {
                assertNonEmpty(example.hanzi, "\(entry.id.rawValue) example hanzi")
                assertNonEmpty(example.pinyin, "\(entry.id.rawValue) example pinyin")
                assertNonEmpty(example.translation, "\(entry.id.rawValue) example translation")
            }
        }

        for lesson in snapshots.flatMap(\.lessons) {
            for block in lesson.blocks {
                guard case .reading(let reading) = block else { continue }
                for paragraph in reading.paragraphs {
                    for segment in paragraph.segmentation {
                        guard let vocabularyID = segment.vocabularyID,
                              let entry = vocabularyByID[vocabularyID],
                              let pinyin = segment.pinyin else { continue }
                        XCTAssertEqual(
                            TextNormalizer.normalize(pinyin),
                            TextNormalizer.normalize(entry.pinyin),
                            "Segment \(segment.surface) in \(paragraph.id) disagrees with \(vocabularyID.rawValue) pinyin"
                        )
                    }
                }
            }
        }
    }

    /// These pairs are kept as a narrow compatibility fixture for the first
    /// four lessons; newly authored content is checked by the dynamic test
    /// above rather than by extending this list.
    func testStarterFixturePinyinAndScriptPairsRemainStable() async throws {
        let content = store()
        let lessons = try await starterLessonIDs.asyncMap { try await content.lesson(id: $0) }
        let entries = lessons.flatMap(\.vocabulary)
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
        XCTAssertEqual(Set(entries.map(\.hanzi)), Set(expectedPairs.keys))
        for (hanzi, expected) in expectedPairs {
            let matches = entries.filter { $0.hanzi == hanzi }
            XCTAssertFalse(matches.isEmpty, "Starter vocabulary \(hanzi) is missing")
            XCTAssertTrue(matches.allSatisfy {
                $0.traditionalHanzi == expected.traditional &&
                    $0.pinyin == expected.pinyin &&
                    $0.toneNumbers == expected.tones
            })
        }
    }

    // MARK: Assets and engine evaluation

    func testDeliveredAssetsResolveAndMatchTheirDeclaredChecksums() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        var references: [AssetID: AssetReference] = [:]
        for lesson in snapshots.flatMap(\.lessons) {
            for reference in assetReferences(in: lesson) {
                if let previous = references[reference.id] {
                    XCTAssertEqual(previous, reference, "Asset \(reference.id.rawValue) changed its declared location or checksum")
                } else {
                    references[reference.id] = reference
                }
            }
        }
        let stories = try await store().stories()
        for story in stories {
            if let audio = story.audio { references[audio.id] = audio }
            for paragraph in story.paragraphs {
                if let audio = paragraph.audio { references[audio.id] = audio }
            }
        }

        for reference in references.values {
            do {
                let resolved = try await store().assetURL(for: reference)
                XCTAssertTrue(FileManager.default.fileExists(atPath: resolved.path))
                XCTAssertFalse(try Data(contentsOf: resolved).isEmpty, "Asset \(reference.id.rawValue) must not be empty")
            } catch {
                XCTFail("Delivered asset \(reference.id.rawValue) could not be verified: \(error)")
            }
        }
    }

    private func assetReferences(in lesson: LessonDocument) -> [AssetReference] {
        var references: [AssetReference] = []
        for entry in lesson.vocabulary {
            if let audio = entry.audio { references.append(audio) }
            if let audio = entry.example?.audio { references.append(audio) }
        }
        for card in lesson.cards {
            if let audio = card.front.audio { references.append(audio) }
            if let audio = card.back.audio { references.append(audio) }
        }
        for block in lesson.blocks {
            switch block {
            case .introduction(let value):
                if let audio = value.audio { references.append(audio) }
            case .dialogue(let value):
                references.append(contentsOf: value.lines.compactMap(\.audio))
            case .reading(let value):
                references.append(contentsOf: value.paragraphs.compactMap(\.audio))
            case .exercise(let value):
                switch value.spec {
                case .choice(let exercise):
                    references.append(contentsOf: exercise.choices.compactMap(\.audio))
                case .wordOrder(let exercise):
                    references.append(contentsOf: exercise.tokens.compactMap(\.audio))
                case .listeningChoice(let exercise):
                    if let audio = exercise.promptAudio { references.append(audio) }
                    references.append(contentsOf: exercise.choices.compactMap(\.audio))
                case .speaking(let exercise):
                    if let audio = exercise.referenceAudio { references.append(audio) }
                case .handwriting(let exercise):
                    references.append(exercise.guideAsset)
                case .fillBlank, .flashcard:
                    break
                }
            case .vocabulary, .recap:
                break
            }
        }
        return references
    }

    func testEveryDeliveredExerciseHasAnAnswerAcceptedByTheEngine() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        let engine = DefaultExerciseEngine()
        var evaluatedCount = 0

        for lesson in snapshots.flatMap(\.lessons) {
            for block in exerciseBlocks(in: lesson) {
                guard let answer = canonicalAnswer(for: block.spec) else {
                    XCTFail("The canonical answer for \(block.spec.id.rawValue) is not evaluable")
                    continue
                }
                let evaluation = engine.evaluate(spec: block.spec, answer: answer)
                XCTAssertTrue(evaluation.accepted, "The canonical answer for \(block.spec.id.rawValue) was rejected")
                XCTAssertEqual(evaluation.score, 1, accuracy: 0.000_001)
                XCTAssertEqual(evaluation.exerciseID, block.spec.id)
                evaluatedCount += 1
            }
        }

        XCTAssertGreaterThan(evaluatedCount, 0)
    }

    func testFillBlankSpeechSentencesKeepTheirBlanksAndCoverNewLessonContent() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        var fillBlankCount = 0
        var foundStarterFill = false
        var foundNewLessonFill = false
        var foundLatinPrefixFill77 = false
        var foundLatinPrefixFill80 = false

        for lesson in snapshots.flatMap(\.lessons) {
            for block in exerciseBlocks(in: lesson) {
                guard case .fillBlank(let exercise) = block.spec else { continue }
                fillBlankCount += 1
                let exerciseID = exercise.header.id.rawValue

                XCTAssertNotNil(
                    exercise.sentence.range(of: "_+", options: .regularExpression),
                    "Le fill doit conserver un trou visible : \(exerciseID)"
                )
                let answer = try XCTUnwrap(
                    exercise.canonicalSpeechAnswer,
                    "Le fill \(exerciseID) doit proposer une réponse Hanzi pour le TTS"
                )
                let placeholder = try XCTUnwrap(
                    exercise.sentence.range(of: "_+", options: .regularExpression),
                    "Le fill \(exerciseID) doit avoir un emplacement de réponse"
                )
                let completedSentence = exercise.sentence.replacingCharacters(in: placeholder, with: answer)
                let expectedSpeechSentence = MandarinSpeechText.target(from: completedSentence)
                XCTAssertFalse(expectedSpeechSentence.isEmpty, "Le fill \(exerciseID) doit avoir une cible TTS")
                let speechSentence = try XCTUnwrap(
                    exercise.canonicalSpeechSentence,
                    "Le fill \(exerciseID) doit avoir une phrase TTS canonique"
                )
                XCTAssertFalse(speechSentence.contains("_"), "La phrase TTS de \(exerciseID) doit compléter le trou")
                XCTAssertTrue(MandarinSpeechText.isTargetOnly(speechSentence), "La phrase TTS de \(exerciseID) doit rester en mandarin")
                XCTAssertEqual(
                    speechSentence,
                    expectedSpeechSentence,
                    "La phrase TTS de \(exerciseID) doit retirer seulement le texte non mandarin"
                )

                switch exerciseID {
                case "ex-l2-fill":
                    foundStarterFill = true
                    XCTAssertEqual(exercise.sentence, "我___安。")
                    XCTAssertEqual(exercise.canonicalSpeechAnswer, "叫")
                    XCTAssertEqual(exercise.canonicalSpeechSentence, "我叫安。")
                case "ex-l5-fill":
                    foundNewLessonFill = true
                    XCTAssertEqual(exercise.sentence, "你___茶吗？")
                    XCTAssertEqual(exercise.canonicalSpeechAnswer, "喝")
                    XCTAssertEqual(exercise.canonicalSpeechSentence, "你喝茶吗？")
                case "ex-l77-fill":
                    foundLatinPrefixFill77 = true
                    XCTAssertEqual(exercise.sentence, "Tao___今天先准备。")
                    XCTAssertEqual(exercise.canonicalSpeechAnswer, "决定")
                    XCTAssertEqual(exercise.canonicalSpeechSentence, "决定今天先准备。")
                case "ex-l80-fill":
                    foundLatinPrefixFill80 = true
                    XCTAssertEqual(exercise.sentence, "Tao___一袋米。")
                    XCTAssertEqual(exercise.canonicalSpeechAnswer, "拿")
                    XCTAssertEqual(exercise.canonicalSpeechSentence, "拿一袋米。")
                default:
                    break
                }
            }
        }

        XCTAssertGreaterThanOrEqual(fillBlankCount, 2, "Le catalogue doit contenir plusieurs exercices à trou")
        XCTAssertTrue(foundStarterFill, "Le fill de la leçon 2 doit être couvert")
        XCTAssertTrue(foundNewLessonFill, "Le fill d’une nouvelle leçon doit être couvert")
        XCTAssertTrue(foundLatinPrefixFill77, "Le fill latin de la leçon 77 doit être couvert")
        XCTAssertTrue(foundLatinPrefixFill80, "Le fill latin de la leçon 80 doit être couvert")
    }

    private func assertValidShape(_ spec: ExerciseSpec, cardIDs: Set<CardID>) {
        switch spec {
        case .choice(let exercise):
            XCTAssertFalse(exercise.choices.isEmpty)
            XCTAssertEqual(Set(exercise.choices.map(\.id)).count, exercise.choices.count)
            XCTAssertTrue(exercise.choices.allSatisfy { choice in
                !choice.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !choice.label.values.isEmpty
            })
            XCTAssertTrue(exercise.choices.contains { $0.id == exercise.correctChoiceID })
        case .wordOrder(let exercise):
            let tokenIDs = exercise.tokens.map(\.id)
            XCTAssertFalse(tokenIDs.isEmpty)
            XCTAssertEqual(Set(tokenIDs).count, tokenIDs.count)
            XCTAssertEqual(Set(tokenIDs), Set(exercise.correctOrder))
            XCTAssertEqual(tokenIDs.count, exercise.correctOrder.count)
            XCTAssertTrue(exercise.tokens.allSatisfy { token in
                !token.hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    !(token.pinyin?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            })
        case .fillBlank(let exercise):
            XCTAssertFalse(exercise.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(exercise.acceptedAnswers.isEmpty)
            XCTAssertTrue(exercise.acceptedAnswers.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        case .listeningChoice(let exercise):
            XCTAssertTrue(
                exercise.promptAudio != nil || !(exercise.promptText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                "A listening exercise needs a delivered recording or Mandarin prompt text"
            )
            XCTAssertFalse(exercise.choices.isEmpty)
            XCTAssertTrue(exercise.choices.contains { $0.id == exercise.correctChoiceID })
        case .speaking(let exercise):
            XCTAssertFalse(exercise.referenceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(exercise.referencePinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(exercise.allowSelfRating || !exercise.acceptedTranscripts.isEmpty)
            XCTAssertTrue(exercise.acceptedTranscripts.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        case .handwriting(let exercise):
            XCTAssertFalse(exercise.targetHanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(exercise.guideAsset.relativePath.isEmpty)
            XCTAssertTrue(exercise.expectedStrokeCount ?? 0 > 0 || exercise.allowSelfRating)
            XCTAssertEqual(exercise.guideAsset.kind, .handwritingGuide)
        case .flashcard(let exercise):
            XCTAssertTrue(cardIDs.contains(exercise.cardID))
        }
    }

    private func canonicalAnswer(for spec: ExerciseSpec) -> ExerciseAnswer? {
        switch spec {
        case .choice(let exercise):
            return .choice(choiceID: exercise.correctChoiceID)
        case .wordOrder(let exercise):
            return .wordOrder(tokenIDs: exercise.correctOrder)
        case .fillBlank(let exercise):
            guard let answer = exercise.acceptedAnswers.first else { return nil }
            return .text(answer)
        case .listeningChoice(let exercise):
            return .choice(choiceID: exercise.correctChoiceID)
        case .speaking(let exercise):
            if let transcript = exercise.acceptedTranscripts.first(where: {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
                return .speech(SpeechAnswer(transcript: transcript))
            }
            return exercise.allowSelfRating ? .selfRating(.easy) : nil
        case .handwriting(let exercise):
            return .handwriting(HandwritingAnswer(strokeCount: exercise.expectedStrokeCount ?? 0, selfChecked: true))
        case .flashcard:
            return .selfRating(.easy)
        }
    }

    // MARK: Effective reuse and exercise diversity

    func testExerciseFamiliesAndVocabularyReuseAreEffective() async throws {
        let (_, snapshots) = try await allCourseSnapshots()
        var familyCounts: [String: Int] = [:]
        var vocabularyByID: [VocabularyID: VocabularyEntry] = [:]
        for lesson in snapshots.flatMap(\.lessons) {
            for entry in lesson.vocabulary { vocabularyByID[entry.id] = entry }
            for exercise in exerciseBlocks(in: lesson) {
                familyCounts[exerciseFamily(exercise.spec), default: 0] += 1
            }
        }
        XCTAssertFalse(familyCounts.isEmpty)
        XCTAssertTrue(familyCounts.values.allSatisfy { $0 > 0 })

        for lesson in snapshots.flatMap(\.lessons) {
            let raw = try rawLesson(lesson.id)
            guard let metadata = raw["metadata"] as? [String: Any],
                  let reused = metadata["reusedVocabularyIDs"] as? [String] else {
                continue
            }
            let reusedIDs = Set(reused.compactMap(VocabularyID.init(rawValue:)))
            guard !reusedIDs.isEmpty else { continue }
            let effective = effectiveVocabularyIDs(in: lesson, vocabularyByID: vocabularyByID)
            XCTAssertFalse(
                effective.intersection(reusedIDs).isEmpty,
                "Reused vocabulary in \(lesson.id.rawValue) must occur in authored lesson material"
            )
        }
    }

    private func exerciseFamily(_ spec: ExerciseSpec) -> String {
        switch spec {
        case .choice: return "choice"
        case .wordOrder: return "wordOrder"
        case .fillBlank: return "fillBlank"
        case .listeningChoice: return "listeningChoice"
        case .speaking: return "speaking"
        case .handwriting: return "handwriting"
        case .flashcard: return "flashcard"
        }
    }

    private func effectiveVocabularyIDs(
        in lesson: LessonDocument,
        vocabularyByID: [VocabularyID: VocabularyEntry]
    ) -> Set<VocabularyID> {
        var used = Set<VocabularyID>()
        // Match only against the lesson's own vocabulary.  A global Hanzi
        // index can mark an unrelated entry as used when two lessons share a
        // surface form; the lesson-local object is the one the learner sees.
        let entries = lesson.vocabulary.map { vocabularyByID[$0.id] ?? $0 }
        var entriesByHanzi: [String: Set<VocabularyID>] = [:]
        for entry in entries where !entry.hanzi.isEmpty {
            entriesByHanzi[entry.hanzi, default: []].insert(entry.id)
            // Vocabulary cards render this example on their visible face.
            // It is authored context for this exact lexeme, unlike the
            // inventory and recap blocks, which only declare availability.
            if let example = entry.example,
               example.hanzi.contains(entry.hanzi) {
                used.insert(entry.id)
            }
        }
        for block in lesson.blocks {
            switch block {
            case .vocabulary, .recap:
                // These lists declare the lesson inventory. They are not
                // evidence that a reused lexeme was actually practiced.
                break
            case .reading(let value):
                for paragraph in value.paragraphs {
                    used.formUnion(paragraph.segmentation.compactMap(\.vocabularyID))
                }
            case .dialogue(let value):
                for line in value.lines {
                    for entry in entries where line.hanzi.contains(entry.hanzi) {
                        used.insert(entry.id)
                    }
                }
            case .exercise(let value):
                switch value.spec {
                case .wordOrder(let exercise):
                    for token in exercise.tokens {
                        used.formUnion(entriesByHanzi[token.hanzi] ?? [])
                    }
                case .speaking(let exercise):
                    for entry in entries where exercise.referenceText.contains(entry.hanzi) {
                        used.insert(entry.id)
                    }
                case .handwriting(let exercise):
                    for entry in entries where exercise.targetHanzi.contains(entry.hanzi) {
                        used.insert(entry.id)
                    }
                case .flashcard(let exercise):
                    if let card = lesson.cards.first(where: { $0.id == exercise.cardID }) {
                        used.insert(card.vocabularyID)
                    }
                default:
                    break
                }
            case .introduction:
                break
            }
        }
        return used
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
