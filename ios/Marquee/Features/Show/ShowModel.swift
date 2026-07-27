import Foundation
import SwiftUI

/// Everything the show screen knows and every way it changes.
///
/// Marking lives here rather than in the views because three different controls do
/// it — the continue-watching carousel, the episode tick, and "mark all" — and they
/// all have to agree instantly, before the server has answered.
@MainActor
@Observable
final class ShowModel {

    let showID: Int
    private(set) var detail: ShowDetail?
    private(set) var ratings: ShowRatings?
    private(set) var providers: WatchProviders?
    private(set) var requestStatus: RequestStatus?
    private(set) var error: String?
    private(set) var isStale = false
    private(set) var cachedAt: Date?

    /// Which season is expanded. Opens on the one holding your next episode.
    var openSeason: Int?
    /// Aired episodes, in order — the spine everything else indexes into.
    private(set) var watchable: [EpisodeRow] = []

    private var session: Session?
    private let today = MQTime.today()
    private var cacheKey: String { "show-\(showID)" }

    init(showID: Int) {
        self.showID = showID
        if let cached = OfflineStore.shared.cached(ShowDetail.self, for: cacheKey) {
            apply(cached, openingSeason: true)
            isStale = true
            cachedAt = OfflineStore.shared.cacheDate(for: cacheKey)
        }
    }

    // MARK: - Derived

    var title: String { detail?.displayTitle ?? "" }
    var watchedCount: Int { watchable.count(where: \.watched) }
    var totalWatchable: Int { watchable.count }
    var progress: Double {
        totalWatchable > 0 ? Double(watchedCount) / Double(totalWatchable) : 0
    }
    var remaining: Int { max(0, totalWatchable - watchedCount) }
    var isComplete: Bool { totalWatchable > 0 && watchedCount == totalWatchable }

    /// Red once you've stopped watching, violet once a finished series is finished.
    var progressTint: ProgressBar.ProgressTint {
        if detail?.archived == true { return .stopped }
        if isComplete, detail?.isEnded == true { return .complete }
        return .brass
    }

    var nextEpisode: EpisodeRow? { watchable.first { !$0.watched } }

    /// The years a show ran, the way the hero states it: "2016–2021", or "2021–" for
    /// something still going.
    var yearsSpan: String {
        guard let info = detail?.info else { return detail?.year?.text ?? "" }
        guard let first = info.firstAir?.prefix(4), !first.isEmpty else {
            return detail?.year?.text ?? ""
        }
        guard let last = info.lastAir?.prefix(4), last != first else { return String(first) }
        return detail?.status == "Returning Series" ? "\(first)–" : "\(first)–\(last)"
    }

    /// How many aired episodes before this one are still unmarked — the "you're
    /// ahead" prompt exists so a jump never silently marks a whole run.
    func earlierUnwatched(before episode: EpisodeRow) -> Int {
        watchable.count { row in
            !row.watched && (row.season < episode.season
                             || (row.season == episode.season && row.number < episode.number))
        }
    }

    func episode(season: Int, number: Int) -> EpisodeRow? {
        detail?.seasons.first { $0.season == season }?.episodes
            .first { $0.number == number }
    }

    // MARK: - Loading

    func load(session: Session, force: Bool = false) async {
        self.session = session
        guard let client = session.client else { return }
        do {
            let fresh: ShowDetail = try await client.get("show/\(showID)")
            apply(fresh, openingSeason: detail == nil || force)
            OfflineStore.shared.cache(fresh, for: cacheKey)
            isStale = false
            cachedAt = Date()
            error = nil
        } catch let failure as APIError {
            if detail == nil { error = failure.errorDescription }
        } catch {
            if detail == nil { self.error = error.localizedDescription }
        }
    }

    func loadRatings(session: Session) async {
        guard ratings == nil, let client = session.client else { return }
        ratings = try? await client.get("show/\(showID)/ratings", as: ShowRatings.self)
    }

    func loadProviders(session: Session) async {
        guard providers == nil, let client = session.client else { return }
        providers = try? await client.get("watch_providers/show/\(showID)", as: WatchProviders.self)
    }

    func loadRequestStatus(session: Session) async {
        guard session.requestConfig?.enabled == true, let client = session.client else { return }
        requestStatus = try? await client.get("request/status/show/\(showID)", as: RequestStatus.self)
        followDownload(session: session)
    }

    /// Download progress is live data — while something is genuinely in flight, keep
    /// asking so the bar moves instead of sitting where it was when the page loaded.
    func pollRequestStatus(session: Session) async {
        while !Task.isCancelled {
            guard requestStatus?.isBusy == true else { return }
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            await refreshRequestStatus(session: session)
        }
    }

    func refreshRequestStatus(session: Session) async {
        guard let client = session.client else { return }
        requestStatus = try? await client.get("request/status/show/\(showID)", as: RequestStatus.self)
        followDownload(session: session)
    }

    /// Something actually downloading belongs on the Lock Screen, not behind a page
    /// you have to keep open.
    func followDownload(session: Session) {
        guard let status = requestStatus, let detail else { return }
        if status.download != nil {
            LiveDownloads.shared.follow(itemType: "show", itemID: showID,
                                        title: detail.displayTitle,
                                        subtitle: detail.info?.networks?.first,
                                        poster: detail.poster, status: status, session: session)
        } else if status.state == .available {
            LiveDownloads.shared.finish(itemType: "show", itemID: showID)
        }
    }

    private func apply(_ fresh: ShowDetail, openingSeason: Bool) {
        var trimmed = fresh
        // Seasons TMDB lists but never produced come back empty — they'd render as
        // an accordion row that opens onto nothing.
        trimmed.seasons = fresh.seasons.filter { !$0.episodes.isEmpty }
        detail = trimmed
        rebuildWatchable()
        if openingSeason {
            openSeason = nextEpisode?.season ?? trimmed.seasons.last?.season
        }
    }

