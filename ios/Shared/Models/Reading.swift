import Foundation

/// Books and manga are the same shape with different units — pages vs chapters — so
/// one model carries both and `kind` decides how it reads.
public enum ReadingKind: String, Codable, Sendable, CaseIterable {
    case book
    case manga

    /// The API path segment for state and session endpoints.
    public var path: String { rawValue }
    public var unit: String { self == .book ? "pages" : "chapters" }
    public var unitShort: String { self == .book ? "p" : "ch" }
}

public enum ReadingState: String, Codable, Sendable, CaseIterable {
    case want
    case reading
    case finished
    /// Set aside, coming back to it.
    case paused
    /// Did not finish. The pages read still count.
    case dnf

    public var label: String {
        switch self {
        case .want: "Want to read"
        case .reading: "Reading"
        case .finished: "Finished"
        case .paused: "Paused"
        case .dnf: "Didn't finish"
        }
    }

    /// The three everyday shelves, in the order the segmented control shows them.
    /// Paused and Didn't finish live one level down.
    public static let primary: [ReadingState] = [.want, .reading, .finished]
    public static let secondary: [ReadingState] = [.paused, .dnf]

    /// Shelves in the order the Library lists them.
    public static let shelfOrder: [ReadingState] = [.reading, .want, .paused, .finished, .dnf]

    /// A state the server invents after this build shipped must not take the whole
    /// shelf down with it. Decoding directly falls back to "want"; the `readingState`
    /// accessors on the models use `init(rawValue:)` and simply return nil.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = ReadingState(rawValue: raw) ?? .want
    }
}

/// How the owner of a title thinks about its progress. The canonical stored value is
/// always pages for a book — converting on every write drifts the number, so an
/// untouched field is passed straight back through.
public enum ProgressMode: String, Codable, Sendable {
    case pages
    case pct
    case chapters
}

/// `GET /api/reading`
public struct ReadingShelves: Codable, Sendable, Equatable {
    public var books: ReadingSections
    public var manga: ReadingSections
}

public struct ReadingSections: Codable, Sendable, Equatable {
    public var reading: [ReadingItem]
    public var want: [ReadingItem]
    public var finished: [ReadingItem]
    /// Newer servers only — an older one has no such shelves.
    public var paused: [ReadingItem]?
    public var dnf: [ReadingItem]?

    public var all: [ReadingItem] { reading + want + (paused ?? []) + finished + (dnf ?? []) }

    public func items(in state: ReadingState) -> [ReadingItem] {
        switch state {
        case .reading: reading
        case .want: want
        case .finished: finished
        case .paused: paused ?? []
        case .dnf: dnf ?? []
        }
    }

    public mutating func setItems(_ items: [ReadingItem], in state: ReadingState) {
        switch state {
        case .reading: reading = items
        case .want: want = items
        case .finished: finished = items
        case .paused: paused = items
        case .dnf: dnf = items
        }
    }

    /// Take an item off whichever shelf it's on; returns it, and where it was.
    @discardableResult
    public mutating func take(_ id: Int) -> (item: ReadingItem, state: ReadingState, index: Int)? {
        for state in ReadingState.shelfOrder {
            var shelf = items(in: state)
            if let index = shelf.firstIndex(where: { $0.id == id }) {
                let item = shelf.remove(at: index)
                setItems(shelf, in: state)
                return (item, state, index)
            }
        }
        return nil
    }

    /// Put an item on a shelf, at the front unless told otherwise.
    public mutating func put(_ item: ReadingItem, in state: ReadingState, at index: Int = 0) {
        var shelf = items(in: state)
        shelf.insert(item, at: min(max(0, index), shelf.count))
        setItems(shelf, in: state)
    }
}

