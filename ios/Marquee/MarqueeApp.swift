import BackgroundTasks
import SwiftUI
import UIKit

@main
struct MarqueeApp: App {
    @UIApplicationDelegateAdaptor(OrientationDelegate.self) private var orientation
    @State private var session = Session()
    @Environment(\.scenePhase) private var scenePhase

    /// The one background task this app registers: a periodic check for anything that
    /// happened while it was closed — a season Plex finished for you overnight, a
    /// request that landed, a reply to a review.
    private let refreshTaskID = "dev.kadenthompson.marquee.refresh"

    init() {
        BackgroundRefresh.register(id: refreshTaskID)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .refreshesOrientationsWithSizeClass()
                .tint(.mqBrass)
                // Without a delegate installed, a notification raised while the app is
                // open never appears and tapping one does nothing.
                .task {
                    Notifications.shared.start()
                    // Also queue one on launch, not only on the way out — an app that
                    // is opened and never backgrounded would otherwise never ask.
                    BackgroundRefresh.schedule(id: refreshTaskID)
                }
                .onOpenURL { url in
                    // marquee://show/1396, marquee://next, marquee://library …
                    if let route = Navigator.route(fromLink: url.pathComponents
                        .joined(separator: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        .isEmpty ? (url.host ?? "") : "\(url.host ?? "")\(url.path)") {
                        Navigator.shared.open(route)
                    } else {
                        switch url.host {
                        case "next": Navigator.shared.selected = .next
                        case "library": Navigator.shared.selected = .library
                        case "search": Navigator.shared.selected = .search
                        case "you": Navigator.shared.selected = .you
                        default: break
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                BackgroundRefresh.schedule(id: refreshTaskID)
            }
        }
    }
}

/// Portrait on a phone, as it always was — except on a phone-sized device with a
/// tablet-sized screen, which is to say the Duo's inner display. There the app turns
/// like an iPad app, and turning it is how the screening room goes from a book
/// standing open to a laptop on the nightstand.
final class OrientationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return .all }
        let traits = window?.traitCollection
        if traits?.horizontalSizeClass == .regular, traits?.verticalSizeClass == .regular {
            return .allButUpsideDown
        }
        return .portrait
    }
}

/// The answer above changes when the window moves between the Duo's displays, so ask
/// the system to ask again — otherwise the cover display could inherit the inner
/// display's freedom to turn for as long as the old answer stands.
private struct OrientationRefresh: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontal
    @Environment(\.verticalSizeClass) private var vertical

    func body(content: Content) -> some View {
        content.onChange(of: [horizontal, vertical]) {
            for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
                for window in scene.windows {
                    window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
            }
        }
    }
}

private extension View {
    func refreshesOrientationsWithSizeClass() -> some View { modifier(OrientationRefresh()) }
}
