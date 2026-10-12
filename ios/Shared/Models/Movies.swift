import Foundation

/// `GET /api/movies` — the two shelves, watched and watchlist.
public struct MovieShelves: Codable, Sendable, Equatable {
    public var watched: [MovieCard]
    public var watchlist: [MovieCard]
}

public struct MovieCard: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var releaseDate: String?
    public var runtime: Int?
    public var genres: String?
    /// "watched" or "watchlist".
    public var state: String?
    public var watchedAt: String?
    /// Your own 1–10 score.
    public var rating: Int?

    public var displayTitle: String { title ?? "Untitled" }
    public var isWatched: Bool { state == "watched" }

    enum CodingKeys: String, CodingKey {
        case id, title, poster, year, runtime, genres, state, rating
        case releaseDate = "release_date"
        case watchedAt = "watched_at"
    }
}

/// `GET /api/movie/{id}`
public struct MovieDetail: Codable, Sendable, Equatable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var year: FlexInt?
    public var releaseDate: String?
    public var runtime: Int?
    public var genres: String?
    public var info: MovieInfo?
    /// "watched", "watchlist", or nil.
    public var state: String?
    public var myRating: Int?

    public var displayTitle: String { title ?? "Untitled" }
    public var isWatched: Bool { state == "watched" }

    enum CodingKeys: String, CodingKey {
        case id, title, poster, year, runtime, genres, info, state
        case releaseDate = "release_date"
        case myRating = "my_rating"
    }
}

public struct MovieInfo: Codable, Sendable, Equatable {
    public var overview: String?
    public var tagline: String?
    public var vote: Double?
    public var votes: Int?
    public var backdrop: String?
    public var runtime: Int?
    public var genres: [String]?
    public var contentRating: String?
    public var imdbID: String?
    public var directors: [String]?
    public var cast: [CastMember]?
    public var imdb: IMDbRating?

    enum CodingKeys: String, CodingKey {
        case overview, tagline, vote, votes, backdrop, runtime, genres, directors, cast, imdb
        case contentRating = "content_rating"
        case imdbID = "imdb_id"
    }
}

public struct MovieStateRequest: Codable, Sendable, Equatable {
    /// "watched", "watchlist" or "none".
    public var state: String
    public var rating: Int?
    public init(state: String, rating: Int? = nil) {
        self.state = state
        self.rating = rating
    }
}

/// `POST /api/add` — follow a show or shelve a film straight from a search tile.
public struct AddRequest: Codable, Sendable, Equatable {
    public var type: String
    public var id: Int
    public var state: String?
    public init(type: String, id: Int, state: String? = nil) {
        self.type = type
        self.id = id
        self.state = state
    }
}
