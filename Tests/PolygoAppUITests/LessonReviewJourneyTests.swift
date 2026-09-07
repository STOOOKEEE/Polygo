import CoreGraphics
import Foundation
import XCTest

/// Exercises the learner-facing L1 path with the real application and the
/// checked-in lesson answers. This deliberately relies on the app's local
/// persistence so the second launch proves that review state survives a
/// process restart.
final class LessonReviewJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 15
    private var app: XCUIApplication!
    private var permissionMonitor: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        permissionMonitor = addUIInterruptionMonitor(withDescription: "Local audio permissions") { alert in
            Self.denyPermission(in: alert)
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app, app.exists {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "lesson-review-final-screen"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
        if let permissionMonitor {
            removeUIInterruptionMonitor(permissionMonitor)
        }
        app.terminate()
        app = nil
    }

    func testLessonCompletionAddsFiveCardsAndPersistsFirstReviewAcrossRelaunch() throws {
        let lesson = try loadLessonFixture()
        let exercises = lesson.blocks.filter { $0.kind == "exercise" }.compactMap(\.spec)

        XCTAssertEqual(lesson.id, "lesson-01")
        XCTAssertGreaterThanOrEqual(
            exercises.count,
            6,
            "L1 doit conserver ses activités de récupération, production et transfert"
        )
        XCTAssertEqual(lesson.cards.count, 5, "L1 doit fournir cinq cartes dans le JSON")

        completeOnboardingIfNeeded()
        openFirstLessonIfNeeded()

        for (index, exercise) in exercises.enumerated() {
            try answer(exercise)
            evaluateAndAdvance(isLast: index == exercises.count - 1)
        }

        XCTAssertTrue(
            text(containing: "Leçon terminée").waitForExistence(timeout: timeout),
            "La fin de L1 doit être confirmée après six réponses acceptées"
        )

        navigateToTab("Cartes")
        let fiveDue = text(containing: "5 cartes dues")
        XCTAssertTrue(fiveDue.waitForExistence(timeout: timeout), "La fin de L1 doit ajouter cinq cartes dues")

        let startReview = button(exactly: "Commencer")
        XCTAssertTrue(startReview.waitForExistence(timeout: timeout), "Le paquet de cinq cartes doit pouvoir démarrer")
        startReview.tap()
        XCTAssertTrue(text(containing: "Carte 1 / 5").waitForExistence(timeout: timeout), "La première carte doit s’ouvrir")

        let reveal = button(exactly: "Révéler")
        XCTAssertTrue(reveal.waitForExistence(timeout: timeout), "La première carte doit proposer sa révélation")
        reveal.tap()

        let good = button(containing: "Bien, planifier la prochaine révision")
        XCTAssertTrue(good.waitForExistence(timeout: timeout), "La carte révélée doit proposer une note SRS")
        good.tap()
        XCTAssertTrue(
            text(containing: "4 cartes dues").waitForExistence(timeout: timeout),
            "Une seule carte doit quitter la file après une réponse Bien"
        )

        app.terminate()
        app.launch()

        XCTAssertTrue(
            text(containing: "4 cartes dues").waitForExistence(timeout: timeout),
            "Le nombre de cartes dues doit être conservé après relance"
        )
        navigateToTab("Parcours")
        let completedLesson = element(containing: "Dire bonjour", type: .any)
        XCTAssertTrue(completedLesson.waitForExistence(timeout: timeout), "L1 doit rester visible dans le parcours après relance")
        XCTAssertTrue(
            element(containing: "Terminé", type: .any).waitForExistence(timeout: timeout),
            "Le parcours doit conserver l’état terminé de L1 après relance"
        )
    }

    private func answer(_ exercise: ExerciseFixture) throws {
        switch exercise.kind {
        case "choice", "listeningChoice":
            answerChoice(exercise)
        case "wordOrder":
            answerWordOrder(exercise)
        case "fillBlank":
            answerFillBlank(exercise)
        case "speaking":
            answerSpeaking(exercise)
        case "handwriting":
            try answerHandwriting(exercise)
        case "flashcard":
            answerFlashcard()
        default:
            XCTFail("Type d’exercice L1 inattendu dans le JSON : \(exercise.kind)")
        }
    }

    private func answerChoice(_ exercise: ExerciseFixture) {
        guard
            let correctChoiceID = exercise.correctChoiceID,
            let choice = exercise.choices?.first(where: { $0.id == correctChoiceID })
        else {
            XCTFail("Le choix correct manque dans le JSON pour \(exercise.header.id)")
            return
        }

        let label = choice.label["fr"] ?? choice.label.values.first ?? ""
        let option = button(exactly: label)
        XCTAssertTrue(option.waitForExistence(timeout: timeout), "Choix absent : \(label)")
        option.tap()
    }

    private func answerWordOrder(_ exercise: ExerciseFixture) {
        guard let correctOrder = exercise.correctOrder, let tokens = exercise.tokens else {
            XCTFail("L’ordre ou les tuiles manquent dans le JSON pour \(exercise.header.id)")
            return
        }

        for (position, tokenID) in correctOrder.enumerated() {
            guard let token = tokens.first(where: { $0.id == tokenID }) else {
                XCTFail("Tuile inconnue dans l’ordre correct : \(tokenID)")
                return
            }
            let option = button(exactly: "\(token.hanzi), position non choisie")
            XCTAssertTrue(option.waitForExistence(timeout: timeout), "Tuile absente : \(token.hanzi)")
            option.tap()
            XCTAssertTrue(
                button(exactly: "\(token.hanzi), position \(position + 1)").waitForExistence(timeout: timeout),
                "La tuile \(token.hanzi) doit enregistrer sa position"
            )
        }
    }

    private func answerFillBlank(_ exercise: ExerciseFixture) {
        guard let acceptedAnswer = exercise.acceptedAnswers?.first else {
            XCTFail("La réponse acceptée manque dans le JSON pour \(exercise.header.id)")
            return
        }

        let field = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@ OR label CONTAINS[c] %@", "Mot manquant", "Mot manquant")).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: timeout), "Le champ de réponse est absent pour \(exercise.header.id)")
        field.tap()
        field.typeText(acceptedAnswer)
    }

    private func answerFlashcard() {
        let reveal = button(exactly: "Révéler")
        XCTAssertTrue(reveal.waitForExistence(timeout: timeout), "L’activité carte doit proposer sa révélation")
        reveal.tap()

        let good = button(exactly: "Bien")
        XCTAssertTrue(good.waitForExistence(timeout: timeout), "La carte révélée doit proposer une auto-évaluation")
        good.tap()
    }

    private func answerSpeaking(_ exercise: ExerciseFixture) {
        let disclaimer = element(containing: "ne mesurent pas tes phonèmes ni tes tons", type: .any)
        XCTAssertTrue(disclaimer.waitForExistence(timeout: timeout), "L’oral ne doit pas prétendre noter phonèmes ou tons")

        let record = button(exactly: "Enregistrer")
        XCTAssertTrue(record.waitForExistence(timeout: timeout), "L’exercice oral doit proposer l’enregistrement")
        attachScreenshot(named: "oral-controls")
        record.tap()
        dismissPermissionPrompts()

        // A simulator with microphone access may enter the recording state;
        // stop it through the UI before waiting for transcription or fallback.
        let stop = button(exactly: "Arrêter")
        if stop.waitForExistence(timeout: 5) {
            stop.tap()
            dismissPermissionPrompts()
        }

        let selfRating = button(exactly: "À l’aise")
        if !selfRating.waitForExistence(timeout: 3) {
            // The permission result normally opens this disclosure itself.
            // Expand it explicitly when the simulator keeps the result group
            // collapsed so the rating assertion tests the real control.
            let details = button(exactly: "Voir les résultats")
            if details.waitForExistence(timeout: 2) {
                bringIntoView(details)
                XCTAssertTrue(details.isHittable, "Les résultats audio doivent pouvoir être ouverts")
                details.tap()
            }
        }
        if selfRating.waitForExistence(timeout: 8) {
            // The fallback is an explicit learner report. It carries no
            // acoustic, phoneme, or tone score.
            XCTAssertTrue(
                element(containing: "aucun score de ton", type: .any).waitForExistence(timeout: timeout),
                "Le mode d’auto-évaluation oral doit expliquer l’absence de score de ton"
            )
            bringIntoView(selfRating)
            XCTAssertTrue(selfRating.isHittable, "L’auto-évaluation À l’aise doit être touchable après défilement")
            selfRating.tap()
            XCTAssertTrue(
                text(containing: "Auto-évaluation enregistrée").waitForExistence(timeout: timeout),
                "L’auto-évaluation orale doit être enregistrée avant validation"
            )
            XCTAssertEqual(
                selfRating.value as? String,
                "Sélectionnée",
                "Le choix À l’aise doit rester sélectionné après son enregistrement"
            )
        } else {
            // If the simulator has an already-authorized recognizer and it
            // returns a transcript, keep the real transcript path. The same
            // disclaimer must still be visible in that branch.
            XCTAssertTrue(
                element(containing: "Transcription locale", type: .any).waitForExistence(timeout: timeout),
                "L’oral doit fournir une transcription locale ou son fallback explicite"
            )
        }
        attachScreenshot(named: "oral-result")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func answerHandwriting(_ exercise: ExerciseFixture) throws {
        guard let target = exercise.targetHanzi, let guideAsset = exercise.guideAsset else {
            XCTFail("Le guide d’écriture manque dans le JSON pour \(exercise.header.id)")
            return
        }
        let guide = try loadGuide(relativePath: guideAsset.relativePath)
        guard let expectedStrokeCount = exercise.expectedStrokeCount else {
            XCTFail("Le nombre de traits attendu manque dans le JSON pour \(exercise.header.id)")
            return
        }
        XCTAssertEqual(guide.strokes.count, expectedStrokeCount, "Le guide doit correspondre au nombre de traits L1")

        let canvas = element(containing: "Zone de tracé pour \(target)", type: .any)
        XCTAssertTrue(canvas.waitForExistence(timeout: timeout), "La zone de tracé doit être exposée par VoiceOver")
        bringIntoView(canvas)
        XCTAssertTrue(
            isFullyVisible(canvas),
            "La zone de tracé doit être entièrement dans la fenêtre avant les gestes (canevas : \(frameDescription(canvas.frame)), fenêtre : \(frameDescription(viewportFrame())))"
        )

        for stroke in guide.strokes {
            guard let first = stroke.points.first, let last = stroke.points.last else {
                XCTFail("Un trait du guide L1 ne contient pas de points")
                continue
            }
            let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: first.x, dy: first.y))
            let end = canvas.coordinate(withNormalizedOffset: CGVector(dx: last.x, dy: last.y))
            // These are real touch drags on the app's Canvas. The guide drives
            // the endpoints while the app itself captures and validates them.
            start.press(forDuration: 0.05, thenDragTo: end)
        }

        let expectedValue = "\(guide.strokes.count) traits tracés"
        XCTAssertTrue(
            waitForValue(canvas, equals: expectedValue),
            "Le canevas doit recevoir les \(guide.strokes.count) gestes du guide (valeur observée : \(String(describing: canvas.value)))"
        )

        let verify = button(containing: "Vérifier le tracé")
        bringIntoView(verify)
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "Le tracé doit pouvoir être vérifié")
        verify.tap()

        let save = button(exactly: "Enregistrer ce tracé")
        XCTAssertTrue(
            save.waitForExistence(timeout: timeout),
            "Les gestes correspondant au guide doivent produire une validation approximative enregistrable"
        )
        save.tap()
        XCTAssertTrue(
            text(containing: "Tracé enregistré localement").waitForExistence(timeout: timeout),
            "Le dessin doit être persisté localement avant de quitter l’exercice"
        )
        XCTAssertTrue(
            element(containing: "Réponse manuscrite prête à être évaluée", type: .any).waitForExistence(timeout: timeout),
            "La réponse manuscrite persistée doit être prête pour le moteur"
        )
    }

    private func evaluateAndAdvance(isLast: Bool) {
        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "Chaque exercice doit proposer Vérifier")
        XCTAssertTrue(verify.isEnabled, "Une réponse doit être sélectionnée avant chaque validation")
        verify.tap()
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "Chaque réponse du parcours doit être acceptée")

        let next = button(exactly: isLast ? "Terminer" : "Continuer")
        XCTAssertTrue(next.waitForExistence(timeout: timeout), "La progression doit proposer l’étape suivante")
        next.tap()
    }

    private func completeOnboardingIfNeeded() {
        // « Commencer » is also the review-deck action after a completed
        // lesson. Restrict the onboarding tap to the welcome screen so a
        // persisted app session is never mistaken for onboarding.
        let welcome = text(containing: "Bienvenue dans Syllune")
        if welcome.waitForExistence(timeout: 5) {
            let start = button(exactly: "Commencer")
            XCTAssertTrue(start.waitForExistence(timeout: timeout), "L’accueil doit proposer l’onboarding")
            start.tap()
        }

        let name = element(containing: "Comment t’appeler", type: .textField)
        if name.waitForExistence(timeout: 3) {
            name.tap()
            name.typeText("Armand")
            let level = button(exactly: "Je connais le pinyin")
            XCTAssertTrue(level.waitForExistence(timeout: timeout), "Le niveau d’onboarding doit être visible")
            level.tap()
            button(exactly: "Continuer").tap()
        }

        let rhythm = element(containing: "Durée quotidienne", type: .any)
        if rhythm.waitForExistence(timeout: 3) {
            let duration = element(containing: "15 min", type: .any)
            XCTAssertTrue(duration.waitForExistence(timeout: timeout), "La durée d’onboarding doit être visible")
            duration.tap()
            button(exactly: "Continuer").tap()
        }

        let ready = button(exactly: "Ouvrir ma première leçon")
        if ready.waitForExistence(timeout: 3) {
            ready.tap()
        }
    }

    private func openFirstLessonIfNeeded() {
        let verify = button(exactly: "Vérifier")
        if verify.waitForExistence(timeout: 4) { return }

        navigateToTab("Parcours")
        let lesson = button(containing: "Dire bonjour")
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "La première leçon doit être visible dans Parcours")
        lesson.tap()
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "La première leçon doit charger son premier exercice")
    }

    private func navigateToTab(_ label: String) {
        leaveLessonBeforeSelectingTab()
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            return
        }

        let sidebarItem = element(containing: label, type: .any)
        XCTAssertTrue(sidebarItem.waitForExistence(timeout: timeout), "Navigation absente : \(label)")
        sidebarItem.tap()
    }

    private func leaveLessonBeforeSelectingTab() {
        let lessonControl = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Vérifier", "Recommencer cette leçon")
        ).firstMatch
        guard lessonControl.exists else { return }

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: timeout), "Le parcours doit pouvoir quitter la leçon avant un changement d’onglet")
        back.tap()
    }

    private func bringIntoView(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable && isFullyVisible(element) { return }
            // Start the scroll from the far edge of the app so this helper
            // cannot become a handwriting stroke when the target is the
            // drawing surface itself.
            let viewport = viewportFrame()
            let moveDown = element.frame.minY < viewport.minY
            let startY = moveDown ? 0.16 : 0.86
            let endY = moveDown ? 0.86 : 0.16
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: startY))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: endY))
            start.press(forDuration: 0.01, thenDragTo: end)
        }
    }

    private func isFullyVisible(_ element: XCUIElement) -> Bool {
        let frame = element.frame
        let viewport = viewportFrame()
        return frame.width > 0 && frame.height > 0 && viewport.contains(frame)
    }

    private func viewportFrame() -> CGRect {
        let window = app.windows.firstMatch
        if window.exists && !window.frame.isEmpty { return window.frame }
        return app.frame
    }

    private func frameDescription(_ frame: CGRect) -> String {
        String(format: "x=%.1f y=%.1f w=%.1f h=%.1f", frame.minX, frame.minY, frame.width, frame.height)
    }

    private func dismissPermissionPrompts() {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            XCTAssertTrue(Self.denyPermission(in: alert), "La demande d’autorisation audio doit proposer un refus")
            return
        }

        // XCTest invokes interruption monitors when the test interacts with
        // the app. Trigger that monitor once from the unused top-right corner;
        // repeated center taps can toggle the results disclosure underneath
        // a permission sheet and leave the fallback rating unselected.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.02)).tap()
        let promptedAlert = app.alerts.firstMatch
        if promptedAlert.waitForExistence(timeout: 5) {
            XCTAssertTrue(Self.denyPermission(in: promptedAlert), "La demande d’autorisation audio doit proposer un refus")
        }
    }

    @discardableResult
    private static func denyPermission(in alert: XCUIElement) -> Bool {
        for label in ["Ne pas autoriser", "Don't Allow", "Don’t Allow"] {
            let deny = alert.buttons[label]
            if deny.exists {
                deny.tap()
                return true
            }
        }
        return false
    }

    private func waitForValue(_ element: XCUIElement, equals expected: String) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (element.value as? String) == expected { return true }
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func button(containing label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        element(containing: value, type: .any)
    }

    private func element(containing value: String, type: XCUIElement.ElementType) -> XCUIElement {
        app.descendants(matching: type)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", value))
            .firstMatch
    }

    private func loadLessonFixture() throws -> LessonFixture {
        let data = try Data(contentsOf: contentURL(relativePath: "lessons/lesson-01.json"))
        return try JSONDecoder().decode(LessonFixture.self, from: data)
    }

    private func loadGuide(relativePath: String) throws -> GuideFixture {
        let data = try Data(contentsOf: contentURL(relativePath: relativePath))
        return try JSONDecoder().decode(GuideFixture.self, from: data)
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
        let bundles = [Bundle(for: LessonReviewJourneyTests.self), Bundle.main]
        for bundle in bundles {
            if let url = bundle.url(forResource: fileName, withExtension: "json", subdirectory: directory) {
                return url
            }
            if let url = bundle.url(forResource: fileName, withExtension: "json") {
                return url
            }
        }
        throw FixtureError.missing(relativePath)
    }
}

