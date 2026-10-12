@preconcurrency import ActivityKit
import Foundation
import os

/// Starts, updates and ends the Lock Screen activity for an Overseerr download.
///
/// Marquee has no push infrastructure of its own — updates come from the app polling
/// its own server while it's in the foreground. That's honest about the constraint:
/// the activity keeps ticking while you're watching it, and settles on the last known
/// figure when you put the phone down.
@MainActor
final class LiveDownloads {

    static let shared = LiveDownloads()

    private var activities: [String: Activity<DownloadAttributes>] = [:]
    private var pollers: [String: Task<Void, Never>] = [:]
    private let logger = Logger(subsystem: "dev.kadenthompson.marquee", category: "liveactivity")

    private init() {}

    private func key(_ itemType: String, _ itemID: Int) -> String { "\(itemType):\(itemID)" }

    var isAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Begin following a download. Safe to call repeatedly — a second call just
    /// updates the one that's already running.
    func follow(itemType: String, itemID: Int, title: String, subtitle: String?,
                poster: String?, status: RequestStatus, session: Session) {
        guard isAvailable, let download = status.download else { return }
        let id = key(itemType, itemID)
        let state = DownloadAttributes.ContentState(
            progress: download.progress, eta: download.eta,
            active: download.active, finished: status.state == .available)

        if let existing = activities[id] {
            Task { await existing.update(ActivityContent(state: state, staleDate: staleDate)) }
        } else {
            let attributes = DownloadAttributes(itemType: itemType, itemID: itemID,
                                                title: title, subtitle: subtitle, poster: poster)
            do {
                activities[id] = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: staleDate))
                logger.info("started live activity for \(id, privacy: .public)")
            } catch {
                logger.info("live activity refused: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        startPolling(itemType: itemType, itemID: itemID, session: session)
    }

    /// A download that's finished gets one last "ready to watch" frame before it goes.
    func finish(itemType: String, itemID: Int) {
        let id = key(itemType, itemID)
        pollers[id]?.cancel()
        pollers[id] = nil
        guard let activity = activities[id] else { return }
        activities[id] = nil
        let final = DownloadAttributes.ContentState(progress: 100, eta: nil,
                                                    active: 0, finished: true)
        let content = ActivityContent(state: final, staleDate: nil)
        Task { await Self.end(activity, with: content) }
    }

    /// Unpairing has to take the Lock Screen with it — an activity naming a household
    /// title shouldn't outlive the pairing that produced it.
    func endAll() {
        pollers.values.forEach { $0.cancel() }
        pollers.removeAll()
        let running = activities.values
        activities.removeAll()
        Task {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// `Activity` and `ActivityContent` aren't Sendable, so the hop off the main
    /// actor happens in one place, with the values handed over explicitly.
    private nonisolated static func end(_ activity: sending Activity<DownloadAttributes>,
                                        with content: sending ActivityContent<DownloadAttributes.ContentState>) async {
        await activity.end(content, dismissalPolicy: .after(.now.addingTimeInterval(120)))
    }

    private var staleDate: Date { .now.addingTimeInterval(15 * 60) }

    private func startPolling(itemType: String, itemID: Int, session: Session) {
        let id = key(itemType, itemID)
        guard pollers[id] == nil else { return }
        pollers[id] = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let client = session.client else { return }
                guard let status: RequestStatus =
                        try? await client.get("request/status/\(itemType)/\(itemID)") else { continue }

                if status.state == .available || status.download == nil {
                    self?.finish(itemType: itemType, itemID: itemID)
                    return
                }
                guard let download = status.download, let activity = self?.activities[id] else { return }
                let state = DownloadAttributes.ContentState(
                    progress: download.progress, eta: download.eta,
                    active: download.active, finished: false)
                await activity.update(ActivityContent(state: state,
                                                      staleDate: .now.addingTimeInterval(15 * 60)))
            }
        }
    }
}
