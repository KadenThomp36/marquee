import Foundation

/// Turning what someone types into a base URL, and proving there's a Marquee at the
/// other end. Deliberately forgiving about the input and strict about the answer:
/// anything can respond to a GET, but only Marquee answers `/api/build`.
public enum ServerAddress {

    /// Candidate base URLs for a typed address, best first.
    ///
    /// A bare host gets tried over https and then http, because a household server on
    /// the LAN is as likely to be plain http as not — and iOS will only allow that
    /// second attempt for a local address, which is exactly the intended shape.
    public static func candidates(for input: String) -> [URL] {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }

        // People paste the page they were looking at; take the origin from it.
        while text.hasSuffix("/") { text.removeLast() }
        for suffix in ["/api/build", "/api", "/#", "/#/"] where text.hasSuffix(suffix) {
            text.removeLast(suffix.count)
        }
        while text.hasSuffix("/") { text.removeLast() }
        guard !text.isEmpty else { return [] }

        if let url = URL(string: text), let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https", url.host != nil {
            return [origin(of: url)].compactMap { $0 }
        }
        return ["https://\(text)", "http://\(text)"]
            .compactMap { URL(string: $0) }
            .compactMap(origin(of:))
    }

    /// Scheme + host + port only — no path, no query, no fragment.
    private static func origin(of url: URL) -> URL? {
        guard let scheme = url.scheme, let host = url.host else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = url.port
        return components.url
    }

    /// Ask each candidate for `/api/build`. The first that answers like Marquee wins.
    public static func resolve(_ input: String,
                               session: URLSession = .marqueeShared) async throws -> URL {
        let options = candidates(for: input)
        guard !options.isEmpty else { throw APIError.badAddress }
        var lastError: APIError = .badAddress
        for base in options {
            do {
                _ = try await build(at: base, session: session)
                return base
            } catch let error as APIError {
                lastError = error
                // A definite answer from a definite server: stop, don't downgrade to http.
                if case .http = error { throw error }
                if case .notMarquee = error { throw error }
            }
        }
        throw lastError
    }

    /// `GET {base}/api/build` — the cheapest proof that this is a Marquee server.
    @discardableResult
    public static func build(at base: URL,
                             session: URLSession = .marqueeShared) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("api/build"))
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw APIError.offline(reason(for: error, base: base))
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.notMarquee }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode,
                                detail: "That address answered with \(http.statusCode).")
        }
        guard let payload = try? JSONDecoder().decode(BuildResponse.self, from: data),
              !payload.build.isEmpty else {
            throw APIError.notMarquee
        }
        return payload.build
    }

    private static func reason(for error: URLError, base: URL) -> String {
        switch error.code {
        case .cannotFindHost, .dnsLookupFailed:
            "Couldn't find \(base.host ?? "that address")."
        case .cannotConnectToHost:
            "Nothing answered at \(base.host ?? "that address")\(base.port.map { ":\($0)" } ?? "")."
        case .notConnectedToInternet:
            "You're offline."
        case .timedOut:
            "That address didn't answer in time."
        case .appTransportSecurityRequiresSecureConnection:
            "iOS only allows plain http:// to addresses on your local network."
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .serverCertificateHasUnknownRoot:
            "That server's HTTPS certificate wasn't accepted."
        default:
            "Couldn't reach that address."
        }
    }
}
