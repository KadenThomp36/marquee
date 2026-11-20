import Foundation

/// `GET /api/profile` and `/api/profile/{username}`
public struct ProfilePayload: Codable, Sendable, Equatable {
    public var id: Int?
    public var username: String
    public var displayName: String?
    public var avatar: String?
    public var banner: String?
    public var features: UserFeatures?
    public var isAdmin: Bool?
    public var memberSince: String?
    public var isMe: Bool
    public var headline: Headline?
    public var favorites: [Favorite]
    /// Years whose recap has unlocked, newest first.
    public var recapYears: [Int]
    /// True when this year has data but December hasn't arrived.
    public var recapSoon: Bool?
    public var recapYear: Int?
    /// The day this year's recap premieres.
    public var recapRelease: String?

    public var person: Person {
        Person(id: id, username: username, displayName: displayName, avatar: avatar,
               banner: banner, features: features, isAdmin: isAdmin, isMe: isMe)
    }

    enum CodingKeys: String, CodingKey {
        case id, username, avatar, banner, features, headline, favorites
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case memberSince = "member_since"
        case isMe = "is_me"
        case recapYears = "recap_years"
        case recapSoon = "recap_soon"
        case recapYear = "recap_year"
        case recapRelease = "recap_release"
    }
}

public struct Headline: Codable, Sendable, Hashable {
    public var episodes: Int
    public var shows: Int
    public var movies: Int
    public var hours: Int
}

public struct BannerOptionsResponse: Codable, Sendable, Equatable {
    public var options: [BannerOption]
}

public struct BannerOption: Codable, Sendable, Hashable, Identifiable {
    public var title: String
    public var backdrop: String
    public var id: String { backdrop }
}

public struct SetBannerRequest: Codable, Sendable, Equatable {
    public var url: String?
    public var clear: Bool?
    public init(url: String?) { self.url = url }
    public init(clear: Bool) { self.clear = clear }
}

public struct BannerResponse: Codable, Sendable, Equatable {
    public var banner: String?
}

public struct AvatarResponse: Codable, Sendable, Equatable {
    public var avatar: String?
}

public struct UpdateProfileRequest: Codable, Sendable, Equatable {
    public var displayName: String?
    public var username: String?
    public var password: String?

    public init(displayName: String? = nil, username: String? = nil, password: String? = nil) {
        self.displayName = displayName
        self.username = username
        self.password = password
    }

    enum CodingKeys: String, CodingKey {
        case username, password
        case displayName = "display_name"
    }
}

public struct FeaturesRequest: Codable, Sendable, Equatable {
    public var books: Int?
    public var manga: Int?
    public init(books: Int? = nil, manga: Int? = nil) {
        self.books = books
        self.manga = manga
    }
}

public struct FeaturesResponse: Codable, Sendable, Equatable {
    public var ok: Bool?
    public var features: UserFeatures
}

// MARK: - Watched grids

/// `GET /api/watched/{username}/{shows|movies}` — what someone has actually watched,
/// newest first, paged by offset.
public struct WatchedPage: Codable, Sendable, Equatable {
    public var user: Person
    public var kind: String
    public var items: [WatchedItem]
    public var total: Int
    /// Offset for the next page, or nil at the end.
    public var next: Int?
}

public struct WatchedItem: Codable, Sendable, Hashable, Identifiable {
    public var type: String
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var rating: Int?
    /// Shows only.
    public var watched: Int?
    public var aired: Int?
    public var ended: Bool?
    public var watchedAt: String?

    public var uniqueID: String { "\(type):\(id)" }
    public var displayTitle: String { title ?? "Untitled" }
    /// A finished series — every aired episode watched, and it's over.
    public var isFinishedSeries: Bool {
        guard let aired, aired > 0, let watched, ended == true else { return false }
        return watched >= aired
    }

    enum CodingKeys: String, CodingKey {
        case type, id, title, poster, year, rating, watched, aired, ended
        case watchedAt = "watched_at"
    }
}

// MARK: - Stats

/// `GET /api/stats`
public struct Stats: Codable, Sendable, Equatable {
    public var episodes: Int
    public var tvMinutes: Int
    public var movies: Int
    public var movieMinutes: Int
    public var shows: Int
    public var thisYear: ThisYear?
    public var monthly: [MonthCount]
    public var yearly: [YearCount]
    public var topShows: [TopShow]
    public var genres: [NamedCount]
    /// `[[weekday, hour, count], …]` for all time.
    public var heatmap: [[Int]]?
    /// Same shape, keyed by year plus "all", for the watch-clock year selector.
    public var heatYears: [String: [[Int]]]?
    public var streak: Streak
    public var bigDay: BigDay?
    public var firstWatch: FirstWatch?
    public var perDay: Double
    public var completion: Completion?
    public var movieDecades: [DecadeCount]?
    /// Score → how many titles you gave it.
    public var ratingHist: [String: Int]?
    public var topRated: [RatedTitle]?

