import BackgroundTasks
import SwiftUI

@main
struct MarqueeApp: App {
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
