import Foundation

public enum APIError: LocalizedError, Sendable, Equatable {
    /// The token was rejected — the session was revoked, or the server was rebuilt.
    case unauthorized
    /// Reached the host, but it doesn't look like a Marquee server.
    case notMarquee
    /// It *is* Marquee, but an older build without the app-pairing endpoints.
    case needsServerUpdate
    case http(status: Int, detail: String)
    case offline(String)
    case decoding(String)
    case badAddress

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Your session has expired. Sign in again."
        case .notMarquee: "That address answered, but it isn't a Marquee server."
        case .needsServerUpdate:
            "That Marquee server is running an older build that can't pair with the app yet. Update it (main.py and static/) and restart it, then try again."
        case .http(_, let detail): detail
        case .offline(let why): why
        case .decoding(let what): "The server sent something unexpected (\(what))."
        case .badAddress: "That doesn't look like a web address."
        }
    }

    /// True when retrying later could plausibly work — the offline queue only holds
    /// on to writes that failed for this kind of reason.
    public var isTransient: Bool {
        switch self {
        case .offline: true
        case .http(let status, _): status >= 500 || status == 429
        default: false
        }
    }
}

/// Thin, typed wrapper over the Marquee JSON API. One instance per paired server;
/// it holds the address and token and nothing else, so signing out is just dropping it.
public struct MarqueeClient: Sendable {

    public let server: PairedServer
    private let session: URLSession

    public init(server: PairedServer, session: URLSession = .marqueeShared) {
        self.server = server
        self.session = session
    }

    // MARK: - Requests

    public func get<T: Decodable & Sendable>(_ path: String,
                                             query: [String: String] = [:],
                                             as type: T.Type = T.self) async throws -> T {
        try await send(request(path, query: query), as: T.self)
    }

    @discardableResult
    public func post<T: Decodable & Sendable>(_ path: String,
                                              body: (any Encodable & Sendable)? = nil,
                                              as type: T.Type = T.self) async throws -> T {
        var req = request(path)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Several endpoints read the body unconditionally, so an empty POST still
        // has to carry `{}` rather than nothing at all.
        req.httpBody = try body.map { try JSONEncoder().encode(AnyEncodable($0)) } ?? Data("{}".utf8)
        return try await send(req, as: T.self)
    }

    @discardableResult
    public func delete<T: Decodable & Sendable>(_ path: String,
                                                as type: T.Type = T.self) async throws -> T {
        var req = request(path)
        req.httpMethod = "DELETE"
        return try await send(req, as: T.self)
    }

    /// Multipart upload — avatars, banners, TV Time and Goodreads imports.
    @discardableResult
    public func upload<T: Decodable & Sendable>(_ path: String,
                                                fileData: Data,
                                                filename: String,
                                                mimeType: String,
                                                as type: T.Type = T.self) async throws -> T {
        let boundary = "marquee.\(UUID().uuidString)"
        var req = request(path)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n")
        req.httpBody = body
        return try await send(req, as: T.self)
    }

    // MARK: - Plumbing

    private func request(_ path: String, query: [String: String] = [:]) -> URLRequest {
        var components = URLComponents(
            url: server.apiURL.appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path),
            resolvingAgainstBaseURL: false)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { $0.name < $1.name }
        }
        var req = URLRequest(url: components?.url ?? server.apiURL)
        req.setValue("Bearer \(server.token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 30
        return req
    }

    private func send<T: Decodable & Sendable>(_ req: URLRequest, as type: T.Type) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch let error as URLError {
            throw APIError.offline(Self.reason(for: error))
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.notMarquee }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, detail: Self.detail(from: data, status: http.statusCode))
        }
        if T.self == Empty.self, let empty = Empty() as? T { return empty }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: T.self))
        }
    }

    /// FastAPI puts its message in `detail`; anything else falls back to the status.
    private static func detail(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = object["detail"] as? String, !detail.isEmpty {
            return detail
        }
        return HTTPURLResponse.localizedString(forStatusCode: status).capitalizedFirst
    }

    private static func reason(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet: "You're offline."
        case .timedOut: "The server didn't answer in time."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            "Couldn't reach your Marquee server. Is it on, and are you on the right network?"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            "That server's HTTPS certificate wasn't accepted."
        case .appTransportSecurityRequiresSecureConnection:
            "iOS blocked a plain http:// connection to that address."
        default: "Couldn't reach your Marquee server."
        }
    }
}

/// For endpoints whose body we don't care about (`{"ok": true}` and friends).
public struct Empty: Codable, Sendable, Equatable {
    public init() {}
    public init(from decoder: any Decoder) throws {}
    public func encode(to encoder: any Encoder) throws {}
}

/// Type-erasing shim so `post(body:)` can take any Encodable without generics
/// leaking into every call site.
struct AnyEncodable: Encodable {
    private let encodeTo: @Sendable (any Encoder) throws -> Void
    init(_ wrapped: some Encodable & Sendable) {
        encodeTo = { encoder in try wrapped.encode(to: encoder) }
    }
    func encode(to encoder: any Encoder) throws { try encodeTo(encoder) }
}

public extension URLSession {
    /// One session for the whole app: no cookies (the token is the credential and a
    /// stray `sid` cookie would only confuse things), no URL cache of API responses
    /// — the offline layer owns caching and knows what's safe to reuse.
    static let marqueeShared: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) { append(data) }
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
