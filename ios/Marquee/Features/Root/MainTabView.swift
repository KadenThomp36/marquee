import SwiftUI

/// The app's five destinations.
///
/// The web client has six top-level routes plus a gear; a native app shouldn't. Films
/// and Reading collapse into one **Library**, Search takes the system's search tab
/// role, and History, Lists and Settings move under **You** — which is where you'd
/// look for them anyway.
struct MainTabView: View {
    @Environment(Session.self) private var session
    @State private var navigator = Navigator.shared

    var body: some View {
        @Bindable var navigator = navigator

        TabView(selection: $navigator.selected) {
            Tab("Next", systemImage: "play.rectangle.on.rectangle",
                value: Navigator.Destination.next) {
                NextTab()
            }

            Tab("Upcoming", systemImage: "calendar",
                value: Navigator.Destination.upcoming) {
                UpcomingTab()
            }

            Tab("Library", systemImage: "square.stack.fill",
                value: Navigator.Destination.library) {
                LibraryTab()
            }

            Tab("You", systemImage: "person.crop.circle",
                value: Navigator.Destination.you) {
                YouTab()
            }

            Tab(value: Navigator.Destination.search, role: .search) {
                SearchTab()
            }
        }
        // Poster art owns the screen while you're scrolling; the bar comes back the
        // moment you reach for it.
        .tabBarMinimizeBehavior(.onScrollDown)
        .tint(.mqBrass)
        .task(id: session.me?.features?.tracksReading) {
            // The Library tab's Reading section appears and disappears with the
            // per-user feature flag, so keep /api/me fresh.
            await session.refreshMe()
        }
    }
}
