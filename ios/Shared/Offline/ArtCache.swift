import Foundation
import UIKit

/// A tiny on-disk cache of the poster art the widgets need.
///
/// A widget timeline has to render synchronously — it can't await a download — and it
/// has no credentials of its own. So the app downloads the handful of posters its
/// snapshot references and drops them in the shared container; the extension only
/// ever reads from disk.
public final class ArtCache: @unchecked Sendable {

    public static let shared = ArtCache()

    private let directory: URL
    private let lock = NSLock()

    private init() {
        let root = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: OfflineStore.appGroup)
            ?? URL.temporaryDirectory
        directory = root.appendingPathComponent("Art", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func location(for url: String) -> URL {
        // A stable, filesystem-safe name; the URL itself can be any length.
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in url.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x1000_0000_01B3
        }
        return directory.appendingPathComponent(String(hash, radix: 16) + ".img")
    }

    /// Non-async so the lock is never held across a suspension point.
    private func write(_ data: Data, to destination: URL) {
        lock.lock(); defer { lock.unlock() }
        try? data.write(to: destination, options: .atomic)
    }

    private func exists(_ destination: URL) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return FileManager.default.fileExists(atPath: destination.path)
    }

    public func image(for url: String?) -> UIImage? {
        guard let url, !url.isEmpty else { return nil }
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: location(for: url), options: [.mappedIfSafe])
        else { return nil }
        return UIImage(data: data)
    }

    /// Download and store, unless it's already there. Small and idempotent so the app
    /// can call it after every dashboard refresh without thinking about it.
    public func warm(_ urls: [String?], session: URLSession = .marqueeShared) async {
        for case let url? in urls where !url.isEmpty {
            let destination = location(for: url)
            if exists(destination) { continue }
            guard let parsed = URL(string: url),
                  let (data, response) = try? await session.data(from: parsed),
                  (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false,
                  // Downscale before storing: a widget shows a poster at ~70pt, and the
                  // shared container is not the place for a 2,000px original.
                  let image = UIImage(data: data)?.mqDownscaled(maxDimension: 360),
                  let jpeg = image.jpegData(compressionQuality: 0.8)
            else { continue }
            write(jpeg, to: destination)
        }
        prune()
    }

    /// Keep the cache to a sensible size — oldest out first.
    private func prune(limit: Int = 60) {
        lock.lock(); defer { lock.unlock() }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: Array(keys)) else { return }
        guard files.count > limit else { return }
        let sorted = files.sorted {
            let left = (try? $0.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: keys).contentModificationDate) ?? .distantPast
            return left < right
        }
        for file in sorted.prefix(files.count - limit) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    public func clear() {
        lock.lock(); defer { lock.unlock() }
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

extension UIImage {
    func mqDownscaled(maxDimension: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
