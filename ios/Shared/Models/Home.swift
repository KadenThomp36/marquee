import Foundation

/// `GET /api/dashboard` — one call backs the whole Watch Next screen.
public struct Dashboard: Codable, Sendable, Equatable {
    /// Shows with an episode ready to punch.
    public var upNext: [ShowCard]
    /// Behind, and nothing watched in the last 30 days.
    public var stale: [ShowCard]
    /// Episodes airing soon, for the calendar rail.
    public var calendar: [UpcomingEpisode]
    /// Your recent watches, newest first, same-show-same-day already collapsed.
    public var recent: [WatchEntry]
    /// What everyone else in the house watched recently.
    public var social: [WatchEntry]
    public var reviews: [ReviewTeaser]
    public var counts: DashboardCounts?

    enum CodingKeys: String, CodingKey {
        case stale, calendar, recent, social, reviews, counts
        case upNext = "up_next"
    }
}

public struct DashboardCounts: Codable, Sendable, Equatable {
    public var upToDate: Int?
    public var notStarted: Int?

    enum CodingKeys: String, CodingKey {
        case upToDate = "up_to_date"
        case notStarted = "not_started"
    }
}

/// One collapsed watch: "The Bear, S2 E4, +3 more, this afternoon".
public struct WatchEntry: Codable, Sendable, Hashable, Identifiable {
    public var showID: Int
    public var title: String?
    public var poster: String?
    public var season: Int?
    public var number: Int?
    public var epTitle: String?
    public var watchedAt: String
    /// How many episodes of this show on this day were folded into this entry.
    public var count: Int
    /// Present only in the household feed — who watched it.
    public var by: Person?

    public var id: String { "\(showID):\(watchedAt):\(season ?? -1):\(number ?? -1)" }
    public var displayTitle: String { title ?? "Untitled" }
    public var code: String? {
        guard let season, let number else { return nil }
        return "S\(season) · E\(number)"
    }

    enum CodingKeys: String, CodingKey {
        case title, poster, season, number, count, by
        case showID = "show_id"
        case epTitle = "ep_title"
        case watchedAt = "watched_at"
    }
}

public struct ReviewTeaser: Codable, Sendable, Hashable, Identifiable {
    public var type: String
    public var id: Int
    public var title: String?
    public var poster: String?
    public var rating: Int?
    public var body: String?
    public var updatedAt: String?
    public var by: Person

    enum CodingKeys: String, CodingKey {
        case type, id, title, poster, rating, body, by
        case updatedAt = "updated_at"
    }
}

/// `GET /api/upcoming`
public struct UpcomingResponse: Codable, Sendable, Equatable {
    public var episodes: [UpcomingEpisode]
    public var movies: [UpcomingMovie]
}

public struct UpcomingEpisode: Codable, Sendable, Hashable, Identifiable {
    public var showID: Int
    public var showTitle: String?
    public var poster: String?
    public var season: Int
    public var number: Int
    public var title: String?
    public var airDate: String

    public var id: String { "\(showID):\(season):\(number)" }
    public var code: String { "S\(season) · E\(number)" }

    enum CodingKeys: String, CodingKey {
        case season, number, title, poster
        case showID = "show_id"
        case showTitle = "show_title"
        case airDate = "air_date"
    }
}

public struct UpcomingMovie: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var releaseDate: String

    enum CodingKeys: String, CodingKey {
        case id, title, poster
        case releaseDate = "release_date"
    }
}

// MARK: - History

/// `GET /api/history?type=tv` — a page of the timeline. Same-show-same-day runs
/// arrive already grouped; the cursor is a timestamp, not an offset, so an enormous
/// single day paginates inside itself.
public struct TVHistoryPage: Codable, Sendable, Equatable {
    public var items: [TVHistoryGroup]
    public var cursor: String?
}

public struct TVHistoryGroup: Codable, Sendable, Identifiable, Hashable {
    public var day: String
    public var showID: Int
    public var title: String?
    public var poster: String?
    /// `[[season, number, title?], …]`
    public var eps: [[HistoryEpisodeField]]
    public var minutes: Int
    public var lastAt: String?

    public var id: String { "\(day):\(showID)" }
    public var episodes: [(season: Int, number: Int, title: String?)] {
        eps.compactMap { row in
            guard row.count >= 2, let season = row[0].int, let number = row[1].int else { return nil }
            return (season, number, row.count > 2 ? row[2].string : nil)
        }
    }

    enum CodingKeys: String, CodingKey {
        case day, title, poster, eps, minutes
        case showID = "show_id"
        case lastAt = "last_at"
    }
}

/// An element of the `[season, number, title]` triple, which mixes ints and a
/// nullable string in one JSON array.
public enum HistoryEpisodeField: Codable, Sendable, Hashable {
    case int(Int)
    case string(String)
    case none

    public var int: Int? { if case .int(let value) = self { value } else { nil } }
    public var string: String? { if case .string(let value) = self { value } else { nil } }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .none }
        else if let value = try? container.decode(Int.self) { self = .int(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else { self = .none }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .none: try container.encodeNil()
        }
    }
}

public struct MovieHistoryPage: Codable, Sendable, Equatable {
    public var items: [MovieHistoryItem]
    public var cursor: String?
}

public struct MovieHistoryItem: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var rating: Int?
    public var watchedAt: String
    public var runtime: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, poster, year, rating, runtime
        case watchedAt = "watched_at"
    }
}
