import Foundation

// MARK: - The card shape

/// One show as it appears on a card: poster, progress, and the next episode to punch.
/// This is `show_summary()` server-side, and it's what every mark endpoint hands back
/// so the UI can advance in place without refetching the screen.
public struct ShowCard: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var status: String?
    /// Your own 1–10 score for the show.
    public var rating: Int?
    public var avgRuntime: Int?
    /// Episodes that have aired (season > 0, air date on or before today).
    public var aired: Int
    public var watched: Int
    public var remaining: Int
    public var lastWatched: String?
    public var nextAir: String?
    public var nextEp: NextEpisode?

    public var displayTitle: String { title ?? "Untitled" }
    public var isEnded: Bool { ShowStatus.isEnded(status) }
    public var progress: Double { aired > 0 ? Double(watched) / Double(aired) : 0 }
    public var percent: Int { Int((progress * 100).rounded()) }
    /// Hours left to catch up, when we know the average runtime.
    public var hoursRemaining: Double? {
        guard remaining > 0, let avgRuntime, avgRuntime > 0 else { return nil }
        return Double(remaining * avgRuntime) / 60
    }

    enum CodingKeys: String, CodingKey {
        case id, title, poster, year, status, rating, aired, watched, remaining
        case avgRuntime = "avg_runtime"
        case lastWatched = "last_watched"
        case nextAir = "next_air"
        case nextEp = "next_ep"
    }
}

public struct NextEpisode: Codable, Sendable, Hashable {
    public var season: Int
    public var number: Int
    public var title: String?
    public var airDate: String?

    public var code: String { "S\(season) · E\(number)" }

    enum CodingKeys: String, CodingKey {
        case season, number, title
        case airDate = "air_date"
    }
}

public enum ShowStatus {
    public static func isEnded(_ status: String?) -> Bool {
        guard let status = status?.lowercased() else { return false }
        return status == "ended" || status == "canceled" || status == "cancelled"
    }
}

// MARK: - Show detail

/// `GET /api/show/{id}` — the show row, its seasons, and everything the hero needs.
public struct ShowDetail: Codable, Sendable, Equatable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var backdrop: String?
    public var year: FlexInt?
    public var status: String?
    public var genres: String?
    public var avgRuntime: Int?
    public var info: ShowInfo?
    public var followed: Bool
    public var archived: Bool
    /// Your own 1–10 score.
    public var rating: Int?
    public var seasons: [SeasonBlock]

    public var displayTitle: String { title ?? "Untitled" }
    public var isEnded: Bool { ShowStatus.isEnded(status) }
    public var genreList: [String] {
        (genres ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, poster, backdrop, year, status, genres, info, followed, archived, rating, seasons
        case avgRuntime = "avg_runtime"
    }
}

public struct ShowInfo: Codable, Sendable, Equatable {
    public var overview: String?
    public var tagline: String?
    /// TMDB's own score, used only when IMDb has nothing.
    public var vote: Double?
    public var votes: Int?
    public var firstAir: String?
    public var lastAir: String?
    public var networks: [String]?
    public var createdBy: [String]?
    public var contentRating: String?
    public var imdbID: String?
    public var origin: String?
    public var language: String?
    public var seasonCount: Int?
    public var episodeCount: Int?
    public var cast: [CastMember]?
    /// Season number → a real name, when the season has one beyond "Season 3".
    public var seasonNames: [String: String]?
    /// Season number → poster URL.
    public var seasonPosters: [String: String]?
    public var imdb: IMDbRating?

    public func seasonName(_ season: Int) -> String {
        if let name = seasonNames?[String(season)], !name.isEmpty { return name }
        return season == 0 ? "Specials" : "Season \(season)"
    }

    enum CodingKeys: String, CodingKey {
        case overview, tagline, vote, votes, networks, origin, language, cast, imdb
        case firstAir = "first_air"
        case lastAir = "last_air"
        case createdBy = "created_by"
        case contentRating = "content_rating"
        case imdbID = "imdb_id"
        case seasonCount = "n_seasons"
        case episodeCount = "n_episodes"
        case seasonNames = "season_names"
        case seasonPosters = "season_posters"
    }
}

