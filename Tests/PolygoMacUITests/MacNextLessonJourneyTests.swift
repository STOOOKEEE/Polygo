import Foundation
import XCTest

/// Opens the next lesson from Parcours right after a finished lesson recap.
/// A lesson that the learner never worked through must start on its intro,
/// never on a recap inherited from the previous lesson or from an empty
/// terminal checkpoint.
final class MacNextLessonJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private var app: XCUIApplication!
    private var profileID = ""

    private let lessonTwoExercises: [(blockID: String, exerciseID: String)] = [
        ("block-l2-ex-tone", "ex-l2-tone"),
        ("block-l2-ex-meaning", "ex-l2-meaning"),
        ("block-l2-ex-order", "ex-l2-order"),
        ("block-l2-ex-fill", "ex-l2-fill"),
        ("block-l2-ex-reading", "ex-l2-reading-name"),
        ("block-l2-ex-speak", "ex-l2-speak"),
        ("block-l2-ex-write", "ex-l2-write")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        profileID = "ui-mac-next-\(UUID().uuidString.lowercased())"
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testNextLessonOpensOnItsSituationAfterReturningFromFinishedRecap() throws {
        launch(seeding: try journal(lessonThreeTerminalCheckpoint: false))
        openPath()

        openLesson("lesson-02")
        XCTAssertTrue(text(containing: "Leçon terminée").waitForExistence(timeout: timeout), "L2 terminée doit rouvrir son bilan")
        XCTAssertTrue(text(containing: "7 / 7").waitForExistence(timeout: timeout), "Le bilan L2 doit compter ses sept exercices réussis")
        let back = app.buttons.matching(NSPredicate(format: "label == %@", "Retour au parcours")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: timeout), "Le bilan doit proposer le retour au parcours")
        back.click()

        openLesson("lesson-03")
        assertLessonThreeStartsOnItsSituation()
    }

    func testFinishedRecapListsItsWordsAndContinuesToTheNextLesson() throws {
        launch(seeding: try journal(lessonThreeTerminalCheckpoint: false))
        openPath()

        openLesson("lesson-02")
        XCTAssertTrue(text(containing: "Leçon terminée").waitForExistence(timeout: timeout), "L2 terminée doit rouvrir son bilan")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "Mots appris")).firstMatch.waitForExistence(timeout: timeout),
            "Le bilan L2 doit lister ses mots appris"
        )
        attachScreenshot(named: "mac-lesson-completion")
        let next = app.buttons.matching(NSPredicate(format: "label == %@", "Continuer vers la leçon suivante")).firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: timeout), "Le bilan doit proposer la leçon suivante")
        next.click()

        assertLessonThreeStartsOnItsSituation()
    }

    func testUnfinishedLessonSavedAtTheEndWithoutAnswersOpensOnItsSituation() throws {
        // Earlier builds could persist this terminal checkpoint for a lesson
        // the learner never answered.
        launch(seeding: try journal(lessonThreeTerminalCheckpoint: true))
        openPath()

        openLesson("lesson-03")
        assertLessonThreeStartsOnItsSituation()
    }

    private func assertLessonThreeStartsOnItsSituation() {
        let situation = app.staticTexts.matching(identifier: "lesson.step.teaching.block-l3-introduction").firstMatch
        XCTAssertTrue(situation.waitForExistence(timeout: timeout), "L3 jamais commencée doit s’ouvrir sur sa situation")
        XCTAssertFalse(text(containing: "Leçon enregistrée").exists, "L3 ne doit pas afficher de bilan")
        XCTAssertFalse(text(containing: "Leçon terminée").exists, "L3 ne doit pas hériter du bilan de L2")
        attachScreenshot(named: "mac-next-lesson-intro")
        let next = app.buttons.matching(NSPredicate(format: "identifier == %@", "lesson.step.continue")).firstMatch
        var remaining = 8
        while remaining > 0, next.exists {
            next.click()
            remaining -= 1
            _ = app.staticTexts.matching(identifier: "lesson.exercise.ex-l3-tone").firstMatch.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l3-tone").firstMatch.waitForExistence(timeout: timeout),
            "Les mots de L3 doivent mener à son premier exercice"
        )
    }

    private func launch(seeding journal: Data) {
        app = XCUIApplication(bundleIdentifier: "com.syllune.PolygoMac")
        app.launchArguments = [
            // Windows restored from an earlier journey would duplicate the chrome.
            "-ApplePersistenceIgnoreState", "YES",
            "-syllune.profile.id", profileID,
            "-syllune.last.route", "path",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-syllune.appearance", "dark",
            "-syllune.reduceMotion", "true"
        ]
        // The bounded DEBUG hook imports this into the app's own persistence
        // container before AppModel loads.
        app.launchEnvironment["SYLLUNE_PROGRESS_FIXTURE_JSONL"] = String(decoding: journal, as: UTF8.self)
        app.launch()
    }

    private func openPath() {
        let pathItem = app.buttons["BottomTab.path"]
        XCTAssertTrue(pathItem.waitForExistence(timeout: timeout), "Le parcours macOS doit être visible")
        pathItem.click()
    }

    private func openLesson(_ lessonID: String) {
        let node = app.buttons.matching(
            NSPredicate(format: "identifier == %@", "learningPath.lesson.\(lessonID)")
        ).firstMatch
        XCTAssertTrue(node.waitForExistence(timeout: timeout), "\(lessonID) doit être déverrouillée dans le parcours")
        XCTAssertTrue(scrollIntoView(node), "\(lessonID) doit être visible dans le parcours")
        node.click()
    }

    /// The active Path destination owns one vertical scroll view. Scroll its
    /// visible content until the target fits; macOS can report a partially
    /// clipped control as hittable.
    private func scrollIntoView(_ element: XCUIElement) -> Bool {
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: timeout) else { return false }
        for _ in 0..<12 {
            let elementFrame = element.frame
            let viewport = scrollView.frame
            if element.isHittable && viewport.contains(elementFrame) {
                return true
            }
            if elementFrame.minY < viewport.minY {
                scrollView.scroll(byDeltaX: 0, deltaY: 500)
            } else {
                scrollView.scroll(byDeltaX: 0, deltaY: -500)
            }
        }
        return element.isHittable && scrollView.frame.contains(element.frame)
    }

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", value, value)
        ).firstMatch
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// L1 and L2 are completed through the same events as a real session:
    /// L2 has its seven evaluations and its terminal checkpoint, so reopening
    /// it restores the finished recap.
    private func journal(lessonThreeTerminalCheckpoint: Bool) throws -> Data {
        let now = Date().timeIntervalSinceReferenceDate
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
            "displayName": "Mac UI",
            "startingLevel": "beginner"
        ]

        var events: [[String: Any]] = []
        func append(_ id: String, _ payload: [String: Any]) {
            let lamport = events.count + 1
            events.append([
                "eventID": "mac-next-\(id)",
                "profileID": profileID,
                "deviceID": "mac-next-ui-test",
                "lamport": lamport,
                "occurredAt": now + Double(lamport),
                "schemaVersion": 1,
                "payload": payload
            ])
        }

        append("onboarding", ["kind": "onboardingCompleted", "profile": learnerProfile])
        append("l1-completed", ["kind": "lessonCompleted", "lessonID": "lesson-01", "at": now + 2])
        append("l2-started", ["kind": "lessonStarted", "lessonID": "lesson-02", "at": now + 3])
        for exercise in lessonTwoExercises {
            append("\(exercise.exerciseID)-accepted", [
                "kind": "exerciseEvaluated",
                "lessonID": "lesson-02",
                "blockID": exercise.blockID,
                "evaluation": [
                    "exerciseID": exercise.exerciseID,
                    "outcome": "correct",
                    "score": 1.0,
                    "feedback": ["fr": "Correct"],
                    "accepted": true,
                    "normalizedAnswer": exercise.exerciseID
                ],
                "at": now + 4
            ])
        }
        append("l2-terminal-checkpoint", [
            "kind": "lessonCheckpointSaved",
            "lessonID": "lesson-02",
            "exerciseIndex": lessonTwoExercises.count,
            "at": now + 12
        ])
        append("l2-completed", ["kind": "lessonCompleted", "lessonID": "lesson-02", "at": now + 13])
        if lessonThreeTerminalCheckpoint {
            append("l3-terminal-checkpoint", [
                "kind": "lessonCheckpointSaved",
                "lessonID": "lesson-03",
                "exerciseIndex": 7,
                "at": now + 14
            ])
        }

        var journal = Data()
        for event in events {
            journal.append(try JSONSerialization.data(withJSONObject: event))
            journal.append(0x0A)
        }
        return journal
    }
}
