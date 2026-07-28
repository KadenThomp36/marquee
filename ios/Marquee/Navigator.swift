import Foundation
import Observation

/// Where a tap from outside the current screen should land: a celebration's "see the
/// show", a widget, a notification, a Shortcut, a universal link.
///
/// The tab shell watches this and pushes onto the right stack, so nothing else has to
/// know how navigation is wired.
@MainActor
@Observable
public final class Navigator {

    public static let shared = Navigator()

    public enum Route: Hashable, Sendable {
        case show(Int)
        case episode(showID: Int, season: Int, number: Int)
        case movie(Int)
        case person(Int)
        case list(Int)
        case book(Int)
        case manga(Int)
        case profile(String)
        /// Year in Review. `username` nil means "me".
        case recap(year: Int, username: String?)
        /// Everything watched, as a grid. `username` nil means "me".
        case watched(username: String?, kind: String)
        case history
        case notifications
        case settings
        case search(String)
    }

    /// Which tab a route belongs to.
    public enum Destination: Hashable, Sendable {
        case next, upcoming, library, search, you
    }

    public private(set) var pending: Route?
    public var selected: Destination = .next

    private init() {}

    public func open(_ route: Route) {
        selected = tab(for: route)
        pending = route
    }

    public func consume() -> Route? {
        defer { pending = nil }
        return pending
    }

    private func tab(for route: Route) -> Destination {
        switch route {
        case .show, .episode: .next
        case .movie, .book, .manga: .library
        case .search: .search
        case .person: .search
        case .list, .profile, .history, .notifications, .settings, .recap, .watched: .you
        }
    }

    /// The web client's hash routes, which is what notification links and shared URLs
    /// carry — `show/1396/e/5/14`, `movie/27205`, `book/12`.
    public static func route(fromLink link: String) -> Route? {
        let parts = link
            .trimmingCharacters(in: CharacterSet(charactersIn: "#/ "))
            .split(separator: "/")
            .map(String.init)
        guard let first = parts.first else { return nil }
        switch first {
        case "show" where parts.count >= 5 && parts[2] == "e":
            guard let id = Int(parts[1]), let season = Int(parts[3]), let number = Int(parts[4])
            else { return nil }
            return .episode(showID: id, season: season, number: number)
        case "show":
            return Int(parts.count > 1 ? parts[1] : "").map(Route.show)
        case "movie":
            return Int(parts.count > 1 ? parts[1] : "").map(Route.movie)
        case "person":
            return Int(parts.count > 1 ? parts[1] : "").map(Route.person)
        case "list":
            return Int(parts.count > 1 ? parts[1] : "").map(Route.list)
        case "book":
            return Int(parts.count > 1 ? parts[1] : "").map(Route.book)
        case "manga":
            return Int(parts.count > 1 ? parts[1] : "").map(Route.manga)
        case "u":
            return parts.count > 1 ? .profile(parts[1]) : nil
        case "history":
            return .history
        case "inbox":
            return .notifications
        case "settings":
            return .settings
        case "recap":
            return parts.count > 1 ? Int(parts[1]).map { .recap(year: $0, username: nil) } ?? nil : nil
        default:
            return nil
        }
    }
}
