import XCTest

/// Does the Up Next rail come to rest on something, or wherever it happens to stop?
///
/// A detent is a feel, not a picture, so this asserts what produces the feel: after a
/// drag the rail should settle with a card edge on the leading edge rather than a card
/// sliced arbitrarily. Cards are a known width, so "settled" is measurable — the gap
/// between the screen edge and the first full card is either ~0 or it isn't.
final class RailDetentTests: XCTestCase {

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

    func testRailSettlesOnACardEdge() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"))
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        app.launch()
        pair(host: host, user: user, secret: secret)

        let rail = app.scrollViews["rail.upnext"]
        XCTAssertTrue(rail.waitForExistence(timeout: 10))
        sleep(2)

        // Three different drags: whatever the rail does, it should never come to rest
        // part-way across a card.
        for (index, distance) in [0.55, 0.35, 0.7].enumerated() {
            let from = rail.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            let to = rail.coordinate(withNormalizedOffset: CGVector(dx: 0.2 + distance, dy: 0.5))
            from.press(forDuration: 0.08, thenDragTo: to, withVelocity: 320,
                       thenHoldForDuration: 0.05)
            sleep(2)
            attach(name: String(format: "42-rail-settled-%d", index + 1))

            let leading = rail.frame.minX
            // Poster cards in this rail; the leftmost fully-visible one's edge.
            let edges = rail.buttons.allElementsBoundByIndex
                .map { $0.frame.minX }
                .filter { $0 > leading - 4 }
                .sorted()
            guard let first = edges.first else { continue }

            // Either flush against the gutter, or a whole card further along. What it
            // must not be is somewhere arbitrary in between.
            let gap = first - leading
            print("RAILDETENT drag=\(distance) gap=\(gap)")
            XCTAssertLessThan(gap, 30,
                              "Drag \(index + 1) left the leading card \(Int(gap))pt in, "
                              + "so the rail is resting mid-card rather than on an edge")
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
