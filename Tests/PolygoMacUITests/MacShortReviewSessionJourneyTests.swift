import Foundation
import XCTest

/// Proves that Today opens a bounded review slice while the complete due
/// queue remains available afterwards. The fixture has sixteen due cards;
/// the authored daily budget is capped at ten cards.
final class MacShortReviewSessionJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private let fixtureKey = "SYLLUNE_PROGRESS_FIXTURE_JSONL"
    private var app: XCUIApplication!
    private var profileID = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        profileID = "ui-mac-short-\(UUID().uuidString.lowercased())"
        let seedJournal = try makeSeedProgress()

        app = XCUIApplication(bundleIdentifier: "com.syllune.PolygoMac")
        app.launchArguments = [
            "-syllune.profile.id", profileID,
            "-syllune.last.route", "today",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-syllune.appearance", "dark",
            "-syllune.reduceMotion", "true"
        ]
        app.launchEnvironment[fixtureKey] = String(decoding: seedJournal, as: UTF8.self)
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testTodayLimitsReviewThenLeavesRemainingCardsForContinuation() throws {
        let home = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "home.review")
        ).firstMatch
        XCTAssertTrue(home.waitForExistence(timeout: timeout), "Aujourd’hui doit afficher la carte de révision")
        let coinBalanceBeforeReview = try currentCoinBalance()
        XCTAssertTrue(
            text(containing: "cartes pour cette session").waitForExistence(timeout: timeout),
            "Aujourd’hui doit annoncer la limite de la session courte"
        )
        XCTAssertTrue(
            text(containing: "16 dues au total").waitForExistence(timeout: timeout),
            "La file complète doit conserver les seize cartes dues"
        )
        app.launchEnvironment.removeValue(forKey: fixtureKey)

        let review = button(exactly: "Réviser")
        XCTAssertTrue(review.waitForExistence(timeout: timeout), "Aujourd’hui doit proposer la révision")
        XCTAssertTrue(review.isHittable, "Le lien de révision doit être accessible")
        review.click()

        let sessionSummary = text(containing: "cartes sur 16 dues")
        XCTAssertTrue(
            sessionSummary.waitForExistence(timeout: timeout),
            "La route de session doit conserver la taille de la file complète"
        )
        let expectedLimit = try firstInteger(in: accessibleText(of: sessionSummary))
        XCTAssertGreaterThan(expectedLimit, 0, "La limite quotidienne doit être positive")
        XCTAssertLessThanOrEqual(expectedLimit, 10, "La session courte doit rester plafonnée à dix cartes")
        let start = button(exactly: "Commencer")
        XCTAssertTrue(start.waitForExistence(timeout: timeout), "La session courte doit pouvoir commencer")
        start.click()

        let finished = text(containing: "Session terminée")
        let reveal = button(exactly: "Révéler")
        var completedCards = 0
        for _ in 0..<11 {
            let nextCardOrFinished = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in reveal.exists || finished.exists },
                object: nil
            )
            XCTAssertTrue(
                XCTWaiter.wait(for: [nextCardOrFinished], timeout: timeout) == .completed,
                "Une carte doit pouvoir être révélée ou la session doit se terminer"
            )
            if finished.exists { break }
            XCTAssertTrue(reveal.exists, "Chaque carte doit pouvoir être révélée")
            if completedCards == 0 {
                attachScreenshot(named: "mac-short-review-front")
            }
            reveal.click()

            let easy = app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Facile")
            ).firstMatch
            XCTAssertTrue(easy.waitForExistence(timeout: timeout), "Une carte révélée doit proposer une évaluation")
            if completedCards == 0 {
                attachScreenshot(named: "mac-short-review-revealed")
            }
            XCTAssertTrue(easy.isHittable, "L’évaluation Facile doit être accessible")
            easy.click()
            completedCards += 1
            if completedCards == 1 {
                let balanceAfterFirstEvaluation = try currentCoinBalance()
                XCTAssertEqual(
                    balanceAfterFirstEvaluation,
                    coinBalanceBeforeReview,
                    "Une évaluation SRS réelle ne doit pas modifier le solde de pièces"
                )
            }
        }

        XCTAssertTrue(finished.waitForExistence(timeout: timeout), "La session courte doit se terminer après sa limite")
        XCTAssertEqual(completedCards, expectedLimit, "La session doit évaluer exactement la limite annoncée")
        let balanceAfterSession = try currentCoinBalance()
        XCTAssertEqual(
            balanceAfterSession,
            coinBalanceBeforeReview,
            "La session SRS terminée doit conserver le solde initial"
        )
        XCTAssertTrue(
            text(containing: "Il reste").waitForExistence(timeout: timeout),
            "La fin de session doit indiquer les cartes encore dues"
        )
        let remainingText = text(containing: "Il reste")
        let remainingLabel = accessibleText(of: remainingText)
        let remainingCards = try firstInteger(in: remainingLabel)
        XCTAssertEqual(remainingCards, 16 - expectedLimit, "La file complète doit conserver les cartes non révisées")
        let continueReview = button(exactly: "Poursuivre")
        XCTAssertTrue(continueReview.waitForExistence(timeout: timeout), "La file complète doit rester accessible")
        attachScreenshot(named: "mac-short-review-session-finished")
    }

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", value, value)
        ).firstMatch
    }

    private func accessibleText(of element: XCUIElement) -> String {
        if let value = element.value as? String, !value.isEmpty {
            return value
        }
        return element.label
    }
    private func currentCoinBalance() throws -> Int {
        let balances = app.descendants(matching: .any).matching(identifier: "ProgressCoinBalance")
        let balance = balances.firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: timeout), "Le badge de progression doit rester accessible pendant la révision")
        XCTAssertEqual(balances.count, 1, "La navigation imbriquée doit conserver un seul badge global")
        let digits = String(describing: balance.value ?? "").filter { $0.isNumber }
        return try XCTUnwrap(Int(digits), "Le badge doit exposer un solde numérique réel")
    }

    private func firstInteger(in value: String) throws -> Int {
        let regex = try NSRegularExpression(pattern: "\\d+")
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, range: range),
              let integerRange = Range(match.range, in: value),
              let integer = Int(value[integerRange]) else {
            throw NSError(domain: "MacShortReviewSessionJourneyTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Aucun entier dans le libellé : \(value)"
            ])
        }
        return integer
    }

    private func makeSeedProgress() throws -> Data {
        let now = Date().timeIntervalSinceReferenceDate - 60
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
            "displayName": "Session courte",
            "startingLevel": "beginner"
        ]

        var events: [[String: Any]] = [event(
            id: "mac-short-onboarding",
            lamport: 1,
            occurredAt: now,
            payload: ["kind": "onboardingCompleted", "profile": learnerProfile]
        )]
        var lamport = 2
        for lessonID in ["lesson-01", "lesson-02", "lesson-03"] {
            events.append(event(
                id: "mac-short-\(lessonID)-completed",
                lamport: lamport,
                occurredAt: now + Double(lamport),
                payload: ["kind": "lessonCompleted", "lessonID": lessonID, "at": now + Double(lamport)]
            ))
            lamport += 1
        }

        // L1–L3 retain sixteen stable authored cards. Adding each through
        // the same event payload used by completeLesson makes them all due
        // while still allowing ReviewCardsView to resolve their content.
        for lessonID in ["lesson-01", "lesson-02", "lesson-03"] {
            let cards = try loadCards(relativePath: "lessons/\(lessonID).json")
            for cardID in cards {
                events.append(event(
                    id: "mac-short-\(cardID)-added",
                    lamport: lamport,
                    occurredAt: now,
                    payload: ["kind": "flashcardAdded", "cardID": cardID, "at": now]
                ))
                lamport += 1
            }
        }

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
            "deviceID": "mac-short-ui-test",
            "lamport": lamport,
            "occurredAt": occurredAt,
            "schemaVersion": 1,
            "payload": payload
        ]
    }

    private func loadCards(relativePath: String) throws -> [String] {
        let data = try Data(contentsOf: contentURL(relativePath: relativePath))
        let fixture = try JSONDecoder().decode(CardFixtureLesson.self, from: data)
        return fixture.cards.map(\.id)
    }

    private func contentURL(relativePath: String) throws -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceCandidate = repositoryRoot.appendingPathComponent("Content", isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: false)
        if FileManager.default.fileExists(atPath: sourceCandidate.path) { return sourceCandidate }

        let fileName = URL(fileURLWithPath: relativePath).deletingPathExtension().lastPathComponent
        let directory = URL(fileURLWithPath: relativePath).deletingLastPathComponent().path
        for bundle in [Bundle(for: MacShortReviewSessionJourneyTests.self), Bundle.main] {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: directory) { return url }
            if let url = bundle.url(forResource: fileName, withExtension: "json") { return url }
        }
        throw NSError(domain: "MacShortReviewSessionJourneyTests", code: 1, userInfo: [
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

private struct CardFixtureLesson: Decodable {
    let cards: [CardFixture]
}

private struct CardFixture: Decodable {
    let id: String
}
