import Foundation
import Security

/// Everything that identifies the paired server: where it lives and the token that
/// opens it. Both halves are secrets — the address is the household's homelab, so it
/// never touches UserDefaults, a plist, a log line, or the shipped binary.
public struct PairedServer: Codable, Sendable, Equatable {
    /// Normalised base URL, e.g. `https://example` — no trailing slash, no `/api`.
    public var baseURL: URL
    /// Session token, exchanged for `Authorization: Bearer`.
    public var token: String
    /// Who we're signed in as, so the UI can greet them before `/api/me` lands.
    public var username: String
    public var displayName: String
    public var isAdmin: Bool
    /// The name this device registered under, shown in the server's device list.
    public var deviceName: String

    public init(baseURL: URL, token: String, username: String,
                displayName: String, isAdmin: Bool, deviceName: String) {
        self.baseURL = baseURL
        self.token = token
        self.username = username
        self.displayName = displayName
        self.isAdmin = isAdmin
        self.deviceName = deviceName
    }

    public var apiURL: URL { baseURL.appendingPathComponent("api") }
}

/// Keychain-backed storage for the paired server. One item, replaced wholesale.
public enum Vault {

    private static let service = "dev.kadenthompson.marquee.session"
    private static let account = "paired-server"

    /// An app group doubles as a keychain access group, which is what lets the widget
    /// extension read the same token without a team-prefixed keychain entitlement —
    /// and is why a widget's buttons can mark an episode rather than just deep-link.
    private static let accessGroup = OfflineStore.appGroup

    private static func baseQuery(shared: Bool) -> [String: Any] {
        var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: service,
                                    kSecAttrAccount as String: account]
        if shared { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    /// Shared first, then the app's own keychain — a development build without the
    /// app-group entitlement still works, it just can't feed the widget.
    private static var lookupOrder: [Bool] { [true, false] }

    public static func load() -> PairedServer? {
        for shared in lookupOrder {
            var query = baseQuery(shared: shared)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
                  let data = item as? Data,
                  let server = try? JSONDecoder().decode(PairedServer.self, from: data)
            else { continue }
            return server
        }
        return nil
    }

    /// Returns the Keychain status so the caller can refuse to carry on pretending it
    /// paired. A silent failure here looks like "the app forgets my server every
    /// launch", which is a miserable thing to debug from the outside.
    @discardableResult
    public static func save(_ server: PairedServer) -> OSStatus {
        guard let data = try? JSONEncoder().encode(server) else { return errSecParam }
        // AfterFirstUnlock, not WhenUnlocked: the background refresh task and the
        // widget timeline both run with the phone locked in your pocket.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        var lastStatus: OSStatus = errSecParam
        for shared in lookupOrder {
            let query = baseQuery(shared: shared)
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            if status == errSecSuccess { return status }
            if status == errSecItemNotFound {
                var insert = query
                insert.merge(attributes) { _, new in new }
                let added = SecItemAdd(insert as CFDictionary, nil)
                if added == errSecSuccess { return added }
                lastStatus = added
            } else {
                lastStatus = status
            }
        }
        return lastStatus
    }

    /// A human explanation for the handful of Keychain failures that actually happen.
    public static func explain(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            "Saved."
        case errSecMissingEntitlement:
            "iOS wouldn't let Marquee use the Keychain. The app needs to be signed to store your session."
        case errSecInteractionNotAllowed:
            "The Keychain was locked. Unlock the device and try again."
        default:
            "Couldn't save your session to the Keychain (error \(status))."
        }
    }

    /// Unpair: forget the address and the token. The caller is responsible for
    /// telling the server to revoke the session first.
    public static func clear() {
        for shared in lookupOrder {
            SecItemDelete(baseQuery(shared: shared) as CFDictionary)
        }
    }
}

public enum VaultError: LocalizedError {
    case keychain(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .keychain(let status): Vault.explain(status)
        }
    }
}