/// IMDb's non-commercial dataset rating, with the vote count that gives it weight —
/// a 500k-vote 9.9 reads differently from a 40-vote 9.9, and the UI says so.
public struct IMDbRating: Codable, Sendable, Hashable {
    public var rating: Double?
    public var votes: Int?
    public var id: String?
}

public struct CastMember: Codable, Sendable, Hashable, Identifiable {
    public var id: Int?
    public var name: String
    public var character: String?
    public var img: String?
}

public struct SeasonBlock: Codable, Sendable, Identifiable, Hashable {
    public var season: Int
    public var episodes: [EpisodeRow]
    public var id: Int { season }

    public var watchedCount: Int { episodes.count(where: \.watched) }
    public var isComplete: Bool { !episodes.isEmpty && watchedCount == episodes.count }
}

public struct EpisodeRow: Codable, Sendable, Hashable, Identifiable {
    public var season: Int
    public var number: Int
    public var title: String?
    public var airDate: String?
    public var runtime: Int?
    public var still: String?
    /// A placeholder episode TMDB doesn't have — a fan edit, a gap in the catalogue.
    public var custom: Bool?
    public var watched: Bool
    public var watchedAt: String?

    public var id: String { "\(season):\(number)" }
    public var code: String { "S\(season) · E\(number)" }
    public var displayTitle: String { title?.isEmpty == false ? title! : "Episode \(number)" }
    /// Has it aired? An episode with no date hasn't.
    public func hasAired(asOf today: String) -> Bool {
        guard let airDate, !airDate.isEmpty else { return false }
        return airDate <= today
    }

    enum CodingKeys: String, CodingKey {
        case season, number, title, runtime, still, custom, watched
        case airDate = "air_date"
        case watchedAt = "watched_at"
    }
}

// MARK: - Marking

/// What every mark/unmark endpoint returns: the patched card, plus any celebration
/// the mark just earned. Catching `celebrate` centrally is what makes the fanfare
/// fire from the punch button, "mark all", and the season toggle alike.
public struct MarkResponse: Codable, Sendable, Equatable {
    public var ok: Bool?
    public var show: ShowCard?
    public var celebrate: [Celebration]?
}

public struct MarkEpisodeRequest: Codable, Sendable, Equatable {
    public var season: Int
    public var number: Int
    public var unwatch: Bool?
    /// Also mark everything that aired before this one.
    public var previous: Bool?
    /// Change the watch date without toggling.
    public var setDate: String?

    public init(season: Int, number: Int, unwatch: Bool? = nil,
                previous: Bool? = nil, setDate: String? = nil) {
        self.season = season
        self.number = number
        self.unwatch = unwatch
        self.previous = previous
        self.setDate = setDate
    }

    enum CodingKeys: String, CodingKey {
        case season, number, unwatch, previous
        case setDate = "set_date"
    }
}

public struct MarkSeasonRequest: Codable, Sendable, Equatable {
    public var unwatch: Bool?
    public init(unwatch: Bool? = nil) { self.unwatch = unwatch }
}

public struct FollowRequest: Codable, Sendable, Equatable {
    public var unfollow: Bool?
    public var archived: Bool?
    public var rating: Int?
    public init(unfollow: Bool? = nil, archived: Bool? = nil, rating: Int? = nil) {
        self.unfollow = unfollow
        self.archived = archived
        self.rating = rating
    }
}

// MARK: - Episode detail

/// `GET /api/show/{id}/episode/{season}/{number}`
public struct EpisodeDetail: Codable, Sendable, Equatable {
    public var showID: Int
    public var season: Int
    public var number: Int
    public var title: String?
    public var airDate: String?
    public var runtime: Int?
    public var overview: String?
    public var still: String?
    /// TMDB's score for this episode.
    public var rating: Double?
    public var imdbRating: Double?
    public var imdbVotes: Int?
    public var showTitle: String?
    public var showPoster: String?
    public var showBackdrop: String?
    public var seasonPoster: String?
    public var watched: Bool
    public var watchedAt: String?
    public var prev: EpisodeRef?
    public var next: EpisodeRef?
    /// How many earlier aired episodes are still unmarked — drives the "you're ahead"
    /// prompt rather than silently marking a jump.
    public var earlierUnwatched: Int?
    public var extra: EpisodeExtra?