public struct ReadingItem: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var title: String?
    public var cover: String?
    public var year: FlexInt?
    public var state: String?
    public var progress: Int?
    /// Your own score, as sent. Books keep halves server-side, so this may not be a
    /// whole number — decoding it as an Int would fail the entire shelf on one 7.5.
    public var ratingValue: FlexDouble?
    public var startedAt: String?
    public var finishedAt: String?
    public var mode: String?

    // Home's Continue reading rail, and newer shelves.
    /// "book" or "manga" — set only where both kinds share one list (the dashboard).
    public var kind: String?
    /// Units (pages or chapters) per day over the last three weeks.
    public var pace: Double?
    /// At that pace, days until the end.
    public var finishDays: Int?
    /// Newest chapter MangaDex knows about.
    public var latestCh: Int?
    public var latestAt: String?
    /// The last session or checkpoint on this title.
    public var lastReadAt: String?

    // books
    public var author: String?
    public var pages: Int?
    public var olid: String?
    public var hcID: Int?
    public var communityRating: Double?
    public var series: String?

    // manga (and `chapters` on a book, when Open Library gave us a TOC)
    public var chapters: Int?
    public var volumes: Int?
    public var status: String?
    /// manga · manhwa · manhua
    public var origin: String?

    /// Comma-separated, as the shelf query returns it.
    public var genres: String?
    /// Set only on the series browse page.
    public var seriesPos: Int?

    public var displayTitle: String { title ?? "Untitled" }
    public var readingState: ReadingState? { state.flatMap(ReadingState.init(rawValue:)) }
    /// Your own 1–10 score, rounded for display.
    public var rating: Int? { ratingValue?.value.map { Int($0.rounded()) } }
    /// The `kind` field, for lists that mix books and manga. Defaults to book.
    public var readingKind: ReadingKind { kind.flatMap(ReadingKind.init(rawValue:)) ?? .book }
    /// Unique across a mixed list — a book and a manga can share an id.
    public var railID: String { "\(readingKind.rawValue):\(id)" }
    public var genreList: [String] {
        (genres ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Chapters out past where you are — manga only.
    public var newChapters: Int {
        guard let latestCh, latestCh > (progress ?? 0) else { return 0 }
        return latestCh - (progress ?? 0)
    }

    /// The line that makes a reading card useful: new chapters you haven't read, or
    /// when you'll finish at the pace you've actually been reading.
    public var paceLine: String? {
        let behind = newChapters
        if behind > 0 { return "\(behind) new chapter\(behind == 1 ? "" : "s")" }
        if let finishDays, finishDays > 0 {
            return "~\(finishDays) day\(finishDays == 1 ? "" : "s") left at your pace"
        }
        return nil
    }

    /// Where a "+1" lands, in the canonical stored unit. A book tracked in chapters
    /// steps a chapter at a time while the server still stores pages — so convert on
    /// the way out, never on the way back.
    public func incrementedProgress(for kind: ReadingKind) -> Int {
        if kind == .book, mode == ProgressMode.chapters.rawValue,
           let pages, let chapters, chapters > 0 {
            return min(pages, Int((Double(chapterPosition + 1) / Double(chapters)
                                   * Double(pages)).rounded()))
        }
        return min(total(for: kind) ?? .max, (progress ?? 0) + 1)
    }

    public func total(for kind: ReadingKind) -> Int? {
        kind == .book ? pages : chapters
    }

    public func fraction(for kind: ReadingKind) -> Double {
        guard let total = total(for: kind), total > 0 else { return 0 }
        return min(1, Double(progress ?? 0) / Double(total))
    }

    /// Chapter equivalent of a page position, for books tracked by chapter.
    public var chapterPosition: Int {
        guard let pages, pages > 0, let chapters, chapters > 0 else { return progress ?? 0 }
        return min(chapters, Int((Double(progress ?? 0) / Double(pages) * Double(chapters)).rounded()))
    }

    /// The one-line progress readout, in whatever unit this title is tracked in.
    public func progressLabel(for kind: ReadingKind) -> String {
        let total = total(for: kind)
        if mode == ProgressMode.pct.rawValue, let total, total > 0 {
            return "\(Int((Double(progress ?? 0) / Double(total) * 100).rounded()))%"
        }
        if kind == .book, mode == ProgressMode.chapters.rawValue, let chapters, chapters > 0 {
            return "ch \(chapterPosition)/\(chapters)"
        }
        let suffix = total.map { "/\($0)" } ?? ""
        return "\(progress ?? 0)\(suffix) \(kind.unitShort)"
    }

    /// A "+1" button only makes sense where a chapter is the unit.
    public func supportsIncrement(for kind: ReadingKind) -> Bool {
        kind == .manga || (mode == ProgressMode.chapters.rawValue && chapters != nil && pages != nil)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, cover, year, state, progress, mode, author, pages, olid
        case chapters, volumes, status, origin, genres, series, kind, pace
        case ratingValue = "rating"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case hcID = "hc_id"
        case communityRating = "community_rating"
        case seriesPos = "series_pos"
        case finishDays = "finish_days"
        case latestCh = "latest_ch"
        case latestAt = "latest_at"
        case lastReadAt = "last_read_at"
    }
}

/// `GET /api/book/{id}`, `/api/book/hc/{id}`, `/api/manga/{id}`
public struct ReadingDetail: Codable, Sendable, Equatable {
    public var tracked: Bool
    public var kind: ReadingKind
    public var item: ReadingDetailItem
    public var state: ReadingStateRow?
    public var sessions: [ReadingSession]
    public var household: [HouseholdRead]
}

public struct ReadingDetailItem: Codable, Sendable, Equatable {
    public var id: Int?
    public var title: String?
    public var cover: String?
    public var year: FlexInt?
    public var author: String?
    public var pages: Int?
    public var chapters: Int?
    public var volumes: Int?
    public var status: String?
    public var origin: String?
    public var series: String?
    public var seriesPos: Int?
    public var communityRating: Double?
    /// AniList's 0–10 score for manga.
    public var score: Double?
    public var desc: String?
    /// Comma-separated for a book; AniList returns a joined string too.
    public var genres: String?
    public var subjects: [String]?
    /// Chapter titles scraped from an Open Library table of contents.
    public var toc: [String]?
    /// `[[chapter number, title], …]` from MangaDex.
    public var chlist: [MangaChapter]?
    public var hcID: Int?
    public var slug: String?

    public var displayTitle: String { title ?? "Untitled" }
    public var genreList: [String] {
        (genres ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, cover, year, author, pages, chapters, volumes, status, origin
        case series, score, desc, genres, subjects, toc, chlist, slug
        case seriesPos = "series_pos"
        case communityRating = "community_rating"
        case hcID = "hc_id"
    }
}

/// One `[number, title]` pair from MangaDex. Licensed series can be partly delisted,
/// so a row with an empty title renders as "Chapter N".
public struct MangaChapter: Codable, Sendable, Hashable, Identifiable {
    public var number: Int
    public var title: String

    public var id: Int { number }
    public var displayTitle: String { title.isEmpty ? "Chapter \(number)" : title }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        number = (try? container.decode(Int.self)) ?? 0
        title = (try? container.decode(String.self)) ?? ""
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(number)
        try container.encode(title)
    }
}

public struct ReadingStateRow: Codable, Sendable, Equatable {
    public var state: String?
    public var progress: Int?
    /// Lenient for the same reason as `ReadingItem.ratingValue`.
    public var ratingValue: FlexDouble?
    public var startedAt: String?
    public var finishedAt: String?
    public var mode: String?

    public var readingState: ReadingState? { state.flatMap(ReadingState.init(rawValue:)) }
    public var rating: Int? { ratingValue?.value.map { Int($0.rounded()) } }

    enum CodingKeys: String, CodingKey {
        case state, progress, mode
        case ratingValue = "rating"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }
}

/// A row in the reading log: a timed session, or a zero-duration checkpoint that a
/// "+1" or a manual edit left behind.
public struct ReadingSession: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var date: String
    public var minutes: Int
    public var from: Int
    public var to: Int

    /// Under three minutes isn't a sitting — it's a progress note.
    public var isTimed: Bool { minutes >= 3 }
}

