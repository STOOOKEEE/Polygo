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

    func testDarkHomeUsesWideDesktopLayoutAndKeepsPrimaryActionsVisible() throws {
        completeOnboardingIfNeeded()

        // Onboarding opens the first lesson so the learner has an immediate
        // next step. Select the real desktop sidebar item to inspect Today,
        // rather than bypassing navigation with an implementation hook.
        selectSidebarItem("Aujourd’hui")
        captureScreenshot(named: "mac-home-before-layout-assertions")

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: timeout), "La fenêtre macOS doit être visible")
        XCTAssertGreaterThanOrEqual(
            window.frame.width,
            1_000,
            "La fenêtre macOS doit rester assez large pour la composition desktop"
        )

        let hero = button(identifier: "home.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: timeout), "Le hero de l’accueil doit être identifié")
        let primaryAction = hero
        XCTAssertTrue(
            primaryAction.waitForExistence(timeout: timeout),
            "L’accueil doit exposer son action principale"
        )
        XCTAssertTrue(
            primaryAction.isHittable,
            "L’action principale doit être visible dans la fenêtre desktop"
        )
        let path = element(identifier: "home.path")
        XCTAssertTrue(
            path.waitForExistence(timeout: timeout),
            "Le bloc parcours doit être présent"
        )
        let review = element(identifier: "home.review")
        XCTAssertTrue(
            review.waitForExistence(timeout: timeout),
            "Le bloc révisions doit être présent"
        )
        XCTAssertGreaterThan(
            review.frame.minX,
            hero.frame.minX + 8,
            "Le bloc révisions doit se placer dans la colonne desktop secondaire"
        )
        XCTAssertTrue(
            text(containing: "Ton parcours").waitForExistence(timeout: timeout),
            "Le parcours doit rester lisible dans l’accueil macOS"
        )

        captureScreenshot(named: "mac-home-after-onboarding-dark")
    }

    func testTodaySidebarReturnsFromLessonToHomeRoot() throws {
        completeOnboardingIfNeeded()
        selectSidebarItem("Aujourd’hui")

        captureScreenshot(named: "mac-home-before-reset-assertions")
        let hero = button(identifier: "home.hero")
        XCTAssertTrue(hero.waitForExistence(timeout: timeout), "L’accueil doit être visible avant l’ouverture de la leçon")
        let primaryAction = hero
        XCTAssertTrue(primaryAction.waitForExistence(timeout: timeout), "L’accueil doit proposer l’ouverture de la leçon")
        XCTAssertTrue(primaryAction.isHittable, "L’ouverture de la leçon doit être accessible")
        primaryAction.click()

        captureScreenshot(named: "mac-lesson-before-sidebar-reset")
        let lessonAction = button(exactly: "Vérifier")
        XCTAssertTrue(lessonAction.waitForExistence(timeout: timeout), "La leçon doit remplacer l’accueil dans le détail")

        // Today is already selected in the sidebar. This click must still
        // activate the route and recreate the detail stack at its root.
        selectSidebarItem("Aujourd’hui")
        captureScreenshot(named: "mac-home-after-sidebar-reset")
        XCTAssertTrue(hero.waitForExistence(timeout: timeout), "Aujourd’hui doit revenir à la racine après la leçon")
    }

    private func completeOnboardingIfNeeded() {
        let start = button(exactly: "Commencer")
        guard start.waitForExistence(timeout: timeout) else {
            XCTAssertTrue(
                element(containing: "Aujourd’hui").waitForExistence(timeout: timeout),
                "L’app macOS doit démarrer sur l’espace d’apprentissage"
            )
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
        XCTAssertTrue(
            rhythmHeading.waitForExistence(timeout: timeout),
            "Le rythme doit être accessible"
        )
        clickExactHittable(label: "15 min", message: "La durée 15 min doit être proposée")
        button(exactly: "Continuer").click()

        let readyHeading = text(containing: "Tout est prêt")
        XCTAssertTrue(
            readyHeading.waitForExistence(timeout: timeout),
            "La confirmation doit être accessible"
        )
        let openLesson = button(exactly: "Ouvrir ma première leçon")
        XCTAssertTrue(openLesson.waitForExistence(timeout: timeout), "L’ouverture de la première leçon doit être proposée")
        openLesson.click()
    }

    private func selectSidebarItem(_ label: String) {
        let buttons = app.buttons.matching(NSPredicate(format: "label == %@", label))
        _ = buttons.firstMatch.waitForExistence(timeout: timeout)
        for index in 0..<buttons.count {
            let button = buttons.element(boundBy: index)
            if button.waitForExistence(timeout: 2), button.isHittable {
                button.click()
                return
            }
        }

        let rows = app.outlineRows.matching(NSPredicate(format: "label == %@", label))
        _ = rows.firstMatch.waitForExistence(timeout: timeout)
        for index in 0..<rows.count {
            let row = rows.element(boundBy: index)
            if row.waitForExistence(timeout: 2), row.isHittable {
                row.click()
                return
            }
        }

        // Keep a semantic fallback for a macOS List presentation that exposes
        // navigation links as buttons or generic accessibility elements.
        let candidates = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
        _ = candidates.firstMatch.waitForExistence(timeout: timeout)
        for index in 0..<candidates.count {
            let candidate = candidates.element(boundBy: index)
            if candidate.waitForExistence(timeout: 2), candidate.isHittable {
                candidate.click()
                return
            }
        }
        XCTFail("Navigation absente : \(label)")
    }

    private func button(exactly label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
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
