import XCTest

/// Photographs a chart readout mid-scrub, in both appearances. The readout only
/// exists while a finger is on the plot, so `app.screenshot()` — which waits for
/// idle — can never catch it; frames are grabbed from another thread instead.
final class ChartScrubDiagnosticTests: XCTestCase {

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

    override func tearDown() {
        XCUIDevice.shared.appearance = .dark
        app = nil
    }

    func testReadoutInDarkMode() throws {
        try scrubAndShoot(appearance: .dark, prefix: "44-scrub-dark")
    }

    func testReadoutInLightMode() throws {
        try scrubAndShoot(appearance: .light, prefix: "45-scrub-light")
    }

    // MARK: - The scrub

    private func scrubAndShoot(appearance: XCUIDevice.Appearance, prefix: String) throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"))
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        XCUIDevice.shared.appearance = appearance
        app.launch()
        pair(host: host, user: user, secret: secret)

        app.tabBars.buttons["You"].tap()
        sleep(3)

        // The whole chart must sit between the heading zone and the tab bar before
        // a drag on it means anything — a swipe's momentum overshoots wildly, so
        // rough placement first, then small held drags to fine-position.
        let chart = app.otherElements["chart.months"].firstMatch
        var hops = 0
        while !chart.exists, hops < 8 {
            app.swipeUp(velocity: .fast)
            sleep(1)
            hops += 1
        }
        XCTAssertTrue(chart.exists, "months chart should be reachable by scrolling")

        let safeBottom = app.frame.maxY - 170
        let safeTop: CGFloat = 140
        var nudges = 0
        while nudges < 12 {
            let frame = chart.frame
            if frame.maxY <= safeBottom, frame.minY >= safeTop { break }
            let dy: CGFloat = frame.maxY > safeBottom ? -0.18 : 0.18
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55 + dy))
            start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow,
                        thenHoldForDuration: 0.3)
            sleep(1)
            nudges += 1
        }
        XCTAssertLessThan(chart.frame.maxY, safeBottom, "chart should sit above the tab bar")
        sleep(1)

        // A tap selects that x-value and the selection persists after the finger
        // lifts, so the readout can be photographed at idle — no racing frames.
        chart.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.5)).tap()
        sleep(2)
        attach(app.screenshot().image, name: "\(prefix)-selected")
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
        if nice.waitForExistence(timeout: 4), nice.exists, nice.isHittable { nice.tap(); sleep(1) }
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
