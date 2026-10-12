import Foundation

// MARK: - Search & discover

/// `GET /api/search` — shows and films together, with enough state on each tile to
/// show whether you already follow or own it.
public struct SearchResponse: Codable, Sendable, Equatable {
    public var results: [SearchResult]
}

public struct SearchResult: Codable, Sendable, Hashable, Identifiable {
    /// "show" or "movie".
    public var type: String
    public var id: Int
    public var title: String?
    /// A four-character slice of the air date server-side, so it arrives as a string.
    public var year: FlexInt?
    public var poster: String?
    /// Shows only.
    public var followed: Bool?
    /// Films only: "watched" or "watchlist".
    public var state: String?
    /// Discover rails carry TMDB's score.
    public var vote: Double?

    public var isShow: Bool { type == "show" }
    public var displayTitle: String { title ?? "Untitled" }
    public var alreadyHave: Bool { followed == true || state != nil }

    public var stateLabel: String? {
        if followed == true { return "on watchlist" }
        return state
    }
}

/// `GET /api/discover` — trending, "because you watched X", acclaimed. Cached
/// server-side for six hours, so it's cheap to ask for on every visit.
public struct DiscoverResponse: Codable, Sendable, Equatable {
    public var sections: [DiscoverSection]
}

public struct DiscoverSection: Codable, Sendable, Identifiable, Hashable {
    public var title: String
    public var items: [SearchResult]
    public var id: String { title }
}

// MARK: - Artwork gallery

/// `GET /api/images/{type}/{id}` — every poster and backdrop TMDB has, English or
/// language-neutral first.
public struct ArtworkResponse: Codable, Sendable, Equatable {
    public var posters: [Artwork]
    public var backdrops: [Artwork]
    public var count: Int

    public var all: [Artwork] { posters + backdrops }
}

public struct Artwork: Codable, Sendable, Hashable, Identifiable {
    /// "poster" or "backdrop".
    public var kind: String
    public var thumb: String?
    public var full: String?
    public var w: Int?
    public var h: Int?
    public var lang: String?

    public var id: String { full ?? thumb ?? UUID().uuidString }
    public var isWide: Bool { kind == "backdrop" }
    public var aspect: CGFloat {
        guard let w, let h, h > 0 else { return isWide ? MQ.stillAspect : MQ.posterAspect }
        return CGFloat(w) / CGFloat(h)
    }
}

// MARK: - Where to watch

/// `GET /api/watch_providers/{type}/{id}` — US availability from JustWatch via TMDB.
public struct WatchProviders: Codable, Sendable, Equatable {
    public var region: String?
    public var link: String?
    /// Subscription, free and ad-supported tiers folded together — all watch-now.
    public var flatrate: [Provider]
    public var rent: [Provider]
    public var buy: [Provider]
    public var hasAny: Bool

    enum CodingKeys: String, CodingKey {
        case region, link, flatrate, rent, buy
        case hasAny = "has_any"
    }
}

public struct Provider: Codable, Sendable, Hashable, Identifiable {
    public var id: Int?
    public var name: String?
    public var logo: String?
}

// MARK: - People

/// `GET /api/person/{id}` — ranked by how widely seen each title is, so signature
/// roles lead rather than the most recent bit part.
public struct PersonDetail: Codable, Sendable, Equatable {
    public var id: Int
    public var name: String?
    public var bio: String?
    public var birthday: String?
    public var deathday: String?
    public var place: String?
    public var knownFor: String?
    public var img: String?
    public var imdbID: String?
    public var credits: [PersonCredit]

    enum CodingKeys: String, CodingKey {
        case id, name, bio, birthday, deathday, place, img, credits
        case knownFor = "known_for"
        case imdbID = "imdb_id"
    }
}

public struct PersonCredit: Codable, Sendable, Hashable, Identifiable {
    public var type: String
    public var id: Int
    public var title: String?
    public var year: FlexInt?
    public var poster: String?
    public var character: String?
    public var vote: Double?

    public var isShow: Bool { type == "show" }
    public var uniqueID: String { "\(type):\(id)" }
}