public struct HouseholdRead: Codable, Sendable, Hashable, Identifiable {
    public var username: String
    public var displayName: String?
    public var avatar: String?
    public var state: String?
    public var ratingValue: FlexDouble?

    public var id: String { username }
    public var rating: Int? { ratingValue?.value.map { Int($0.rounded()) } }
    /// "Didn't finish" rather than "dnf".
    public var stateLabel: String {
        guard let state else { return "" }
        return ReadingState(rawValue: state)?.label ?? state
    }
    public var person: Person {
        Person(id: nil, username: username, displayName: displayName, avatar: avatar,
               banner: nil, features: nil, isAdmin: nil, isMe: false)
    }

    enum CodingKeys: String, CodingKey {
        case username, avatar, state
        case ratingValue = "rating"
        case displayName = "display_name"
    }
}

/// A live session, still running.
public struct ActiveSession: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var kind: String
    public var itemID: Int
    public var startedAt: String
    public var startPos: Int?
    public var title: String?
    public var cover: String?
    public var pages: Int?
    public var chapters: Int?
    public var bookChapters: Int?
    public var mode: String?

    public var readingKind: ReadingKind { ReadingKind(rawValue: kind) ?? .book }
    public var total: Int? { readingKind == .book ? pages : chapters }

    enum CodingKeys: String, CodingKey {
        case id, kind, title, cover, pages, chapters, mode
        case itemID = "item_id"
        case startedAt = "started_at"
        case startPos = "start_pos"
        case bookChapters = "book_chapters"
    }
}