    private func rebuildWatchable() {
        watchable = (detail?.seasons ?? [])
            .flatMap(\.episodes)
            .filter { $0.season > 0 && $0.hasAired(asOf: today) }
            .sorted { ($0.season, $0.number) < ($1.season, $1.number) }
    }

    // MARK: - Marking

    enum MarkScope {
        /// Just this one.
        case single
        /// This one and every aired episode before it.
        case throughHere
    }

    func setWatched(_ watched: Bool, season: Int, number: Int,
                    scope: MarkScope = .single, session: Session) async {
        applyLocally(watched: watched, season: season, number: number, scope: scope)

        guard let client = session.client else { return }
        let request = MarkEpisodeRequest(season: season, number: number,
                                         unwatch: watched ? nil : true,
                                         previous: scope == .throughHere ? true : nil)
        do {
            let response: MarkResponse = try await client.post("show/\(showID)/watch", body: request)
            if let earned = response.celebrate, !earned.isEmpty {
                session.enqueue(earned)
            }
            OfflineStore.shared.cache(detail, for: cacheKey)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .markEpisode(showID: showID, season: season, number: number,
                             unwatch: !watched, previous: scope == .throughHere)))
        }
    }

    func setSeasonWatched(_ watched: Bool, season: Int, session: Session) async {
        guard var current = detail,
              let index = current.seasons.firstIndex(where: { $0.season == season })
        else { return }

        for episodeIndex in current.seasons[index].episodes.indices {
            let episode = current.seasons[index].episodes[episodeIndex]
            // Marking a season doesn't reach into the future; unmarking clears it all.
            guard watched ? episode.hasAired(asOf: today) : true else { continue }
            current.seasons[index].episodes[episodeIndex].watched = watched
            if watched, current.seasons[index].episodes[episodeIndex].watchedAt == nil {
                current.seasons[index].episodes[episodeIndex].watchedAt = MQTime.stamp()
            }
        }
        detail = current
        rebuildWatchable()

        guard let client = session.client else { return }
        do {
            let response: MarkResponse = try await client.post(
                "show/\(showID)/season/\(season)/watch",
                body: MarkSeasonRequest(unwatch: watched ? nil : true))
            if let earned = response.celebrate, !earned.isEmpty {
                session.enqueue(earned)
            }
            OfflineStore.shared.cache(detail, for: cacheKey)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .markSeason(showID: showID, season: season, unwatch: !watched)))
        }
    }

    /// Change a watch's date without toggling it.
    func setWatchDate(_ date: String, season: Int, number: Int, session: Session) async {
        mutateEpisode(season: season, number: number) { $0.watchedAt = date }
        guard let client = session.client else { return }
        _ = try? await client.post("show/\(showID)/watch",
                                   body: MarkEpisodeRequest(season: season, number: number,
                                                            setDate: date),
                                   as: MarkResponse.self)
        OfflineStore.shared.cache(detail, for: cacheKey)
    }

    private func applyLocally(watched: Bool, season: Int, number: Int, scope: MarkScope) {
        guard var current = detail else { return }
        for seasonIndex in current.seasons.indices {
            for episodeIndex in current.seasons[seasonIndex].episodes.indices {
                let episode = current.seasons[seasonIndex].episodes[episodeIndex]
                let isTarget = episode.season == season && episode.number == number
                let isEarlier = scope == .throughHere && watched
                    && episode.season > 0 && episode.hasAired(asOf: today)
                    && (episode.season < season
                        || (episode.season == season && episode.number < number))
                guard isTarget || isEarlier else { continue }
                current.seasons[seasonIndex].episodes[episodeIndex].watched = watched
                if watched, current.seasons[seasonIndex].episodes[episodeIndex].watchedAt == nil {
                    current.seasons[seasonIndex].episodes[episodeIndex].watchedAt = MQTime.stamp()
                }
            }
        }
        detail = current
        rebuildWatchable()
    }

    private func mutateEpisode(season: Int, number: Int, _ change: (inout EpisodeRow) -> Void) {
        guard var current = detail,
              let seasonIndex = current.seasons.firstIndex(where: { $0.season == season }),
              let episodeIndex = current.seasons[seasonIndex].episodes
                .firstIndex(where: { $0.number == number })
        else { return }
        change(&current.seasons[seasonIndex].episodes[episodeIndex])
        detail = current
        rebuildWatchable()
    }

    // MARK: - Show-level actions

    func follow(session: Session) async {
        guard let client = session.client else { return }
        detail?.followed = true
        _ = try? await client.post("show/\(showID)/follow", body: FollowRequest(), as: Empty.self)
        await load(session: session)
    }

    func setArchived(_ archived: Bool, session: Session) async {
        detail?.archived = archived
        guard let client = session.client else { return }
        do {
            try await client.post("show/\(showID)/follow",
                                  body: FollowRequest(archived: archived), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(.archiveShow(showID: showID, archived: archived)))
        }
    }

    func rate(_ rating: Int?, session: Session) async {
        detail?.rating = rating
        guard let client = session.client, let rating else { return }
        do {
            try await client.post("show/\(showID)/follow",
                                  body: FollowRequest(rating: rating), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(.rateShow(showID: showID, rating: rating)))
        }
    }

    /// Unfollow removes the show *and every watch of it* — the server is explicit
    /// about that, so the confirmation has to be too.
    func remove(session: Session) async {
        guard let client = session.client else { return }
        _ = try? await client.post("show/\(showID)/follow",
                                   body: FollowRequest(unfollow: true), as: Empty.self)
        OfflineStore.shared.cache(Optional<ShowDetail>.none, for: cacheKey)
    }
}
