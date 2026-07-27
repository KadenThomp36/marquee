import SwiftUI

struct NextTab: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WatchNextScreen()
                .marqueeDestinations()
        }
        .routed(into: $path)
    }
}

/// The home screen, and the reason the app exists: what to watch next, one tap to
/// cross it off, and the trail of everything already crossed off receding to the left.
struct WatchNextScreen: View {
    @Environment(Session.self) private var session

    @State private var data = RemoteData<Dashboard>(cacheKey: "dashboard")
    @State private var discover = RemoteData<DiscoverResponse>(cacheKey: "discover")
    @State private var unreadCount = 0

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    greeting

                    if let dashboard = data.value {
                        content(dashboard)
                    } else if data.isEmpty {
                        skeleton
                    } else if let error = data.error {
                        LoadFailure(message: error) { await refresh(force: true) }
                    }

                    if data.isStale { StaleFooter(cachedAt: data.cachedAt) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .refreshable { await refresh(force: true) }
        }
        .navigationTitle("Watch Next")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .task { await refresh() }
        .task { await loadDiscover() }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(_ dashboard: Dashboard) -> some View {
        if !dashboard.upNext.isEmpty || !dashboard.recent.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PlainRailHeader(title: "Up Next")
                UpNextRail(upNext: dashboard.upNext,
                           recent: dashboard.recent,
                           onPunch: punch)
            }
        }

        if dashboard.upNext.isEmpty {
            EmptyLine("Nothing in the queue — everything is crossed off.")
        }

        if !dashboard.stale.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PlainRailHeader(title: "Haven't watched in a while")
                ShowCardRail(shows: dashboard.stale, onPunch: punch)
            }
        }

        if !dashboard.calendar.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                RailHeader(title: "On the calendar") { UpcomingScreen() }
                HorizontalRail {
                    ForEach(dashboard.calendar) { episode in
                        CalendarCard(episode: episode)
                    }
                }
            }
        }

        if let section = recommendedSection {
            VStack(alignment: .leading, spacing: 12) {
                PlainRailHeader(title: section.title)
                HorizontalRail {
                    ForEach(section.items.prefix(14)) { item in
                        NavigationLink(value: item.isShow ? Navigator.Route.show(item.id)
                                                          : Navigator.Route.movie(item.id)) {
                            PosterTile(result: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }

        if !dashboard.social.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PlainRailHeader(title: "Around the house")
                HorizontalRail {
                    ForEach(dashboard.social) { entry in
                        WatchedMiniCard(entry: entry, showsWho: true)
                    }
                }
            }
        }

        if !dashboard.reviews.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PlainRailHeader(title: "Fresh reviews")
                VStack(spacing: 10) {
                    ForEach(dashboard.reviews.prefix(4)) { review in
                        ReviewTeaserRow(review: review)
                    }
                }
                .padding(.horizontal, MQ.gutter)
            }
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(timeOfDay)
                .font(.mqTitle)
                .foregroundStyle(Color.mqInk)
            if let name = session.me?.shortName {
                Text(name)
                    .font(MarqueeFont.wordmark(21, relativeTo: .title2))
                    .foregroundStyle(Color.mqBrass)
            }
        }
        .padding(.horizontal, MQ.gutter)
        .accessibilityElement(children: .combine)
    }

    private var timeOfDay: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case ..<5: "Late show"
        case ..<12: "Good morning"
        case ..<18: "Good afternoon"
        default: "Tonight's feature"
        }
    }

    /// The web client leads with "because you watched X" when discover has one, and
    /// falls back to whatever the first section is.
    private var recommendedSection: DiscoverSection? {
        guard let sections = discover.value?.sections else { return nil }
        return sections.first { $0.title.lowercased().contains("because you watched") }
            ?? sections.first
    }

    private var skeleton: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(height: 18, radius: 6).frame(width: 140)
            HorizontalRail {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonBlock(height: MQ.upNextWidth * 1.5, radius: MQ.radius)
                        .frame(width: MQ.upNextWidth)
                }
            }
        }
        .padding(.horizontal, MQ.gutter)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(value: Navigator.Route.notifications) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel(unreadCount > 0
                                ? "Notifications, \(unreadCount) unread"
                                : "Notifications")
        }
    }

    // MARK: - Loading

    private func refresh(force: Bool = false) async {
        guard let client = session.client else { return }
        await data.load(force: force) {
            try await client.get("dashboard", as: Dashboard.self)
        }
        if let dashboard = data.value {
            WidgetBridge.publish(dashboard: dashboard, session: session)
        }
        if let notifications: NotificationsResponse = try? await client.get("notifications") {
            unreadCount = notifications.unread
        }
    }

    private func loadDiscover() async {
        guard let client = session.client else { return }
        await discover.load {
            try await client.get("discover", as: DiscoverResponse.self)
        }
    }

    // MARK: - The punch

    /// Mark the next episode watched, advance the card in place, and fold the watch
    /// into the history strip so it slides in behind you.
    private func punch(_ show: ShowCard) async {
        guard let episode = show.nextEp, let client = session.client else { return }

        // Optimistic: the card advances now, the server catches up.
        let stamp = MQTime.stamp()
        data.mutate { dashboard in
            dashboard.recent.insert(
                WatchEntry(showID: show.id, title: show.title, poster: show.poster,
                           season: episode.season, number: episode.number,
                           epTitle: episode.title, watchedAt: stamp, count: 1, by: nil),
                at: 0)
        }

        do {
            let response: MarkResponse = try await client.post(
                "show/\(show.id)/watch",
                body: MarkEpisodeRequest(season: episode.season, number: episode.number),
                as: MarkResponse.self)

            if let updated = response.show {
                data.mutate { dashboard in
                    apply(updated, to: &dashboard)
                }
            }
            if let earned = response.celebrate, !earned.isEmpty {
                session.enqueue(earned)
            }
            if let dashboard = data.value {
                WidgetBridge.publish(dashboard: dashboard, session: session)
            }
        } catch {
            // Offline or the server stumbled: keep the optimistic state and replay it.
            OfflineStore.shared.enqueue(PendingWrite(
                .markEpisode(showID: show.id, season: episode.season,
                             number: episode.number, unwatch: false, previous: false)))
            data.mutate { dashboard in
                advanceLocally(show.id, from: episode, in: &dashboard)
            }
        }
    }

    /// Replace a card with the server's patched copy, or drop it once there's nothing
    /// left to watch.
    private func apply(_ updated: ShowCard, to dashboard: inout Dashboard) {
        for keyPath in [\Dashboard.upNext, \Dashboard.stale] {
            guard let index = dashboard[keyPath: keyPath].firstIndex(where: { $0.id == updated.id })
            else { continue }
            if updated.nextEp != nil {
                dashboard[keyPath: keyPath][index] = updated
            } else {
                dashboard[keyPath: keyPath].remove(at: index)
            }
        }
    }

    /// The same advance, computed locally, for when the server never answered.
    private func advanceLocally(_ showID: Int, from episode: NextEpisode, in dashboard: inout Dashboard) {
        for keyPath in [\Dashboard.upNext, \Dashboard.stale] {
            guard let index = dashboard[keyPath: keyPath].firstIndex(where: { $0.id == showID })
            else { continue }
            var card = dashboard[keyPath: keyPath][index]
            card.watched = min(card.watched + 1, card.aired)
            card.remaining = max(card.remaining - 1, 0)
            card.lastWatched = MQTime.stamp()
            // We don't know the next episode without the catalogue, so the card keeps
            // its progress and loses its punch button until the next sync.
            card.nextEp = nil
            if card.remaining > 0 {
                dashboard[keyPath: keyPath][index] = card
            } else {
                dashboard[keyPath: keyPath].remove(at: index)
            }
        }
    }
}

// MARK: - Small pieces

struct EmptyLine: View {
    let message: String
    init(_ message: String) { self.message = message }

    var body: some View {
        Text(message)
            .font(.mqSub)
            .foregroundStyle(Color.mqInkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .padding(.horizontal, MQ.gutter)
    }
}

struct LoadFailure: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 28))
                .foregroundStyle(Color.mqInkMuted)
            Text(message)
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
                .multilineTextAlignment(.center)
            Button("Try again") { Task { await retry() } }
                .buttonStyle(.mqChip)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, MQ.gutter)
    }
}

/// The standard edge-to-edge horizontal rail: content scrolls under the gutter but
/// starts and ends aligned with it.
struct HorizontalRail<Content: View>: View {
    var spacing: CGFloat = MQ.railGap
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: spacing) {
                content
            }
            .padding(.horizontal, MQ.gutter)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
}