public struct ActiveSessionsResponse: Codable, Sendable, Equatable {
    public var sessions: [ActiveSession]
}

public struct SessionStartResponse: Codable, Sendable, Equatable {
    public var ok: Bool?
    public var sessionID: Int?
    public var startedAt: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case sessionID = "session_id"
        case startedAt = "started_at"
    }
}

public struct EndSessionRequest: Codable, Sendable, Equatable {
    public var pos: Int?
    public var discard: Bool?
    public init(pos: Int? = nil, discard: Bool? = nil) {
        self.pos = pos
        self.discard = discard
    }
}

public struct EditSessionRequest: Codable, Sendable, Equatable {
    public var date: String?
    public var minutes: Int?
    public var from: Int?
    public var to: Int?
    public var delete: Bool?

    public init(date: String? = nil, minutes: Int? = nil,
                from: Int? = nil, to: Int? = nil, delete: Bool? = nil) {
        self.date = date
        self.minutes = minutes
        self.from = from
        self.to = to
        self.delete = delete
    }
}

/// `POST /api/book/{id}/state` and `/api/manga/{id}/state`. Every field is optional
/// and omitted fields are left exactly as they were — the server passes stored values
/// through untouched, which is what keeps page counts from drifting.
public struct ReadingStateRequest: Codable, Sendable, Equatable {
    public var state: String?
    public var progress: Int?
    public var rating: Int?
    public var startedAt: String?
    public var finishedAt: String?
    public var mode: String?

    public init(state: ReadingState? = nil, progress: Int? = nil, rating: Int? = nil,
                startedAt: String? = nil, finishedAt: String? = nil, mode: ProgressMode? = nil) {
        self.state = state?.rawValue
        self.progress = progress
        self.rating = rating
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.mode = mode?.rawValue
    }

    /// Send `"rating": null`. Omitting the key means "leave it", so clearing a
    /// score has to be explicit.
    public var clearsRating = false

    /// "none" removes the title from the shelf entirely (and drops a live session on
    /// it). The undo is `RestoreReadingRequest`.
    public static var remove: ReadingStateRequest {
        var request = ReadingStateRequest()
        request.state = "none"
        return request
    }

    public static var clearRating: ReadingStateRequest {
        var request = ReadingStateRequest()
        request.clearsRating = true
        return request
    }

