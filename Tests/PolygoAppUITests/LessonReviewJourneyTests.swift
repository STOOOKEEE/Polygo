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

    func testLessonSkipKeepsOralUnevaluatedAndPersistsWritingPathAcrossRelaunch() throws {
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
            text(containing: "Leçon enregistrée").waitForExistence(timeout: timeout),
            "La fin de L1 doit signaler l’exercice oral passé sans évaluation"
        )
        XCTAssertFalse(text(containing: "Leçon terminée").exists, "Une leçon avec un exercice oral non évalué ne doit pas être marquée terminée")
        XCTAssertTrue(
            text(containing: "5 / 6 exercices réussis").waitForExistence(timeout: timeout),
            "Le bilan doit exclure l’exercice oral passé sans évaluation"
        )

        app.terminate()
        app.launch()

        XCTAssertTrue(
            text(containing: "Leçon enregistrée").waitForExistence(timeout: timeout),
            "Le bilan d’une leçon non terminée doit être conservé après relance"
        )
        XCTAssertTrue(
            text(containing: "5 / 6 exercices réussis").waitForExistence(timeout: timeout),
            "Le bilan non évalué doit conserver ses compteurs après relance"
        )
    }

    func testGuidedWritingRejectsWrongStrokeThenAcceptsRetry() throws {
        let exercise = try openWritingExercise()
        guard let target = exercise.targetHanzi,
              let guideAsset = exercise.guideAsset else {
            return XCTFail("L’exercice manuscrit doit déclarer sa cible et son guide")
        }
        let guide = try loadGuide(relativePath: guideAsset.relativePath)
        guard let firstStroke = guide.strokes.first,
              let guideStart = firstStroke.points.first,
              let guideEnd = firstStroke.points.last else {
            return XCTFail("Le guide manuscrit doit déclarer un premier trait")
        }

        let canvas = element(containing: "Zone de tracé pour \(target)", type: .any)
        XCTAssertTrue(canvas.waitForExistence(timeout: timeout), "La zone de tracé doit être exposée pour \(target)")
        bringIntoView(canvas)
        XCTAssertTrue(isFullyVisible(canvas), "La zone de tracé doit être entièrement visible avant le geste")
        XCTAssertTrue(waitForValue(canvas, equals: "0 traits tracés"), "Le canevas doit démarrer vide")

        // Reversing the first guide segment exercises the guided gate itself:
        // the bad gesture is drawn, but it must not consume stroke 1.
        let reversedStart = canvas.coordinate(withNormalizedOffset: CGVector(dx: guideEnd.x, dy: guideEnd.y))
        let reversedEnd = canvas.coordinate(withNormalizedOffset: CGVector(dx: guideStart.x, dy: guideStart.y))
        reversedStart.press(forDuration: 0.05, thenDragTo: reversedEnd)
        XCTAssertTrue(waitForValue(canvas, equals: "0 traits tracés"), "Un trait inversé ne doit pas augmenter le compteur")
        XCTAssertTrue(
            text(containing: "à refaire : commence").waitForExistence(timeout: timeout),
            "Le geste rejeté doit expliquer que le trait est à refaire"
        )

        let correctStart = canvas.coordinate(withNormalizedOffset: CGVector(dx: guideStart.x, dy: guideStart.y))
        let correctEnd = canvas.coordinate(withNormalizedOffset: CGVector(dx: guideEnd.x, dy: guideEnd.y))
        correctStart.press(forDuration: 0.05, thenDragTo: correctEnd)
        XCTAssertTrue(waitForValue(canvas, equals: "1 traits tracés"), "Le même trait correctement repris doit être accepté")
        XCTAssertTrue(
            text(containing: "Trait 1/\(guide.strokes.count) validé").waitForExistence(timeout: timeout),
            "Le retour doit confirmer la validation du premier trait"
        )
        XCTAssertFalse(
            text(containing: "Réponse manuscrite prête à être évaluée").exists,
            "Un seul trait accepté ne doit pas encore créer une réponse complète"
        )
    }

    func testFreeWritingFailureCanBeSelfReportedAndAdvance() throws {
        let exercise = try openWritingExercise()
        guard let target = exercise.targetHanzi,
              let guideAsset = exercise.guideAsset else {
            return XCTFail("L’exercice manuscrit doit déclarer sa cible et son guide")
        }
        let guide = try loadGuide(relativePath: guideAsset.relativePath)
        guard let firstStroke = guide.strokes.first,
              let start = firstStroke.points.first,
              let end = firstStroke.points.last else {
            return XCTFail("Le guide manuscrit doit déclarer un premier trait")
        }

        let canvas = element(containing: "Zone de tracé pour \(target)", type: .any)
        XCTAssertTrue(canvas.waitForExistence(timeout: timeout), "La zone de tracé doit être exposée pour \(target)")
        bringIntoView(canvas)
        let freeMode = button(exactly: "Libre")
        XCTAssertTrue(freeMode.waitForExistence(timeout: timeout), "Le mode libre doit être disponible")
        tapWhenVisible(freeMode)
        XCTAssertTrue(
            text(containing: "Mode libre : le guide est masqué").waitForExistence(timeout: timeout),
            "Le mode libre doit masquer le guide pendant le tracé"
        )

        // A single free stroke is a real drawing, but it is intentionally
        // incomplete for the seven-stroke guide.
        let strokeStart = canvas.coordinate(withNormalizedOffset: CGVector(dx: start.x, dy: start.y))
        let strokeEnd = canvas.coordinate(withNormalizedOffset: CGVector(dx: end.x, dy: end.y))
        strokeStart.press(forDuration: 0.05, thenDragTo: strokeEnd)
        XCTAssertTrue(waitForValue(canvas, equals: "1 traits tracés"), "Le mode libre doit conserver le trait dessiné")

        let validateDrawing = button(exactly: "Vérifier le tracé")
        XCTAssertTrue(validateDrawing.waitForExistence(timeout: timeout), "Le tracé libre doit pouvoir être vérifié")
        validateDrawing.tap()
        XCTAssertTrue(
            text(containingAny: ["Nombre de traits à revoir", "Tracé à revoir"]).waitForExistence(timeout: timeout),
            "Un tracé libre incomplet doit afficher une reprise explicite"
        )
        // Preserve the failed drawing state for visual review before the
        // learner chooses the explicit retry self-report.
        attachScreenshot(named: "writingerror-next")

        let selfReport = button(exactly: "À refaire")
        XCTAssertTrue(selfReport.waitForExistence(timeout: timeout), "L’échec libre doit proposer une auto-évaluation explicite")
        selfReport.tap()
        XCTAssertTrue(
            text(containing: "Réponse manuscrite prête à être évaluée").waitForExistence(timeout: timeout),
            "L’auto-évaluation doit préparer la réponse manuscrite"
        )

        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "La réponse manuscrite doit rejoindre l’action de la leçon")
        XCTAssertTrue(verify.isEnabled, "Une auto-évaluation manuscrite doit pouvoir être envoyée au moteur")
        verify.tap()
        XCTAssertTrue(text(containing: "À revoir").waitForExistence(timeout: timeout), "Le moteur doit conserver l’échec du tracé incomplet")
        // The post-submission footer is the actionable failure state that
        // reviewers need to inspect: the learner can continue despite the
        // failed attempt. Keep the pre-submission capture above as well.
        attachScreenshot(named: "writingerror-next-footer")

        let continueAnyway = button(exactly: "Continuer malgré tout")
        XCTAssertTrue(continueAnyway.waitForExistence(timeout: timeout), "La leçon doit permettre de progresser après un échec")
        continueAnyway.tap()
        XCTAssertTrue(
            text(containing: "Leçon enregistrée").waitForExistence(timeout: timeout),
            "La progression après un échec doit enregistrer la leçon sans la déclarer terminée"
        )

        // Leave the shared simulator at a clean, resumable lesson state for
        // the following UI journeys.
        let restart = button(exactly: "Recommencer cette leçon")
        XCTAssertTrue(restart.waitForExistence(timeout: timeout), "L’écran terminal doit permettre de recommencer")
        restart.tap()
        XCTAssertTrue(firstExercisePrompt().waitForExistence(timeout: timeout), "La leçon doit revenir à son premier exercice")
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

    private func answerSpeaking(_: ExerciseFixture) {
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

        // The oral surface no longer invents a learner rating when no
        // pronunciation provider can conclude. The lesson action bar keeps
        // the exercise explicitly unevaluated and lets the learner continue.
        let resultDetails = button(exactly: "Voir les résultats")
        if resultDetails.waitForExistence(timeout: 2) {
            tapWhenVisible(resultDetails)
            XCTAssertTrue(
                text(containingAny: ["aucun score de prononciation", "Résultat incertain", "Transcription locale"]).waitForExistence(timeout: timeout),
                "Un résultat oral doit rester descriptif et sans faux score"
            )
        }
        XCTAssertFalse(button(exactly: "À l’aise").exists, "L’oral ne doit plus proposer de bouton d’auto-évaluation")
        XCTAssertFalse(text(containing: "Correct").exists, "Une absence d’analyse ne doit pas produire un faux Correct")
        let skip = button(exactly: "Passer sans évaluer")
        XCTAssertTrue(skip.waitForExistence(timeout: timeout), "L’oral sans score doit proposer Passer sans évaluer")
        XCTAssertTrue(skip.isEnabled, "Passer sans évaluer doit être disponible sans réponse audio")
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
        let skip = button(exactly: "Passer sans évaluer")
        if skip.waitForExistence(timeout: 2) {
            XCTAssertTrue(skip.isEnabled, "Passer sans évaluer doit être activable pour l’oral")
            XCTAssertFalse(text(containing: "Correct").exists, "Le passage sans évaluation ne doit pas afficher Correct")
            tapWhenVisible(skip)
            XCTAssertTrue(
                text(containing: "Passé sans évaluation").waitForExistence(timeout: timeout),
                "Le retour doit indiquer que l’exercice oral n’a pas été évalué"
            )
            XCTAssertFalse(text(containing: "Correct").exists, "Un exercice passé sans évaluation ne doit pas être marqué Correct")
            let continueAnyway = button(exactly: "Continuer malgré tout")
            XCTAssertTrue(continueAnyway.waitForExistence(timeout: timeout), "La progression doit rester disponible après un exercice non évalué")
            tapWhenVisible(continueAnyway)
            return
        }

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

    private func openWritingExercise() throws -> ExerciseFixture {
        let lesson = try loadLessonFixture()
        let exercises = lesson.blocks.filter { $0.kind == "exercise" }.compactMap(\.spec)
        guard let writingIndex = exercises.firstIndex(where: { $0.kind == "handwriting" }) else {
            throw FixtureError.missing("lessons/lesson-01.json (handwriting exercise)")
        }

        completeOnboardingIfNeeded()
        openFirstLessonIfNeeded()

        // A previous journey may have left the lesson at its terminal
        // checkpoint. Restart through the same learner-facing control, then
        // walk the fixture's preceding exercises until writing is current.
        for _ in 0..<2 {
            let restart = button(exactly: "Recommencer cette leçon")
            if restart.waitForExistence(timeout: 3) {
                restart.tap()
                XCTAssertTrue(firstExercisePrompt().waitForExistence(timeout: timeout), "La leçon doit revenir au premier exercice")
            }

            var moved = true
            var safety = 0
            while moved && safety < exercises.count + 2 {
                safety += 1
                moved = false
                for (index, exercise) in exercises.enumerated() {
                    guard let prompt = exercise.header.prompt?["fr"], !prompt.isEmpty else {
                        XCTFail("Le prompt français manque pour \(exercise.header.id)")
                        continue
                    }
                    let promptElement = text(containing: prompt)
                    guard promptElement.waitForExistence(timeout: 1) else { continue }

                    if text(containingAny: ["Correct", "À revoir", "Passé sans évaluation"]).exists,
                       let next = currentFeedbackAdvanceButton() {
                        tapWhenVisible(next)
                        moved = true
                        break
                    }

                    if index == writingIndex {
                        let target = exercise.targetHanzi ?? ""
                        let canvas = element(containing: "Zone de tracé pour \(target)", type: .any)
                        if canvas.waitForExistence(timeout: timeout) {
                            // The guided and free tests are intentionally
                            // repeatable even when XCTest runs them after a
                            // prior interrupted attempt.
                            bringIntoView(canvas)
                            let clear = button(exactly: "Effacer")
                            if clear.exists && clear.isEnabled {
                                tapWhenVisible(clear)
                                XCTAssertTrue(waitForValue(canvas, equals: "0 traits tracés"), "Le canevas manuscrit doit pouvoir être remis à zéro")
                            }
                            return exercise
                        }
                        XCTFail("La zone de tracé manque pour \(exercise.header.id)")
                        throw FixtureError.missing("handwriting canvas for \(exercise.header.id)")
                    }

                    try answer(exercise)
                    evaluateAndAdvance(isLast: false)
                    moved = true
                    break
                }
            }

            // If the saved position was after handwriting, finish the
            // terminal path and restart once so the target can be exercised.
            let terminal = text(containingAny: ["Leçon terminée", "Leçon enregistrée"])
            if terminal.waitForExistence(timeout: 3) {
                let restart = button(exactly: "Recommencer cette leçon")
                XCTAssertTrue(restart.waitForExistence(timeout: timeout), "La leçon terminale doit pouvoir être redémarrée")
                restart.tap()
                XCTAssertTrue(firstExercisePrompt().waitForExistence(timeout: timeout), "La leçon doit revenir au premier exercice")
            }
        }

        throw FixtureError.missing("lessons/lesson-01.json (current handwriting exercise)")
    }

    private func currentFeedbackAdvanceButton() -> XCUIElement? {
        for label in ["Continuer", "Continuer malgré tout", "Terminer"] {
            let candidate = button(exactly: label)
            if candidate.exists { return candidate }
        }
        return nil
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

    private func button(containingAny values: [String]) -> XCUIElement {
        for value in values {
            let candidate = button(containing: value)
            if candidate.waitForExistence(timeout: 1) { return candidate }
        }
        return app.buttons.matching(NSPredicate(format: "label == %@", "__missing__")).firstMatch
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
    let prompt: [String: String]?
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
