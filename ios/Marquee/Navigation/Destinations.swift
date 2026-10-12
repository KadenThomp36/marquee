import SwiftUI

/// One place that knows what every route looks like, applied to every stack — so a
/// show pushed from Watch Next, from Search, from a list, or from a notification is
/// the same screen with the same back behaviour.
extension View {
    func marqueeDestinations() -> some View {
        navigationDestination(for: Navigator.Route.self) { route in
            switch route {
            case .show(let id):
                ShowScreen(showID: id)
            case .episode(let showID, let season, let number):
                EpisodeScreen(showID: showID, season: season, number: number)
            case .movie(let id):
                MovieScreen(movieID: id)
            case .person(let id):
                PersonScreen(personID: id)
            case .list(let id):
                ListScreen(listID: id)
            case .book(let id):
                ReadingDetailScreen(kind: .book, itemID: id)
            case .bookPreview(let hardcoverID):
                ReadingDetailScreen(kind: .book, itemID: hardcoverID, isHardcoverPreview: true)
            case .manga(let id):
                ReadingDetailScreen(kind: .manga, itemID: id)
            case .profile(let username):
                ProfileScreen(username: username)
            case .recap(let year, let username):
                RecapScreen(year: year, username: username)
            case .watched(let username, let kind):
                WatchedGridScreen(username: username, kind: kind)
            case .history:
                HistoryScreen()
            case .notifications:
                NotificationsScreen()
            case .settings:
                SettingsScreen()
            case .search(let query):
                SearchScreen(initialQuery: query)
            }
        }
    }
}

/// Lets a tab's stack respond to routes opened from outside it — a celebration, a
/// widget, a notification, a Shortcut.
struct RouteReceiver: ViewModifier {
    @Binding var path: NavigationPath
    @State private var navigator = Navigator.shared

    func body(content: Content) -> some View {
        content.onChange(of: navigator.pending) { _, pending in
            guard pending != nil, let route = navigator.consume() else { return }
            path.append(route)
        }
    }
}

extension View {
    func routed(into path: Binding<NavigationPath>) -> some View {
        modifier(RouteReceiver(path: path))
    }
}
