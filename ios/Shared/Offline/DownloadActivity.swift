import ActivityKit
import Foundation

/// A Live Activity for something you asked Overseerr to fetch.
///
/// The web client polls a progress bar while the page is open; on a phone that
/// belongs on the Lock Screen, where you can watch a download land without keeping
/// the app in front of you. The activity ends itself when the download completes.
public struct DownloadAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 0–100.
        public var progress: Int
        /// Sonarr/Radarr's own estimate, e.g. "00:04:12".
        public var eta: String?
        /// How many separate grabs are in flight.
        public var active: Int
        /// True once the server reports it as available on Plex.
        public var finished: Bool

        public init(progress: Int, eta: String?, active: Int, finished: Bool) {
            self.progress = progress
            self.eta = eta
            self.active = active
            self.finished = finished
        }

        public var fraction: Double { Double(min(max(progress, 0), 100)) / 100 }
    }

    /// "show" or "movie".
    public var itemType: String
    public var itemID: Int
    public var title: String
    public var subtitle: String?
    /// Absolute poster URL from the API.
    public var poster: String?

    public init(itemType: String, itemID: Int, title: String,
                subtitle: String?, poster: String?) {
        self.itemType = itemType
        self.itemID = itemID
        self.title = title
        self.subtitle = subtitle
        self.poster = poster
    }
}
