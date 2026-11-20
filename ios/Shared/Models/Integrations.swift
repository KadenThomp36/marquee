import Foundation

// MARK: - Overseerr

/// `GET /api/request/config` — whether the household has Overseerr wired up at all.
public struct RequestConfig: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var url: String?
}

/// `GET /api/overseerr/me` — Overseerr attributes requests by Plex identity, so this
/// is really "is your Plex account known to the request server".
public struct OverseerrAccount: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var linked: Bool?
    public var account: String?
    public var reason: String?
}

public enum RequestState: String, Sendable {
    case none
    case pending
    case processing
    case partial
    case downloading
    case available
    case unknown

    public var label: String {
        switch self {
        case .none: "Not on server"
        case .pending: "Requested"
        case .processing: "Processing"
        case .partial: "Partial"
        case .downloading: "Downloading"
        case .available: "On Plex"
        case .unknown: "Unknown"
        }
    }

    /// Anything already asked for — the button becomes "Manage request".
    public var isRequested: Bool {
        self == .pending || self == .processing || self == .partial || self == .downloading
    }
}

/// `GET /api/request/status/{type}/{id}`
public struct RequestStatus: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var status: String?
    public var download: DownloadProgress?
    /// Shows only.
    public var seasons: [SeasonRequestState]?

    public var state: RequestState { RequestState(rawValue: status ?? "none") ?? .unknown }

    /// True while something is genuinely in flight — the only time it's worth polling.
    public var isBusy: Bool {
        download != nil
            || (seasons ?? []).contains { $0.state == .downloading }
            || state == .pending || state == .processing
    }
}

public struct DownloadProgress: Codable, Sendable, Hashable {
    /// How many grabs are running.
    public var active: Int
    /// 0–100, averaged across them.
    public var progress: Int
    /// Sonarr/Radarr's own estimate, e.g. "00:04:12".
    public var eta: String?

    public var fraction: Double { Double(min(max(progress, 0), 100)) / 100 }
}

public struct SeasonRequestState: Codable, Sendable, Hashable, Identifiable {
    public var number: Int
    public var episodes: Int
    public var status: String
    public var progress: Int?
    public var eta: String?

    public var id: Int { number }
    public var state: RequestState { RequestState(rawValue: status) ?? .unknown }
    /// Only a season that's on nobody's list yet can be selected to request.
    public var isSelectable: Bool { state == .none }
}

public struct MakeRequest: Codable, Sendable, Equatable {
    public var itemType: String
    public var itemID: Int
    /// Season numbers, or nil for a film.
    public var seasons: [Int]?

    public init(itemType: String, itemID: Int, seasons: [Int]? = nil) {
        self.itemType = itemType
        self.itemID = itemID
        self.seasons = seasons
    }

    enum CodingKeys: String, CodingKey {
        case seasons
        case itemType = "item_type"
        case itemID = "item_id"
    }
}

public struct RequestResult: Codable, Sendable, Equatable {
    public var ok: Bool?
    public var status: String?
}

/// `GET /api/request/detail/{movie|show}/{tmdb_id}`: everything behind a request
/// pill. Who asked and when, what's downloading, and what's on Plex now. Every
/// field is optional so an older server, or one without Overseerr, decodes cleanly.
public struct RequestDetail: Codable, Sendable, Equatable {
    public var enabled: Bool?
    /// Overseerr is configured but didn't answer.
    public var unavailable: Bool?
    public var status: String?
    public var requests: [OverseerrRequest]?
    public var downloads: [RequestDownload]?
    public var file: PlexFile?

    public init(enabled: Bool? = true, unavailable: Bool? = nil, status: String? = nil,
                requests: [OverseerrRequest]? = nil, downloads: [RequestDownload]? = nil,
                file: PlexFile? = nil) {
        self.enabled = enabled
        self.unavailable = unavailable
        self.status = status
        self.requests = requests
        self.downloads = downloads
        self.file = file
    }

    public var isEmpty: Bool {
        (requests ?? []).isEmpty && (downloads ?? []).isEmpty && file == nil
    }
}

/// One request in Overseerr.
public struct OverseerrRequest: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    /// Already in words: "Waiting for approval", "Approved", "Declined".
    public var status: String?
    public var requestedBy: String?
    /// ISO 8601 in UTC, the way Overseerr writes it. Not a Marquee stamp.
    public var createdAt: String?
    public var is4k: Bool?
    public var seasons: [Int]?
    public var mine: Bool?
    public var canDelete: Bool?

    public init(id: Int, status: String?, requestedBy: String?, createdAt: String?,
                is4k: Bool? = false, seasons: [Int]? = nil, mine: Bool? = false, canDelete: Bool? = false) {
        self.id = id
        self.status = status
        self.requestedBy = requestedBy
        self.createdAt = createdAt
        self.is4k = is4k
        self.seasons = seasons
        self.mine = mine
        self.canDelete = canDelete
    }

    enum CodingKeys: String, CodingKey {
        case id, status, seasons, mine
        case is4k
        case requestedBy = "requested_by"
        case createdAt = "created_at"
        case canDelete = "can_delete"
    }
}