    enum CodingKeys: String, CodingKey {
        case state, progress, rating, mode
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(state, forKey: .state)
        try container.encodeIfPresent(progress, forKey: .progress)
        if clearsRating {
            try container.encodeNil(forKey: .rating)
        } else {
            try container.encodeIfPresent(rating, forKey: .rating)
        }
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(finishedAt, forKey: .finishedAt)
        try container.encodeIfPresent(mode, forKey: .mode)
    }
}

/// `POST /api/{kind}/{id}/restore` — put a removed title back exactly as it was.
/// Built from the item as it sat on the shelf before the remove.
public struct RestoreReadingRequest: Codable, Sendable, Equatable {
    public var state: String
    public var progress: Int?
    /// Sent as a number, never a string: the server validates 1–10.
    public var rating: Double?
    public var mode: String?
    public var startedAt: String?
    public var finishedAt: String?

    public init(from item: ReadingItem, state fallback: ReadingState) {
        state = item.readingState?.rawValue ?? fallback.rawValue
        progress = item.progress
        rating = item.ratingValue?.value
        mode = item.mode
        startedAt = item.startedAt
        finishedAt = item.finishedAt
    }

    enum CodingKeys: String, CodingKey {
        case state, progress, rating, mode
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }
}

// MARK: - Search and adding

public struct BookSearchResponse: Codable, Sendable, Equatable {
    public var results: [BookSearchResult]
}

public struct BookSearchResult: Codable, Sendable, Hashable, Identifiable {
    public var hcID: Int
    public var title: String?
    public var author: String?
    public var year: FlexInt?
    public var pages: Int?
    public var cover: String?
    public var series: String?
    public var seriesPos: Int?
    public var communityRating: Double?
    public var ratingsCount: Int?
    public var genres: String?
    public var desc: String?
    public var slug: String?

    public var id: Int { hcID }
    public var displayTitle: String { title ?? "Untitled" }

    enum CodingKeys: String, CodingKey {
        case title, author, year, pages, cover, series, genres, desc, slug
        case hcID = "hc_id"
        case seriesPos = "series_pos"
        case communityRating = "community_rating"
        case ratingsCount = "ratings_count"
    }
}

public struct MangaSearchResponse: Codable, Sendable, Equatable {
    public var results: [MangaSearchResult]
}

public struct MangaSearchResult: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var title: String?
    public var cover: String?
    public var chapters: Int?
    public var volumes: Int?
    public var status: String?
    public var origin: String?
    public var year: FlexInt?
    public var score: Double?
    /// AniList returns a real array here, unlike the shelf's comma-joined string.
    public var genres: [String]?
    public var desc: String?

    public var displayTitle: String { title ?? "Untitled" }
}

/// `POST /api/books/add` — the whole row goes up, because the server stores what the
/// client already fetched rather than asking Hardcover twice.
public struct AddBookRequest: Codable, Sendable, Equatable {
    public var hcID: Int
    public var title: String?
    public var author: String?
    public var year: Int?
    public var pages: Int?
    public var cover: String?
    public var series: String?
    public var rating: Double?
    public var genres: String?
    public var slug: String?
    public var desc: String?
    public var state: String

    public init(from result: BookSearchResult, state: ReadingState) {
        hcID = result.hcID
        title = result.title
        author = result.author
        year = result.year?.value
        pages = result.pages
        cover = result.cover
        series = result.series
        rating = result.communityRating
        genres = result.genres
        slug = result.slug
        desc = result.desc
        self.state = state.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case title, author, year, pages, cover, series, rating, genres, slug, desc, state
        case hcID = "hc_id"
    }
}

public struct AddMangaRequest: Codable, Sendable, Equatable {
    public var id: Int
    public var state: String
    public init(id: Int, state: ReadingState) {
        self.id = id
        self.state = state.rawValue
    }
}

public struct AddedResponse: Codable, Sendable, Equatable {
    public var ok: Bool?
    public var id: Int?
}

/// `GET /api/book/{id}/matches` — the list behind "Wrong book?", for when automatic
/// matching landed on a workbook or a boxed set.
public struct BookMatchesResponse: Codable, Sendable, Equatable {
    public var current: Int?
    public var results: [BookSearchResult]
}

