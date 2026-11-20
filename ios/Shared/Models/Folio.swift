import Foundation

// Folio is the household's own e-reader app (a Boox Palma). It uploads reading
// sessions to the server, which is what these shapes describe: the per-account
// integration in Settings, a recently synced session, and one book's reading in depth.
// Every field a newer server adds is optional, so an older one still decodes.

/// `GET/POST /api/integrations/folio`
public struct FolioIntegration: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var autoCapture: Bool
    public var devices: [FolioDevice]
    /// Sittings that arrived for a file Marquee can't place yet (contract v1.1).
    public var waiting: [FolioWaiting]?
    /// Set on the answer to a manual match.
    public var imported: Int?
    public var title: String?

    enum CodingKeys: String, CodingKey {
        case enabled, devices, waiting, imported, title
        case autoCapture = "auto_capture"
    }
}

/// One reader file whose sittings are parked until its book is known.
public struct FolioWaiting: Codable, Sendable, Equatable, Identifiable {
    public var key: String
    public var title: String
    public var authors: [String]
    public var isbn: String?
    public var sittings: Int
    public var minutes: Int
    public var firstAt: String?
    public var nextAttemptAt: String?
    /// "no match", "unavailable" (Hardcover couldn't answer), or nil: not asked yet.
    public var reason: String?

    public var id: String { key }
    public var byline: String {
        authors.isEmpty ? (isbn.map { "ISBN \($0)" } ?? "No author in the file") : authors.joined(separator: ", ")
    }

    enum CodingKeys: String, CodingKey {
        case key, title, authors, isbn, sittings, minutes, reason
        case firstAt = "first_at"
        case nextAttemptAt = "next_attempt_at"
    }
}

/// `POST /api/integrations/folio/waiting/{match,ignore,retry}`. A match names a book
/// already on the shelf (`bookID`) or a Hardcover result (`hcID` plus its fields, the
/// same as `/api/books/add` takes, as a fallback if Hardcover can't be reached).
public struct FolioWaitingRequest: Codable, Sendable, Equatable {
    public var key: String
    public var bookID: Int?
    public var hcID: Int?
    public var title: String?
    public var author: String?
    public var pages: Int?
    public var cover: String?
    public var slug: String?

    public init(key: String, bookID: Int? = nil, result: BookSearchResult? = nil) {
        self.key = key
        self.bookID = bookID
        self.hcID = result?.hcID
        self.title = result?.title
        self.author = result?.author
        self.pages = result?.pages
        self.cover = result?.cover
        self.slug = result?.slug
    }

    enum CodingKeys: String, CodingKey {
        case key, title, author, pages, cover, slug
        case bookID = "book_id"
        case hcID = "hc_id"
    }
}

public struct FolioDevice: Codable, Sendable, Equatable, Identifiable {
    public var id: Int
    public var name: String?
    public var platform: String?
    public var appVersion: String?
    public var pairedAt: String?
    public var lastSyncAt: String?
    public var sessionsSynced: Int
    /// False once the device was signed out from the general Devices list: it's still
    /// listed so it can be unpaired properly or paired again.
    public var signedIn: Bool?

    public var displayName: String { (name?.isEmpty == false ? name : nil) ?? "Folio" }

    enum CodingKeys: String, CodingKey {
        case id, name, platform
        case appVersion = "app_version"
        case pairedAt = "paired_at"
        case lastSyncAt = "last_sync_at"
        case sessionsSynced = "sessions_synced"
        case signedIn = "signed_in"
    }
}

/// `POST /api/integrations/folio` — either key optional.
public struct FolioIntegrationUpdate: Codable, Sendable, Equatable {
    public var enabled: Bool?
    public var autoCapture: Bool?

    public init(enabled: Bool? = nil, autoCapture: Bool? = nil) {
        self.enabled = enabled
        self.autoCapture = autoCapture
    }

    enum CodingKeys: String, CodingKey {
        case enabled
        case autoCapture = "auto_capture"
    }
}

/// The newest Folio session inside the last day and a half — "read on Boox Palma
/// 40 min ago". On `/api/reading/active`, `/api/book/{id}` and the stats page.
public struct RecentFolio: Codable, Sendable, Equatable, Hashable {
    public var bookID: Int
    public var title: String?
    public var cover: String?
    public var device: String
    public var endedAt: String
    public var minutes: Int
    public var pages: Int?
    public var endFraction: Double?
    public var chapter: String?

    enum CodingKeys: String, CodingKey {
        case title, cover, device, minutes, pages, chapter
        case bookID = "book_id"
        case endedAt = "ended_at"
        case endFraction = "end_fraction"
    }
}

/// The one-line reading summary on a book's detail page.
public struct ReadingSummary: Codable, Sendable, Equatable {
    public var minutes: Int
    public var sessions: Int
    public var folio: Int?
}

// MARK: - One book, in depth: `GET /api/book/{id}/stats`

public struct BookStats: Codable, Sendable, Equatable {
    public var book: Book
    public var tracked: Bool
    public var state: State?
    public var totals: Totals
    public var pace: Pace
    public var forecast: Forecast?
    public var sessions: [Sitting]
    public var days: [Day]
    public var clock: [Int]?
    public var chapters: [Chapter]
    public var sources: [Source]
    public var live: Live?
    public var recentFolio: RecentFolio?

