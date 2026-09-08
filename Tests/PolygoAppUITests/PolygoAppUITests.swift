import XCTest

final class PolygoAppUITests: XCTestCase {
    private var app: XCUIApplication!
    private let timeout: TimeInterval = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The product strings are French. These arguments also keep the smoke
        // contract deterministic when the simulator's preferred language is
        // different from the app's development language.
        app.launchArguments = ["-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"]
        app.launch()
    }

    func testFrenchOnboardingAndPrimaryOfflineJourneys() throws {
        completeOnboardingIfNeeded()

        navigateToTab("Parcours")
        let lesson = element(containing: "Dire bonjour", type: .button)
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "La première leçon doit être visible dans le parcours")
        lesson.tap()

        // The suite may run after the lesson completion journey on the same
        // simulator. Reopen the completed lesson through its explicit reset
        // action before asserting the first exercise surface.
        let restart = element(containing: "Recommencer cette leçon", type: .button)
        if restart.waitForExistence(timeout: 4) {
            restart.tap()
        }

        let verify = element(containing: "Vérifier", type: .button)
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "Le premier exercice doit être chargé")

        // The lesson keeps its optional discovery material collapsed. Expand
        // it before targeting a vocabulary token so the test follows the
        // learner-facing path rather than matching text in the introduction.
        let discovery = element(containing: "Découvrir avant de répondre", type: .button)
        XCTAssertTrue(discovery.waitForExistence(timeout: timeout), "La découverte facultative doit être proposée")
        discovery.tap()

        // Vocabulary tokens in the lesson are pronunciation controls. They
        // must leave the exercise usable; the dedicated dictionary below is
        // the explicit route to the optional word detail screen.
        // The expanded discovery block also exposes dialogue lines as
        // buttons whose labels contain 你好. Match the token's exact label so
        // this action follows the vocabulary control.
        let word = button(exactly: "你好")
        XCTAssertTrue(word.waitForExistence(timeout: timeout), "Le mot 你好 doit être lié depuis la leçon")
        tapWhenVisible(word)
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "La lecture du mot doit laisser la leçon utilisable")

        navigateToTab("Cartes")
        XCTAssertTrue(element(containing: "Cartes", type: .any).waitForExistence(timeout: timeout), "La section Cartes doit être accessible")

        navigateToTab("Profil")
        // The surrounding card title also contains « Réglages »; target the
        // navigation control rather than that static heading.
        let settingsLink = element(containing: "Réglages", type: .button)
        XCTAssertTrue(settingsLink.waitForExistence(timeout: timeout), "Le profil doit proposer les réglages")
        settingsLink.tap()
        let theme = element(containing: "Thème", type: .any)
        XCTAssertTrue(findAfterScrolling(theme), "Les réglages doivent exposer le thème")
        theme.tap()
        let darkTheme = element(containing: "Sombre", type: .any)
        XCTAssertTrue(darkTheme.waitForExistence(timeout: timeout), "Le sélecteur de thème doit proposer le mode sombre")
        darkTheme.tap()
        XCTAssertTrue(element(containing: "Sombre", type: .any).waitForExistence(timeout: timeout), "Le thème choisi doit être appliqué")
        XCTAssertTrue(findAfterScrolling(element(containing: "Hors ligne", type: .any)), "Les réglages doivent exposer le statut hors ligne")
        XCTAssertTrue(findAfterScrolling(element(containing: "Sur cet appareil", type: .any)), "Le statut de synchronisation doit être honnête")

        navigateToTab("Explorer")
        let story = element(containing: "Le premier échange", type: .any)
        XCTAssertTrue(story.waitForExistence(timeout: timeout), "Une histoire locale doit être proposée")
        story.tap()
        XCTAssertTrue(element(containing: "Lecture", type: .any).waitForExistence(timeout: timeout), "La lecture de l’histoire doit s’ouvrir")

        // Return to Explorer's root before opening the dictionary sheet. The
        // sheet's list uses an ASCII pinyin query so the test does not depend
        // on the simulator keyboard layout for Chinese input.
        goBack()
        openVocabularyDetailFromDictionary()
    }

    private func completeOnboardingIfNeeded() {
        // A completed lesson can expose an "À commencer" status on its
        // row. Match the onboarding action exactly so a persisted session
        // cannot be mistaken for the welcome screen.
        let start = button(exactly: "Commencer")
        guard start.waitForExistence(timeout: 5) else {
            // A simulator reused between runs may already have a local
            // profile. The rest of the smoke still exercises the live shell.
            XCTAssertTrue(element(containing: "Aujourd’hui", type: .any).waitForExistence(timeout: timeout), "L’application doit démarrer sur le shell principal")
            return
        }

        start.tap()

        let name = element(containing: "Comment t’appeler", type: .textField)
        XCTAssertTrue(name.waitForExistence(timeout: timeout), "L’étape de nom doit être visible en français")
        name.tap()
        name.typeText("Armand")

        for option in ["Je commence", "Je connais le pinyin", "Je lis déjà quelques phrases"] {
            XCTAssertTrue(element(containing: option, type: .button).waitForExistence(timeout: timeout), "Option onboarding absente : \(option)")
        }
        element(containing: "Je connais le pinyin", type: .button).tap()
        element(containing: "Continuer", type: .button).tap()

        XCTAssertTrue(element(containing: "Durée quotidienne", type: .any).waitForExistence(timeout: timeout), "L’étape de rythme doit être visible")
        for duration in ["5 min", "10 min", "15 min"] {
            XCTAssertTrue(element(containing: duration, type: .any).waitForExistence(timeout: timeout), "Durée onboarding absente : \(duration)")
        }
        element(containing: "15 min", type: .any).tap()
        element(containing: "Continuer", type: .button).tap()

        XCTAssertTrue(element(containing: "Tout est prêt", type: .any).waitForExistence(timeout: timeout), "L’étape de confirmation doit être visible")
        element(containing: "Ouvrir ma première leçon", type: .button).tap()
        XCTAssertTrue(element(containing: "Aujourd’hui", type: .any).waitForExistence(timeout: timeout), "L’onboarding doit ouvrir l’espace d’apprentissage")
    }

    private func navigateToTab(_ label: String) {
        leaveLessonBeforeSelectingTab()
        let tab = app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
        if tab.waitForExistence(timeout: 5) {
            tab.tap()
            return
        }

        // iPad may render the same shell as a navigation sidebar instead of
        // a tab bar. The label contract is shared by both presentations.
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

    private func goBack() {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 5) {
            back.tap()
        } else {
            XCTFail("Le bouton de retour est absent")
        }
    }

    private func findAfterScrolling(_ element: XCUIElement, maxSwipes: Int = 6) -> Bool {
        if element.waitForExistence(timeout: 2) { return true }
        for _ in 0..<maxSwipes {
            app.swipeUp()
            if element.waitForExistence(timeout: 1) { return true }
        }
        return false
    }

    private func openVocabularyDetailFromDictionary() {
        let dictionary = element(containing: "Dictionnaire de l’unité 1", type: .button)
        XCTAssertTrue(dictionary.waitForExistence(timeout: timeout), "L’explorateur doit proposer le dictionnaire")
        dictionary.tap()

        XCTAssertTrue(element(containing: "Dictionnaire", type: .any).waitForExistence(timeout: timeout), "Le dictionnaire doit s’ouvrir")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout), "Le dictionnaire doit proposer sa recherche")
        search.tap()
        search.typeText("nihao")

        let word = element(containing: "你好", type: .button)
        XCTAssertTrue(word.waitForExistence(timeout: timeout), "La recherche pinyin doit trouver 你好")
        tapWhenVisible(word)
        XCTAssertTrue(element(containing: "Fiche mot", type: .any).waitForExistence(timeout: timeout), "La fiche mot doit s’ouvrir depuis le dictionnaire")
        let audio = element(containing: "Écouter", type: .button)
        XCTAssertTrue(audio.waitForExistence(timeout: timeout), "La fiche mot doit proposer l’action audio")
        audio.tap()
    }

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func tapWhenVisible(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "L’élément doit être touchable : \(element.label)")
        element.tap()
    }

    private func element(containing text: String, type: XCUIElement.ElementType) -> XCUIElement {
        app.descendants(matching: type)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
            .firstMatch
    }
}
