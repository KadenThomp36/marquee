import XCTest

/// Screens the app has to survive: the light appearance, accessibility text sizes,
/// and Reduce Motion. These take screenshots rather than asserting pixel values —
/// the point is that a person can look at the result and see nothing is clipped.
final class AppearanceTests: XCTestCase {

    private var app: XCUIApplication!

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

    override func tearDown() {
        XCUIDevice.shared.appearance = .dark
        app = nil
    }

    /// The pairing screen is the one screen a stranger sees, so it's the one that has
    /// to hold up in both appearances at any text size.
    func testPairingInLightAndLargeText() {
        XCUIDevice.shared.appearance = .light
        app.launchArguments += ["-UIPreferredContentSizeCategoryName",
                                "UICTContentSizeCategoryAccessibilityL"]
        app.launch()

        let address = app.textFields["pairing.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        attach(name: "10-pairing-light-axl")

        XCTAssertTrue(app.buttons["pairing.connect"].isHittable,
                      "Connect must still be reachable at accessibility text sizes")
    }

    func testPairingWithReduceMotion() {
        app.launchArguments += ["-UIAccessibilityReduceMotionEnabled", "1"]
        app.launch()
        XCTAssertTrue(app.textFields["pairing.address"].waitForExistence(timeout: 10))
        attach(name: "11-pairing-reduce-motion")
    }

    /// The whole app in light mode, once there's a server to talk to.
    func testAppInLightMode() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"),
                                 "set TEST_RUNNER_MARQUEE_TEST_SERVER to run this")
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        XCUIDevice.shared.appearance = .light
        app.launch()
        pair(host: host, user: user, secret: secret)

        attach(name: "12-light-watch-next")
        // Scrolled: the heading should have faded out and the top should have grown a
        // soft blur where content passes under it.
        app.swipeUp(velocity: .slow)
        sleep(1)
        attach(name: "12b-light-scrolled")
        // Back to the top, or the minimised tab bar has no buttons to tap.
        app.swipeDown(velocity: .fast)
        sleep(1)
        for tab in ["Library", "You"] {
            let button = app.tabBars.buttons[tab]
            guard button.waitForExistence(timeout: 3) else { continue }
            button.tap()
            sleep(2)
            attach(name: "13-light-\(tab.lowercased())")
            if tab == "You" {
                app.swipeUp(velocity: .slow)
                sleep(1)
                attach(name: "13b-you-mid")
                app.swipeUp(velocity: .slow)
                sleep(1)
                attach(name: "13c-you-stats")
            }
        }
    }

    /// Everything at an accessibility text size, where a fixed-height row or a
    /// non-wrapping chip row shows up immediately.
    func testAppAtAccessibilityTextSize() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"),
                                 "set TEST_RUNNER_MARQUEE_TEST_SERVER to run this")
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        app.launchArguments += ["-UIPreferredContentSizeCategoryName",
                                "UICTContentSizeCategoryAccessibilityXL"]
        app.launch()
        pair(host: host, user: user, secret: secret)

        attach(name: "14-axxl-watch-next")

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "card.show.")).firstMatch
        if card.waitForExistence(timeout: 5) {
            card.tap()
            sleep(4)
            attach(name: "15-axxl-show")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        for tab in ["Library", "You"] {
            let button = app.tabBars.buttons[tab]
            guard button.waitForExistence(timeout: 3) else { continue }
            button.tap()
            sleep(2)
            attach(name: "16-axxl-\(tab.lowercased())")
        }
    }

    // MARK: - Helpers

    private func pair(host: String, user: String, secret: String) {
        let address = app.textFields["pairing.address"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText(host)
        app.buttons["pairing.connect"].tap()

        let signIn = app.buttons["pairing.method.password"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 20))
        signIn.tap()

        let usernameField = app.textFields["pairing.username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        usernameField.typeText(user)
        let passwordField = app.secureTextFields["pairing.password"]
        passwordField.tap()
        passwordField.typeText(secret)
        app.buttons["pairing.signIn"].tap()

        XCTAssertTrue(app.tabBars.buttons["Next"].waitForExistence(timeout: 25))
        dismissSystemPrompts()
        let nice = app.buttons["Nice"]
        if nice.waitForExistence(timeout: 4) { nice.tap(); sleep(1) }
    }

    private func dismissSystemPrompts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for host in [app, springboard] {
            for label in ["Not Now", "Not now"] {
                let button = host!.buttons[label]
                if button.waitForExistence(timeout: 2), button.isHittable {
                    button.tap()
                    sleep(1)
                    return
                }
            }
        }
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
