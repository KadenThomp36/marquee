import XCTest

/// Photographs the You page through a full pull-to-refresh, because the banner's
/// behaviour under the spinner can't be asserted on — it has to be looked at.
/// Launched with `-mq-slow-refresh` so the spinner stays up for three seconds.
final class RefreshStretchDiagnosticTests: XCTestCase {

    private var app: XCUIApplication!

    private func environment(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-mq-reset-pairing", "-mq-slow-refresh"]
    }

    func testBannerDuringRefreshSpinner() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"))
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        app.launch()
        pair(host: host, user: user, secret: secret)

        app.tabBars.buttons["You"].tap()
        sleep(4)                      // profile + banner art
        attach(app.screenshot().image, name: "40-refresh-00-rest")

        // Photograph continuously while the main thread performs the pull.
        // app.screenshot() waits for idle; XCUIScreen from another thread doesn't.
        var frames: [UIImage] = []
        let lock = NSLock()
        let capturing = expectation(description: "captured")
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<24 {
                let shot = XCUIScreen.main.screenshot().image
                lock.lock(); frames.append(shot); lock.unlock()
                Thread.sleep(forTimeInterval: 0.25)
            }
            capturing.fulfill()
        }

        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
        start.press(forDuration: 0.05, thenDragTo: end,
                    withVelocity: .slow, thenHoldForDuration: 0.1)

        wait(for: [capturing], timeout: 20)
        lock.lock()
        for (index, frame) in frames.enumerated() {
            attach(frame, name: String(format: "40-refresh-%02d", index + 1))
        }
        lock.unlock()
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
        if nice.waitForExistence(timeout: 4), nice.exists, nice.isHittable { nice.tap(); sleep(1) }   // re-checked: the celebration can auto-dismiss between existence and tap
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

    private func attach(_ image: UIImage, name: String) {
        let shot = XCTAttachment(image: image)
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
