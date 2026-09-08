import CoreGraphics
import Foundation
import XCTest

/// Regression coverage for the learner-facing lesson flow. The test keeps a
/// draft answer, moves the app through the inactive state, then relaunches it
/// before and after validation. The same journey also exercises the compact
/// dialogue, written participation, token audio targets, and oral controls.
final class ZZLessonRegressionJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private var app: XCUIApplication!
    private var permissionMonitor: NSObjectProtocol?

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Keep the event journal isolated per XCTest method while retaining
        // the same profile for the terminate/relaunch checks in this journey.
        app.launchArguments = [
            "-syllune.profile.id", "ui-\(UUID().uuidString.lowercased())",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"
        ]
        permissionMonitor = addUIInterruptionMonitor(withDescription: "Local audio permissions") { alert in
            Self.denyPermission(in: alert)
        }
        app.launch()
    }

    override func tearDownWithError() throws {
        if let permissionMonitor {
            removeUIInterruptionMonitor(permissionMonitor)
        }
        app.terminate()
        app = nil
    }

    func testLessonDraftFeedbackDialogueAndOralJourney() throws {
        completeOnboardingIfNeeded()
        navigateToTab("Aujourd’hui")
        XCTAssertTrue(text(containing: "Ton parcours").waitForExistence(timeout: timeout), "La capture d’accueil doit montrer le tableau de bord")
        attachScreenshot(named: "home-after-onboarding")
        openFirstLesson()
        expandDiscoveryIfNeeded()
        let dialogueHeading = text(containing: "Dialogue")
        XCTAssertTrue(dialogueHeading.waitForExistence(timeout: timeout), "Le dialogue doit être affiché")
        bringIntoView(dialogueHeading)
        attachScreenshot(named: "dialogue-discovery")
        // Alias used by the visual review collector; retain the descriptive
        // attachment above for the journey report as well.
        attachScreenshot(named: "dialogue")

        // The preamble must stay compact while still offering every authored
        // line. Read the fixture here so a dialogue edit cannot silently
        // leave the regression journey asserting yesterday's copy.
        let lessonDialogue = try dialogueFromFixture(lessonID: "lesson-01")
        for line in lessonDialogue.lines {
            XCTAssertTrue(text(containing: line.hanzi).waitForExistence(timeout: timeout), "Réplique absente : \(line.hanzi)")
        }
        for speaker in Set(lessonDialogue.lines.map(\.speaker)) {
            XCTAssertTrue(text(containing: speaker).waitForExistence(timeout: timeout), "Locuteur absent : \(speaker)")
        }

        let playDialogue = button(exactly: "Écouter tout le dialogue en chinois")
        XCTAssertTrue(playDialogue.waitForExistence(timeout: timeout), "Le dialogue doit proposer une lecture complète")
        tapWhenVisible(playDialogue)
        let stopDialogue = button(exactly: "Arrêter le dialogue")
        if stopDialogue.waitForExistence(timeout: 3) {
            tapWhenVisible(stopDialogue)
        } else {
            // A simulator without an installed Mandarin voice can reject TTS
            // immediately. The playback contract is still checked below by
            // the dedicated response action and the offline status path.
            XCTAssertTrue(text(containingAny: ["Audio indisponible", "Lecture du dialogue"]).waitForExistence(timeout: timeout), "La lecture complète doit signaler son état")
        }

        let token = button(exactly: "早")
        XCTAssertTrue(token.waitForExistence(timeout: timeout), "Chaque mot chinois doit être une cible audio")
        tapWhenVisible(token)
        // Tapping a token is an audio action. It must not require a detail
        // page before the learner can continue in the lesson.
        XCTAssertTrue(
            text(containing: "Dialogue").waitForExistence(timeout: timeout),
            "La lecture d’un mot doit laisser le dialogue utilisable"
        )

        XCTAssertTrue(
            text(containing: "Question de compréhension").waitForExistence(timeout: timeout),
            "Le dialogue doit annoncer sa question de compréhension"
        )
        XCTAssertTrue(
            text(containing: "Écoute la réponse, puis écris la réplique juste avant").waitForExistence(timeout: timeout),
            "La participation doit demander la réplique précédente"
        )
        let participationReply = try participationReplyFromFixture()
        let responseAudio = button(exactly: "Écouter la réponse")
        XCTAssertTrue(responseAudio.waitForExistence(timeout: timeout), "La participation doit permettre d’écouter la réponse")
        tapWhenVisible(responseAudio)

        let participationField = firstTextField(containingAny: ["réplique en caractères chinois", "réplique précédente", "réponse"])
        XCTAssertTrue(participationField.waitForExistence(timeout: timeout), "La participation doit accepter une réponse écrite")
        tapWhenVisible(participationField)
        participationField.typeText(participationReply)
        dismissKeyboardIfNeeded()
        let checkParticipation = button(containingAny: ["Vérifier ma réplique", "Vérifier la réplique", "Vérifier cette réponse"])
        XCTAssertTrue(checkParticipation.waitForExistence(timeout: timeout), "La réponse écrite doit pouvoir être vérifiée")
        tapWhenVisible(checkParticipation)
        XCTAssertTrue(
            text(containingAny: ["Bonne réplique", "Réponse correcte", "Participation réussie"]).waitForExistence(timeout: timeout),
            "La bonne réplique précédente doit produire un retour"
        )

        // First exercise: preserve a selected choice while the app is
        // backgrounded and again after the process is relaunched.
        let firstPrompt = firstExercisePrompt().waitForExistence(timeout: timeout)
        XCTAssertTrue(firstPrompt, "Le premier exercice doit rester accessible après le préambule")
        // The fixture's correct answer is the third tone; use its stable
        // visible prefix so this assertion also catches a missing choice.
        let correctTone = button(containingAny: ["3 — descend puis remonte", "3 —"])
        XCTAssertTrue(correctTone.waitForExistence(timeout: timeout), "Le bon choix du premier exercice est absent")
        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "Le premier exercice doit proposer Vérifier")
        attachInteractionDiagnostics(named: "tone-choice-before-tap", focus: correctTone, action: verify)
        tapWhenVisible(correctTone)
        attachInteractionDiagnostics(named: "tone-choice-after-tap", focus: correctTone, action: verify)
        XCTAssertTrue(
            waitForEnabled(verify),
            "Une réponse sélectionnée doit activer Vérifier"
        )
        backgroundAndReactivate()
        XCTAssertTrue(firstExercisePrompt().waitForExistence(timeout: timeout), "Le même exercice doit survivre au changement d’application")
        XCTAssertTrue(button(exactly: "Vérifier").isEnabled, "La réponse choisie doit rester validable après le retour au premier plan")

        app.terminate()
        app.launch()
        reopenCurrentLessonIfNeeded()
        XCTAssertTrue(firstExercisePrompt().waitForExistence(timeout: timeout), "Le même exercice doit être restauré après relance")
        let restoredVerify = button(exactly: "Vérifier")
        XCTAssertTrue(restoredVerify.waitForExistence(timeout: timeout), "Le contrôle de validation doit être restauré")
        XCTAssertTrue(restoredVerify.isEnabled, "La réponse sélectionnée doit être visible comme réponse en cours après relance")
        tapWhenVisible(restoredVerify)
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "La validation doit être enregistrée")

        // Feedback is itself resumable. A second relaunch must show the
        // correction and Continue, rather than evaluating the same answer a
        // second time or returning to the empty control.
        app.terminate()
        app.launch()
        reopenCurrentLessonIfNeeded()
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "Le feedback doit survivre à la relance")
        let continueAfterFeedback = button(exactly: "Continuer")
        XCTAssertTrue(continueAfterFeedback.waitForExistence(timeout: timeout), "Le feedback restauré doit proposer Continuer")
        tapWhenVisible(continueAfterFeedback)

        let meaning = button(exactly: "Bonjour ; salut")
        XCTAssertTrue(meaning.waitForExistence(timeout: timeout), "Le second exercice doit être chargé")
        tapWhenVisible(meaning)
        XCTAssertTrue(button(exactly: "Vérifier").waitForExistence(timeout: timeout), "Le second exercice doit être validable")
        tapWhenVisible(button(exactly: "Vérifier"))
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "Le second exercice doit être accepté")
        tapWhenVisible(button(exactly: "Continuer"))

        // Word-order controls must restore the partial tile sequence, not
        // merely the parent answer enum.
        let firstTile = button(exactly: "你, position non choisie")
        XCTAssertTrue(firstTile.waitForExistence(timeout: timeout), "La première tuile doit être disponible")
        tapWhenVisible(firstTile)
        XCTAssertTrue(button(exactly: "你, position 1").waitForExistence(timeout: timeout), "La position de la tuile doit être visible")
        XCTAssertTrue(button(exactly: "Vérifier").isEnabled, "Une séquence partielle doit activer Vérifier")
        backgroundAndReactivate()
        app.terminate()
        app.launch()
        reopenCurrentLessonIfNeeded()
        XCTAssertTrue(button(exactly: "你, position 1").waitForExistence(timeout: timeout), "La tuile sélectionnée doit être restaurée visuellement")
        XCTAssertTrue(button(exactly: "Vérifier").isEnabled, "La séquence restaurée doit rester validable")
        let secondTile = button(exactly: "好, position non choisie")
        XCTAssertTrue(secondTile.waitForExistence(timeout: timeout), "La seconde tuile doit être disponible")
        tapWhenVisible(secondTile)
        tapWhenVisible(button(exactly: "Vérifier"))
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "L’ordre restauré doit être accepté")
        tapWhenVisible(button(exactly: "Continuer"))

        let readingChoice = button(containing: "Oui, 再见 clôt l'échange")
        XCTAssertTrue(readingChoice.waitForExistence(timeout: timeout), "La question de lecture doit être chargée")
        tapWhenVisible(readingChoice)
        tapWhenVisible(button(exactly: "Vérifier"))
        XCTAssertTrue(text(containing: "Correct").waitForExistence(timeout: timeout), "La question de lecture doit être acceptée")
        tapWhenVisible(button(exactly: "Continuer"))

        // Oral surface: model playback, explicit stop, speed choice, and a
        // permission-safe fallback. The copy must explain that no phoneme or
        // tone score is being inferred.
        XCTAssertTrue(text(containing: "你好").waitForExistence(timeout: timeout), "La cible orale doit être visible")
        XCTAssertTrue(text(containing: "nǐ hǎo").waitForExistence(timeout: timeout), "Le pinyin oral doit être visible")
        let modelPlay = modelToggleButton()
        XCTAssertTrue(modelPlay.waitForExistence(timeout: timeout), "L’oral doit proposer le modèle")
        XCTAssertTrue(button(exactly: "Normale").waitForExistence(timeout: timeout), "La vitesse normale doit être disponible")
        XCTAssertTrue(button(exactly: "Lente").waitForExistence(timeout: timeout), "La vitesse lente doit être disponible")
        XCTAssertTrue(button(exactly: "Enregistrer").waitForExistence(timeout: timeout), "L’oral doit proposer un grand contrôle d’enregistrement")
        let targetAudio = button(containing: "你好")
        XCTAssertTrue(targetAudio.waitForExistence(timeout: timeout), "La phrase cible doit être une cible audio")
        tapWhenVisible(targetAudio)
        XCTAssertTrue(modelPlay.waitForExistence(timeout: timeout), "La lecture de la phrase cible doit rester dans l’exercice")
        if modelStopButton().waitForExistence(timeout: 2) {
            // The target itself uses the same local voice path. Stop that
            // utterance first so the following action tests the model toggle
            // from its idle state.
            tapWhenVisible(modelStopButton())
        }
        bringIntoView(modelPlay)
        attachScreenshot(named: "oral-controls")
        tapWhenVisible(modelPlay)
        let stopModel = modelStopButton()
        if stopModel.waitForExistence(timeout: 3) {
            tapWhenVisible(stopModel)
        } else {
            XCTAssertTrue(
                text(containingAny: ["Modèle lancé", "Modèle lu", "Audio indisponible"]).waitForExistence(timeout: timeout),
                "La lecture du modèle doit produire un état observable"
            )
        }
        tapWhenVisible(button(exactly: "Lente"))
        tapWhenVisible(button(exactly: "Enregistrer"))
        dismissPermissionPrompts()
        let stopRecording = button(exactly: "Arrêter")
        if stopRecording.waitForExistence(timeout: 5) {
            tapWhenVisible(stopRecording)
            dismissPermissionPrompts()
        }

        // Without a configured provider, the exercise remains explicitly
        // unevaluated. There is no synthetic learner rating and no false
        // Correct feedback; the lesson offers a clear skip path instead.
        let resultDetails = button(exactly: "Voir les résultats")
        if resultDetails.waitForExistence(timeout: 3) {
            tapWhenVisible(resultDetails)
            XCTAssertTrue(
                text(containingAny: ["aucun score de prononciation", "Résultat incertain", "Transcription locale", "ne mesurent pas tes phonèmes ni tes tons"]).waitForExistence(timeout: timeout),
                "Le détail oral doit rester descriptif et sans faux score"
            )
        }
        XCTAssertFalse(button(exactly: "À l’aise").exists, "L’oral ne doit plus proposer de bouton d’auto-évaluation")
        XCTAssertFalse(text(containing: "Correct").exists, "Une absence d’analyse ne doit pas produire un faux Correct")
        let skip = button(exactly: "Passer sans évaluer")
        XCTAssertTrue(skip.waitForExistence(timeout: timeout), "L’oral doit proposer Passer sans évaluer")
        XCTAssertTrue(skip.isEnabled, "Passer sans évaluer doit être disponible sans réponse audio")
        attachScreenshot(named: "oral-result")
        // Capture the unconfigured-provider state under the stable review
        // name before the explicit skip is submitted.
        attachScreenshot(named: "oralunconfigured")
        tapWhenVisible(skip)
        XCTAssertTrue(text(containing: "Passé sans évaluation").waitForExistence(timeout: timeout), "L’état oral doit rester Non évalué après le passage")
        XCTAssertFalse(text(containing: "Correct").exists, "Un oral passé sans évaluation ne doit pas être marqué Correct")
        let continueAnyway = button(exactly: "Continuer malgré tout")
        XCTAssertTrue(continueAnyway.waitForExistence(timeout: timeout), "La leçon doit permettre d’avancer après l’oral non évalué")
        tapWhenVisible(continueAnyway)
        XCTAssertTrue(
            element(containing: "Zone de tracé pour 你", type: .any).waitForExistence(timeout: timeout),
            "Le passage sans évaluation doit mener à l’exercice d’écriture"
        )
        attachScreenshot(named: "writing-after-oral-skip")
    }

    func testLessonDialogueFixtureDeclaresComprehensionAndPreviousReply() throws {
        let dialogue = try dialogueFromFixture(lessonID: "lesson-01")
        XCTAssertGreaterThanOrEqual(dialogue.lines.count, 5, "Le dialogue L1 doit conserver toutes ses répliques")
        XCTAssertTrue(
            dialogue.comprehensionExerciseIDs.contains("ex-l1-reading-last-word"),
            "Le dialogue doit référencer une question de compréhension"
        )
        assertDialogueContract(dialogue, lessonID: "lesson-01")
    }

    func testAllLessonDialogueFixturesExposeSupportAndPreviousReplyMapping() throws {
        for lessonID in ["lesson-01", "lesson-02", "lesson-03", "lesson-04"] {
            let dialogue = try dialogueFromFixture(lessonID: lessonID)
            XCTAssertGreaterThanOrEqual(dialogue.lines.count, 5, "Le dialogue \(lessonID) doit conserver ses répliques")
            for line in dialogue.lines {
                XCTAssertFalse(line.speaker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Locuteur absent dans \(lessonID)")
                XCTAssertFalse(line.hanzi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Réplique absente dans \(lessonID)")
                XCTAssertFalse(line.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Pinyin absent pour \(line.hanzi) dans \(lessonID)")
                XCTAssertFalse(line.translation["fr"]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true, "Traduction française absente pour \(line.hanzi) dans \(lessonID)")
            }
            assertDialogueContract(dialogue, lessonID: lessonID)
        }
    }

    private func dialogueFromFixture(lessonID: String) throws -> DialogueContract {
        let data = try Data(contentsOf: fixtureURL(relativePath: "lessons/\(lessonID).json"))
        let lesson = try JSONDecoder().decode(LessonContract.self, from: data)
        guard let dialogue = lesson.blocks.first(where: { $0.kind == "dialogue" }),
              let lines = dialogue.lines else {
            throw FixtureError.invalidDialogue(lessonID)
        }
        return DialogueContract(
            lines: lines,
            comprehensionExerciseIDs: dialogue.comprehensionExerciseIDs ?? [],
            participation: dialogue.participation
        )
    }

    private func assertDialogueContract(_ dialogue: DialogueContract, lessonID: String) {
        guard let participation = dialogue.participation,
              participation.audioLineIndex > 0,
              participation.audioLineIndex < dialogue.lines.count else {
            return XCTFail("La participation \(lessonID) doit écouter une réplique qui possède une réplique précédente")
        }
        XCTAssertTrue(
            participation.acceptedResponses.contains(dialogue.lines[participation.audioLineIndex - 1].hanzi),
            "La participation \(lessonID) doit accepter exactement la réplique précédant la réponse audio"
        )
    }

    private func completeOnboardingIfNeeded() {
        let welcome = text(containing: "Bienvenue dans Syllune")
        if welcome.waitForExistence(timeout: 5) {
            button(exactly: "Commencer").tap()
        }

        let name = app.textFields.matching(NSPredicate(format: "label CONTAINS[c] %@", "Comment t’appeler")).firstMatch
        if name.waitForExistence(timeout: 3) {
            name.tap()
            name.typeText("Armand")
            button(exactly: "Je connais le pinyin").tap()
            button(exactly: "Continuer").tap()
        }

        if text(containing: "Durée quotidienne").waitForExistence(timeout: 3) {
            element(containing: "15 min", type: .any).tap()
            button(exactly: "Continuer").tap()
        }

        let ready = button(exactly: "Ouvrir ma première leçon")
        if ready.waitForExistence(timeout: 3) {
            ready.tap()
        }
        XCTAssertTrue(text(containing: "Aujourd’hui").waitForExistence(timeout: timeout), "L’espace d’apprentissage doit être ouvert")
    }

    private func openFirstLesson() {
        // The suite intentionally runs this journey after the other UI
        // journeys. Always reopen the lesson from the path so a completed
        // dataset can be restarted through the product UI before exercising
        // draft and feedback restoration.
        navigateToTab("Parcours")
        let lesson = button(containing: "Dire bonjour")
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "La première leçon doit être visible")
        // Keep a stable artifact name for the roadmap review. This is taken
        // before entering the lesson so the screenshot captures the actual
        // path surface rather than the lesson's navigation stack.
        attachScreenshot(named: "roadmap")
        tapWhenVisible(lesson)

        let restart = button(exactly: "Recommencer cette leçon")
        if restart.waitForExistence(timeout: 4) {
            tapWhenVisible(restart)
        }
        XCTAssertTrue(firstExercisePrompt().waitForExistence(timeout: timeout), "La première activité doit être visible")
    }

    private func reopenCurrentLessonIfNeeded() {
        if firstExercisePrompt().waitForExistence(timeout: 5) || text(containing: "Correct").waitForExistence(timeout: 2) {
            return
        }
        navigateToTab("Parcours")
        let lesson = button(containing: "Dire bonjour")
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "La leçon courante doit rester accessible")
        tapWhenVisible(lesson)
    }

    private func expandDiscoveryIfNeeded() {
        let discovery = button(containing: "Découvrir avant de répondre")
        if discovery.waitForExistence(timeout: 5) {
            tapWhenVisible(discovery)
        }
        XCTAssertTrue(text(containing: "Dialogue").waitForExistence(timeout: timeout), "Le bloc découverte doit pouvoir être ouvert")
    }

    private func attachScreenshot(named name: String) {
        guard app.exists else { return }
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func attachInteractionDiagnostics(named name: String, focus: XCUIElement, action: XCUIElement) {
        attachScreenshot(named: name)
        let attachment = XCTAttachment(string: """
        focus: \(focus.debugDescription)
        focus frame: \(frameDescription(focus.frame))
        focus hittable: \(focus.isHittable)
        action: \(action.debugDescription)
        action frame: \(frameDescription(action.frame))
        action enabled: \(action.isEnabled)
        action hittable: \(action.isHittable)
        viewport: \(frameDescription(viewportFrame()))

        Accessibility hierarchy:
        \(app.debugDescription)
        """)
        attachment.name = "\(name)-ax"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapWhenVisible(_ element: XCUIElement) {
        bringIntoView(element)
        XCTAssertTrue(element.isHittable, "L’élément doit être touchable après défilement : \(element.label)")
        element.tap()
    }

    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isEnabled { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.exists && element.isEnabled
    }

    private func bringIntoView(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable && isFullyVisible(element) { return }
            let viewport = viewportFrame()
            guard !viewport.isEmpty, !element.frame.isEmpty else { return }
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
        var viewport = window.exists && !window.frame.isEmpty ? window.frame : app.frame
        let navigationBar = app.navigationBars.firstMatch
        if navigationBar.exists && !navigationBar.frame.isEmpty {
            let top = min(viewport.maxY, navigationBar.frame.maxY + 8)
            viewport.origin.y = max(viewport.minY, top)
            viewport.size.height = max(0, viewport.maxY - viewport.origin.y)
        }
        for label in ["Vérifier", "Continuer", "Terminer", "Continuer malgré tout", "Passer sans évaluer", "Recommencer cette leçon"] {
            let candidate = button(exactly: label)
            guard candidate.exists, !candidate.frame.isEmpty, candidate.frame.minY > viewport.midY else { continue }
            viewport.size.height = max(0, min(viewport.maxY, candidate.frame.minY - 8) - viewport.minY)
            break
        }
        return viewport
    }

    private func frameDescription(_ frame: CGRect) -> String {
        String(format: "x=%.1f y=%.1f w=%.1f h=%.1f", frame.minX, frame.minY, frame.width, frame.height)
    }

    private func backgroundAndReactivate() {
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout), "L’application doit revenir au premier plan")
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

    private func dismissPermissionPrompts() {
        let alert = app.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            XCTAssertTrue(Self.denyPermission(in: alert), "La demande d’autorisation audio doit proposer un refus")
            return
        }

        // Trigger the interruption monitor once from an unused corner. A
        // repeated center tap can toggle the results disclosure underneath
        // the permission sheet and hide the fallback rating.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.02)).tap()
        let promptedAlert = app.alerts.firstMatch
        if promptedAlert.waitForExistence(timeout: 5) {
            XCTAssertTrue(Self.denyPermission(in: promptedAlert), "La demande d’autorisation audio doit proposer un refus")
        }
    }

    private func dismissKeyboardIfNeeded() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        // The return key is localized by the simulator. Tapping it keeps the
        // authored response intact while releasing the controls hidden behind
        // the keyboard.
        for label in ["Retour", "Return", "Done", "Terminé"] {
            let key = keyboard.buttons[label]
            if key.exists && key.isHittable {
                key.tap()
                return
            }
        }

        // A single-line field can also dismiss its keyboard by tapping the
        // unobstructed content above it when no localized return key exists.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
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

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func button(containing value: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", value)).firstMatch
    }

    private func button(containingAny values: [String]) -> XCUIElement {
        for value in values {
            let candidate = button(containing: value)
            if candidate.waitForExistence(timeout: 1) { return candidate }
        }
        return app.buttons.matching(NSPredicate(format: "label == %@", "__missing__")).firstMatch
    }

    private func modelToggleButton() -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ OR label CONTAINS[c] %@", "model-audio-toggle", "Écouter le modèle")
        ).firstMatch
    }

    private func modelStopButton() -> XCUIElement {
        app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS[c] %@", "model-audio-toggle", "Arrêter")
        ).firstMatch
    }

    private func firstTextField(containingAny values: [String]) -> XCUIElement {
        for value in values {
            let candidate = app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@ OR label CONTAINS[c] %@", value, value)).firstMatch
            if candidate.waitForExistence(timeout: 1) { return candidate }
        }
        return app.textFields.matching(NSPredicate(format: "label == %@", "__missing__")).firstMatch
    }

    private func text(containing value: String) -> XCUIElement {
        element(containing: value, type: .any)
    }

    private func firstExercisePrompt() -> XCUIElement {
        // ChineseSelectableText exposes the authored prompt and its Chinese
        // token as separate accessibility elements. Match the stable authored
        // prefix so the assertion follows the visible exercise through
        // restart/background/relaunch without depending on token grouping.
        text(containing: "Quel ton porte")
    }

    private func text(containingAny values: [String]) -> XCUIElement {
        for value in values {
            let candidate = text(containing: value)
            if candidate.waitForExistence(timeout: 1) { return candidate }
        }
        return app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "__missing__")).firstMatch
    }

    private func element(containing value: String, type: XCUIElement.ElementType) -> XCUIElement {
        app.descendants(matching: type)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", value))
            .firstMatch
    }

    private func fixtureURL(relativePath: String) -> URL {
        let sourceURL = URL(fileURLWithPath: #filePath)
        let repositoryRoot = sourceURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return repositoryRoot.appendingPathComponent("Content", isDirectory: true)
            .appendingPathComponent(relativePath, isDirectory: false)
    }

    private func participationReplyFromFixture() throws -> String {
        let data = try Data(contentsOf: fixtureURL(relativePath: "lessons/lesson-01.json"))
        let lesson = try JSONDecoder().decode(LessonContract.self, from: data)
        guard
            let dialogue = lesson.blocks.first(where: { $0.kind == "dialogue" }),
            let participation = dialogue.participation,
            let lines = dialogue.lines,
            participation.audioLineIndex > 0,
            participation.audioLineIndex < lines.count
        else {
            throw FixtureError.invalidParticipation
        }
        // XCTest types through the simulator's active keyboard layout. Use
        // the authored ASCII pinyin variant when available; the app's
        // normalizer deliberately accepts it alongside the Chinese answer.
        if let asciiAnswer = participation.acceptedResponses.first(where: { answer in
            !answer.isEmpty && answer.unicodeScalars.allSatisfy {
                $0.value < 128 && CharacterSet.alphanumerics.contains($0)
            }
        }) {
            return asciiAnswer
        }
        return lines[participation.audioLineIndex - 1].hanzi
    }
}

private struct LessonContract: Decodable {
    let id: String
    let blocks: [BlockContract]
}

private struct BlockContract: Decodable {
    let kind: String
    let lines: [LineContract]?
    let comprehensionExerciseIDs: [String]?
    let participation: ParticipationContract?
}

private struct LineContract: Decodable {
    let speaker: String
    let hanzi: String
    let pinyin: String
    let translation: [String: String]
}

private struct ParticipationContract: Decodable {
    let audioLineIndex: Int
    let acceptedResponses: [String]
}

private enum FixtureError: LocalizedError {
    case invalidParticipation
    case invalidDialogue(String)

    var errorDescription: String? {
        switch self {
        case .invalidParticipation:
            return "Participation dialogue invalide dans le contenu L1"
        case .invalidDialogue(let lessonID):
            return "Dialogue invalide dans le contenu \(lessonID)"
        }
    }
}

private struct DialogueContract {
    let lines: [LineContract]
    let comprehensionExerciseIDs: [String]
    let participation: ParticipationContract?
}
