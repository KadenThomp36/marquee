import SwiftUI
import UIKit

/// One decoded copy of each piece of art, kept in memory.
///
/// `AsyncImage` reloads per view: two views showing the same poster each fetch and
/// each flash a placeholder first. That is invisible while scrolling and very visible
/// the moment two copies of one card have to sit on top of each other — which is
/// exactly what the punch animation does.
///
/// So art is loaded once and held. A cache hit is synchronous, which is the whole
/// point: it can be read during `body`, so a poster already on screen never flashes
/// when a second view asks for it.
@MainActor
final class ArtLoader {
    static let shared = ArtLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    /// Disk-backed, so a rail you saw yesterday still draws instantly today. Separate
    /// from `URLSession.marqueeShared`, which is deliberately cookie-less and
    /// uncached because it carries the session token.
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 32 << 20,
                                          diskCapacity: 256 << 20,
                                          directory: nil)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration)
    }()

    private init() {
        memory.countLimit = 320
        memory.totalCostLimit = 96 << 20
    }

    /// Synchronous, and safe to call from `body`.
    func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        if let running = inFlight[url] { return await running.value }

        // Detached, and decoded up front. `Task {}` here would inherit this actor and
        // decode a full-resolution poster on the main thread — and UIImage decodes
        // lazily at draw time, so without `preparingForDisplay` the cost lands during
        // the swipe that revealed it. That is what made the artwork gallery stutter.
        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let (data, _) = try? await Self.session.data(from: url) else { return nil }
            guard let image = UIImage(data: data) else { return nil }
            return image.preparingForDisplay() ?? image
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil

        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            memory.setObject(image, forKey: url as NSURL, cost: cost)
        }
        return image
    }

    /// Called when a pairing is dropped, so no art outlives the server it came from.
    func clear() {
        memory.removeAllObjects()
        Self.session.configuration.urlCache?.removeAllCachedResponses()
    }
}
