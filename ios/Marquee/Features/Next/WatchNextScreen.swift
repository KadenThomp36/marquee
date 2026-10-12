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
    /// The stub from the last punch, and the timer that clears it.
    @State private var receipt: PunchReceipt?
    @State private var receiptTimer: Task<Void, Never>?
    /// The ticket currently in the air, flown here rather than inside a rail so that
    /// nothing between it and the window can clip it.
    @State private var flight: PunchFlight?
    @State private var beat: PunchBeat = .biting
    @State private var holeRadius: CGFloat = 0
    @State private var bit = false

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    greeting.mqHeadingEffect()

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
            .mqTopEdgeBlur()
            .refreshable { await refresh(force: true) }
            .coordinateSpace(.named(MQ.punchSpace))

            // The flight layer, above the scroll view and every rail in it.
            .overlay(alignment: .topLeading) {
                if let flight {
                    PunchedTicket(poster: flight.values.poster,
                                  title: flight.values.title,
                                  episodeLine: flight.values.episodeLine,
                                  subline: flight.values.subline,
                                  progress: flight.values.progress,
                                  holeInset: PunchCard.holeInset,
                                  holeRadius: holeRadius,
                                  beat: beat)
                        .frame(width: flight.frame.width, height: flight.frame.height)
                        .offset(x: flight.frame.minX, y: flight.frame.minY)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            // Over the tab bar, where the thumb that just punched already is.
            .overlay(alignment: .bottom) {
                if let receipt {
                    PunchReceiptBanner(receipt: receipt, onDismiss: dismissReceipt)
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        // Two sensations: the thud of the die going through, then the mark landing.
        .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9), trigger: bit)
        .mqBareNavigationBar()
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
                           onPunch: punch,
                           onLift: fly)
            }
        }

        if dashboard.upNext.isEmpty {
            EmptyLine("Nothing in the queue — everything is crossed off.")
        }

        if !dashboard.stale.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PlainRailHeader(title: "Haven't watched in a while")
                ShowCardRail(shows: dashboard.stale, onPunch: punch, onLift: fly)
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
        HStack(alignment: .top) {
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
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            NavigationLink(value: Navigator.Route.notifications) {
                Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 19))
                    .foregroundStyle(Color.mqInk)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(unreadCount > 0
                                ? "Notifications, \(unreadCount) unread"
                                : "Notifications")
        }
        .padding(.horizontal, MQ.gutter)
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

        showReceipt(PunchReceipt(showID: show.id,
                                 season: episode.season,
                                 number: episode.number,
                                 showTitle: show.displayTitle,
                                 episodeTitle: episode.title,
                                 code: episode.code,
                                 art: show.poster))

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

    /// Punch, hold, lift, and away — run here so the ticket can leave the rail it
    /// came from. Inside the rail it was sliced off at the bounds the moment it grew.
    private func fly(_ new: PunchFlight) {
        holeRadius = 0
        beat = .biting
        flight = new
        bit.toggle()

        Task {
            // 1. The die comes down and bites through. Stiff and fast — a punch is
            //    not a gentle thing — with the card compressing under it.
            withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) {
                holeRadius = 10
            }
            try? await Task.sleep(for: PunchTiming.bite)

            // 2. Through. The chad drops, the card springs back, and it *sits there*
            //    punched. This pause is the whole animation: without it there is no
            //    moment where you see what happened, only something leaving.
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { beat = .punched }
            try? await Task.sleep(for: PunchTiming.hold)

            // 3. Lifted off the spike — rises, tips, shadow lengthens underneath.
            withAnimation(.easeOut(duration: 0.22)) { beat = .lifted }
            try? await Task.sleep(for: PunchTiming.lift)

            // 4. And away, into the history end of the rail.
            withAnimation(.easeIn(duration: 0.46)) { beat = .gone }
            try? await Task.sleep(for: PunchTiming.away)

            flight = nil
            holeRadius = 0
            beat = .biting
        }
    }

    /// Raise the stub, and take it away again a few seconds later. Replacing one
    /// cancels the previous countdown, so punching twice quickly doesn't have the
    /// first timer pull the second receipt off screen early.
    private func showReceipt(_ new: PunchReceipt) {
        receiptTimer?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            receipt = new
        }
        receiptTimer = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.25)) { receipt = nil }
        }
    }

    private func dismissReceipt() {
        receiptTimer?.cancel()
        withAnimation(.easeIn(duration: 0.2)) { receipt = nil }
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
            // Breathing room *inside* the clip so card shadows aren't shaved off,
            // taken back outside it so the rail keeps its place in the rhythm.
            // Previously this was `.scrollClipDisabled()`, which let a scrolling rail
            // draw its cards straight over the sections above and below it — the page
            // read like an overflowing webview.
            .padding(.vertical, MQ.railShadowRoom)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, -MQ.railShadowRoom)
    }
}
