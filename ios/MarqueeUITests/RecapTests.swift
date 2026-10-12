import XCTest

/// Walks the Year in Review slideshow end to end, screenshotting every slide. The
/// card on the profile used to link straight back to the profile, so the point of
/// this test is that tapping it goes somewhere and that each slide draws.
final class RecapTests: XCTestCase {

    private var app: XCUIApplication!

    private func environment(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-mq-reset-pairing"]
    }

    func testWrappedOpensAndPlaysThrough() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"))
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        app.launch()
        pair(host: host, user: user, secret: secret)

        app.tabBars.buttons["You"].tap()
        sleep(3)

        let card = app.buttons["card.recap"]
        XCTAssertTrue(card.waitForExistence(timeout: 8),
                      "The profile should offer a Year in Review card")
        card.tap()
        sleep(3)

        // The slideshow replaces the profile: the settings gear is gone.
        XCTAssertFalse(app.buttons["Settings"].exists,
                       "Tapping wrapped should leave the profile, not reload it")

        for slide in 1...8 {
            attach(name: String(format: "20-recap-%02d", slide))
            // Right half advances.
            let frame = app.frame
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.55))
                .withOffset(CGVector(dx: 0, dy: 0)).tap()
            _ = frame
            sleep(1)
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

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for target in [app, springboard] {
            for title in ["Not Now", "Not now"] {
                let button = target!.buttons[title]
                if button.waitForExistence(timeout: 2), button.isHittable {
                    button.tap(); sleep(1); break
                }
            }
        }
        let nice = app.buttons["Nice"]
        if nice.waitForExistence(timeout: 4), nice.exists, nice.isHittable { nice.tap(); sleep(1) }   // re-checked: the celebration can auto-dismiss between existence and tap
    }

    private func attach(name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