public struct RematchRequest: Codable, Sendable, Equatable {
    public var hcID: Int
    public init(hcID: Int) { self.hcID = hcID }
    enum CodingKeys: String, CodingKey { case hcID = "hc_id" }
}

/// `GET /api/books/browse` — everything by an author, or everything in a series:
/// your own copies first, then the rest of the bibliography to add from.
public struct BrowseResponse: Codable, Sendable, Equatable {
    public var by: String
    public var name: String
    public var header: BrowseHeader?
    public var shelf: [ReadingItem]
    public var more: [BookSearchResult]

    public var isAuthor: Bool { by == "author" }
}

public struct BrowseHeader: Codable, Sendable, Equatable {
    public var id: Int?
    public var name: String?
    public var slug: String?
    public var booksCount: Int?
    public var bio: String?
    public var image: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, bio, image
        case booksCount = "books_count"
    }
}

// MARK: - Reading stats

public struct ReadingStatsResponse: Codable, Sendable, Equatable {
    public var books: ReadingStats?
    public var manga: ReadingStats?
}

public struct ReadingStats: Codable, Sendable, Equatable {
    public var totals: ReadingTotals
    /// Units per hour, only once there's at least a quarter hour of timed sessions.
    public var pace: Double?
    public var avgSessionMin: Int?
    public var streak: Streak
    /// `[[date, units], …]` for the last 30 days.
    public var daily30: [DailyUnits]?
    /// `[["2026-04", 812], …]`
    public var monthly: [MonthlyUnits]?
    public var yearly: [MonthlyUnits]?
    /// Minutes of timed reading per hour of day.
    public var clock: [Int]?
    public var weekday: [Int]?
    public var finished: FinishedCounts
    public var readingNow: Int
    public var fastest: FastestFinish?
    public var longest: LongestRead?
    public var bigDay: BigReadingDay?
    public var ratingHist: [String: Int]?

    public var isEmpty: Bool {
        totals.all == 0 && totals.sessions == 0 && finished.all == 0
    }

    enum CodingKeys: String, CodingKey {
        case totals, pace, streak, daily30, monthly, yearly, clock, weekday, finished
        case fastest, longest
        case avgSessionMin = "avg_session_min"
        case readingNow = "reading_now"
        case bigDay = "big_day"
        case ratingHist = "rating_hist"
    }
}

public struct ReadingTotals: Codable, Sendable, Equatable {
    public var week: Int
    public var month: Int
    public var year: Int
    public var all: Int
    public var hoursAll: Double
    public var hoursMonth: Double
    public var sessions: Int
    public var timedSessions: Int

    enum CodingKeys: String, CodingKey {
        case week, month, year, all, sessions
        case hoursAll = "hours_all"
        case hoursMonth = "hours_month"
        case timedSessions = "timed_sessions"
    }
}

public struct FinishedCounts: Codable, Sendable, Equatable {
    public var all: Int
    public var year: Int
}

public struct FastestFinish: Codable, Sendable, Equatable {
    public var title: String
    public var days: Int
}

public struct LongestRead: Codable, Sendable, Equatable {
    public var title: String
    public var units: Int
}

public struct BigReadingDay: Codable, Sendable, Equatable {
    public var date: String
    public var units: Int
}

/// `["2026-07-14", 42]` — a date and a unit count in one JSON array.
public struct DailyUnits: Codable, Sendable, Hashable, Identifiable {
    public var date: String
    public var units: Double
    public var id: String { date }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        date = (try? container.decode(String.self)) ?? ""
        units = (try? container.decode(Double.self)) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(date)
        try container.encode(units)
    }
}

/// `["2026-07", 812]`
public struct MonthlyUnits: Codable, Sendable, Hashable, Identifiable {
    public var key: String
    public var units: Int
    public var id: String { key }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        key = (try? container.decode(String.self)) ?? ""
        units = (try? container.decode(Int.self)) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(key)
        try container.encode(units)
    }
}
