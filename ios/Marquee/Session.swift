import Foundation
import SwiftUI
import UIKit

/// App-wide state: who we're paired with, who we are, and the queue of celebrations
/// waiting to be shown. Everything that needs the server goes through `client`, which
/// only exists once a server is paired — so an unpaired build genuinely cannot reach
/// anything.
@MainActor
@Observable
public final class Session {

    public enum Phase: Equatable {
        /// Reading the Keychain on launch.
        case starting
        /// No server yet — show the pairing screen.
        case unpaired
        /// Paired and usable.
        case ready
    }

    public private(set) var phase: Phase = .starting
    public private(set) var server: PairedServer?
    public private(set) var me: Person?
    /// Set when the session was rejected, so the pairing screen can say why.
    public private(set) var signedOutReason: String?

    /// Celebrations waiting their turn. The fanfare shows one at a time.
    public var celebrationQueue: [Celebration] = []
    /// Titles already on one of your lists — one small fetch, reused by every tile.
    public private(set) var listMembership: [String: Int] = [:]
    /// Overseerr availability, fetched once per launch.
    public private(set) var requestConfig: RequestConfig?

    public var client: MarqueeClient? { server.map { MarqueeClient(server: $0) } }
    public var isPaired: Bool { server != nil }

    /// The name this device registers under, and the placeholder in the pairing field.
    public static var suggestedDeviceName: String {
        let name = UIDevice.current.name
        return name.isEmpty ? UIDevice.current.model : name
    }

    public init() {}

    // MARK: - Lifecycle

    public func start() async {
        #if DEBUG
        // A hermetic starting point for the UI tests. Debug-only, opt-in per launch,
        // and it only ever *removes* a pairing — it can't create or point at one.
        if ProcessInfo.processInfo.arguments.contains("-mq-reset-pairing") {
            Vault.clear()
            OfflineStore.shared.clearAll()
        }
        #endif
        guard let stored = Vault.load() else {
            phase = .unpaired
            return
        }
        server = stored
        me = Person(id: nil, username: stored.username, displayName: stored.displayName,
                    avatar: nil, banner: nil, features: nil, isAdmin: stored.isAdmin, isMe: true)
        phase = .ready
        await refreshMe()
    }

    /// Re-read `/api/me`: it's the session check *and* the source of the feature flags
    /// that decide whether Reading exists at all.
    public func refreshMe() async {
        guard let client else { return }
        do {
            let response: MeResponse = try await client.get("me")
            me = response.person
            if var server {
                server.username = response.username
                server.displayName = response.person.name
                server.isAdmin = response.isAdmin ?? false
                self.server = server
                Vault.save(server)
            }
        } catch APIError.unauthorized {
            signOutLocally(reason: "That device was unpaired from the server.")
        } catch {
            // Offline: keep going with what the Keychain remembered.
        }
    }

    /// Take a freshly-paired server. Throws if the Keychain refused it — pairing that
    /// only lives in memory would silently unpair on the next launch.
    public func adopt(server: PairedServer, me person: Person?) throws {
        let status = Vault.save(server)
        guard status == errSecSuccess else {
            throw VaultError.keychain(status)
        }
        self.server = server
        self.me = person
        signedOutReason = nil
        phase = .ready
    }

    /// Unpair: revoke server-side first so the token dies even if the app is deleted
    /// straight after, then forget everything locally.
    public func unpair() async {
        if let client {
            _ = try? await client.post("logout", as: Empty.self)
        }
        OfflineStore.shared.clearAll()
        signOutLocally(reason: nil)
    }

    public func signOutLocally(reason: String?) {
        Vault.clear()
        // Art is cached to disk now, and some of it — banners, uploads — came from
        // the server itself. Unpairing forgets everything, including the pictures.
        ArtLoader.shared.clear()
        server = nil
        me = nil
        listMembership = [:]
        requestConfig = nil
        celebrationQueue = []
        signedOutReason = reason
        phase = .unpaired
    }

    // MARK: - Shared lookups

    public func refreshListMembership() async {
        guard let client else { return }
        if let response: ListMembership = try? await client.get("lists/members") {
            listMembership = response.members
        }
    }

    public func listCount(_ type: String, _ id: Int) -> Int {
        listMembership["\(type):\(id)"] ?? 0
    }

    public func loadRequestConfig() async {
        guard requestConfig == nil, let client else { return }
        requestConfig = try? await client.get("request/config", as: RequestConfig.self)
    }

    // MARK: - Celebrations

    /// Anything finished while the app was closed (Plex marking your last episode
    /// overnight) is banked server-side and celebrated on next launch.
    public func checkCelebrations() async {
        guard let client else { return }
        guard let response: CelebrationsResponse = try? await client.get("celebrations") else { return }
        enqueue(response.celebrations)
    }

    public func enqueue(_ celebrations: [Celebration]) {
        let known = Set(celebrationQueue.map(\.id))
        celebrationQueue.append(contentsOf: celebrations.filter { !known.contains($0.id) })
    }

    /// Mark one as seen and drop it from the queue.
    public func finishCelebration(_ celebration: Celebration) {
        celebrationQueue.removeAll { $0.id == celebration.id }
        guard let client else { return }
        Task { _ = try? await client.post("celebrations/seen",
                                          body: CelebrationSeen(ids: [celebration.id]),
                                          as: Empty.self) }
    }
}

public struct CelebrationSeen: Codable, Sendable {
    public var ids: [Int]
}