private enum FixtureError: LocalizedError {
    case missing(String)

    var errorDescription: String? {
        switch self {
        case .missing(let path): return "Fixture introuvable : \(path)"
        }
    }
}

private struct LessonFixture: Decodable {
    let id: String
    let blocks: [BlockFixture]
    let cards: [CardFixture]
}

private struct BlockFixture: Decodable {
    let kind: String
    let spec: ExerciseFixture?
}

private struct ExerciseFixture: Decodable {
    let kind: String
    let header: ExerciseHeaderFixture
    let choices: [ChoiceFixture]?
    let correctChoiceID: String?
    let tokens: [TokenFixture]?
    let correctOrder: [String]?
    let sentence: String?
    let acceptedAnswers: [String]?
    let targetHanzi: String?
    let guideAsset: AssetFixture?
    let expectedStrokeCount: Int?
}

private struct ExerciseHeaderFixture: Decodable {
    let id: String
}

private struct ChoiceFixture: Decodable {
    let id: String
    let label: [String: String]
}

private struct TokenFixture: Decodable {
    let id: String
    let hanzi: String
}

private struct AssetFixture: Decodable {
    let relativePath: String
}

private struct CardFixture: Decodable {
    let id: String
}

private struct GuideFixture: Decodable {
    let strokes: [GuideStrokeFixture]
}

private struct GuideStrokeFixture: Decodable {
    let points: [GuidePointFixture]
}

private struct GuidePointFixture: Decodable {
    let x: CGFloat
    let y: CGFloat
}
