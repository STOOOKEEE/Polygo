import Foundation
import XCTest

/// Starts after the protected starter lessons through the same JSONL journal
/// that the application uses, then exercises the first authored daily-plan
/// session through the macOS UI. The fixture represents four real
/// lessonCompleted events from an earlier visit; the bounded Debug import
/// only transfers that journal into the AUT sandbox.
final class MacDailyPlanJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private var app: XCUIApplication!
    private var profileID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        profileID = "ui-mac-daily-\(UUID().uuidString.lowercased())"
        let seedJournal = try makeSeedProgressAfterStarterLessons()

        app = XCUIApplication(bundleIdentifier: "com.syllune.PolygoMac")
        app.launchArguments = [
            "-syllune.profile.id", profileID,
            "-syllune.last.route", "today",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-syllune.appearance", "dark",
            "-syllune.reduceMotion", "true"
        ]
        // The bounded DEBUG hook imports this into the app's own persistence
        // container before AppModel loads, which also makes the fixture work
        // when the UI runner and the AUT have different sandboxes.
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

        let dayOne = label(containing: "Jour 1 sur 90")
        XCTAssertTrue(dayOne.waitForExistence(timeout: timeout), "Aujourd’hui doit afficher J1/90")
        XCTAssertTrue(label(containing: "minutes de cours").waitForExistence(timeout: timeout), "Aujourd’hui doit afficher le budget de cours")
        XCTAssertTrue(label(containing: "minutes de révision").waitForExistence(timeout: timeout), "Aujourd’hui doit afficher le budget de révision")
        // Keep relaunches focused on the durable events produced by the app.
        app.launchEnvironment.removeValue(forKey: "SYLLUNE_PROGRESS_FIXTURE_JSONL")
        attachScreenshot(named: "mac-daily-plan-day-one")

        // AppKit exposes the accessibility identifier applied to the hero
        // container as the tappable button. The nested NavigationLink keeps
        // its iOS identifier, but is not a separate macOS accessibility node.
        let openLesson = button(identifier: "home.hero")
        XCTAssertTrue(openLesson.waitForExistence(timeout: timeout), "Aujourd’hui doit proposer la séance du jour")
        XCTAssertTrue(openLesson.isHittable, "L’action de la séance du jour doit être accessible")
        openLesson.click()

        let listeningExercise = app.staticTexts.matching(
            identifier: "lesson.exercise.ex-l5-listen"
        ).firstMatch
        XCTAssertTrue(listeningExercise.waitForExistence(timeout: timeout), "La séance 1 du programme doit ouvrir l’écoute de L5")
        let play = app.buttons.matching(
            NSPredicate(format: "label == %@", "Écouter le mot")
        ).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: timeout), "L’écoute TTS doit être actionnable")
        XCTAssertTrue(play.isHittable, "Le contrôle TTS doit être visible")
        play.click()
        XCTAssertTrue(
            text(containingAny: ["Lecture terminée", "Audio indisponible"]).waitForExistence(timeout: timeout),
            "Le contrôle TTS doit exposer un état observable"
        )
        attachScreenshot(named: "mac-daily-plan-lesson-five-listening")

        // The listening fixture deliberately begins at a stable exercise ID,
        // while the choice itself remains a normal learner interaction.
        let answerLabel = listeningChoice.label["fr"] ?? listeningChoice.label.values.first ?? ""
        let answer = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", answerLabel)).firstMatch
        XCTAssertTrue(answer.waitForExistence(timeout: timeout), "La réponse de l’écoute doit être proposée")
        answer.click()
        let verify = app.buttons.matching(NSPredicate(format: "label == %@", "Vérifier")).firstMatch
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "La réponse d’écoute doit pouvoir être enregistrée")
        XCTAssertTrue(verify.isEnabled, "Une réponse choisie doit activer l’enregistrement")
        verify.click()
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "La réponse d’écoute doit être évaluée")
        app.buttons.matching(NSPredicate(format: "label == %@", "Continuer")).firstMatch.click()

        // The listening evaluation and the following position must survive a
        // process restart before the rest of the session is completed.
        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l5-speak").firstMatch.waitForExistence(timeout: timeout),
            "La reprise doit retrouver l’activité orale après l’écoute validée"
        )

        // The next authored activity is optional oral practice. Passing it
        // preserves the valid offline progression path while keeping the
        // listening answer above a real scored interaction.
        let skipOral = app.buttons.matching(NSPredicate(format: "label == %@", "Passer sans évaluer")).firstMatch
        XCTAssertTrue(skipOral.waitForExistence(timeout: timeout), "L’oral optionnel doit rester franchissable hors ligne")
        skipOral.click()
        let continueAnyway = app.buttons.matching(NSPredicate(format: "label == %@", "Continuer malgré tout")).firstMatch
        XCTAssertTrue(continueAnyway.waitForExistence(timeout: timeout), "Le passage oral doit conserver la progression")
        continueAnyway.click()

        let readingDisclosure = app.descendants(matching: .disclosureTriangle).matching(
            NSPredicate(format: "identifier == %@", "lesson.reading.\(readingBlock.id)")
        ).firstMatch
        XCTAssertTrue(readingDisclosure.waitForExistence(timeout: timeout), "Le texte associé doit être relisible dans la question")
        XCTAssertTrue(readingDisclosure.isHittable, "Le contrôle de relecture doit être accessible")
        readingDisclosure.click()
        for paragraph in readingParagraphs {
            assertReadingParagraph(paragraph)
        }
        attachScreenshot(named: "mac-daily-plan-lesson-five-reading-open")
        readingDisclosure.click()

        let readingLabel = readingChoice.label["fr"] ?? readingChoice.label.values.first ?? ""
        let readingAnswer = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", readingLabel)).firstMatch
        XCTAssertTrue(readingAnswer.waitForExistence(timeout: timeout), "La compréhension de lecture de L5 doit être disponible")
        readingAnswer.click()
        let finalVerify = app.buttons.matching(NSPredicate(format: "label == %@", "Vérifier")).firstMatch
        XCTAssertTrue(finalVerify.waitForExistence(timeout: timeout), "La compréhension doit pouvoir être enregistrée")
        finalVerify.click()
        let finish = app.buttons.matching(NSPredicate(format: "label == %@", "Terminer")).firstMatch
        XCTAssertTrue(finish.waitForExistence(timeout: timeout), "La dernière activité doit proposer Terminer")
        finish.click()

        XCTAssertTrue(text(containing: "Leçon terminée").waitForExistence(timeout: timeout), "La séance terminée doit être confirmée")
        let path = app.buttons.matching(NSPredicate(format: "label == %@", "Retour au parcours")).firstMatch
        XCTAssertTrue(path.waitForExistence(timeout: timeout), "Le bilan doit revenir au parcours")
        path.click()
        XCTAssertTrue(text(containing: "Parcours").waitForExistence(timeout: timeout), "Le retour doit afficher le parcours")
        attachScreenshot(named: "mac-daily-plan-path-after-day-one")

        selectSidebarItem("Aujourd’hui")
        let dayTwo = label(containing: "Jour 2 sur 90")
        XCTAssertTrue(dayTwo.waitForExistence(timeout: timeout), "La complétion de L5 doit faire progresser le programme à J2")
        attachScreenshot(named: "mac-daily-plan-day-two")
    }

    private func selectSidebarItem(_ label: String) {
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", label))
        _ = buttons.firstMatch.waitForExistence(timeout: timeout)
        for index in 0..<buttons.count {
            let candidate = buttons.element(boundBy: index)
            if candidate.waitForExistence(timeout: 2), candidate.isHittable {
                candidate.click()
                return
            }
        }
        XCTFail("Navigation absente : \(label)")
    }

    private func button(identifier: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    private func label(containing value: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", value))
            .firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", value, value)
        ).firstMatch
    }

    private func text(containingAny values: [String]) -> XCUIElement {
        let predicates = values.flatMap { value in
            [
                NSPredicate(format: "value CONTAINS[c] %@", value),
                NSPredicate(format: "label CONTAINS[c] %@", value)
            ]
        }
        return app.staticTexts
            .matching(NSCompoundPredicate(orPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    private func assertReadingParagraph(_ paragraph: DailyReadingParagraphFixture) {
        let hanzi = label(containing: paragraph.hanzi)
        if !hanzi.waitForExistence(timeout: 2) {
            // ChineseSelectableText exposes one accessible token per character
            // when the paragraph is tokenized. The pinyin and translation below
            // still identify the complete paragraph without depending on that
            // platform-specific grouping.
            for character in paragraph.hanzi where !character.isWhitespace && !character.isPunctuation {
                XCTAssertTrue(
                    label(containing: String(character)).waitForExistence(timeout: timeout),
                    "Le caractère \(character) du paragraphe \(paragraph.id) doit être visible"
                )
            }
        }
        XCTAssertTrue(
            text(containing: paragraph.pinyin).waitForExistence(timeout: timeout),
            "Le pinyin du paragraphe \(paragraph.id) doit être visible"
        )
        let translation = paragraph.translation["fr"] ?? paragraph.translation.values.first ?? ""
        XCTAssertTrue(
            text(containing: translation).waitForExistence(timeout: timeout),
            "La traduction du paragraphe \(paragraph.id) doit être visible"
        )
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
            "displayName": "Daily Mac",
            "startingLevel": "beginner"
        ]

        var events: [[String: Any]] = [event(
            id: "mac-daily-onboarding",
            lamport: 1,
            occurredAt: now,
            payload: ["kind": "onboardingCompleted", "profile": learnerProfile]
        )]
        for (offset, lessonID) in ["lesson-01", "lesson-02", "lesson-03", "lesson-04"].enumerated() {
            events.append(event(
                id: "mac-daily-\(lessonID)-completed",
                lamport: offset + 2,
                occurredAt: now + Double(offset + 1),
                payload: ["kind": "lessonCompleted", "lessonID": lessonID, "at": now + Double(offset + 1)]
            ))
        }
        events.append(event(
            id: "mac-daily-l5-started",
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
                id: "mac-daily-\(exerciseID)-accepted",
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
            id: "mac-daily-l5-listening-checkpoint",
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
            "deviceID": "mac-daily-ui-test",
            "lamport": lamport,
            "occurredAt": occurredAt,
            "schemaVersion": 1,
            "payload": payload
        ]
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
        for bundle in [Bundle(for: MacDailyPlanJourneyTests.self), Bundle.main] {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: directory) {
                return url
            }
            if let url = bundle.url(forResource: fileName, withExtension: "json") {
                return url
            }
        }
        throw NSError(domain: "MacDailyPlanJourneyTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Fixture introuvable : \(relativePath)"
        ])
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
