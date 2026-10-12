import Foundation

// MARK: - Household reviews

/// `GET /api/reviews/{type}/{id}` — the house's own reviews, with threaded replies.
public struct ReviewsResponse: Codable, Sendable, Equatable {
    public var reviews: [Review]
}

public struct Review: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var rating: Int?
    public var body: String?
    public var createdAt: String?
    public var updatedAt: String?
    /// Yours — editable, and never hidden behind a spoiler curtain.
    public var mine: Bool
    public var author: Person
    public var replies: [ReviewReply]?

    enum CodingKeys: String, CodingKey {
        case id, rating, body, mine, author, replies
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct ReviewReply: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var body: String
    public var createdAt: String?
    public var mine: Bool
    public var author: Person

    enum CodingKeys: String, CodingKey {
        case id, body, mine, author
        case createdAt = "created_at"
    }
}

public struct PostReviewRequest: Codable, Sendable, Equatable {
    public var rating: Int?
    public var body: String
    public init(rating: Int?, body: String) {
        self.rating = rating
        self.body = body
    }
}

public struct PostReplyRequest: Codable, Sendable, Equatable {
    public var body: String
    public init(body: String) { self.body = body }
}

// MARK: - Reviews from outside the house

/// `GET /api/external_reviews/{type}/{id}` — Trakt, TMDB and MyAnimeList, sorted by
/// how many people found them useful.
public struct ExternalReviewsResponse: Codable, Sendable, Equatable {
    public var reviews: [ExternalReview]
}

public struct ExternalReview: Codable, Sendable, Identifiable, Hashable {
    /// "Trakt", "TMDB", "MyAnimeList".
    public var source: String
    public var author: String?
    public var rating: Int?
    public var likes: Int?
    public var body: String
    public var date: String?

    public var id: String { "\(source):\(author ?? "?"):\(body.prefix(24))" }
}

// MARK: - Notifications

/// `GET /api/notifications`
public struct NotificationsResponse: Codable, Sendable, Equatable {
    public var unread: Int
    public var items: [AppNotification]
}

public struct AppNotification: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    /// reply · comment · airing · new_season · available · plex
    public var type: String
    public var title: String
    public var body: String?
    /// A hash-route fragment from the web client, e.g. `show/1396/e/5/14`.
    public var link: String?
    public var createdAt: String?
    public var read: Bool

    enum CodingKeys: String, CodingKey {
        case id, type, title, body, link, read
        case createdAt = "created_at"
    }
}

/// `GET /api/notifications/prefs` — everything defaults to off; the server owns the
/// labels and help text so both clients say the same thing.
public struct NotificationPrefsResponse: Codable, Sendable, Equatable {
    public var prefs: [NotificationPref]
}

public struct NotificationPref: Codable, Sendable, Identifiable, Hashable {
    public var type: String
    public var label: String
    public var help: String
    /// Only "airing" carries lead-time options.
    public var hasDays: Bool
    public var enabled: Bool
    /// Comma-separated lead times in days for "airing"; 0 means "when it airs".
    public var value: String?

    public var id: String { type }
    public var leadDays: Set<String> {
        Set((value ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    enum CodingKeys: String, CodingKey {
        case type, label, help, enabled, value
        case hasDays = "has_days"
    }
}

public struct SetNotificationPref: Codable, Sendable, Equatable {
    public var type: String
    public var enabled: Bool
    public var value: String?
    public init(type: String, enabled: Bool, value: String?) {
        self.type = type
        self.enabled = enabled
        self.value = value
    }
}

public struct MarkNotificationsRead: Codable, Sendable, Equatable {
    public var id: Int?
    public init(id: Int? = nil) { self.id = id }
}

// MARK: - Celebrations

/// A season or a whole series finished. Recorded server-side, so one that happened
/// while the app was closed still gets its moment on next launch.
public struct Celebration: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    /// "season" or "show".
    public var kind: String
    public var season: Int
    public var seasonName: String?
    public var episodes: Int
    public var minutes: Int
    /// Days between the first and last episode of the run, when both are known.
    public var days: Int?
    public var seasons: Int
    public var firstWatched: String?
    public var lastWatched: String?
    /// "your 12th season finished in 2026".
    public var nthThisYear: Int
    public var year: Int
    public var show: CelebrationShow

    public var isSeries: Bool { kind == "show" }

    enum CodingKeys: String, CodingKey {
        case id, kind, season, episodes, minutes, days, seasons, year, show
        case seasonName = "season_name"
        case firstWatched = "first_watched"
        case lastWatched = "last_watched"
        case nthThisYear = "nth_this_year"
    }
}

public struct CelebrationShow: Codable, Sendable, Hashable {
    public var id: Int
    public var title: String?
    public var poster: String?
    public var backdrop: String?
    public var year: FlexInt?
    public var status: String?

    public var displayTitle: String { title ?? "Untitled" }
}

public struct CelebrationsResponse: Codable, Sendable, Equatable {
    public var celebrations: [Celebration]
}
