import Foundation
import os

/// Drains the offline write queue whenever there's a server to drain it into.
///
/// Replay is safe because of how the server is built: episode marks are
/// `INSERT OR IGNORE` rows keyed by (user, show, season, number), and state changes
/// are last-write-wins. So a write that already landed simply does nothing the second
/// time, and the only thing this has to get right is *stopping* — a write the server
/// rejects outright is dropped rather than retried forever.
public actor SyncCoordinator {

    public static let shared = SyncCoordinator()

    private var running = false
    private let logger = Logger(subsystem: "dev.kadenthompson.marquee", category: "sync")

    private init() {}

    /// How many writes are still waiting — Settings shows this so a queue that can't
    /// drain is visible rather than silent.
    public nonisolated var pendingCount: Int { OfflineStore.shared.pending().count }

    @MainActor
    public func replayPending(session: Session) async {
        guard let client = session.client else { return }
        await drain(with: client, session: session)
    }

    private func drain(with client: MarqueeClient, session: Session) async {
        guard !running else { return }
        running = true
        defer { running = false }

        let queue = OfflineStore.shared.pending().sorted { $0.createdAt < $1.createdAt }
        guard !queue.isEmpty else { return }
        logger.info("replaying \(queue.count) queued write(s)")

        var celebrations: [Celebration] = []
        for write in queue {
            do {
                if let earned = try await perform(write, with: client) {
                    celebrations.append(contentsOf: earned)
                }
                OfflineStore.shared.remove(write.id)
            } catch let error as APIError where error.isTransient {
                // Still offline, or the server is unhappy in a way that might pass.
                logger.info("replay paused: \(error.localizedDescription, privacy: .public)")
                break
            } catch APIError.unauthorized {
                logger.error("replay hit an expired session; stopping")
                break
            } catch {
                // A permanent rejection: the show was removed, the list was deleted.
                // Dropping it is the only way the queue ever empties.
                logger.error("dropping unreplayable write \(write.summary, privacy: .public)")
                OfflineStore.shared.remove(write.id)
            }
        }

        if !celebrations.isEmpty {
            let earned = celebrations
            await MainActor.run { session.enqueue(earned) }
        }
    }

    /// Returns any celebration the write earned on its way in.
    private func perform(_ write: PendingWrite, with client: MarqueeClient) async throws -> [Celebration]? {
        switch write.kind {
        case let .markEpisode(showID, season, number, unwatch, previous):
            let response: MarkResponse = try await client.post(
                "show/\(showID)/watch",
                body: MarkEpisodeRequest(season: season, number: number,
                                         unwatch: unwatch ? true : nil,
                                         previous: previous ? true : nil))
            return response.celebrate

        case let .markSeason(showID, season, unwatch):
            let response: MarkResponse = try await client.post(
                "show/\(showID)/season/\(season)/watch",
                body: MarkSeasonRequest(unwatch: unwatch ? true : nil))
            return response.celebrate

        case let .rateShow(showID, rating):
            try await client.post("show/\(showID)/follow",
                                  body: FollowRequest(rating: rating), as: Empty.self)
            return nil

        case let .archiveShow(showID, archived):
            try await client.post("show/\(showID)/follow",
                                  body: FollowRequest(archived: archived), as: Empty.self)
            return nil

        case let .movieState(movieID, state, rating):
            try await client.post("movie/\(movieID)/state",
                                  body: MovieStateRequest(state: state, rating: rating),
                                  as: Empty.self)
            return nil

        case let .listToggle(listID, itemType, itemID, remove):
            try await client.post("list/\(listID)/item",
                                  body: ListItemToggle(itemType: itemType, itemID: itemID,
                                                       remove: remove ? true : nil),
                                  as: Empty.self)
            return nil

        case let .favorite(itemType, itemID, remove):
            if remove {
                try await client.delete("favorites/\(itemType)/\(itemID)", as: Empty.self)
            } else {
                try await client.post("favorites",
                                      body: FavoriteRequest(itemType: itemType, itemID: itemID),
                                      as: Empty.self)
            }
            return nil

        case let .readingProgress(kind, itemID, progress):
            try await client.post("\(kind)/\(itemID)/state",
                                  body: ReadingStateRequest(progress: progress), as: Empty.self)
            return nil

        case let .readingState(kind, itemID, state):
            let request = state == "none"
                ? ReadingStateRequest.remove
                : ReadingStateRequest(state: ReadingState(rawValue: state))
            try await client.post("\(kind)/\(itemID)/state", body: request, as: Empty.self)
            return nil

        case let .review(itemType, itemID, rating, body):
            try await client.post("reviews/\(itemType)/\(itemID)",
                                  body: PostReviewRequest(rating: rating, body: body),
                                  as: Empty.self)
            return nil
        }
    }
}
