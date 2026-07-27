import Foundation
import os

/// Local durability: the last good copy of the screens you look at, and the writes
/// you made while the server was out of reach.
///
/// Two rules shape this. First, an offline launch shows the last cached state rather
/// than a spinner — so every screen's payload is written back here after a successful
/// fetch. Second, marks are idempotent server-side (`INSERT OR IGNORE`) and state
/// changes are last-write-wins, which is what makes blind replay safe.
public final class OfflineStore: @unchecked Sendable {

    public static let shared = OfflineStore()

    /// Where the widget also looks. Falls back to the app's own container when the
    /// App Group isn't available, so a development build still works — the widget
    /// just won't have anything to show.
    public static let appGroup = "group.dev.kadenthompson.marquee"

    private let lock = NSLock()
    private let root: URL
    private let cacheDir: URL
    private let queueURL: URL
    private let logger = Logger(subsystem: "dev.kadenthompson.marquee", category: "offline")

    private init() {
        let shared = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup)
        let fallback = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                    in: .userDomainMask,
                                                    appropriateFor: nil, create: true)
        root = shared ?? fallback ?? URL.temporaryDirectory
        cacheDir = root.appendingPathComponent("Cache", isDirectory: true)
        queueURL = root.appendingPathComponent("pending-writes.json")
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Cached payloads

    private func url(for key: String) -> URL {
        // Keys are route-ish ("show/1396"), so flatten them into one filename.
        let safe = key.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .replacingOccurrences(of: "&", with: "_")
        return cacheDir.appendingPathComponent("\(safe).json")
    }

    public func cache(_ value: some Encodable, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        lock.lock(); defer { lock.unlock() }
        try? data.write(to: url(for: key), options: .atomic)
    }

    public func cached<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    /// When the cached copy was written — used to caption a stale screen honestly
    /// rather than pretending it's live.
    public func cacheDate(for key: String) -> Date? {
        lock.lock(); defer { lock.unlock() }
        return (try? FileManager.default.attributesOfItem(atPath: url(for: key).path))?[.modificationDate] as? Date
    }

    // MARK: - Pending writes

    public func pending() -> [PendingWrite] {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: queueURL) else { return [] }
        return (try? JSONDecoder().decode([PendingWrite].self, from: data)) ?? []
    }

    public func enqueue(_ write: PendingWrite) {
        lock.lock(); defer { lock.unlock() }
        var queue = (try? Data(contentsOf: queueURL))
            .flatMap { try? JSONDecoder().decode([PendingWrite].self, from: $0) } ?? []
        // A later write to the same thing supersedes an earlier one — replaying both
        // would just make the server do the work twice.
        queue.removeAll { $0.supersededBy(write) }
        queue.append(write)
        try? JSONEncoder().encode(queue).write(to: queueURL, options: .atomic)
        logger.info("queued \(write.summary, privacy: .public); \(queue.count) pending")
    }

    public func remove(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: queueURL),
              var queue = try? JSONDecoder().decode([PendingWrite].self, from: data) else { return }
        queue.removeAll { $0.id == id }
        try? JSONEncoder().encode(queue).write(to: queueURL, options: .atomic)
    }

    public func clearQueue() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: queueURL)
    }

    /// Unpairing wipes everything — the cache holds titles, posters and watch dates
    /// from the household, and none of it should outlive the pairing.
    public func clearAll() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.removeItem(at: queueURL)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Widget handoff

    /// The widget can't authenticate on its own, so the app leaves it a small snapshot
    /// in the shared container after every dashboard refresh.
    public func writeWidgetSnapshot(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        lock.lock(); defer { lock.unlock() }
        try? data.write(to: root.appendingPathComponent("widget-snapshot.json"), options: .atomic)
    }

    public func readWidgetSnapshot() -> WidgetSnapshot? {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: root.appendingPathComponent("widget-snapshot.json"))
        else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

// MARK: - The queue's payload