    public var code: String { "S\(season) · E\(number)" }
    public var displayTitle: String { title?.isEmpty == false ? title! : "Episode \(number)" }
    /// Reviews on an episode key off a packed id — the same one the server uses.
    public var reviewKey: Int { showID * 1_000_000 + season * 1_000 + number }
    public var imdb: IMDbRating? {
        imdbRating.map { IMDbRating(rating: $0, votes: imdbVotes, id: nil) }
    }

    enum CodingKeys: String, CodingKey {
        case season, number, title, runtime, overview, still, rating, watched, prev, next, extra
        case showID = "show_id"
        case airDate = "air_date"
        case imdbRating = "imdb_rating"
        case imdbVotes = "imdb_votes"
        case showTitle = "show_title"
        case showPoster = "show_poster"
        case showBackdrop = "show_backdrop"
        case seasonPoster = "season_poster"
        case watchedAt = "watched_at"
        case earlierUnwatched = "earlier_unwatched"
    }
}

public struct EpisodeRef: Codable, Sendable, Hashable {
    public var season: Int
    public var number: Int
}

public struct EpisodeExtra: Codable, Sendable, Equatable {
    public var vote: Double?
    public var votes: Int?
    public var directors: [String]?
    public var writers: [String]?
    public var guests: [CastMember]?
}

// MARK: - Ratings panel

/// `GET /api/show/{id}/ratings` — per-episode points and per-season averages. Two
/// sources live side by side and the UI is expected to show which is which rather
/// than silently mixing them.
public struct ShowRatings: Codable, Sendable, Equatable {
    public var episodes: [RatedEpisode]
    public var seasonAvg: [SeasonAverage]
    /// "imdb" when most episodes came from the dataset, else "tmdb".
    public var source: String?
    public var imdbCount: Int?
    public var count: Int?

    public var isMixed: Bool {
        guard let imdbCount, let count else { return false }
        return imdbCount > 0 && imdbCount < count
    }

    enum CodingKeys: String, CodingKey {
        case episodes, source, count
        case seasonAvg = "season_avg"
        case imdbCount = "imdb_count"
    }
}

public struct RatedEpisode: Codable, Sendable, Hashable, Identifiable {
    public var season: Int
    public var number: Int
    public var title: String?
    public var rating: Double
    /// "imdb" or "tmdb" — drawn as a filled or hollow point.
    public var src: String
    public var votes: Int?
    public var tmdbRating: Double?

    public var id: String { "\(season):\(number)" }
    public var isIMDb: Bool { src == "imdb" }

    enum CodingKeys: String, CodingKey {
        case season, number, title, rating, src, votes
        case tmdbRating = "tmdb_rating"
    }
}

public struct SeasonAverage: Codable, Sendable, Hashable, Identifiable {
    public var season: Int
    public var avg: Double
    public var count: Int
    public var src: String?
    public var id: Int { season }
    public var isIMDb: Bool { src == "imdb" }
}

// MARK: - Custom episodes

public struct CustomEpisodesRequest: Codable, Sendable, Equatable {
    public var season: Int
    public var count: Int
    public var titles: String
    public var airDate: String

    public init(season: Int, count: Int, titles: String, airDate: String) {
        self.season = season
        self.count = count
        self.titles = titles
        self.airDate = airDate
    }

    enum CodingKeys: String, CodingKey {
        case season, count, titles
        case airDate = "air_date"
    }
}

public struct CustomEpisodesResponse: Codable, Sendable, Equatable {
    public var ok: Bool?
    public var added: Int
    public var season: Int
}

public struct DeleteCustomEpisode: Codable, Sendable, Equatable {
    public var season: Int
    public var number: Int
    public init(season: Int, number: Int) {
        self.season = season
        self.number = number
    }
}
