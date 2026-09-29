import XCTest

/// Checks the real macOS application window after onboarding and keeps a
/// native XCTest attachment for visual review. This is intentionally one
/// short journey: the iOS target owns the longer behavioral smoke coverage.
final class MacHomeJourneyTests: XCTestCase {
    private let timeout: TimeInterval = 20
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication(bundleIdentifier: "com.syllune.PolygoMac")
        app.launchArguments = [
            // Windows restored from an earlier journey would duplicate the chrome.
            "-ApplePersistenceIgnoreState", "YES",
            "-syllune.profile.id", "mac-home-\(UUID().uuidString.lowercased())",
            "-syllune.onboarding.step", "0",
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR",
            "-syllune.appearance", "dark"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
    }

    func testDarkHomeKeepsPrimaryActionsVisible() throws {
        completeOnboardingIfNeeded()
        pressCommand("1")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: timeout), "La fenêtre macOS doit être visible")
        XCTAssertTrue(button(identifier: "home.primaryAction").waitForExistence(timeout: timeout), "Aujourd’hui doit proposer son action principale")
        XCTAssertTrue(button(identifier: "home.primaryAction").isHittable, "L’action principale doit être visible")
        XCTAssertTrue(element(identifier: "home.path").waitForExistence(timeout: timeout), "Le bloc parcours doit être présent")
        XCTAssertTrue(element(identifier: "home.review").waitForExistence(timeout: timeout), "Le bloc révisions doit être présent")
        XCTAssertTrue(text(containing: "Ton parcours").waitForExistence(timeout: timeout), "Le parcours doit rester lisible dans l’accueil macOS")
        assertBottomNavigation(balance: 0)
        captureScreenshot(named: "mac-home-before-layout-assertions")

        selectBottomTab("path")
        XCTAssertTrue(element(containing: "Dire bonjour").waitForExistence(timeout: timeout), "Le parcours macOS doit afficher sa première leçon")
        assertBottomNavigation(balance: 0)
        captureScreenshot(named: "roadmap")
        captureScreenshot(named: "mac-path-dark")

        selectBottomTab("today")
        XCTAssertTrue(text(containing: "Ton parcours").waitForExistence(timeout: timeout), "Le bouton Aujourd’hui doit revenir à son contenu")
        captureScreenshot(named: "mac-home-after-onboarding-dark")
    }

    func testLightPathCaptureUsesRealAppearancePreference() throws {
        completeOnboardingIfNeeded()
        pressCommand("1")
        restartWithAppearance("light")
        selectBottomTab("path")
        XCTAssertTrue(element(containing: "Dire bonjour").waitForExistence(timeout: timeout), "Le parcours doit être visible en thème clair")
        assertBottomNavigation(balance: 0)
        captureScreenshot(named: "mac-path-light")
    }

    func testTodayShortcutRestoresFocusedLessonAfterRelaunch() throws {
        completeOnboardingIfNeeded()
        let prompt = app.staticTexts["lesson.exercise.ex-l1-tone"]
        XCTAssertTrue(prompt.waitForExistence(timeout: timeout), "L’onboarding doit ouvrir la première leçon focalisée")

        let correctTone = button(containing: "3 — descend puis remonte")
        XCTAssertTrue(scrollIntoView(correctTone), "Le bon choix doit être visible dans la leçon")
        correctTone.click()
        let verify = button(exactly: "Vérifier")
        XCTAssertTrue(verify.waitForExistence(timeout: timeout), "Le footer de la leçon doit être disponible")
        XCTAssertTrue(verify.isEnabled, "Le choix doit activer le footer")
        XCTAssertTrue(verify.isHittable, "Le footer doit être actionnable")
        assertFocusedChromeHidden()
        captureScreenshot(named: "mac-focused-exercise-footer")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts["lesson.exercise.ex-l1-tone"].waitForExistence(timeout: timeout), "La leçon focalisée doit être restaurée après relance")
        let restoredVerify = button(exactly: "Vérifier")
        XCTAssertTrue(restoredVerify.waitForExistence(timeout: timeout), "Le footer doit être restauré")
        XCTAssertTrue(restoredVerify.isEnabled, "La réponse choisie doit survivre à la relance")
        assertFocusedChromeHidden()
        captureScreenshot(named: "mac-focused-exercise-restored")

        pressCommand("1")
        XCTAssertTrue(button(identifier: "home.primaryAction").waitForExistence(timeout: timeout), "⌘1 doit revenir à Aujourd’hui depuis la leçon")
        assertBottomNavigation(balance: 0)
        captureScreenshot(named: "mac-home-after-lesson-shortcut")
    }

    func testBottomTabShortcutsAndNestedExplorerRetap() throws {
        completeOnboardingIfNeeded()
        pressCommand("1")
        assertSelectedTab("today")

        pressCommand("2")
        assertSelectedTab("path")
        XCTAssertTrue(element(containing: "Dire bonjour").waitForExistence(timeout: timeout), "⌘2 doit ouvrir le parcours")

        pressCommand("3")
        assertSelectedTab("explorer")
        XCTAssertTrue(button(containing: "Le premier échange").waitForExistence(timeout: timeout), "⌘3 doit ouvrir Explorer")

        pressCommand("4")
        assertSelectedTab("cards")
        XCTAssertTrue(text(containing: "Cartes").waitForExistence(timeout: timeout), "⌘4 doit ouvrir les cartes")

        pressCommand("5")
        assertSelectedTab("profile")
        XCTAssertTrue(text(containing: "Profil").waitForExistence(timeout: timeout), "⌘5 doit ouvrir le profil")

        app.typeKey(",", modifierFlags: .command)
        XCTAssertTrue(text(containing: "Thème").waitForExistence(timeout: timeout), "⌘, doit ouvrir les réglages du profil")
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(text(containing: "Dictionnaire").waitForExistence(timeout: timeout), "⌘K doit ouvrir le dictionnaire")
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: timeout), "⌘K doit rendre la recherche disponible")

        let explorer = app.buttons["BottomTab.explorer"]
        XCTAssertTrue(explorer.waitForExistence(timeout: timeout), "Le vrai bouton Explorer doit rester disponible dans le dictionnaire")
        XCTAssertTrue(explorer.isHittable, "Explorer doit être cliquable depuis le dictionnaire")
        explorer.click()
        XCTAssertTrue(button(identifier: "explorer.dictionary").waitForExistence(timeout: timeout), "Le retap actif doit revenir à la racine d’Explorer")
        XCTAssertTrue(button(containing: "Le premier échange").waitForExistence(timeout: timeout), "La destination imbriquée doit laisser place à la racine d’Explorer")
    }

    func testTabShortcutsOnlyNavigateTheFocusedWindow() throws {
        completeOnboardingIfNeeded()
        pressCommand("2")
        assertSelectedTab("path")
        let originalWindow = try XCTUnwrap(app.windows.allElementsBoundByAccessibilityElement.first)

        pressCommand("n")
        let secondWindow = expectation(
            for: NSPredicate(format: "count == 2"),
            evaluatedWith: app.windows
        )
        wait(for: [secondWindow], timeout: timeout)
        defer {
            // Restored windows would leak into the next journeys: wait until
            // the second window is really closed before the app terminates.
            pressCommand("w")
            let closed = expectation(for: NSPredicate(format: "count == 1"), evaluatedWith: app.windows)
            wait(for: [closed], timeout: timeout)
        }

        pressCommand("5")
        XCTAssertTrue(originalWindow.buttons["BottomTab.path"].isSelected,
                      "Le raccourci de la nouvelle fenêtre ne doit pas déplacer la première")
        let selectedProfiles = app.buttons.matching(identifier: "BottomTab.profile")
            .matching(NSPredicate(format: "selected == true"))
        XCTAssertEqual(selectedProfiles.count, 1, "Seule la fenêtre focalisée doit afficher Profil")
    }

    func testInlineWordSurvivesTabSwitchAndActiveRetapClosesIt() throws {
        completeOnboardingIfNeeded()
        pressCommand("k")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: timeout))
        search.click()
        search.typeText("nihao")
        let dictionaryWord = button(containing: "你好")
        XCTAssertTrue(dictionaryWord.waitForExistence(timeout: timeout))
        dictionaryWord.click()
        let add = button(containing: "Ajouter aux cartes")
        XCTAssertTrue(scrollIntoView(add))
        add.click()
        XCTAssertTrue(button(containing: "Déjà dans mes cartes").waitForExistence(timeout: timeout))

        pressCommand("4")
        let start = button(exactly: "Commencer")
        XCTAssertTrue(start.waitForExistence(timeout: timeout))
        start.click()
        let token = button(exactly: "你好")
        XCTAssertTrue(token.waitForExistence(timeout: timeout))
        token.click()
        let detail = text(containing: "Fiche mot")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout))
        pressCommand("5")
        assertSelectedTab("profile")
        pressCommand("4")
        XCTAssertTrue(detail.waitForExistence(timeout: timeout),
                      "Le changement d’onglet doit conserver la fiche ouverte depuis une carte")
        pressCommand("4")
        XCTAssertFalse(detail.exists, "Le retap actif doit fermer la fiche et retrouver les cartes")
        XCTAssertTrue(start.waitForExistence(timeout: timeout),
                      "Le retap actif doit revenir à l’entrée de la session de cartes")
        assertBottomNavigation(balance: 0)
    }

    private func completeOnboardingIfNeeded() {
        let start = button(exactly: "Commencer")
        guard start.waitForExistence(timeout: timeout) else {
            continueThroughTeaching()
            let resumedLesson = button(exactly: "Vérifier").waitForExistence(timeout: 3)
            let today = button(identifier: "home.primaryAction").waitForExistence(timeout: 3)
            XCTAssertTrue(resumedLesson || today, "L’app macOS doit restaurer une leçon ou Aujourd’hui")
            return
        }
        start.click()

        let name = app.textFields.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Comment t’appeler")
        ).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: timeout), "L’étape du nom doit être accessible sur macOS")
        name.click()
        name.typeText("Armand")

        for option in ["Je commence", "Je connais le pinyin", "Je lis déjà quelques phrases"] {
            XCTAssertTrue(button(exactly: option).waitForExistence(timeout: timeout), "Option absente : \(option)")
        }
        button(exactly: "Je connais le pinyin").click()
        button(exactly: "Continuer").click()

        let rhythmHeading = text(containing: "Durée quotidienne")
        XCTAssertTrue(rhythmHeading.waitForExistence(timeout: timeout), "Le rythme doit être accessible")
        clickExactHittable(label: "15 min", message: "La durée 15 min doit être proposée")
        button(exactly: "Continuer").click()

        XCTAssertTrue(text(containing: "Tout est prêt").waitForExistence(timeout: timeout), "La confirmation doit être accessible")
        let openLesson = button(exactly: "Ouvrir ma première leçon")
        XCTAssertTrue(openLesson.waitForExistence(timeout: timeout), "L’ouverture de la première leçon doit être proposée")
        openLesson.click()
        let situation = app.staticTexts["lesson.step.teaching.block-l1-introduction"]
        XCTAssertTrue(situation.waitForExistence(timeout: timeout), "La première leçon doit s’ouvrir sur sa situation")
        captureScreenshot(named: "lesson-situation")
        continueThroughTeaching()
        XCTAssertTrue(button(exactly: "Vérifier").waitForExistence(timeout: timeout), "La première leçon doit mener à son exercice focalisé")
    }

    /// Lessons teach just in time: continue through the teaching steps up to
    /// the next exercise.
    private func continueThroughTeaching() {
        let next = button(identifier: "lesson.step.continue")
        let anyStep = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@ OR identifier BEGINSWITH %@", "lesson.step.continue", "lesson.exercise.")
        ).firstMatch
        guard anyStep.waitForExistence(timeout: 5) else { return }
        var remaining = 8
        while remaining > 0, next.exists {
            next.click()
            remaining -= 1
            _ = anyStep.waitForExistence(timeout: timeout)
        }
    }

    private func bottomTab(_ name: String) -> XCUIElement? {
        switch name {
        case "today": return app.buttons["BottomTab.today"]
        case "path": return app.buttons["BottomTab.path"]
        case "explorer": return app.buttons["BottomTab.explorer"]
        case "cards": return app.buttons["BottomTab.cards"]
        case "profile": return app.buttons["BottomTab.profile"]
        default: return nil
        }
    }

    private func selectBottomTab(_ name: String) {
        guard let tab = bottomTab(name) else {
            XCTFail("Destination inconnue : \(name)")
            return
        }
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Le bouton BottomTab.\(name) doit être accessible")
        XCTAssertTrue(tab.isHittable, "Le bouton BottomTab.\(name) doit être visible")
        tab.click()
    }

    private func assertSelectedTab(_ name: String) {
        guard let tab = bottomTab(name) else {
            XCTFail("Destination inconnue : \(name)")
            return
        }
        XCTAssertTrue(tab.waitForExistence(timeout: timeout), "Le bouton BottomTab.\(name) doit être présent")
        XCTAssertTrue(tab.isSelected, "Le raccourci doit sélectionner BottomTab.\(name)")
    }

    private func pressCommand(_ key: String) {
        app.typeKey(key, modifierFlags: .command)
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
        for identifier in [
            "BottomTab.today",
            "BottomTab.path",
            "BottomTab.explorer",
            "BottomTab.cards",
            "BottomTab.profile"
        ] {
            let tab = app.buttons[identifier]
            XCTAssertTrue(tab.exists, "Le bouton \(identifier) doit être présent")
            XCTAssertTrue(tab.isHittable, "Le bouton \(identifier) doit être accessible")
        }
        let balance = app.descendants(matching: .any).matching(identifier: "ProgressCoinBalance").firstMatch
        XCTAssertTrue(balance.waitForExistence(timeout: timeout), "Le badge de progression doit être accessible")
        let digits = String(describing: balance.value ?? "").filter { $0.isNumber }
        XCTAssertEqual(Int(digits), expectedBalance, "Le badge doit exposer le solde historique exact")
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
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: identifier).firstMatch.exists, "Le chrome global \(identifier) doit être masqué pendant la leçon")
        }
    }

    private func scrollIntoView(_ element: XCUIElement) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        let scrollView = app.scrollViews.firstMatch
        guard scrollView.waitForExistence(timeout: timeout) else { return false }
        for _ in 0..<12 {
            let targetFrame = element.frame
            let viewport = scrollView.frame
            if element.isHittable && viewport.contains(targetFrame) { return true }
            scrollView.scroll(byDeltaX: 0, deltaY: targetFrame.minY < viewport.minY ? 500 : -500)
        }
        return element.isHittable && scrollView.frame.contains(element.frame)
    }

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func button(containing label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", label)).firstMatch
    }

    private func button(identifier: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier == %@", identifier)).firstMatch
    }

    private func captureScreenshot(named name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func clickExactHittable(label: String, message: String) {
        let candidates = app.radioButtons
            .matching(NSPredicate(format: "label == %@", label))
        guard candidates.firstMatch.waitForExistence(timeout: timeout) else {
            XCTFail(message)
            return
        }
        for index in 0..<candidates.count {
            let candidate = candidates.element(boundBy: index)
            if candidate.waitForExistence(timeout: 2), candidate.isHittable {
                candidate.click()
                return
            }
        }
        XCTFail(message)
    }

    private func element(identifier: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@", identifier))
            .firstMatch
    }

    private func element(containing label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS[c] %@", label))
            .firstMatch
    }

    private func text(containing label: String) -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "value CONTAINS[c] %@ OR label CONTAINS[c] %@", label, label)
        ).firstMatch
    }
}