/// One grab in Sonarr or Radarr.
public struct RequestDownload: Codable, Sendable, Hashable {
    /// The release name, which is where the quality shows: "…1080p.WEB-DL…".
    public var title: String?
    public var status: String?
    /// Already formatted: "4.2 GB".
    public var size: String?
    /// 0–100, or nil when it can't be measured yet.
    public var progress: Int?
    /// Sonarr/Radarr's `HH:MM:SS`.
    public var eta: String?
    public var season: Int?
    public var episode: Int?

    public init(title: String?, status: String?, size: String?, progress: Int?, eta: String?,
                season: Int? = nil, episode: Int? = nil) {
        self.title = title
        self.status = status
        self.size = size
        self.progress = progress
        self.eta = eta
        self.season = season
        self.episode = episode
    }
}

/// What's on Plex. A film reports its best copy. A show reports the most common
/// resolution across its episodes and the total size.
public struct PlexFile: Codable, Sendable, Hashable {
    public var resolution: String?
    public var video: String?
    public var audio: String?
    public var hdr: String?
    public var container: String?
    public var size: String?
    public var bitrate: String?
    public var copies: Int?
    /// Shows: the episodes aren't all the same resolution.
    public var mixed: Bool?
    public var episodes: Int?

    public init(resolution: String? = nil, video: String? = nil, audio: String? = nil,
                hdr: String? = nil, container: String? = nil, size: String? = nil,
                bitrate: String? = nil, copies: Int? = nil, mixed: Bool? = nil, episodes: Int? = nil) {
        self.resolution = resolution
        self.video = video
        self.audio = audio
        self.hdr = hdr
        self.container = container
        self.size = size
        self.bitrate = bitrate
        self.copies = copies
        self.mixed = mixed
        self.episodes = episodes
    }
}

// MARK: - Plex

/// `GET /api/plex/status`
public struct PlexStatus: Codable, Sendable, Equatable {
    public var plexUsername: String?
    /// This user has their own token, which is what enables direct history polling.
    public var hasOwnToken: Bool?
    public var directSync: Bool?
    public var lastEvent: String?
    public var lastEventUser: String?
    public var lastPoll: String?

    public var isLinked: Bool { plexUsername?.isEmpty == false }

    enum CodingKeys: String, CodingKey {
        case plexUsername = "plex_username"
        case hasOwnToken = "has_own_token"
        case directSync = "direct_sync"
        case lastEvent = "last_event"
        case lastEventUser = "last_event_user"
        case lastPoll = "last_poll"
    }
}

/// `POST /api/plex/pin` — the four-character code you approve on plex.tv.
public struct PlexPin: Codable, Sendable, Equatable {
    public var id: Int
    public var code: String
    public var url: String
}

public struct PlexPinPoll: Codable, Sendable, Equatable {
    public var linked: Bool
    public var username: String?
    public var thumb: String?
    public var email: String?
}

// MARK: - IMDb

/// `GET /api/imdb/status` — the daily dataset pull, in numbers.
public struct IMDbStatus: Codable, Sendable, Equatable {
    public var last: String?
    public var running: Bool
    public var stats: IMDbSyncStats?
    public var episodes: Int?
    public var episodesRated: Int?

    enum CodingKeys: String, CodingKey {
        case last, running, stats, episodes
        case episodesRated = "episodes_rated"
    }
}

public struct IMDbSyncStats: Codable, Sendable, Equatable {
    public var episodes: Int?
    public var shows: Int?
    public var movies: Int?
    public var newIDs: Int?
    public var seconds: Double?

    enum CodingKeys: String, CodingKey {
        case episodes, shows, movies, seconds
        case newIDs = "new_ids"
    }
}

// MARK: - Imports

public struct ImportStatus: Codable, Sendable, Equatable {
    /// idle · running · done · failed
    public var state: String
    public var done: Int?
    public var total: Int?
    public var errors: [String]?

    public var isRunning: Bool { state == "running" }
    public var fraction: Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(done ?? 0) / Double(total))
    }
}

// MARK: - Household admin

public struct AdminUser: Codable, Sendable, Identifiable, Hashable {
    public var id: Int
    public var username: String
    public var displayName: String?
    public var avatar: String?
    public var isAdmin: Int?
    public var plexUsername: String?
    public var createdAt: String?

    public var person: Person {
        Person(id: id, username: username, displayName: displayName, avatar: avatar,
               banner: nil, features: nil, isAdmin: (isAdmin ?? 0) != 0, isMe: false)
    }

    enum CodingKeys: String, CodingKey {
        case id, username, avatar
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case plexUsername = "plex_username"
        case createdAt = "created_at"
    }
}

public struct RegistrationState: Codable, Sendable, Equatable {
    public var closed: Bool
}

public struct SetRegistration: Codable, Sendable, Equatable {
    public var closed: Bool
    public init(closed: Bool) { self.closed = closed }
}

public struct CreateUserRequest: Codable, Sendable, Equatable {
    public var username: String
    public var password: String
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}
