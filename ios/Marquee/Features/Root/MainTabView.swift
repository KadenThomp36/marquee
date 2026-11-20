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
    @State private var hinge = Hinge.shared
    @AppStorage(DuoSettings.screeningRoomKey) private var screeningRoomEnabled = true
    /// Left by hand; stays left until the phone stops being half-open.
    @State private var leftScreeningRoom = false

    private var showsScreeningRoom: Bool {
        screeningRoomEnabled && hinge.posture == .halfOpen && !leftScreeningRoom
    }

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
        // Underneath the room, the app is out of reach for VoiceOver as well as touch.
        .accessibilityHidden(showsScreeningRoom)
        // The Duo, propped half-open: the whole window becomes the screening room.
        .overlay {
            if showsScreeningRoom {
                ScreeningRoom { leftScreeningRoom = true }
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showsScreeningRoom)
        .onChange(of: hinge.posture) { _, posture in
            if posture != .halfOpen { leftScreeningRoom = false }
        }
        .task(id: session.me?.features?.tracksReading) {
            // The Library tab's Reading section appears and disappears with the
            // per-user feature flag, so keep /api/me fresh.
            await session.refreshMe()
        }
    }
}
