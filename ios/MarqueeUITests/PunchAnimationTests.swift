import XCTest

/// Punches an episode and photographs the stub on its way out.
///
/// An animation can't be asserted on, so this is a contact sheet: rapid screenshots
/// across the ~700ms flight, to be looked at. If the stub never appears, or appears
/// and doesn't move, that shows up immediately.
final class PunchAnimationTests: XCTestCase {

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
        // Ten times slower, so a 700ms flight can actually be photographed. This is
        // UIKit's own debug knob, not anything the app knows about.
        app.launchArguments += ["-UIAnimationDragCoefficient", "10"]
    }

    func testPunchTearsOffAStub() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"))
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        app.launch()
        pair(host: host, user: user, secret: secret)

        // The punch button lives on the first queue card.
        let punch = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Mark ")).firstMatch
        XCTAssertTrue(punch.waitForExistence(timeout: 10),
                      "The first Up Next card should offer a punch button")

        attach(name: "30-punch-00-before")

        // `app.screenshot()` waits for the app to go idle, and an animation is not
        // idle — so every frame taken after `tap()` returns is of the aftermath.
        // `XCUIScreen` does no such synchronisation, so grab from another thread
        // while the main one taps.
        var frames: [XCUIScreenshot] = []
        let lock = NSLock()
        let capturing = expectation(description: "flight captured")

        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<16 {
                let shot = XCUIScreen.main.screenshot()
                lock.lock(); frames.append(shot); lock.unlock()
                Thread.sleep(forTimeInterval: 0.16)
            }
            capturing.fulfill()
        }

        punch.tap()
        wait(for: [capturing], timeout: 30)

        lock.lock()
        let captured = frames
        lock.unlock()
        for (index, shot) in captured.enumerated() {
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = String(format: "30-punch-%02d", index + 1)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertGreaterThan(captured.count, 5, "Should have caught the flight")

        sleep(2)
        attach(name: "30-punch-99-after")
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
