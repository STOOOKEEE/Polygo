import Foundation
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
        app.launchArguments = [
            "-syllune.profile.id", "ui-\(UUID().uuidString.lowercased())",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"
        ]
        app.launch()
    }

    func testFrenchOnboardingAndPrimaryOfflineJourneys() throws {
        // A new profile must not reopen a previous profile's saved lesson.
        app.launchArguments += ["-syllune.last.route", "lesson/lesson-05"]
        app.launch()
        app.launchArguments.removeLast(2)
        completeOnboardingIfNeeded()
        XCTAssertTrue(
            app.staticTexts["lesson.exercise.ex-l1-tone"].waitForExistence(timeout: timeout),
            "Le nouvel onboarding doit ouvrir la première leçon, pas la route du profil précédent"
        )

        navigateToTab("Parcours")
        let lesson = app.buttons["learningPath.lesson.lesson-01"]
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "La première leçon doit être visible dans le parcours")
        tapWhenVisible(lesson)

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
        let theme = element(containing: "Thème", type: .button)
        XCTAssertTrue(findAfterScrolling(theme), "Les réglages doivent exposer le thème")
        let priorThemeValue = "\(theme.label) \(String(describing: theme.value ?? ""))"
        let priorTheme = ["Système", "Clair", "Sombre"].first {
            priorThemeValue.localizedCaseInsensitiveContains($0)
        }
        guard let priorTheme else {
            XCTFail("Le réglage doit exposer sa préférence actuelle")
            return
        }
        tapWhenVisible(theme)
        let darkTheme = element(containing: "Sombre", type: .any)
        XCTAssertTrue(darkTheme.waitForExistence(timeout: timeout), "Le sélecteur de thème doit proposer le mode sombre")
        darkTheme.tap()
        XCTAssertTrue(element(containing: "Sombre", type: .any).waitForExistence(timeout: timeout), "Le thème choisi doit être appliqué")
        XCTAssertTrue(findAfterScrolling(element(containing: "Hors ligne", type: .any)), "Les réglages doivent exposer le statut hors ligne")
        XCTAssertTrue(findAfterScrolling(element(containing: "Sur cet appareil", type: .any)), "Le statut de synchronisation doit être honnête")
        if priorTheme != "Sombre" {
            tapWhenVisible(element(containing: "Thème", type: .button))
            let originalTheme = element(containing: priorTheme, type: .any)
            XCTAssertTrue(originalTheme.waitForExistence(timeout: timeout), "Le thème initial doit pouvoir être restauré")
            originalTheme.tap()
        }
        navigateToTab("Explorer")
        let story = element(containing: "Le premier échange", type: .any)
        XCTAssertTrue(story.waitForExistence(timeout: timeout), "Une histoire locale doit être proposée")
        attachScreenshot(named: "ios-explorer")
        story.tap()
        let storyReading = element(containing: "Lecture", type: .any)
        XCTAssertTrue(storyReading.waitForExistence(timeout: timeout), "La lecture de l’histoire doit s’ouvrir")
        if storyReading.exists {
            attachScreenshot(named: "ios-story-reading")
        }
        // Return to Explorer's root before opening the dictionary sheet. The
        // sheet's list uses an ASCII pinyin query so the test does not depend
        // on the simulator keyboard layout for Chinese input.
        goBack()
        openVocabularyDetailFromDictionary()
    }
    func testInactiveTabsPreserveStoryAndSettingsUntilActiveTabRetap() throws {
        completeOnboardingIfNeeded()
        navigateToTab("Explorer")

        let story = element(containing: "Le premier échange", type: .any)
        XCTAssertTrue(story.waitForExistence(timeout: timeout), "Une histoire locale doit être accessible dans Explorer")
        story.tap()
        let storyReading = element(containing: "Lecture", type: .any)
        XCTAssertTrue(storyReading.waitForExistence(timeout: timeout), "La lecture de l’histoire doit s’ouvrir")

        navigateToTab("Parcours")
        XCTAssertTrue(app.buttons["learningPath.lesson.lesson-01"].waitForExistence(timeout: timeout), "Le changement d’onglet doit afficher le parcours")
        navigateToTab("Explorer")
        XCTAssertTrue(storyReading.waitForExistence(timeout: timeout), "Revenir à Explorer doit conserver l’histoire ouverte")
        XCTAssertTrue(storyReading.isHittable, "L’histoire conservée doit rester réellement visible après le retour d’onglet")

        let explorer = app.buttons["BottomTab.explorer"]
        XCTAssertTrue(explorer.isSelected, "Explorer doit être l’onglet actif avant son retap")
        explorer.tap()
        XCTAssertTrue(element(containing: "Histoires", type: .any).waitForExistence(timeout: timeout), "Le retap actif doit dépiler l’histoire jusqu’à la racine Explorer")
        XCTAssertTrue(story.waitForExistence(timeout: timeout), "La racine Explorer doit retrouver l’histoire")
        XCTAssertTrue(story.isHittable, "La racine Explorer doit rendre son histoire actionnable")
        XCTAssertFalse(storyReading.exists, "Le retap actif doit réellement fermer la lecture imbriquée")

        navigateToTab("Profil")
        let settingsLink = element(containing: "Réglages", type: .button)
        XCTAssertTrue(settingsLink.waitForExistence(timeout: timeout), "Le profil doit proposer ses réglages")
        settingsLink.tap()
        let theme = element(containing: "Thème", type: .any)
        XCTAssertTrue(findAfterScrolling(theme), "Les réglages doivent afficher leur préférence de thème")

        navigateToTab("Parcours")
        XCTAssertTrue(app.buttons["learningPath.lesson.lesson-01"].waitForExistence(timeout: timeout), "Le parcours doit s’ouvrir depuis Réglages")
        navigateToTab("Profil")
        XCTAssertTrue(findAfterScrolling(theme), "Revenir au profil doit conserver Réglages ouvert")

        let profile = app.buttons["BottomTab.profile"]
        XCTAssertTrue(profile.isSelected, "Profil doit être l’onglet actif avant son retap")
        profile.tap()
        XCTAssertTrue(settingsLink.waitForExistence(timeout: timeout), "Le retap actif doit dépiler Réglages vers Profil")
        XCTAssertTrue(settingsLink.isHittable, "La racine Profil doit rendre ses réglages actionnables après le retap")
        XCTAssertFalse(theme.exists, "Le retap actif doit réellement fermer Réglages")
    }

    func testIPadKeyboardShortcutsReachTabsAndSettingsFromFocusedContent() throws {
        completeOnboardingIfNeeded()
        navigateToTab("Parcours")

        let lesson = app.buttons["learningPath.lesson.lesson-01"]
        XCTAssertTrue(lesson.waitForExistence(timeout: timeout), "La première leçon doit être accessible depuis Parcours")
        tapWhenVisible(lesson)
        let restart = button(exactly: "Recommencer cette leçon")
        if restart.waitForExistence(timeout: 3) {
            tapWhenVisible(restart)
        }
        XCTAssertTrue(app.staticTexts["lesson.exercise.ex-l1-tone"].waitForExistence(timeout: timeout), "L’exercice réel doit être ouvert avant le raccourci")
        assertFocusedChromeHidden()

        app.typeKey("1", modifierFlags: .command)
        let today = app.buttons["BottomTab.today"]
        XCTAssertTrue(today.waitForExistence(timeout: timeout), "⌘1 doit atteindre Aujourd’hui depuis une leçon sans chrome")
        XCTAssertTrue(today.isSelected, "⌘1 doit sélectionner Aujourd’hui")
        XCTAssertTrue(element(containing: "Ton parcours", type: .any).waitForExistence(timeout: timeout), "⌘1 doit afficher le contenu réel d’Aujourd’hui")

        func focusDictionarySearch() {
            app.typeKey("3", modifierFlags: .command)
            let explorer = app.buttons["BottomTab.explorer"]
            XCTAssertTrue(explorer.waitForExistence(timeout: timeout), "⌘3 doit atteindre Explorer")
            XCTAssertTrue(explorer.isSelected, "⌘3 doit sélectionner Explorer")
            XCTAssertTrue(element(containing: "Le premier échange", type: .any).waitForExistence(timeout: timeout), "⌘3 doit afficher la racine Explorer")

            let dictionary = app.buttons["explorer.dictionary"]
            XCTAssertTrue(dictionary.waitForExistence(timeout: timeout), "Explorer doit proposer le vrai dictionnaire")
            dictionary.tap()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: timeout), "Le dictionnaire doit proposer sa recherche")
            search.tap()
            search.typeText("nihao")
            XCTAssertTrue(element(containing: "你好", type: .button).waitForExistence(timeout: timeout), "La recherche focalisée doit afficher le résultat réel")
        }

        focusDictionarySearch()
        app.typeKey("1", modifierFlags: .command)
        XCTAssertTrue(today.isSelected, "⌘1 doit rester actionnable depuis le champ focalisé")
        XCTAssertTrue(element(containing: "Ton parcours", type: .any).waitForExistence(timeout: timeout), "⌘1 depuis la recherche doit atteindre Aujourd’hui")

        focusDictionarySearch()
        let path = app.buttons["BottomTab.path"]
        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(path.waitForExistence(timeout: timeout), "⌘2 doit atteindre Parcours depuis le champ focalisé")
        XCTAssertTrue(path.isSelected, "⌘2 doit sélectionner Parcours")
        XCTAssertTrue(app.buttons["learningPath.lesson.lesson-01"].waitForExistence(timeout: timeout), "⌘2 doit afficher la première leçon")

        focusDictionarySearch()
        let explorer = app.buttons["BottomTab.explorer"]
        app.typeKey("3", modifierFlags: .command)
        XCTAssertTrue(explorer.isSelected, "⌘3 doit rester actionnable depuis le champ focalisé")
        XCTAssertTrue(element(containing: "Le premier échange", type: .any).waitForExistence(timeout: timeout), "⌘3 depuis le dictionnaire doit revenir à la racine Explorer")

        focusDictionarySearch()
        let cards = app.buttons["BottomTab.cards"]
        app.typeKey("4", modifierFlags: .command)
        XCTAssertTrue(cards.waitForExistence(timeout: timeout), "⌘4 doit atteindre Cartes depuis le champ focalisé")
        XCTAssertTrue(cards.isSelected, "⌘4 doit sélectionner Cartes")
        XCTAssertTrue(element(containing: "Cartes", type: .any).waitForExistence(timeout: timeout), "⌘4 doit afficher la destination réelle Cartes")

        focusDictionarySearch()
        let profile = app.buttons["BottomTab.profile"]
        app.typeKey("5", modifierFlags: .command)
        XCTAssertTrue(profile.waitForExistence(timeout: timeout), "⌘5 doit atteindre Profil depuis le champ focalisé")
        XCTAssertTrue(profile.isSelected, "⌘5 doit sélectionner Profil")
        XCTAssertTrue(element(containing: "Profil", type: .any).waitForExistence(timeout: timeout), "⌘5 doit afficher la destination réelle Profil")

        focusDictionarySearch()
        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(profile.isSelected, "⌘, doit conserver Profil comme onglet des réglages")
        let theme = element(containing: "Thème", type: .any)
        XCTAssertTrue(findAfterScrolling(theme), "⌘, depuis le champ focalisé doit ouvrir les vrais Réglages")
    }

    func testPathCapturesAcrossThemesAndOrientationsAndFocusedFooter() throws {
        let originalOrientation = XCUIDevice.shared.orientation
        defer { XCUIDevice.shared.orientation = originalOrientation }

        restartWithAppearance("light")
        completeOnboardingIfNeeded()
        navigateToTab("Parcours")
        XCTAssertTrue(app.buttons["learningPath.lesson.lesson-01"].waitForExistence(timeout: timeout), "La première leçon doit être visible avant la capture")
        assertBottomNavigation(balance: 0)
        attachScreenshot(named: "ios-path-light-portrait")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["BottomTab.path"].waitForExistence(timeout: timeout), "Le parcours doit rester visible en paysage")
        assertBottomNavigation(balance: 0)
        attachScreenshot(named: "ios-path-light-landscape")

        restartWithAppearance("dark")
        navigateToTab("Parcours")
        XCTAssertTrue(app.buttons["learningPath.lesson.lesson-01"].waitForExistence(timeout: timeout), "Le parcours doit être restauré après le changement de thème")
        attachScreenshot(named: "ios-path-dark-landscape")

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["BottomTab.path"].waitForExistence(timeout: timeout), "Le parcours doit rester visible en portrait")
        attachScreenshot(named: "ios-path-dark-portrait")

        let lesson = app.buttons["learningPath.lesson.lesson-01"]
        tapWhenVisible(lesson)
        let exercise = app.staticTexts["lesson.exercise.ex-l1-tone"]
        XCTAssertTrue(exercise.waitForExistence(timeout: timeout), "L’exercice doit s’ouvrir depuis le parcours")
        let answer = element(containing: "3 — descend puis remonte", type: .button)
        tapWhenVisible(answer)
        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "Le footer doit proposer la validation")
        XCTAssertTrue(verify.isEnabled, "Le footer doit rester actionnable")
        XCTAssertTrue(verify.isHittable, "Le footer doit rester visible")
        assertFocusedChromeHidden()
        attachScreenshot(named: "ios-focused-exercise-footer")
    }

    func testRestoredStandalonePracticeHidesChromeUntilExit() throws {
        completeOnboardingIfNeeded()
        navigateToTab("Aujourd’hui")
        let originalArguments = app.launchArguments

        for route in ["oral/ex-l1-speak", "writing/ex-l1-write"] {
            app.terminate()
            app.launchArguments = originalArguments + ["-syllune.last.route", route]
            app.launch()
            if route.hasPrefix("oral/") {
                XCTAssertTrue(app.buttons["model-audio-toggle"].waitForExistence(timeout: timeout),
                              "La route restaurée doit charger le vrai exercice oral")
                XCTAssertTrue(button(exactly: "Passer sans évaluer").exists)
            } else {
                XCTAssertTrue(element(containing: "Zone de tracé pour 你", type: .any)
                    .waitForExistence(timeout: timeout),
                              "La route restaurée doit charger le vrai canevas d’écriture")
            }
            assertFocusedChromeHidden()
            attachScreenshot(named: route.hasPrefix("oral/") ? "ios-standalone-oral" : "ios-standalone-writing")
            goBack()
            assertBottomNavigation(balance: 0)
            navigateToTab("Aujourd’hui")

            app.terminate()
            app.launchArguments = originalArguments
            app.launch()
            XCTAssertTrue(app.buttons["BottomTab.today"].waitForExistence(timeout: timeout))
            XCTAssertTrue(app.buttons["BottomTab.today"].isSelected,
                          "La relance sans argument doit conserver la destination choisie après la sortie")
            assertBottomNavigation(balance: 0)
        }
    }


    private func restartWithAppearance(_ appearance: String) {
        app.terminate()
        var arguments = app.launchArguments
        if let index = arguments.firstIndex(of: "-syllune.appearance"),
           arguments.indices.contains(index + 1) {
            arguments.removeSubrange(index...(index + 1))
        }
        app.launchArguments = arguments + ["-syllune.appearance", appearance]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout), "L’application doit reprendre après le changement de thème")
    }

    private func assertBottomNavigation(balance expectedBalance: Int) {
        let balance = app.descendants(matching: .any).matching(identifier: "ProgressCoinBalance").firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: timeout), "Le solde global doit être accessible")
        for identifier in [
            "BottomTab.today",
            "BottomTab.path",
            "BottomTab.explorer",
            "BottomTab.cards",
            "BottomTab.profile"
        ] {
            XCTAssertTrue(app.buttons[identifier].exists, "Le contrôle \(identifier) doit être présent sur une destination principale")
        }
        let digits = String(describing: balance.value ?? "").filter { $0.isNumber }
        XCTAssertEqual(Int(digits), expectedBalance, "La valeur accessible du solde doit correspondre à l’historique réel")
    }

    private func assertFocusedChromeHidden() {
        for identifier in [
            "BottomTab.today",
            "BottomTab.path",
            "BottomTab.explorer",
            "BottomTab.cards",
            "BottomTab.profile",
            "ProgressCoinBalance"
        ] {
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists, "Le chrome global \(identifier) doit être masqué pendant l’exercice")
        }
    }

    private func completeOnboardingIfNeeded() {
        // The onboarding draft is stored in global UserDefaults. A simulator
        // reused by CI can therefore reopen on any of its four steps even
        // though this method uses a fresh profile journal. Drive whichever
        // draft step is currently visible before asserting the shell.
        let welcome = element(containing: "Bienvenue dans Syllune", type: .any)
        if welcome.waitForExistence(timeout: 5) {
            attachScreenshot(named: "ios-onboarding-welcome")
            button(exactly: "Commencer").tap()
        }

        let name = element(containing: "Comment t’appeler", type: .textField)
        if name.waitForExistence(timeout: 3) {
            name.tap()
            attachScreenshot(named: "ios-onboarding-name-keyboard")
            name.typeText("Armand")
            for option in ["Je commence", "Je connais le pinyin", "Je lis déjà quelques phrases"] {
                XCTAssertTrue(element(containing: option, type: .button).waitForExistence(timeout: timeout), "Option onboarding absente : \(option)")
            }
            element(containing: "Je connais le pinyin", type: .button).tap()
            element(containing: "Continuer", type: .button).tap()
        }

        if element(containing: "Durée quotidienne", type: .any).waitForExistence(timeout: 3) {
            for duration in ["5 min", "10 min", "15 min"] {
                XCTAssertTrue(element(containing: duration, type: .any).waitForExistence(timeout: timeout), "Durée onboarding absente : \(duration)")
            }
            element(containing: "15 min", type: .any).tap()
            attachScreenshot(named: "ios-onboarding-rhythm")
            element(containing: "Continuer", type: .button).tap()

        }

        let ready = button(exactly: "Ouvrir ma première leçon")
        if ready.waitForExistence(timeout: 3) {
            attachScreenshot(named: "ios-onboarding-ready")
            ready.tap()
        }
        let resumedLesson = app.staticTexts["lesson.exercise.ex-l1-tone"].waitForExistence(timeout: timeout)
        let todayIsAvailable = app.buttons["BottomTab.today"].waitForExistence(timeout: timeout)
        XCTAssertTrue(resumedLesson || todayIsAvailable, "L’application doit ouvrir une leçon ou une destination principale")
    }

    private func navigateToTab(_ label: String) {
        leaveLessonBeforeSelectingTab()
        let identifier: String
        switch label {
        case "Aujourd’hui": identifier = "BottomTab.today"
        case "Parcours": identifier = "BottomTab.path"
        case "Explorer": identifier = "BottomTab.explorer"
        case "Cartes": identifier = "BottomTab.cards"
        case "Profil": identifier = "BottomTab.profile"
        default:
            XCTFail("Destination inconnue : \(label)")
            return
        }
        let tab = app.buttons[identifier]
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Le bouton de destination \(label) doit être accessible")
        XCTAssertTrue(tab.isHittable, "Le bouton de destination \(label) doit être visible")
        tab.tap()
    }

    private func leaveLessonBeforeSelectingTab() {
        let lessonControl = app.buttons.matching(
            NSPredicate(format: "label == %@ OR label == %@", "Vérifier", "Recommencer cette leçon")
        ).firstMatch
        guard lessonControl.exists else { return }

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: timeout), "La leçon doit pouvoir être quittée avant de changer de destination")
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
        let dictionary = app.buttons["explorer.dictionary"]
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
        var fullyVisible = false
        for _ in 0..<8 {
            let frame = element.frame
            let navigationBar = app.navigationBars.firstMatch
            let footer = app.buttons["BottomTab.today"]
            let top = navigationBar.exists ? navigationBar.frame.maxY : app.frame.minY
            let bottom = footer.exists ? footer.frame.minY : app.frame.maxY
            fullyVisible = element.isHittable && frame.minY >= top && frame.maxY <= bottom
            if fullyVisible { break }
            if frame.minY < top {
                app.swipeDown()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(fullyVisible, "L’élément doit être visible hors des barres de navigation : \(element.label)")
        element.tap()
    }

    private func element(containing text: String, type: XCUIElement.ElementType) -> XCUIElement {
        app.descendants(matching: type)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", text))
            .firstMatch
    }
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