    enum CodingKeys: String, CodingKey {
        case book, tracked, state, totals, pace, forecast, sessions, days, clock
        case chapters, sources, live
        case recentFolio = "recent_folio"
    }

    public struct Book: Codable, Sendable, Equatable {
        public var id: Int
        public var title: String?
        public var author: String?
        public var cover: String?
        public var pages: Int?
        public var chapters: Int?

        public var displayTitle: String { title ?? "Untitled" }
    }

    public struct State: Codable, Sendable, Equatable {
        public var state: String?
        public var progress: Int?
        public var mode: String?
        public var startedAt: String?
        public var finishedAt: String?
        public var fraction: Double?

        public var readingState: ReadingState? { state.flatMap(ReadingState.init(rawValue:)) }

        enum CodingKeys: String, CodingKey {
            case state, progress, mode, fraction
            case startedAt = "started_at"
            case finishedAt = "finished_at"
        }
    }

    public struct Totals: Codable, Sendable, Equatable {
        public var minutes: Int
        public var sessions: Int
        public var checkpoints: Int
        public var days: Int
        public var pages: Int
        public var avgMinutes: Int?
        public var longestMinutes: Int?

        enum CodingKeys: String, CodingKey {
            case minutes, sessions, checkpoints, days, pages
            case avgMinutes = "avg_minutes"
            case longestMinutes = "longest_minutes"
        }
    }

    public struct Pace: Codable, Sendable, Equatable {
        public var pagesPerHour: Double?
        public var pctPerHour: Double?
        public var perDay: Double?

        enum CodingKeys: String, CodingKey {
            case pagesPerHour = "pages_per_hour"
            case pctPerHour = "pct_per_hour"
            case perDay = "per_day"
        }
    }

    public struct Forecast: Codable, Sendable, Equatable {
        public var days: Int
        public var perDay: Double?
        /// "pages", or "pct" for a book without a page count.
        public var unit: String
        public var date: String
        public var hoursLeft: Double?

        enum CodingKeys: String, CodingKey {
            case days, unit, date
            case perDay = "per_day"
            case hoursLeft = "hours_left"
        }
    }

    /// One session (a sitting), or a zero-length progress update when `checkpoint`.
    public struct Sitting: Codable, Sendable, Equatable, Identifiable, Hashable {
        public var id: Int
        public var startedAt: String
        public var endedAt: String?
        public var minutes: Int
        public var wallMinutes: Int?
        public var from: Int
        public var to: Int
        public var pages: Int?
        public var startFraction: Double?
        public var endFraction: Double?
        public var pagesTurned: Int?
        /// folio · ios · web · marquee (logged before sources were recorded)
        public var source: String
        public var sourceLabel: String
        public var checkpoint: Bool
        public var startChapter: String?
        public var endChapter: String?

        enum CodingKeys: String, CodingKey {
            case id, minutes, from, to, pages, source, checkpoint
            case startedAt = "started_at"
            case endedAt = "ended_at"
            case wallMinutes = "wall_minutes"
            case startFraction = "start_fraction"
            case endFraction = "end_fraction"
            case pagesTurned = "pages_turned"
            case sourceLabel = "source_label"
            case startChapter = "start_chapter"
            case endChapter = "end_chapter"
        }

        /// Where in the book it ran, as fractions — Folio's own when it sent them.
        public func span(pages: Int?) -> (start: Double, end: Double)? {
            let start = startFraction ?? pages.map { Double(from) / Double(max(1, $0)) }
            let end = endFraction ?? pages.map { Double(to) / Double(max(1, $0)) }
            guard let start, let end, end > start else { return nil }
            return (start, end)
        }

        /// The reading-log shape, for the shared edit sheet.
        public var logEntry: ReadingSession {
            ReadingSession(id: id, date: startedAt, minutes: minutes, from: from, to: to)
        }
    }

    public struct Day: Codable, Sendable, Equatable {
        public var date: String
        public var minutes: Double
        public var pages: Int
    }

    public struct Chapter: Codable, Sendable, Equatable, Identifiable {
        public var title: String
        public var minutes: Double
        public var pagesTurned: Int
        public var perHour: Double?
        /// "pages" (printed, from chapter fractions), "pct" (no page count), or
        /// "screens" (pages turned on the reader — the fallback). Older servers: nil.
        public var paceUnit: String?

        public var id: String { title }

        enum CodingKeys: String, CodingKey {
            case title, minutes
            case pagesTurned = "pages_turned"
            case perHour = "per_hour"
            case paceUnit = "pace_unit"
        }
    }

    public struct Source: Codable, Sendable, Equatable, Identifiable {
        public var source: String
        public var label: String
        public var sessions: Int
        public var minutes: Int

        public var id: String { label }
    }

    public struct Live: Codable, Sendable, Equatable {
        public var sessionID: Int
        public var startedAt: String

        enum CodingKeys: String, CodingKey {
            case sessionID = "session_id"
            case startedAt = "started_at"
        }
    }
}
