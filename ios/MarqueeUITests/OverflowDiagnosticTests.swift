import XCTest

/// A diagnostic, not a guarantee: walks into a show page and reports every element
/// whose frame pokes outside the screen. Horizontal overflow on a vertical page is
/// invisible in a screenshot — the content is simply clipped — so this is how the
/// offender gets named.
final class OverflowDiagnosticTests: XCTestCase {

    private var app: XCUIApplication!

    private func environment(_ key: String) -> String? {
        let value = ProcessInfo.processInfo.environment[key]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-mq-reset-pairing"]
    }

    func testNothingOverflowsTheShowPage() throws {
        let host = try XCTUnwrap(environment("MARQUEE_TEST_SERVER"))
        let user = try XCTUnwrap(environment("MARQUEE_TEST_USER"))
        let secret = try XCTUnwrap(environment("MARQUEE_TEST_PASSWORD"))

        app.launch()
        pair(host: host, user: user, secret: secret)

        let card = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "card.show.")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        sleep(4)

        report(label: "SHOW")
    }

    /// Walk the whole tree and print anything crossing the screen's edges.
    private func report(label: String) {
        let screen = app.frame
        var offenders: [String] = []

        func walk(_ element: XCUIElement, depth: Int) {
            guard depth < 12 else { return }
            let children = element.children(matching: .any).allElementsBoundByIndex
            for child in children {
                guard child.exists else { continue }
                let box = child.frame
                if box.width > 0, box.minX < -0.5 || box.maxX > screen.maxX + 0.5 {
                    offenders.append(String(
                        format: "%@%@ '%@' x=%.1f…%.1f (screen 0…%.1f)",
                        String(repeating: "  ", count: depth),
                        String(describing: child.elementType),
                        child.identifier.isEmpty ? child.label.prefix(40).description
                                                 : child.identifier,
                        box.minX, box.maxX, screen.maxX))
                }
                walk(child, depth: depth + 1)
            }
        }
        walk(app, depth: 0)

        let attachment = XCTAttachment(string: offenders.joined(separator: "\n"))
        attachment.name = "overflow-\(label.lowercased())"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertTrue(offenders.isEmpty,
                      "\(label): \(offenders.count) element(s) cross the screen edge:\n"
                      + offenders.prefix(25).joined(separator: "\n"))
    }

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
        for host in [app, springboard] {
            for title in ["Not Now", "Not now"] {
                let button = host!.buttons[title]
                if button.waitForExistence(timeout: 2), button.isHittable {
                    button.tap(); sleep(1); break
                }
            }
        }
        let nice = app.buttons["Nice"]
        if nice.waitForExistence(timeout: 4), nice.exists, nice.isHittable { nice.tap(); sleep(1) }   // re-checked: the celebration can auto-dismiss between existence and tap
    }
}
