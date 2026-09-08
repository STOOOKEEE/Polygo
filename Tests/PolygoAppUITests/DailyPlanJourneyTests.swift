import Foundation
import XCTest

/// Covers the first authored programme session on iPhone after the four
/// protected starter lessons. Progress is passed as the same JSONL event
/// journal used by the app and imported by the bounded Debug fixture hook;
/// all post-seed answers go through the real UI.
final class DailyPlanJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private var app: XCUIApplication!
    private var profileID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        profileID = "ui-ios-daily-\(UUID().uuidString.lowercased())"
        let seedJournal = try makeSeedProgressAfterStarterLessons()
        app = XCUIApplication()
        app.launchArguments = [
            "-syllune.profile.id", profileID,
            "-syllune.last.route", "today",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-syllune.appearance", "dark",
            "-syllune.reduceMotion", "true"
        ]
        // The UI-test runner has a different sandbox from the application.
        // AppDependencies imports this complete journal into the app's own
        // Application Support directory during the first Debug launch.
        app.launchEnvironment["SYLLUNE_PROGRESS_FIXTURE_JSONL"] = String(decoding: seedJournal, as: UTF8.self)
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testDailyPlanOpensLessonFivePersistsListeningAnswerAndAdvancesToDayTwo() throws {
        let lesson = try loadLessonFixture()
        let listening = try XCTUnwrap(
            lesson.exercises.first(where: { $0.header.id == "ex-l5-listen" }),
            "L5 doit conserver l’activité d’écoute stable"
        )
        let listeningChoice = try XCTUnwrap(
            listening.choices?.first(where: { $0.id == listening.correctChoiceID }),
            "La réponse de l’écoute doit exister dans le fixture"
        )
        let reading = try XCTUnwrap(
            lesson.exercises.first(where: { $0.header.id == "ex-l5-reading" }),
            "L5 doit conserver la compréhension de lecture stable"
        )
        let readingBlock = try XCTUnwrap(
            lesson.blocks.first(where: { block in
                block.kind == "reading" &&
                    (block.comprehensionExerciseIDs ?? []).contains(reading.header.id)
            }),
            "Le texte de L5 doit référencer la question de compréhension"
        )
        let readingParagraphs = try XCTUnwrap(
            readingBlock.paragraphs,
            "Le texte de L5 doit conserver ses paragraphes"
        )
        let readingChoice = try XCTUnwrap(
            reading.choices?.first(where: { $0.id == reading.correctChoiceID }),
            "La réponse de lecture doit exister dans le fixture"
        )
        XCTAssertEqual(readingParagraphs.count, 2, "Le texte de L5 doit proposer deux paragraphes")
        XCTAssertEqual(
            Array(lesson.exercises.map(\.header.id).prefix(4)),
            ["ex-l5-meaning", "ex-l5-order", "ex-l5-fill", "ex-l5-listen"],
            "L5 doit conserver l’ordre contractuel jusqu’à l’écoute"
        )

        XCTAssertTrue(
            element(containing: "Jour 1 sur 90").waitForExistence(timeout: timeout),
            "Aujourd’hui doit afficher J1/90"
        )
        XCTAssertTrue(
            element(containing: "minutes de cours").waitForExistence(timeout: timeout),
            "Aujourd’hui doit afficher le budget de cours"
        )
        XCTAssertTrue(
            element(containing: "minutes de révision").waitForExistence(timeout: timeout),
            "Aujourd’hui doit afficher le budget de révision"
        )
        // The fixture has been consumed before the Today content becomes
        // visible. Remove it so every later launch in this journey reads only
        // the journal that the application has persisted.
        app.launchEnvironment.removeValue(forKey: "SYLLUNE_PROGRESS_FIXTURE_JSONL")
        attachScreenshot(named: "ios-daily-plan-day-one")

        let openLesson = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "home.hero")
        ).firstMatch
        XCTAssertTrue(openLesson.waitForExistence(timeout: timeout), "Aujourd’hui doit proposer la séance du jour")
        XCTAssertTrue(openLesson.isHittable, "L’action de la séance du jour doit être accessible")
        openLesson.tap()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l5-listen").firstMatch.waitForExistence(timeout: timeout),
            "La séance doit reprendre sur l’écoute de L5"
        )
        let play = button(exactly: "Écouter le mot")
        XCTAssertTrue(play.waitForExistence(timeout: timeout), "L’écoute TTS doit être actionnable")
        XCTAssertTrue(play.isHittable, "Le contrôle TTS doit être visible")
        play.tap()
        XCTAssertTrue(
            element(containingAny: ["Lecture terminée", "Audio indisponible"]).waitForExistence(timeout: timeout),
            "Le contrôle TTS doit exposer un état observable"
        )
        attachScreenshot(named: "ios-daily-plan-lesson-five-listening")

        let answerLabel = listeningChoice.label["fr"] ?? listeningChoice.label.values.first ?? ""
        let answer = element(containing: answerLabel, type: .button)
        XCTAssertTrue(answer.waitForExistence(timeout: timeout), "La bonne réponse de l’écoute doit être proposée")
        answer.tap()
        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "La réponse d’écoute doit pouvoir être enregistrée")
        XCTAssertTrue(verify.isEnabled, "Une réponse choisie doit activer l’enregistrement")
        verify.tap()
        XCTAssertTrue(element(containing: "Correct").waitForExistence(timeout: timeout), "La réponse d’écoute doit être évaluée")
        button(exactly: "Continuer").tap()
        let oralExercise = app.staticTexts.matching(
            identifier: "lesson.exercise.ex-l5-speak"
        ).firstMatch
        XCTAssertTrue(oralExercise.waitForExistence(timeout: timeout), "L’avancement doit afficher l’activité orale")

        // The listening evaluation and the following position must survive a
        // process restart before the rest of the session is completed.
        // Remove the bootstrap route override so the relaunch reads the
        // lesson route persisted by the application.
        app.launchArguments.removeAll { $0 == "-syllune.last.route" || $0 == "today" }
        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l5-speak").firstMatch.waitForExistence(timeout: timeout),
            "La reprise doit retrouver l’activité orale après l’écoute validée"
        )

        let skipOral = button(exactly: "Passer sans évaluer")
        XCTAssertTrue(skipOral.waitForExistence(timeout: timeout), "L’oral optionnel doit rester franchissable hors ligne")
        skipOral.tap()
        let continueAnyway = button(exactly: "Continuer malgré tout")
        XCTAssertTrue(continueAnyway.waitForExistence(timeout: timeout), "Le passage oral doit conserver la progression")
        continueAnyway.tap()

        let readingDisclosure = app.buttons.matching(
            NSPredicate(format: "identifier == %@", "lesson.reading.\(readingBlock.id)")
        ).firstMatch
        XCTAssertTrue(readingDisclosure.waitForExistence(timeout: timeout), "Le texte associé doit être relisible dans la question")
        XCTAssertTrue(readingDisclosure.isHittable, "Le contrôle de relecture doit être accessible")
        readingDisclosure.tap()
        for paragraph in readingParagraphs {
            assertReadingParagraph(paragraph)
        }
        attachScreenshot(named: "ios-daily-plan-lesson-five-reading-open")
        readingDisclosure.tap()

        let readingLabel = readingChoice.label["fr"] ?? readingChoice.label.values.first ?? ""
        let readingAnswer = element(containing: readingLabel, type: .button)
        XCTAssertTrue(readingAnswer.waitForExistence(timeout: timeout), "La compréhension de lecture doit être disponible")
        readingAnswer.tap()
        let finalVerify = button(exactly: "Vérifier")
        XCTAssertTrue(finalVerify.waitForExistence(timeout: timeout), "La compréhension doit pouvoir être enregistrée")
        finalVerify.tap()
        let finish = button(exactly: "Terminer")
        XCTAssertTrue(finish.waitForExistence(timeout: timeout), "La dernière activité doit proposer Terminer")
        finish.tap()

        XCTAssertTrue(element(containing: "Leçon terminée").waitForExistence(timeout: timeout), "La séance terminée doit être confirmée")
        let path = button(exactly: "Retour au parcours")
        XCTAssertTrue(path.waitForExistence(timeout: timeout), "Le bilan doit revenir au parcours")
        path.tap()
        XCTAssertTrue(element(containing: "Parcours").waitForExistence(timeout: timeout), "Le retour doit afficher le parcours")
        attachScreenshot(named: "ios-daily-plan-path-after-day-one")

        let today = app.tabBars.buttons["Aujourd’hui"]
        XCTAssertTrue(today.waitForExistence(timeout: timeout), "Le tab Aujourd’hui doit rester accessible")
        today.tap()
        XCTAssertTrue(element(containing: "Jour 2 sur 90").waitForExistence(timeout: timeout), "La séance suivante doit être J2")
        attachScreenshot(named: "ios-daily-plan-day-two")
    }

    private func element(containing value: String, type: XCUIElement.ElementType = .any) -> XCUIElement {
        app.descendants(matching: type)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", value))
            .firstMatch
    }

    private func element(containingAny values: [String]) -> XCUIElement {
        let predicate = values.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: predicate))
            .firstMatch
    }

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func assertReadingParagraph(_ paragraph: DailyReadingParagraphFixture) {
        let hanzi = element(containing: paragraph.hanzi)
        if !hanzi.waitForExistence(timeout: 2) {
            // ChineseSelectableText exposes one accessible token per character
            // when the paragraph is tokenized. The pinyin and translation below
            // still identify the complete paragraph without depending on that
            // platform-specific grouping.
            for character in paragraph.hanzi where !character.isWhitespace && !character.isPunctuation {
                XCTAssertTrue(
                    element(containing: String(character)).waitForExistence(timeout: timeout),
                    "Le caractère \(character) du paragraphe \(paragraph.id) doit être visible"
                )
            }
        }
        XCTAssertTrue(
            element(containing: paragraph.pinyin).waitForExistence(timeout: timeout),
            "Le pinyin du paragraphe \(paragraph.id) doit être visible"
        )
        let translation = paragraph.translation["fr"] ?? paragraph.translation.values.first ?? ""
        XCTAssertTrue(
            element(containing: translation).waitForExistence(timeout: timeout),
            "La traduction du paragraphe \(paragraph.id) doit être visible"
        )
    }

    private func loadLessonFixture() throws -> DailyLessonFixture {
        let data = try Data(contentsOf: contentURL(relativePath: "lessons/lesson-05.json"))
        return try JSONDecoder().decode(DailyLessonFixture.self, from: data)
    }

    private func contentURL(relativePath: String) throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceCandidate = repositoryRoot.appendingPathComponent("Content", isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: false)
        if FileManager.default.fileExists(atPath: sourceCandidate.path) {
            return sourceCandidate
        }
        let fileName = URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
        let directory = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
        for bundle in [Bundle(for: DailyPlanJourneyTests.self), Bundle.main] {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: directory) {
                return url
            }
            if let url = bundle.url(forResource: fileName, withExtension: "json") {
                return url
            }
        }
        throw NSError(domain: "DailyPlanJourneyTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Fixture introuvable : \(relativePath)"
        ])
    }

    private func makeSeedProgressAfterStarterLessons() throws -> Data {
        let now = Date().timeIntervalSinceReferenceDate
        let lessonFixture = try loadLessonFixture()
        let learnerProfile: [String: Any] = [
            "id": profileID,
            "nativeLanguage": "fr",
            "goal": "conversation",
            "dailyMinutes": 15,
            "selectedCourseID": "mandarin-starter",
            "preferences": [
                "interfaceLanguage": "fr",
                "script": "simplified",
                "preferredSpeechLocale": "zh-CN",
                "audioSpeed": 1.0,
                "showPinyin": true,
                "autoPlayAudio": false,
                "reminderDays": [1, 2, 3, 4, 5, 6, 7],
                "appearance": "dark",
                "reduceMotion": true
            ],
            "createdAt": now,
            "displayName": "Daily iPhone",
            "startingLevel": "beginner"
        ]
        var events: [[String: Any]] = [event(
            id: "ios-daily-onboarding",
            lamport: 1,
            occurredAt: now,
            payload: ["kind": "onboardingCompleted", "profile": learnerProfile]
        )]
        for (offset, lessonID) in ["lesson-01", "lesson-02", "lesson-03", "lesson-04"].enumerated() {
            events.append(event(
                id: "ios-daily-\(lessonID)-completed",
                lamport: offset + 2,
                occurredAt: now + Double(offset + 1),
                payload: ["kind": "lessonCompleted", "lessonID": lessonID, "at": now + Double(offset + 1)]
            ))
        }
        events.append(event(
            id: "ios-daily-l5-started",
            lamport: 6,
            occurredAt: now + 5,
            payload: ["kind": "lessonStarted", "lessonID": "lesson-05", "at": now + 5]
        ))
        for (offset, exerciseID) in [
            (0, "ex-l5-meaning"),
            (1, "ex-l5-order"),
            (2, "ex-l5-fill")
        ] {
            let blockID = try XCTUnwrap(
                lessonFixture.blocks.first(where: { $0.kind == "exercise" && $0.spec?.header.id == exerciseID })?.id,
                "Le blockID de \(exerciseID) doit exister dans le pack"
            )
            events.append(event(
                id: "ios-daily-\(exerciseID)-accepted",
                lamport: offset + 7,
                occurredAt: now + Double(offset + 6),
                payload: [
                    "kind": "exerciseEvaluated",
                    "lessonID": "lesson-05",
                    "blockID": blockID,
                    "evaluation": [
                        "exerciseID": exerciseID,
                        "outcome": "correct",
                        "score": 1.0,
                        "feedback": ["fr": "Correct"],
                        "accepted": true,
                        "normalizedAnswer": exerciseID
                    ],
                    "at": now + Double(offset + 6)
                ]
            ))
        }
        events.append(event(
            id: "ios-daily-l5-listening-checkpoint",
            lamport: 10,
            occurredAt: now + 9,
            payload: [
                "kind": "lessonCheckpointSaved",
                "lessonID": "lesson-05",
                "exerciseIndex": 3,
                "exerciseID": "ex-l5-listen",
                "at": now + 9
            ]
        ))

        var journal = Data()
        for value in events {
            journal.append(try JSONSerialization.data(withJSONObject: value))
            journal.append(0x0A)
        }
        return journal
    }

    private func event(id: String, lamport: Int, occurredAt: Double, payload: [String: Any]) -> [String: Any] {
        [
            "eventID": id,
            "profileID": profileID,
            "deviceID": "ios-daily-ui-test",
            "lamport": lamport,
            "occurredAt": occurredAt,
            "schemaVersion": 1,
            "payload": payload
        ]
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct DailyLessonFixture: Decodable {
    let blocks: [DailyBlockFixture]

    var exercises: [DailyExerciseFixture] {
        blocks.compactMap { block in
            guard block.kind == "exercise" else { return nil }
            return block.spec
        }
    }
}

private struct DailyBlockFixture: Decodable {
    let id: String
    let kind: String
    let spec: DailyExerciseFixture?
    let paragraphs: [DailyReadingParagraphFixture]?
    let comprehensionExerciseIDs: [String]?
}

private struct DailyReadingParagraphFixture: Decodable {
    let id: String
    let hanzi: String
    let pinyin: String
    let translation: [String: String]
}

private struct DailyExerciseFixture: Decodable {
    let kind: String
    let header: DailyHeaderFixture
    let choices: [DailyChoiceFixture]?
    let correctChoiceID: String?
}

private struct DailyHeaderFixture: Decodable {
    let id: String
}

private struct DailyChoiceFixture: Decodable {
    let id: String
    let label: [String: String]
}
