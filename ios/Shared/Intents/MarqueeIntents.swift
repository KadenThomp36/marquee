import AppIntents
import Foundation
import WidgetKit

/// Shortcuts, Siri, the Action button, and the buttons inside widgets.
///
/// These run in whichever process invokes them — the app, or the widget extension —
/// so they read the paired server straight from the shared Keychain rather than
/// assuming an app is running.

// MARK: - Marking

/// "Mark the next episode of X watched."
struct MarkNextEpisodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Next Episode Watched"
    static let description = IntentDescription(
        "Crosses off the next episode of a show you're watching.",
        categoryName: "Watching")
    /// Widgets run this in place — no app launch for a one-tap punch.
    static let openAppWhenRun = false

    @Parameter(title: "Show")
    var show: ShowEntity

    init() {}
    init(show: ShowEntity) { self.show = show }

    static var parameterSummary: some ParameterSummary {
        Summary("Mark the next episode of \(\.$show) watched")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let server = Vault.load() else {
            throw MarqueeIntentError.notPaired
        }
        let client = MarqueeClient(server: server)

        // Ask the server what's next rather than trusting a snapshot that may be
        // hours old — the whole point is that this works from a locked screen.
        let dashboard: Dashboard = try await client.get("dashboard")
        guard let card = (dashboard.upNext + dashboard.stale)
            .first(where: { $0.id == show.id }) else {
            throw MarqueeIntentError.noSuchShow
        }
        guard let episode = card.nextEp else {
            return .result(dialog: "\(card.displayTitle) is all caught up.")
        }
        let response: MarkResponse = try await client.post(
            "show/\(show.id)/watch",
            body: MarkEpisodeRequest(season: episode.season, number: episode.number))

        MarqueeWidgetRefresh.request()
        let remaining = response.show?.remaining ?? max(0, card.remaining - 1)
        return .result(dialog: "Marked \(episode.code) of \(card.displayTitle) watched. \(remaining) to go.")
    }

}

/// "What's up next?"
struct WhatsUpNextIntent: AppIntent {
    static let title: LocalizedStringResource = "What's Up Next"
    static let description = IntentDescription(
        "Reads back the shows waiting for you.", categoryName: "Watching")
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let server = Vault.load() else { throw MarqueeIntentError.notPaired }
        let client = MarqueeClient(server: server)
        let dashboard: Dashboard = try await client.get("dashboard")

        guard let first = dashboard.upNext.first else {
            return .result(dialog: "Nothing in the queue — everything is crossed off.")
        }
        let episode = first.nextEp.map { " — \($0.code)" } ?? ""
        if dashboard.upNext.count == 1 {
            return .result(dialog: "\(first.displayTitle)\(episode).")
        }
        return .result(dialog: "\(first.displayTitle)\(episode), and \(dashboard.upNext.count - 1) more waiting.")
    }
}

/// "Start a reading session."
struct StartReadingSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a Reading Session"
    static let description = IntentDescription(
        "Starts the timer on something you're reading.", categoryName: "Reading")
    static let openAppWhenRun = false

    @Parameter(title: "Book or series")
    var item: ReadingEntity

    init() {}
    init(item: ReadingEntity) { self.item = item }

    static var parameterSummary: some ParameterSummary {
        Summary("Start reading \(\.$item)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let server = Vault.load() else { throw MarqueeIntentError.notPaired }
        let client = MarqueeClient(server: server)
        _ = try await client.post("\(item.kind)/\(item.id)/session/start",
                                  as: SessionStartResponse.self)
        MarqueeWidgetRefresh.request()
        return .result(dialog: "Started reading \(item.name). Enjoy.")
    }
}

