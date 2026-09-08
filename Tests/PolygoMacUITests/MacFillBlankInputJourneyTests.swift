import Foundation
import XCTest

/// Covers the macOS fill-blank path from the persisted roadmap through a real
/// lesson answer. The journey deliberately enters the Hanzi answer with
/// surrounding spaces so native TextField focus and the exercise normalizer
/// are both exercised after the lesson's Mandarin audio control is used.
final class MacFillBlankInputJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private var app: XCUIApplication!
    private var profileID = ""
    private var profileDirectory: URL?

    override func setUpWithError() throws {
        continueAfterFailure = false

        profileID = "ui-mac-input-\(UUID().uuidString.lowercased())"
        try seedProgress()

        app = XCUIApplication(bundleIdentifier: "com.syllune.PolygoMac")
        app.launchArguments = [
            "-syllune.profile.id", profileID,
            "-syllune.last.route", "path",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-syllune.appearance", "dark",
            "-syllune.reduceMotion", "true"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        if let profileDirectory, FileManager.default.fileExists(atPath: profileDirectory.path) {
            try? FileManager.default.removeItem(at: profileDirectory)
        }
    }

    func testFillBlankSpeaksAndAcceptsHanZiAnswerAfterRoadmapNavigation() throws {
        let pathItem = app.buttons.matching(
            NSPredicate(format: "label == %@", "Parcours")
        ).firstMatch
        XCTAssertTrue(pathItem.waitForExistence(timeout: timeout), "Le parcours macOS doit être visible")
        XCTAssertTrue(pathItem.isHittable, "Le parcours macOS doit être cliquable")
        pathItem.click()

        let lesson = app.buttons.matching(
            NSPredicate(format: "identifier == %@", "learningPath.lesson.lesson-02")
        ).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "L2 doit être déverrouillée dans le parcours")
        XCTAssertTrue(
            scrollIntoView(lesson),
            "La carte L2 doit être visible et activée"
        )
        lesson.click()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l2-tone").firstMatch.waitForExistence(timeout: timeout),
            "L’ouverture de la carte L2 doit commencer par son premier exercice"
        )

        submitChoice(label: "2 — montant", exerciseID: "ex-l2-tone")
        submitChoice(label: "Quoi ; quel", exerciseID: "ex-l2-meaning")
        submitWordOrder(
            tokens: ["你", "叫", "什么", "名字"],
            exerciseID: "ex-l2-order"
        )

        let fillExercise = app.staticTexts.matching(identifier: "lesson.exercise.ex-l2-fill").firstMatch
        XCTAssertTrue(fillExercise.waitForExistence(timeout: timeout), "Le parcours L2 doit atteindre le champ à compléter")

        // The answer prompt remains a visible blank while its speech source is
        // completed internally. An exact underscore token distinguishes the
        // rendered sentence from the longer French instruction text.
        let blank = app.staticTexts.matching(
            NSPredicate(format: "value == %@ OR label == %@", "___", "___")
        ).firstMatch
        XCTAssertTrue(blank.waitForExistence(timeout: timeout), "La phrase de L2 doit conserver son trou visible")
        XCTAssertTrue(scrollIntoView(blank), "Le trou de la phrase doit être visible")

        let field = app.textFields.matching(
            NSPredicate(
                format: "placeholderValue CONTAINS[c] %@ OR label CONTAINS[c] %@",
                "Mot manquant",
                "Mot manquant"
            )
        ).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Le champ Mot manquant doit être exposé sur macOS")
        XCTAssertTrue(field.isEnabled, "Le champ Mot manquant doit accepter la saisie")
        XCTAssertTrue(scrollIntoView(field), "Le champ Mot manquant doit être visible et cliquable")

        // This is the actual Chinese speech control from FillAnswerView. The
        // exact completed phrase is covered by the PolygoCore content
        // contract; this UI step proves that the lesson reaches and invokes
        // the control while leaving the blank on screen.
        let listen = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Lire le chinois", "Écouter")
        ).firstMatch
        XCTAssertTrue(listen.waitForExistence(timeout: timeout), "La phrase de L2 doit proposer sa lecture en mandarin")
        XCTAssertTrue(scrollIntoView(listen), "La commande de lecture de la phrase doit être accessible")
        listen.click()
        XCTAssertTrue(
            text(containing: "Lecture terminée").waitForExistence(timeout: timeout),
            "La lecture de la phrase doit aller jusqu’à son état terminé avant la saisie"
        )

        XCTAssertTrue(scrollIntoView(field), "Le champ Mot manquant doit rester visible après la lecture")
        field.click()
        field.typeText(" 叫 ")

        XCTAssertTrue(
            waitForValue(field, " 叫 "),
            "La valeur du champ doit conserver les espaces autour du Hanzi saisi"
        )
        XCTAssertEqual(
            field.value as? String,
            " 叫 ",
            "La valeur AX réelle doit conserver les espaces autour du Hanzi saisi"
        )
        XCTAssertTrue(
            fillExercise.exists,
            "La saisie après la lecture ne doit pas quitter l’exercice"
        )
        attachScreenshot(named: "mac-fill-blank-input")

        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "La réponse Hanzi doit pouvoir être vérifiée")
        XCTAssertTrue(verify.isHittable, "Le bouton Vérifier doit être cliquable")
        XCTAssertTrue(
            waitForEnabled(verify),
            "Une réponse Hanzi entourée d’espaces doit activer Vérifier"
        )
        verify.click()
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "La réponse Hanzi doit être acceptée")

        let continueButton = button(exactly: "Continuer")
        XCTAssertTrue(continueButton.waitForExistence(timeout: timeout), "Le champ validé doit permettre de poursuivre")
        XCTAssertTrue(continueButton.isHittable, "Le bouton Continuer doit être cliquable")
        XCTAssertTrue(continueButton.isEnabled, "Le bouton Continuer doit être activé après une réponse correcte")
        continueButton.click()
        let nextExercise = app.staticTexts.matching(identifier: "lesson.exercise.ex-l2-reading-name").firstMatch
        XCTAssertTrue(nextExercise.waitForExistence(timeout: timeout), "La validation du champ doit faire progresser la leçon L2")
        XCTAssertTrue(scrollIntoView(nextExercise), "L’exercice suivant doit devenir visible après la validation")
        attachScreenshot(named: "mac-fill-blank-advanced")
    }

    private func submitChoice(label: String, exerciseID: String) {
        let exercise = app.staticTexts.matching(identifier: "lesson.exercise.\(exerciseID)").firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: timeout), "L’exercice \(exerciseID) doit être visible")

        let choice = button(containing: label)
        XCTAssertTrue(choice.waitForExistence(timeout: timeout), "La réponse \(label) doit être proposée")
        XCTAssertTrue(scrollIntoView(choice), "La réponse \(label) doit être visible et cliquable")
        choice.click()

        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "\(exerciseID) doit proposer Vérifier")
        XCTAssertTrue(verify.isHittable, "Le bouton Vérifier de \(exerciseID) doit être cliquable")
        XCTAssertTrue(
            waitForEnabled(verify),
            "La réponse de \(exerciseID) doit activer Vérifier"
        )
        verify.click()
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "\(exerciseID) doit être évalué correctement")

        let continueButton = button(exactly: "Continuer")
        XCTAssertTrue(continueButton.waitForExistence(timeout: timeout), "\(exerciseID) doit proposer Continuer")
        XCTAssertTrue(continueButton.isHittable, "Le bouton Continuer de \(exerciseID) doit être cliquable")
        XCTAssertTrue(continueButton.isEnabled, "Le bouton Continuer de \(exerciseID) doit être activé après une réponse correcte")
        continueButton.click()
    }

    private func submitWordOrder(tokens: [String], exerciseID: String) {
        let exercise = app.staticTexts.matching(identifier: "lesson.exercise.\(exerciseID)").firstMatch
        XCTAssertTrue(exercise.waitForExistence(timeout: timeout), "L’exercice \(exerciseID) doit être visible")

        for token in tokens {
            let tile = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "\(token), position")
            ).firstMatch
            XCTAssertTrue(tile.waitForExistence(timeout: timeout), "La tuile \(token) doit être proposée")
            XCTAssertTrue(scrollIntoView(tile), "La tuile \(token) doit être visible et cliquable")
            tile.click()
        }

        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "\(exerciseID) doit proposer Vérifier")
        XCTAssertTrue(verify.isHittable, "Le bouton Vérifier de \(exerciseID) doit être cliquable")
        XCTAssertTrue(
            waitForEnabled(verify),
            "La bonne séquence doit activer Vérifier"
        )
        verify.click()
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "\(exerciseID) doit être évalué correctement")

        let continueButton = button(exactly: "Continuer")
        XCTAssertTrue(continueButton.waitForExistence(timeout: timeout), "\(exerciseID) doit proposer Continuer")
        XCTAssertTrue(continueButton.isHittable, "Le bouton Continuer de \(exerciseID) doit être cliquable")
        XCTAssertTrue(continueButton.isEnabled, "Le bouton Continuer de \(exerciseID) doit être activé après une réponse correcte")
        continueButton.click()
    }

    /// SwiftUI keeps the exercise body in one vertical ScrollView. On macOS
    /// the first exercise can start below a long dialogue preamble, so an AX
    /// match may exist while its control is still outside the viewport.
    /// Scroll the real lesson container until the exact control can receive a
    /// click, while leaving the application layout untouched. AX can report a
    /// partially clipped control as hittable on macOS, so geometry is checked
    /// against the selected scroll container before returning.
    @discardableResult
    private func scrollIntoView(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }

        // NavigationSplitView exposes both a sidebar List and the lesson
        // content as AX ScrollViews. Match the element to the container whose
        // horizontal bounds contain it instead of relying on query order.
        let scrollViews = app.scrollViews
        var scrollView: XCUIElement?
        var bestHorizontalOverlap: CGFloat = 0
        for index in 0..<scrollViews.count {
            let candidate = scrollViews.element(boundBy: index)
            guard candidate.waitForExistence(timeout: 2) else { continue }
            let frame = candidate.frame
            guard frame.width > 0, frame.height > 0 else { continue }
            let elementFrame = element.frame
            let overlap = max(
                0,
                min(elementFrame.maxX, frame.maxX) - max(elementFrame.minX, frame.minX)
            )
            if overlap > bestHorizontalOverlap {
                bestHorizontalOverlap = overlap
                scrollView = candidate
            }
        }
        guard let scrollView else { return false }

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

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func button(containing value: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", value)).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", value, value)
        ).firstMatch
    }

    private func attachScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func waitForValue(_ field: XCUIElement, _ expected: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: field
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: element
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Seeds the same JSONL store used by the app. A completed L1 event
    /// unlocks L2; the test then opens L2 from Parcours and advances through
    /// its authored exercises before editing the fill answer.
    private func seedProgress() throws {
        let fileManager = FileManager.default
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let root = applicationSupport.appendingPathComponent("Polygo", isDirectory: true)
        let profile = root
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
        profileDirectory = profile
        if fileManager.fileExists(atPath: profile.path) {
            try fileManager.removeItem(at: profile)
        }
        try fileManager.createDirectory(at: profile, withIntermediateDirectories: true)

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

        let events: [[String: Any]] = [
            event(
                id: "mac-input-onboarding",
                lamport: 1,
                profileID: profileID,
                occurredAt: now,
                payload: ["kind": "onboardingCompleted", "profile": learnerProfile]
            ),
            event(
                id: "mac-input-l1-completed",
                lamport: 2,
                profileID: profileID,
                occurredAt: now + 1,
                payload: ["kind": "lessonCompleted", "lessonID": "lesson-01", "at": now + 1]
            ),
        ]

        var journal = Data()
        for event in events {
            journal.append(try JSONSerialization.data(withJSONObject: event))
            journal.append(0x0A)
        }
        try journal.write(to: profile.appendingPathComponent("events.jsonl"), options: [.atomic])
    }

    private func event(
        id: String,
        lamport: Int,
        profileID: String,
        occurredAt: Double,
        payload: [String: Any]
    ) -> [String: Any] {
        [
            "eventID": id,
            "profileID": profileID,
            "deviceID": "mac-ui-test",
            "lamport": lamport,
            "occurredAt": occurredAt,
            "schemaVersion": 1,
            "payload": payload
        ]
    }
}
