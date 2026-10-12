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

    // Library extras from newer servers — optional so older ones still decode.
    public var addedAt: String?
    public var imdb: Double?
    public var vote: Double?
    /// Content certification: "PG-13", "R".
    public var cert: String?
    public var prov: StreamingProvider?
    public var provKnown: Bool?
    public var household: [HouseholdFilm]?

    public var displayTitle: String { title ?? "Untitled" }
    public var isWatched: Bool { state == "watched" }

    /// Not out yet — the watchlist's "Coming soon" group.
    public func isUpcoming(today: String) -> Bool {
        guard let releaseDate, releaseDate.count >= 10 else { return false }
        return String(releaseDate.prefix(10)) > today
    }

    enum CodingKeys: String, CodingKey {
        case id, title, poster, year, runtime, genres, state, rating
        case imdb, vote, cert, prov, household
        case releaseDate = "release_date"
        case watchedAt = "watched_at"
        case addedAt = "added_at"
        case provKnown = "prov_known"
    }
}

/// A housemate's relationship with a film on one of your cards.
public struct HouseholdFilm: Codable, Sendable, Hashable, Identifiable {
    public var name: String?
    public var username: String?
    public var avatar: String?
    /// "watched" or "watchlist".
    public var state: String?
    public var rating: FlexInt?

    public var id: String { username ?? name ?? "?" }
    public var displayName: String { name ?? username ?? "Someone" }
    public var person: Person {
        Person(id: nil, username: username, displayName: name, avatar: avatar,
               banner: nil, features: nil, isAdmin: nil, isMe: false)
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
    /// Only sent by an undo, to put a removed film back exactly as it was.
    public var watchedAt: String?
    public var addedAt: String?

    public init(state: String, rating: Int? = nil,
                watchedAt: String? = nil, addedAt: String? = nil) {
        self.state = state
        self.rating = rating
        self.watchedAt = watchedAt
        self.addedAt = addedAt
    }

    enum CodingKeys: String, CodingKey {
        case state, rating
        case watchedAt = "watched_at"
        case addedAt = "added_at"
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
