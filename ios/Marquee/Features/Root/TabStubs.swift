import SwiftUI

// The four tabs that aren't Watch Next yet. Each is replaced by its real screen.

struct UpcomingTab: View {
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            UpcomingScreen().marqueeDestinations()
        }
        .routed(into: $path)
    }
}


struct SearchTab: View {
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            SearchScreen().marqueeDestinations()
        }
        .routed(into: $path)
    }
}


/// Placeholder body for a destination that hasn't been built yet.
struct ComingSoon: View {
    let title: String
    let detail: String

    var body: some View {
        MarqueeScreen {
            ContentUnavailableView {
                Label(title, systemImage: "popcorn")
            } description: {
                Text(detail)
            }
        }
        .navigationTitle(title)
    }
}