/// A write that hasn't reached the server yet. Deliberately a closed enum: every
/// case has to be safe to replay out of order and more than once.
public struct PendingWrite: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var createdAt: Date
    public var kind: Kind

    public init(_ kind: Kind) {
        id = UUID()
        createdAt = Date()
        self.kind = kind
    }

    public enum Kind: Codable, Sendable, Hashable {
        /// Idempotent: `INSERT OR IGNORE` on the way in, `DELETE` on the way out.
        case markEpisode(showID: Int, season: Int, number: Int, unwatch: Bool, previous: Bool)
        case markSeason(showID: Int, season: Int, unwatch: Bool)
        case rateShow(showID: Int, rating: Int)
        case archiveShow(showID: Int, archived: Bool)
        /// Last-write-wins.
        case movieState(movieID: Int, state: String, rating: Int?)
        case listToggle(listID: Int, itemType: String, itemID: Int, remove: Bool)
        case favorite(itemType: String, itemID: Int, remove: Bool)
        case readingProgress(kind: String, itemID: Int, progress: Int)
        case readingState(kind: String, itemID: Int, state: String)
        case review(itemType: String, itemID: Int, rating: Int?, body: String)
    }

    /// Does `other` make this write pointless?
    func supersededBy(_ other: PendingWrite) -> Bool {
        switch (kind, other.kind) {
        case let (.markEpisode(a, b, c, _, _), .markEpisode(d, e, f, _, _)):
            return a == d && b == e && c == f
        case let (.rateShow(a, _), .rateShow(b, _)):
            return a == b
        case let (.archiveShow(a, _), .archiveShow(b, _)):
            return a == b
        case let (.movieState(a, _, _), .movieState(b, _, _)):
            return a == b
        case let (.listToggle(a, b, c, _), .listToggle(d, e, f, _)):
            return a == d && b == e && c == f
        case let (.favorite(a, b, _), .favorite(c, d, _)):
            return a == c && b == d
        case let (.readingProgress(a, b, _), .readingProgress(c, d, _)):
            return a == c && b == d
        case let (.readingState(a, b, _), .readingState(c, d, _)):
            return a == c && b == d
        case let (.review(a, b, _, _), .review(c, d, _, _)):
            return a == c && b == d
        default:
            return false
        }
    }

    /// Human-readable, for the "N changes waiting" line in Settings.
    public var summary: String {
        switch kind {
        case let .markEpisode(_, season, number, unwatch, _):
            "\(unwatch ? "Unmarked" : "Marked") S\(season) E\(number)"
        case let .markSeason(_, season, unwatch):
            "\(unwatch ? "Unmarked" : "Marked") season \(season)"
        case .rateShow: "Rated a show"
        case .archiveShow: "Changed a show's status"
        case .movieState: "Updated a film"
        case .listToggle: "Edited a list"
        case .favorite: "Changed a favorite"
        case .readingProgress: "Updated reading progress"
        case .readingState: "Moved something on the shelf"
        case .review: "Posted a review"
        }
    }
}

// MARK: - Widget snapshot

/// What the widgets render. Small on purpose — a handful of rows and the poster URLs
/// they need, written by the app, never fetched by the extension.
public struct WidgetSnapshot: Codable, Sendable {
    public var updatedAt: Date
    public var upNext: [WidgetShow]
    public var reading: [WidgetRead]
    /// How many episodes are waiting across every followed show.
    public var episodesWaiting: Int
    public var isPaired: Bool

    public init(updatedAt: Date, upNext: [WidgetShow], reading: [WidgetRead],
                episodesWaiting: Int, isPaired: Bool) {
        self.updatedAt = updatedAt
        self.upNext = upNext
        self.reading = reading
        self.episodesWaiting = episodesWaiting
        self.isPaired = isPaired
    }

    public static let empty = WidgetSnapshot(updatedAt: .distantPast, upNext: [],
                                             reading: [], episodesWaiting: 0, isPaired: false)
}

public struct WidgetShow: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var title: String
    public var poster: String?
    public var episodeCode: String?
    public var episodeTitle: String?
    public var season: Int?
    public var number: Int?
    public var watched: Int
    public var aired: Int

    public init(id: Int, title: String, poster: String?, episodeCode: String?,
                episodeTitle: String?, season: Int?, number: Int?, watched: Int, aired: Int) {
        self.id = id
        self.title = title
        self.poster = poster
        self.episodeCode = episodeCode
        self.episodeTitle = episodeTitle
        self.season = season
        self.number = number
        self.watched = watched
        self.aired = aired
    }

    public var progress: Double { aired > 0 ? Double(watched) / Double(aired) : 0 }
}

public struct WidgetRead: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var kind: String
    public var title: String
    public var cover: String?
    public var progress: Int
    public var total: Int?

    public init(id: Int, kind: String, title: String, cover: String?, progress: Int, total: Int?) {
        self.id = id
        self.kind = kind
        self.title = title
        self.cover = cover
        self.progress = progress
        self.total = total
    }

    public var fraction: Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(progress) / Double(total))
    }
}
