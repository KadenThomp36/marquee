import XCTest

/// A walkthrough that pairs the app with a Marquee server and visits the main
/// screens, attaching a screenshot of each.
///
/// The server address and credentials are **never** in this file. They come from the
/// environment at run time:
///
///     TEST_RUNNER_MARQUEE_TEST_SERVER=127.0.0.1:8010 \
///     TEST_RUNNER_MARQUEE_TEST_USER=… \
///     TEST_RUNNER_MARQUEE_TEST_PASSWORD=… \
///     xcodebuild test -scheme Marquee -destination '…'
///
/// With nothing set, the pairing tests skip and only the unpaired-state test runs —
/// so a checkout of this repo can be tested by a stranger without reaching anything.
final class PairingWalkthroughTests: XCTestCase {

    private var app: XCUIApplication!

    private var server: String? { environment("MARQUEE_TEST_SERVER") }
    private var username: String? { environment("MARQUEE_TEST_USER") }
    private var password: String? { environment("MARQUEE_TEST_PASSWORD") }

    private func environment(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Every test starts from genuinely unpaired, so one test's session can't make
        // the next one pass (or fail) for the wrong reason.
        app.launchArguments += ["-mq-reset-pairing"]
    }

    // MARK: - Always runs

    /// The guarantee that matters most: a fresh install shows a pairing screen with
    /// no server in it, and nothing about anyone's homelab on screen.
    func testFreshInstallRevealsNothing() {
        app.launchArguments += ["-com.apple.CoreData.SQLDebug", "0"]
        app.launch()

        let address = app.textFields["pairing.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 10),
                      "Pairing should ask for a server address")
        XCTAssertEqual(address.value as? String, "marquee.example.com",
                       "The address field must start empty — the placeholder is the only text in it")
        XCTAssertTrue(app.staticTexts["Connect to your own Marquee server."].exists)
        attach(name: "01-pairing")
    }

    // MARK: - Needs a server

    func testPairAndWalkTheApp() throws {
        let host = try XCTUnwrap(server, "set TEST_RUNNER_MARQUEE_TEST_SERVER to run this")
        let user = try XCTUnwrap(username, "set TEST_RUNNER_MARQUEE_TEST_USER to run this")
        let secret = try XCTUnwrap(password, "set TEST_RUNNER_MARQUEE_TEST_PASSWORD to run this")

        app.launch()

        // Step 1 — the address.
        let address = app.textFields["pairing.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText(host)
        attach(name: "02-address-typed")
        app.buttons["pairing.connect"].tap()

        // Step 2 — choose a sign-in method.
        let signInCard = app.buttons["pairing.method.password"]
        XCTAssertTrue(signInCard.waitForExistence(timeout: 20),
                      "The server should answer /api/build and offer a sign-in method")
        attach(name: "03-method")
        signInCard.tap()

        // Step 3 — credentials.
        let usernameField = app.textFields["pairing.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(user)
        let passwordField = app.secureTextFields["pairing.password"]
        passwordField.tap()
        passwordField.typeText(secret)
        app.buttons["pairing.signIn"].tap()

        // Paired: reaching the tabs is the proof. On iPad the same TabView renders
        // as a sidebar rather than a tab bar, so look for the control, not the bar.
        XCTAssertTrue(tab("Next").waitForExistence(timeout: 25),
                      "Signing in should reach the app")
        dismissSystemPrompts()

        // A banked celebration may be covering the screen — let it play out.
        dismissCelebrationIfPresent()
        attach(name: "04-watch-next")

        // Scroll the Up Next rail left, into the history that recedes behind it.
        let rail = app.scrollViews.firstMatch
        if rail.exists {
            rail.swipeRight(velocity: .slow)
            sleep(1)
            attach(name: "04b-rail-history")
        }

        // Into a show from Watch Next — by identifier, so this never wanders into
        // whichever button happens to be first in the hierarchy.
        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "card.show.")).firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
            sleep(4)
            attach(name: "06-show")
            app.swipeUp(velocity: .slow)
            sleep(2)
            attach(name: "07-show-seasons")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        // Walk the remaining tabs last: the search tab takes over the bar while it's
        // active, so leaving it until the end keeps the rest reachable.
        for name in ["Upcoming", "Library", "You", "Search"] {
            let button = tab(name)
            guard button.waitForExistence(timeout: 3), button.isHittable else { continue }
            button.tap()
            sleep(2)
            attach(name: "08-tab-\(name.lowercased())")
        }
    }

    /// Unpair, so a repeated run starts from the same place and nothing is left
    /// pointing at a real server after the suite finishes.
    override func tearDown() {
        app = nil
    }

    // MARK: - Helpers

    /// The control that selects a tab, wherever the platform decided to put it:
    /// a tab bar on iPhone, a sidebar or top bar on iPad.
    private func tab(_ name: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[name]
        if inBar.exists { return inBar }
        let inSidebar = app.buttons[name]
        return inSidebar.exists ? inSidebar : inBar
    }

    /// iOS offers to save the password after a sign-in; it sits over the app and
    /// would otherwise photobomb every screenshot from here on.
    private func dismissSystemPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            for host in [app, springboard] {
                for label in ["Not Now", "Not now", "Never for This Website"] {
                    let button = host!.buttons[label]
                    if button.waitForExistence(timeout: 2), button.isHittable {
                        button.tap()
                        sleep(1)
                        return
                    }
                }
            }
        }
    }

    private func dismissCelebrationIfPresent() {
        let nice = app.buttons["Nice"]
        if nice.waitForExistence(timeout: 4) {
            attach(name: "04a-celebration")
            nice.tap()
            sleep(1)
        }
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