/// "End my reading session — I'm on page 214."
///
/// The other half of `StartReadingSessionIntent`: without it a session started from
/// Siri or the Action button could only be ended by opening the app. The position is
/// in the unit you track the title in — pages, chapters, or percent — and converted to
/// the stored unit here, exactly as the app's progress sheet does it.
struct EndReadingSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "End a Reading Session"
    static let description = IntentDescription(
        "Stops the timer on your reading session and logs where you got to.",
        categoryName: "Reading")
    static let openAppWhenRun = false

    @Parameter(title: "Where you got to",
               description: "A page, chapter or percentage — whichever you track this title in.")
    var position: Int

    @Parameter(title: "Book or series",
               description: "Leave empty to end whichever session is running.")
    var item: ReadingEntity?

    init() {}
    init(position: Int, item: ReadingEntity? = nil) {
        self.position = position
        self.item = item
    }

    static var parameterSummary: some ParameterSummary {
        Summary("End reading at \(\.$position)") {
            \.$item
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let server = Vault.load() else { throw MarqueeIntentError.notPaired }
        let client = MarqueeClient(server: server)
        let active: ActiveSessionsResponse = try await client.get("reading/active")
        let running = active.sessions.filter { session in
            guard let item else { return true }
            return session.itemID == item.id && session.kind == item.kind
        }
        // The most recently started, if somehow there are several.
        guard let live = running.max(by: { $0.startedAt < $1.startedAt }) else {
            return .result(dialog: "There's no reading session running.")
        }

        let stored = Self.storedPosition(position, for: live)
        _ = try await client.post("\(live.readingKind.path)/\(live.itemID)/session/end",
                                  body: EndSessionRequest(pos: stored), as: Empty.self)
        MarqueeWidgetRefresh.request()

        let title = live.title ?? "your book"
        var minutes = 0
        if let started = MQTime.date(from: live.startedAt) {
            minutes = max(1, Int(Date().timeIntervalSince(started) / 60))
        }
        let duration = minutes > 0 ? " after \(MQTime.clock(minutes: minutes))" : ""
        return .result(dialog: "Saved \(title)\(duration).")
    }

    /// Spoken units to stored units: percent and chapters become pages for a book;
    /// a manga is stored in chapters already, unless it's tracked in percent.
    static func storedPosition(_ spoken: Int, for live: ActiveSession) -> Int {
        let value = max(0, spoken)
        let mode = ProgressMode(rawValue: live.mode ?? "")
        if live.readingKind == .manga {
            guard mode == .pct, let chapters = live.chapters, chapters > 0 else { return value }
            return min(chapters, Int((Double(min(value, 100)) / 100 * Double(chapters)).rounded()))
        }
        guard let pages = live.pages, pages > 0 else { return value }
        switch mode {
        case .pct:
            return min(pages, Int((Double(min(value, 100)) / 100 * Double(pages)).rounded()))
        case .chapters:
            guard let chapters = live.bookChapters, chapters > 0 else { return min(pages, value) }
            return min(pages, Int((Double(min(value, chapters)) / Double(chapters) * Double(pages)).rounded()))
        default:
            return min(pages, value)
        }
    }
}

// MARK: - Entities

/// A show you're part-way through, offered as a Shortcuts parameter and indexed for
/// Spotlight so "Marquee Brass & Bone" finds it from the Home Screen.
struct ShowEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Show")
    static let defaultQuery = ShowEntityQuery()

    var id: Int
    var name: String
    var subtitle: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)",
                              subtitle: subtitle.map { "\($0)" })
    }
}

struct ShowEntityQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [ShowEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    /// The shows that are actually in progress — the only ones "mark the next episode"
    /// makes sense for.
    func suggestedEntities() async throws -> [ShowEntity] {
        guard let server = Vault.load() else { return [] }
        let client = MarqueeClient(server: server)
        guard let dashboard: Dashboard = try? await client.get("dashboard") else { return [] }
        return (dashboard.upNext + dashboard.stale).map {
            ShowEntity(id: $0.id, name: $0.displayTitle,
                       subtitle: $0.nextEp.map { next in "Next: \(next.code)" })
        }
    }
}

struct ReadingEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Reading")
    static let defaultQuery = ReadingEntityQuery()

    var id: Int
    var kind: String
    var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct ReadingEntityQuery: EntityQuery {
    func entities(for identifiers: [Int]) async throws -> [ReadingEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ReadingEntity] {
        guard let server = Vault.load() else { return [] }
        let client = MarqueeClient(server: server)
        guard let shelves: ReadingShelves = try? await client.get("reading") else { return [] }
        return shelves.books.reading.map { ReadingEntity(id: $0.id, kind: "book", name: $0.displayTitle) }
            + shelves.manga.reading.map { ReadingEntity(id: $0.id, kind: "manga", name: $0.displayTitle) }
    }
}

// MARK: - Shortcuts

struct MarqueeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: WhatsUpNextIntent(),
                    phrases: ["What's up next on \(.applicationName)",
                              "\(.applicationName) up next"],
                    shortTitle: "What's Up Next",
                    systemImageName: "play.rectangle.on.rectangle")
        AppShortcut(intent: MarkNextEpisodeIntent(),
                    phrases: ["Mark the next episode watched in \(.applicationName)",
                              "Punch an episode in \(.applicationName)"],
                    shortTitle: "Mark Next Episode",
                    systemImageName: "checkmark.circle")
        AppShortcut(intent: StartReadingSessionIntent(),
                    phrases: ["Start a reading session in \(.applicationName)",
                              "\(.applicationName) start reading"],
                    shortTitle: "Start Reading",
                    systemImageName: "book")
        AppShortcut(intent: EndReadingSessionIntent(),
                    phrases: ["End my reading session in \(.applicationName)",
                              "\(.applicationName) stop reading"],
                    shortTitle: "End Reading",
                    systemImageName: "book.closed")
    }
}

// MARK: - Support

enum MarqueeIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notPaired
    case noSuchShow

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notPaired: "Marquee isn't paired with a server yet. Open the app to pair it."
        case .noSuchShow: "That show isn't in your queue any more."
        }
    }
}

/// Widgets live in another process, so either side can be the one that changed
/// something — this is the nudge both of them send.
enum MarqueeWidgetRefresh {
    static func request() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
