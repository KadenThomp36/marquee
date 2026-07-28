import Foundation

// MARK: - Lenient scalars
//
// The API is hand-written literals, not a generated schema, so the same idea is
// sometimes an Int and sometimes a String — `year` is `2019` from /show/{id} and
// `"2019"` from /search (it's a slice of an air date there). These decode either
// without turning a whole screen into an error.

/// An integer that may arrive as a number, a numeric string, or nothing at all.
public struct FlexInt: Codable, Sendable, Hashable, ExpressibleByIntegerLiteral {
    public let value: Int?
    public init(_ value: Int?) { self.value = value }
    public init(integerLiteral value: Int) { self.value = value }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = nil }
        else if let int = try? container.decode(Int.self) { value = int }
        else if let double = try? container.decode(Double.self) { value = Int(double) }
        else if let string = try? container.decode(String.self) { value = Int(string.prefix(8)) }
        else { value = nil }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try value.map { try container.encode($0) } ?? container.encodeNil()
    }
}

public extension FlexInt {
    var orZero: Int { value ?? 0 }
    var text: String { value.map(String.init) ?? "" }
}

/// A double that may arrive as a number or a numeric string.
public struct FlexDouble: Codable, Sendable, Hashable {
    public let value: Double?
    public init(_ value: Double?) { self.value = value }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = nil }
        else if let double = try? container.decode(Double.self) { value = double }
        else if let string = try? container.decode(String.self) { value = Double(string) }
        else { value = nil }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try value.map { try container.encode($0) } ?? container.encodeNil()
    }
}

// MARK: - People

public struct UserFeatures: Codable, Sendable, Hashable {
    public var books: Int?
    public var manga: Int?
    public var tracksBooks: Bool { (books ?? 0) != 0 }
    public var tracksManga: Bool { (manga ?? 0) != 0 }
    /// Reading is opt-in per user; the whole destination stays hidden until it's on.
    public var tracksReading: Bool { tracksBooks || tracksManga }
    public init(books: Int? = nil, manga: Int? = nil) {
        self.books = books
        self.manga = manga
    }
}

/// The public face of an account — what other household members can see.
///
/// `username` is optional because the dashboard's bylines aren't full accounts: the
/// household feed and the review teasers send only a display name and an avatar, which
/// is all a byline needs.
public struct Person: Codable, Sendable, Hashable, Identifiable {
    public var id: Int?
    public var username: String?
    public var displayName: String?
    public var avatar: String?
    public var banner: String?
    public var features: UserFeatures?
    public var isAdmin: Bool?
    public var isMe: Bool?

    public var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        if let username, !username.isEmpty { return username }
        return "Someone"
    }
    /// First name only, for greetings.
    public var shortName: String { name.split(separator: " ").first.map(String.init) ?? name }
    /// Deterministic hue for the fallback monogram, matching the web client's rule.
    public var monogramHue: Double {
        Double(name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 360)
    }
    public var monogram: String {
        String(name.trimmingCharacters(in: .whitespaces).first.map(String.init)?.uppercased() ?? "?")
    }

    enum CodingKeys: String, CodingKey {
        case id, username, avatar, banner, features
        case displayName = "display_name"
        case isAdmin = "is_admin"
        case isMe = "is_me"
    }
}

/// `GET /api/me`
public struct MeResponse: Codable, Sendable, Equatable {
    public var id: Int?
    public var username: String
    public var displayName: String?
    public var avatar: String?
    public var banner: String?
    public var features: UserFeatures?
    public var isAdmin: Bool?

    public var person: Person {
        Person(id: id, username: username, displayName: displayName, avatar: avatar,
               banner: banner, features: features, isAdmin: isAdmin, isMe: true)
    }

    enum CodingKeys: String, CodingKey {
        case id, username, avatar, banner, features
        case displayName = "display_name"
        case isAdmin = "is_admin"
    }
}

/// `POST /api/login` and `POST /api/pair/claim`
public struct AuthResponse: Codable, Sendable, Equatable {
    public var token: String?
    public var username: String?
    public var isAdmin: Bool?
    public var user: MeResponse?

    enum CodingKeys: String, CodingKey {
        case token, username, user
        case isAdmin = "is_admin"
    }
}

public struct BuildResponse: Codable, Sendable, Equatable {
    public var build: String
}

public struct SignupOpen: Codable, Sendable, Equatable {
    public var open: Bool
}

/// `POST /api/pair/start`
public struct PairCode: Codable, Sendable, Equatable {
    public var code: String
    public var expiresAt: String?
    public var expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case code
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
    }
}

/// `GET /api/sessions` — the devices signed in as you.
public struct DeviceSession: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var deviceName: String
    public var createdAt: String?
    public var lastSeen: String?
    public var current: Bool

    enum CodingKeys: String, CodingKey {
        case id, current
        case deviceName = "device_name"
        case createdAt = "created_at"
        case lastSeen = "last_seen"
    }
}

public struct DeviceSessions: Codable, Sendable, Equatable {
    public var sessions: [DeviceSession]
    /// How many sessions exist in total. The server sends only the most recently
    /// used ones — an account that has been signing in for years has far more rows
    /// than anyone wants to scroll.
    public var total: Int?

    /// Sessions the server held back.
    public var hidden: Int { max(0, (total ?? sessions.count) - sessions.count) }
}

public struct MembersResponse: Codable, Sendable, Equatable {
    public var members: [Person]
}
