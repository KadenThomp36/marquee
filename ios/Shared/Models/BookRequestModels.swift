import Foundation

// MARK: - Book requests (Shelfmark)
//
// The server finds an ebook through Shelfmark, downloads it and drops it into the
// household's Calibre library. Every field here is optional beyond the id, so an
// older or newer server decodes without turning a screen into an error.

/// `GET /api/book-requests/config`
public struct BookRequestConfig: Codable, Sendable, Equatable {
    public var enabled: Bool?
    public var isEnabled: Bool { enabled == true }
}

/// Where a request is. The server's background loop only acts on the first three.
public enum BookRequestPhase: String, Sendable {
    case finding, downloading, importing, done, pick, failed, cancelled, unknown

    /// Still moving on its own — worth polling.
    public var isActive: Bool { self == .finding || self == .downloading || self == .importing }
    /// Something a person can still call off.
    public var isCancellable: Bool { isActive || self == .pick }
}

/// A size as Prowlarr reports it: bytes as a number, or already formatted text.
public struct ReleaseSize: Codable, Sendable, Hashable {
    public let text: String?

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            text = nil
        } else if let bytes = try? container.decode(Double.self) {
            text = bytes > 0 ? ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file) : nil
        } else if let string = try? container.decode(String.self) {
            text = string.isEmpty ? nil : string
        } else {
            text = nil
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try text.map { try container.encode($0) } ?? container.encodeNil()
    }
}

/// An id that is a string to the server but may arrive as a number.
public struct LooseID: Codable, Sendable, Hashable {
    public let value: String

    public init(_ value: String) { self.value = value }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) { value = string }
        else if let int = try? container.decode(Int.self) { value = String(int) }
        else if let double = try? container.decode(Double.self) { value = String(double) }
        else { value = "" }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// The copy being downloaded, or the one that made it.
public struct BookRequestCopy: Codable, Sendable, Hashable {
    public var title: String?
    public var size: ReleaseSize?
    public var format: String?
    public var seeders: FlexInt?

    /// "EPUB · 1.2 MB · 14 seeders"
    public var summary: String {
        var parts: [String] = []
        if let format, !format.isEmpty { parts.append(format.uppercased()) }
        if let size = size?.text { parts.append(size) }
        if let seeders = seeders?.value { parts.append("\(seeders) seeder\(seeders == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }
}

/// One copy the indexers found, offered when a person has to choose.
public struct BookRequestChoice: Codable, Sendable, Hashable, Identifiable {
    public var sourceID: LooseID
    public var title: String?
    public var size: ReleaseSize?
    public var format: String?
    public var seeders: FlexInt?
    public var indexer: String?
    public var score: FlexDouble?
    public var tried: Bool?
    public var recommended: Bool?

    public var id: String { sourceID.value }
    public var wasTried: Bool { tried == true }
    public var isRecommended: Bool { recommended == true }

    public var summary: String {
        BookRequestCopy(title: title, size: size, format: format, seeders: seeders).summary
    }

    enum CodingKeys: String, CodingKey {
        case title, size, format, seeders, indexer, score, tried, recommended
        case sourceID = "source_id"
    }
}

/// One request, as every endpoint returns it.
public struct BookRequest: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var userID: Int?
    public var bookID: Int?
    public var providerID: String?
    public var title: String?
    public var author: String?
    public var year: FlexInt?
    public var cover: String?
    public var state: String?
    public var message: String?
    /// 0–100, and only ever moves forward.
    public var progress: FlexDouble?
    public var attempts: Int?
    public var requestedBy: String?
    public var mine: Bool?
    public var copy: BookRequestCopy?
    public var createdAt: String?
    public var updatedAt: String?
    public var finishedAt: String?
    /// Set on create: somebody had already asked for it, and this is that request.
    public var already: Bool?
    /// `GET /api/book-requests/{id}` only.
    public var choices: [BookRequestChoice]?

    public var phase: BookRequestPhase { BookRequestPhase(rawValue: state ?? "") ?? .unknown }
    public var isMine: Bool { mine == true }
    public var displayTitle: String { title ?? "Untitled" }
    public var fraction: Double { min(max((progress?.value ?? 0) / 100, 0), 1) }
    public var percent: Int { Int((progress?.value ?? 0).rounded()) }

    enum CodingKeys: String, CodingKey {
        case id, title, author, year, cover, state, message, progress, attempts, mine, copy
        case already, choices
        case userID = "user_id"
        case bookID = "book_id"
        case providerID = "provider_id"
        case requestedBy = "requested_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case finishedAt = "finished_at"
    }
}

/// `GET /api/book-requests` and `GET /api/book-requests?book_id=`
public struct BookRequestList: Codable, Sendable, Equatable {
    public var enabled: Bool?
    public var requests: [BookRequest]?
}

/// The request a search result already has, if any.
public struct BookRequestRef: Codable, Sendable, Hashable {
    public var id: Int
    public var state: String?
    public var phase: BookRequestPhase { BookRequestPhase(rawValue: state ?? "") ?? .unknown }
}

/// One title from Shelfmark's metadata search (Open Library).
public struct ShelfmarkBook: Codable, Sendable, Hashable, Identifiable {
    public var provider: String?
    public var providerID: String
    public var title: String?
    public var authors: [String]?
    public var year: FlexInt?
    /// An absolute https URL, or nil.
    public var cover: String?
    public var request: BookRequestRef?

    public var id: String { "\(provider ?? "")/\(providerID)" }
    public var displayTitle: String { title ?? "Untitled" }
    public var authorLine: String { (authors ?? []).joined(separator: ", ") }

    enum CodingKeys: String, CodingKey {
        case provider, title, authors, year, cover, request
        case providerID = "provider_id"
    }
}

/// `GET /api/book-requests/search?q=`
public struct ShelfmarkSearchResponse: Codable, Sendable, Equatable {
    public var results: [ShelfmarkBook]?
    /// True when the downloader didn't answer — not the same as "nothing found".
    public var unavailable: Bool?
}

/// `POST /api/book-requests` — either a Marquee book id (the server finds the
/// edition) or a search result, passed back as it came.
public struct CreateBookRequest: Codable, Sendable, Equatable {
    public var bookID: Int?
    public var provider: String?
    public var providerID: String?
    public var title: String?
    public var authors: [String]?
    public var year: Int?
    public var cover: String?

    public init(bookID: Int) { self.bookID = bookID }

    public init(_ book: ShelfmarkBook) {
        provider = book.provider
        providerID = book.providerID
        title = book.title
        authors = book.authors
        year = book.year?.value
        cover = book.cover
    }

    enum CodingKeys: String, CodingKey {
        case provider, title, authors, year, cover
        case bookID = "book_id"
        case providerID = "provider_id"
    }
}

/// `POST /api/book-requests/{id}/pick`
public struct PickBookCopy: Codable, Sendable, Equatable {
    public var sourceID: String
    public init(sourceID: String) { self.sourceID = sourceID }
    enum CodingKeys: String, CodingKey { case sourceID = "source_id" }
}
