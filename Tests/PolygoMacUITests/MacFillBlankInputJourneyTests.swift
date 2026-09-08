import Foundation
import XCTest

/// Keeps the macOS text input path covered with an ASCII diagnostic value.
/// The value is intentionally not an answer from the lesson: retaining the
/// literal space in the field proves that the app-level key commands do not
/// consume text entered by a focused control.
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

    func testFillBlankRetainsLiteralSpaceWhileFocused() throws {
        let pathItem = app.buttons.matching(
            NSPredicate(format: "label == %@", "Parcours")
        ).firstMatch
        XCTAssertTrue(pathItem.waitForExistence(timeout: timeout), "Le parcours macOS doit être visible")
        if pathItem.isHittable { pathItem.click() }

        let lesson = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "learningPath.lesson.lesson-02")
        ).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "L2 doit être déverrouillée dans le parcours")
        XCTAssertTrue(lesson.isHittable, "La carte L2 doit être activée")
        lesson.click()

        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l2-fill").firstMatch.waitForExistence(timeout: timeout),
            "Le test doit ouvrir directement l’exercice à champ de L2"
        )
        let field = app.textFields.matching(
            NSPredicate(
                format: "placeholderValue CONTAINS[c] %@ OR label CONTAINS[c] %@",
                "Mot manquant",
                "Mot manquant"
            )
        ).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Le champ Mot manquant doit être exposé sur macOS")
        XCTAssertTrue(field.isEnabled, "Le champ Mot manquant doit accepter la saisie")
        XCTAssertTrue(field.isHittable, "Le champ Mot manquant doit être visible et cliquable")

        field.click()
        field.typeText("abc def")

        XCTAssertTrue(
            waitForValue(field, "abc def"),
            "La valeur du champ doit conserver l’espace saisi"
        )
        XCTAssertEqual(
            field.value as? String,
            "abc def",
            "La valeur AX réelle doit conserver l’espace saisi"
        )
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "lesson.exercise.ex-l2-fill").firstMatch.exists,
            "La saisie dans le champ ne doit pas quitter l’exercice"
        )
    }

    private func waitForValue(_ field: XCUIElement, _ expected: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected),
            object: field
        )
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Seeds the same JSONL store used by the app, so this journey starts at
    /// the real L2 fill exercise without an app-only test bypass or fixture
    /// provider. A completed L1 event unlocks L2; the checkpoint selects its
    /// fourth exercise and leaves the answer empty for the UI to edit.
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
            event(
                id: "mac-input-l2-checkpoint",
                lamport: 3,
                profileID: profileID,
                occurredAt: now + 2,
                payload: [
                    "kind": "lessonCheckpointSaved",
                    "lessonID": "lesson-02",
                    "exerciseIndex": 3,
                    "exerciseID": "ex-l2-fill",
                    "at": now + 2
                ]
            )
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