    public var totalMinutes: Int { tvMinutes + movieMinutes }

    enum CodingKeys: String, CodingKey {
        case episodes, movies, shows, monthly, yearly, genres, heatmap, streak, completion
        case tvMinutes = "tv_minutes"
        case movieMinutes = "movie_minutes"
        case thisYear = "this_year"
        case topShows = "top_shows"
        case heatYears = "heat_years"
        case bigDay = "big_day"
        case firstWatch = "first_watch"
        case perDay = "per_day"
        case movieDecades = "movie_decades"
        case ratingHist = "rating_hist"
        case topRated = "top_rated"
    }
}

public struct ThisYear: Codable, Sendable, Equatable {
    public var episodes: Int
    public var movies: Int
    public var top: [TopShow]?
}

public struct MonthCount: Codable, Sendable, Hashable, Identifiable {
    public var ym: String
    public var count: Int
    public var id: String { ym }
}

public struct YearCount: Codable, Sendable, Hashable, Identifiable {
    public var y: String
    public var c: Int
    public var id: String { y }
}

public struct TopShow: Codable, Sendable, Hashable, Identifiable {
    public var showID: Int?
    public var title: String
    public var poster: String?
    public var eps: Int
    public var mins: Int?
    public var id: String { title }

    enum CodingKeys: String, CodingKey {
        case title, poster, eps, mins
        case showID = "id"
    }
}

public struct NamedCount: Codable, Sendable, Hashable, Identifiable {
    public var name: String
    public var count: Int
    public var id: String { name }
}

public struct DecadeCount: Codable, Sendable, Hashable, Identifiable {
    public var dec: Int?
    public var c: Int
    public var id: Int { dec ?? 0 }
    public var label: String { dec.map { "\($0)s" } ?? "Unknown" }
}

public struct RatedTitle: Codable, Sendable, Hashable, Identifiable {
    public var title: String
    public var rating: Int
    public var id: String { title }
}

public struct Streak: Codable, Sendable, Hashable {
    public var current: Int
    public var longest: Int
    public var longestEnd: String?

    enum CodingKeys: String, CodingKey {
        case current, longest
        case longestEnd = "longest_end"
    }
}

/// The biggest genuine single-day binge — bulk import timestamps excluded, so an
/// import never masquerades as a 1,300-episode day.
public struct BigDay: Codable, Sendable, Hashable {
    public var date: String
    public var count: Int
    public var top: String?
}

public struct FirstWatch: Codable, Sendable, Hashable {
    public var watchedAt: String?
    public var title: String?

    enum CodingKeys: String, CodingKey {
        case title
        case watchedAt = "watched_at"
    }
}

/// Where your followed shows stand.
public struct Completion: Codable, Sendable, Hashable {
    public var finished: Int
    public var inProgress: Int
    public var upToDate: Int
    public var dropped: Int
    public var notStarted: Int

    public var total: Int { finished + inProgress + upToDate + dropped + notStarted }

    enum CodingKeys: String, CodingKey {
        case finished, dropped
        case inProgress = "in_progress"
        case upToDate = "up_to_date"
        case notStarted = "not_started"
    }
}

/// `GET /api/stats/advanced` — the Trakt-VIP-parity cuts. Film details backfill
/// gradually, so `moviesEnriched` says how complete this is.
public struct AdvancedStats: Codable, Sendable, Equatable {
    public var networks: [NamedCount]
    public var studios: [NamedCount]
    public var countries: [CountryCount]
    public var actors: [ActorCount]
    public var directors: [NamedCount]
    public var moviesEnriched: Int?
    public var moviesTotal: Int?

    public var isEmpty: Bool {
        networks.isEmpty && studios.isEmpty && countries.isEmpty
            && actors.isEmpty && directors.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case networks, studios, countries, actors, directors
        case moviesEnriched = "movies_enriched"
        case moviesTotal = "movies_total"
    }
}

public struct CountryCount: Codable, Sendable, Hashable, Identifiable {
    public var code: String
    public var name: String
    public var count: Int
    public var id: String { code }
}

public struct ActorCount: Codable, Sendable, Hashable, Identifiable {
    public var name: String
    public var img: String?
    public var shows: Int
    public var movies: Int
    public var id: String { name }
    public var total: Int { shows + movies }
}

// MARK: - Recap

/// `GET /api/recap/{year}` — a year only unlocks once it's over (or once it's
/// December, for the current one).
public struct Recap: Codable, Sendable, Equatable {
    public var year: Int
    public var locked: Bool?
    public var hasData: Bool
    public var episodes: Int?
    public var movies: Int?
    public var minutes: Int?
    public var tvMinutes: Int?
    public var movieMinutes: Int?
    public var topShows: [TopShow]?
    public var topMovies: [RecapMovie]?
    public var genres: [NamedCount]?
    /// Twelve counts, January first.
    public var months: [Int]?
    public var busiestMonth: String?
    public var busiestMonthCount: Int?
    public var binge: BigDay?
    public var firstWatch: FirstWatch?
    public var lastWatch: FirstWatch?
    public var newShows: Int?
    public var years: [Int]?
    /// False while the year is still running: the numbers keep counting to New Year.
    public var final: Bool?
    /// An admin looking before release day.
    public var preview: Bool?
    public var reading: RecapReading?
    public var persona: RecapPersona?
    /// Plays by hour of day (24, midnight first) and weekday (7, Monday first).
    public var hours: [Int]?
    public var weekdays: [Int]?
    public var peakHour: Int?
    public var peakWeekday: String?
    public var daysWatched: Int?
    public var streak: RecapStreak?
    public var household: RecapHousehold?
    /// On a locked year: when it opens.
    public var release: String?

    enum CodingKeys: String, CodingKey {
        case year, locked, episodes, movies, minutes, genres, months, binge, years
        case final, preview, reading, persona, hours, weekdays, streak, household, release
        case peakHour = "peak_hour"
        case peakWeekday = "peak_weekday"
        case daysWatched = "days_watched"
        case hasData = "has_data"
        case tvMinutes = "tv_minutes"
        case movieMinutes = "movie_minutes"
        case topShows = "top_shows"
        case topMovies = "top_movies"
        case busiestMonth = "busiest_month"
        case busiestMonthCount = "busiest_month_count"
        case firstWatch = "first_watch"
        case lastWatch = "last_watch"
        case newShows = "new_shows"
    }
}

public struct RecapMovie: Codable, Sendable, Hashable, Identifiable {
    public var title: String
    public var poster: String?
    public var rating: Int?
    public var id: String { title }
}

public struct RecapIndex: Codable, Sendable, Equatable {
    public var years: [Int]
    /// The year to present once, by itself, until it's been seen — from release day
    /// to the end of January.
    public var autoshow: Int?
    public var release: String?
}

/// "The Night Owl — 41% of it after 10 pm."
public struct RecapPersona: Codable, Sendable, Hashable {
    public var key: String
    public var title: String
    public var line: String
}

public struct RecapStreak: Codable, Sendable, Hashable {
    public var days: Int
    public var start: String
    public var end: String
}

public struct RecapHousehold: Codable, Sendable, Hashable {
    public var rank: Int
    public var of: Int
}

/// The reading half of a recap, when its owner reads.
public struct RecapReading: Codable, Sendable, Hashable {
    public var books: Int?
    public var manga: Int?
    public var pages: Int?
    public var chapters: Int?
    public var minutes: Int?
    public var covers: [Cover]?
    public var topAuthor: Author?
    public var longest: Book?
    public var fastest: Fastest?
    public var favourite: Book?
    public var busiestMonth: String?
    public var busiestMonthUnits: Int?
    public var goal: Goal?

    enum CodingKeys: String, CodingKey {
        case books, manga, pages, chapters, minutes, covers, longest, fastest, favourite, goal
        case topAuthor = "top_author"
        case busiestMonth = "busiest_month"
        case busiestMonthUnits = "busiest_month_units"
    }

    public struct Cover: Codable, Sendable, Hashable {
        public var title: String?
        public var cover: String?
    }
    public struct Author: Codable, Sendable, Hashable {
        public var name: String
        public var count: Int
        public var pages: Int
    }
    public struct Book: Codable, Sendable, Hashable {
        public var title: String
        public var cover: String?
        public var author: String?
        public var pages: Int?
        public var rating: Int?
    }
    public struct Fastest: Codable, Sendable, Hashable {
        public var title: String
        public var days: Int
    }
    public struct Goal: Codable, Sendable, Hashable {
        public var target: Int?
        public var done: Int?
    }
}
