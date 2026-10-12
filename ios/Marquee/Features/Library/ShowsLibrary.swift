import SwiftUI

/// The shelves a followed show can sit on — `GET /api/shows`.
enum ShowShelf: String, CaseIterable, Identifiable {
    case watchlist
    case watching
    case caughtUp = "caught_up"
    case finished
    case stopped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watchlist: "Watchlist"
        case .watching: "Watching"
        case .caughtUp: "Caught up"
        case .finished: "Finished"
        case .stopped: "Stopped"
        }
    }

    var emptyMessage: String {
        switch self {
        case .watchlist: "Your watchlist is empty — add shows from Search and they wait here until you start one."
        case .watching: "Nothing in progress. Start something from your watchlist."
        case .caughtUp: "No show is waiting on new episodes."
        case .finished: "No finished series yet."
        case .stopped: "You haven't stopped watching anything."
        }
    }
}

extension ShowShelves {
    func cards(on shelf: ShowShelf) -> [ShowCard] {
        switch shelf {
        case .watchlist: watchlist
        case .watching: watching
        case .caughtUp: caughtUp
        case .finished: finished
        case .stopped: stopped
        }
    }

    mutating func setCards(_ cards: [ShowCard], on shelf: ShowShelf) {
        switch shelf {
        case .watchlist: watchlist = cards
        case .watching: watching = cards
        case .caughtUp: caughtUp = cards
        case .finished: finished = cards
        case .stopped: stopped = cards
        }
    }

    /// Lift a show off whichever shelf it's on, remembering where it was so an undo
    /// can put it back in the same spot.
    mutating func take(_ id: Int) -> (shelf: ShowShelf, index: Int, card: ShowCard)? {
        for shelf in ShowShelf.allCases {
            var row = self.cards(on: shelf)
            if let index = row.firstIndex(where: { $0.id == id }) {
                let card = row.remove(at: index)
                setCards(row, on: shelf)
                return (shelf, index, card)
            }
        }
        return nil
    }

    mutating func put(_ card: ShowCard, on shelf: ShowShelf, at index: Int = 0) {
        var row = self.cards(on: shelf)
        row.insert(card, at: min(max(0, index), row.count))
        setCards(row, on: shelf)
    }
}

/// Every show you follow, shelved — and the watchlist, which is the one thing the
/// household asked for most: somewhere to see all the shows they've added and haven't
/// started.
///
/// A real `List`, unlike the poster grids beside it, because a watchlist row is
/// something you act on: swipe to remove (with an undo), a big Start button off the
/// art, a long press for everything else.
struct ShowsShelf: View {
    var query: String = ""
    /// Opened from Home's watchlist rail: start on that shelf.
    var initialShelf: ShowShelf?

    @Environment(Session.self) private var session
    @State private var data = RemoteData<ShowShelves>(cacheKey: "shows-library")
    @AppStorage("library.showShelf") private var shelf: ShowShelf = .watchlist
    /// The server predates `/api/shows` — fall back to the old watched grid.
    @State private var legacy = false
    @State private var appliedInitial = false
    @State private var undo: UndoToast?
    @State private var receipt: PunchReceipt?
    @State private var punchTick = 0
    @State private var dealing = false
    @State private var dealtPick: Int?
    @State private var openedShow: Int?
    @State private var confirmingRemove: ShowCard?

    var body: some View {
        if legacy {
            LegacyShowsGrid(query: query)
        } else {
            shelves
        }
    }

    private var shelves: some View {
        VStack(spacing: 0) {
            shelfPicker
                .padding(.bottom, 6)

            List {
                if let value = data.value {
                    content(value)
                } else if data.isEmpty {
                    ForEach(0..<6, id: \.self) { _ in
                        SkeletonBlock(height: 92).shelfRow()
                    }
                } else if let error = data.error {
                    LoadFailure(message: error) { await load(force: true) }.shelfRow()
                }
                if data.isStale { StaleFooter(cachedAt: data.cachedAt).shelfRow() }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .refreshable { await load(force: true) }
        }
        .task { await load() }
        .onAppear {
            if let initialShelf, !appliedInitial {
                shelf = initialShelf
                appliedInitial = true
            }
        }
        .sensoryFeedback(.success, trigger: punchTick)
        .overlay(alignment: .bottom) {
            if let current = receipt {
                PunchReceiptBanner(receipt: current) {
                    withAnimation(.easeIn(duration: 0.2)) { receipt = nil }
                }
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: current.id) { [id = current.id] in
                    try? await Task.sleep(for: .seconds(5))
                    guard !Task.isCancelled, receipt?.id == id else { return }
                    withAnimation(.easeIn(duration: 0.25)) { receipt = nil }
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: receipt?.id)
        .undoBanner($undo)
        .sheet(isPresented: $dealing, onDismiss: {
            if let pick = dealtPick {
                dealtPick = nil
                openedShow = pick
            }
        }) {
            DealSheet(pool: dealPool) { id in
                dealtPick = id
                dealing = false
            }
        }
        .navigationDestination(item: $openedShow) { id in
            ShowScreen(showID: id)
        }
        .confirmationDialog("Remove \(confirmingRemove?.displayTitle ?? "this show")?",
                            isPresented: .init(get: { confirmingRemove != nil },
                                               set: { if !$0 { confirmingRemove = nil } }),
                            titleVisibility: .visible) {
            if let card = confirmingRemove {
                Button("Remove and delete watch history", role: .destructive) {
                    Task { await remove(card) }
                    confirmingRemove = nil
                }
                Button("Cancel", role: .cancel) { confirmingRemove = nil }
            }
        } message: {
            Text("This removes the show and every episode you've marked watched. It can't be undone.")
        }
    }

    // MARK: - Pieces

    /// Five shelves don't fit a segmented control with counts on a phone, so they're
    /// chips — scrolled, not squeezed.
    private var shelfPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(ShowShelf.allCases) { option in
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { shelf = option }
                    } label: {
                        HStack(spacing: 5) {
                            Text(option.title)
                            if let count = count(option) {
                                Text("\(count)")
                                    .monospacedDigit()
                                    .opacity(0.7)
                            }
                        }
                        .lineLimit(1)
                    }
                    .buttonStyle(.mqChip(on: shelf == option))
                    .accessibilityAddTraits(shelf == option ? .isSelected : [])
                }
            }
            .padding(.horizontal, MQ.gutter)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: shelf)
    }

    @ViewBuilder
    private func content(_ value: ShowShelves) -> some View {
        let cards = filtered(value.cards(on: shelf))

        if shelf == .watchlist {
            if query.isEmpty, !dealPool.isEmpty {
                dealButton.shelfRow(top: 2, bottom: 8)
            }
            ForEach(groups(cards)) { group in
                Section {
                    ForEach(group.cards) { card in row(card) }
                } header: {
                    groupHeader(group)
                }
            }
        } else {
            ForEach(cards) { card in row(card) }
        }

        if cards.isEmpty {
            EmptyLine(query.isEmpty
                      ? shelf.emptyMessage
                      : "No show on this shelf matches \u{201C}\(query)\u{201D}.")
                .shelfRow()
        }
    }

    private func row(_ card: ShowCard) -> some View {
        ShowShelfRow(card: card, shelf: shelf,
                     onOpen: { openedShow = card.id },
                     onStart: { await start(card) })
            .shelfRow(top: 7, bottom: 7)
            .swipeActions(edge: .trailing, allowsFullSwipe: card.watched == 0) {
                Button { requestRemove(card) } label: {
                    Label("Remove", systemImage: "trash")
                }
                .tint(Color.mqVelvet)
                if shelf == .watching {
                    Button { Task { await setArchived(card, true) } } label: {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .tint(Color.mqInkMuted)
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if shelf == .stopped {
                    Button { Task { await setArchived(card, false) } } label: {
                        Label("Resume", systemImage: "play.circle")
                    }
                    .tint(Color.mqBrassFill)
                }
            }
            .contextMenu {
                if let episode = card.nextEp, shelf != .stopped {
                    Button(startLabel(card, episode), systemImage: "checkmark") {
                        Task { await start(card) }
                    }
                }
                if shelf == .watching || shelf == .caughtUp {
                    Button("Stop watching", systemImage: "stop.circle") {
                        Task { await setArchived(card, true) }
                    }
                }
                if shelf == .stopped {
                    Button("Resume watching", systemImage: "play.circle") {
                        Task { await setArchived(card, false) }
                    }
                }
                Button(removeLabel(card), systemImage: "trash", role: .destructive) {
                    requestRemove(card)
                }
            }
            .accessibilityAction(named: Text(removeLabel(card))) {
                requestRemove(card)
            }
    }

    private func startLabel(_ card: ShowCard, _ episode: NextEpisode) -> String {
        card.watched == 0 ? "Start — mark \(episode.code) watched" : "Mark \(episode.code) watched"
    }

    private func removeLabel(_ card: ShowCard) -> String {
        card.watched == 0 ? "Remove from watchlist" : "Remove and delete watch history"
    }

    private func groupHeader(_ group: WatchlistSection) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(group.group.title).mqEyebrowStyle()
            Spacer(minLength: 6)
            Text([String(group.cards.count), LibraryFormat.hours(group.minutes)]
                    .compactMap { $0 }.joined(separator: " · "))
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .monospacedDigit()
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var dealButton: some View {
        Button { dealing = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "dice")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.mqBrass)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Can\u{2019}t decide?")
                        .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                    Text("Deal three from what you could start tonight")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mqInkMuted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mqPanel()
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Derived

    private struct WatchlistSection: Identifiable {
        let group: ShowCard.WatchlistGroup
        let cards: [ShowCard]
        var id: String { group.rawValue }
        var minutes: Double { cards.reduce(0) { $0 + ($1.totalMin ?? 0) } }
    }

    private func groups(_ cards: [ShowCard]) -> [WatchlistSection] {
        ShowCard.WatchlistGroup.allCases.compactMap { group in
            let members = cards.filter { $0.watchlistGroup == group }
            return members.isEmpty ? nil : WatchlistSection(group: group, cards: members)
        }
    }

    private func filtered(_ cards: [ShowCard]) -> [ShowCard] {
        guard !query.isEmpty else { return cards }
        return cards.filter { $0.displayTitle.localizedCaseInsensitiveContains(query) }
    }

    private func count(_ option: ShowShelf) -> Int? {
        data.value.map { filtered($0.cards(on: option)).count }
    }

    /// "Can't decide?" deals from what you could start tonight — nothing still to come.
    private var dealPool: [ShowCard] {
        (data.value?.watchlist ?? []).filter { $0.watchlistGroup == .binge }
    }

    /// Where a show belongs after its state changed under it.
    private func home(for card: ShowCard) -> ShowShelf {
        if card.watched == 0 { return .watchlist }
        if card.nextEp != nil || card.remaining > 0 { return .watching }
        return card.isEnded ? .finished : .caughtUp
    }

    // MARK: - Loading

    private func load(force: Bool = false) async {
        guard let client = session.client else { return }
        await data.load(force: force) {
            try await client.get("shows", as: ShowShelves.self)
        }
        // Nothing to show and the fetch failed: is this a server from before shelves?
        if data.value == nil, data.error != nil {
            do {
                _ = try await client.get("shows", as: Empty.self)
            } catch APIError.http(let status, _) where status == 404 {
                legacy = true
            } catch {}
        }
    }

    // MARK: - Actions

    /// Mark the next episode watched — on the watchlist that's "start it" — and move
    /// the show to wherever it now belongs.
    private func start(_ card: ShowCard) async {
        guard let episode = card.nextEp, let client = session.client else { return }
        punchTick += 1
        undo = nil
        receipt = PunchReceipt(showID: card.id,
                               season: episode.season,
                               number: episode.number,
                               showTitle: card.displayTitle,
                               episodeTitle: episode.title,
                               code: episode.code,
                               art: card.poster)
        do {
            let response: MarkResponse = try await client.post(
                "show/\(card.id)/watch",
                body: MarkEpisodeRequest(season: episode.season, number: episode.number),
                as: MarkResponse.self)
            let updated = response.show.map { card.merged(with: $0) } ?? advancedLocally(card)
            withAnimation(.snappy) { data.mutate { reshelve(updated, in: &$0) } }
            if let earned = response.celebrate, !earned.isEmpty {
                session.enqueue(earned)
            }
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .markEpisode(showID: card.id, season: episode.season,
                             number: episode.number, unwatch: false, previous: false)))
            withAnimation(.snappy) { data.mutate { reshelve(advancedLocally(card), in: &$0) } }
        }
    }

    private func reshelve(_ card: ShowCard, in shelves: inout ShowShelves) {
        _ = shelves.take(card.id)
        shelves.put(card, on: home(for: card))
    }

    /// The same advance, worked out here, for when the server never answered. The
    /// next episode isn't knowable without the catalogue, so the card loses its
    /// button until the next sync.
    private func advancedLocally(_ card: ShowCard) -> ShowCard {
        var out = card
        out.watched = min(card.watched + 1, max(card.aired, card.watched + 1))
        out.remaining = max(card.remaining - 1, 0)
        out.lastWatched = MQTime.stamp()
        out.nextEp = nil
        out.stale = false
        return out
    }

    /// Removing something you never started is harmless, so it happens at once and
    /// offers an undo. Removing a show you've watched deletes its history — that asks.
    private func requestRemove(_ card: ShowCard) {
        if card.watched == 0 {
            Task { await remove(card) }
        } else {
            confirmingRemove = card
        }
    }

    private func remove(_ card: ShowCard) async {
        guard let client = session.client else { return }
        var spot: (shelf: ShowShelf, index: Int)?
        withAnimation(.snappy) {
            data.mutate { shelves in
                if let found = shelves.take(card.id) { spot = (found.shelf, found.index) }
            }
        }
        let removedFrom = spot
        do {
            try await client.post("show/\(card.id)/follow",
                                  body: FollowRequest(unfollow: true), as: Empty.self)
        } catch {
            // Didn't happen — put it back rather than pretend.
            if let removedFrom {
                withAnimation(.snappy) {
                    data.mutate { $0.put(card, on: removedFrom.shelf, at: removedFrom.index) }
                }
            }
            return
        }
        receipt = nil
        // Watch history went with it; an undo couldn't honestly bring that back.
        guard card.watched == 0 else { return }
        undo = UndoToast(message: "Removed \(card.displayTitle)") {
            withAnimation(.snappy) {
                data.mutate {
                    $0.put(card, on: removedFrom?.shelf ?? .watchlist, at: removedFrom?.index ?? 0)
                }
            }
            // Handing back added_at keeps it in its place on the watchlist.
            _ = try? await client.post("show/\(card.id)/follow",
                                       body: FollowRequest(addedAt: card.addedAt),
                                       as: Empty.self)
        }
    }

    private func setArchived(_ card: ShowCard, _ archived: Bool) async {
        guard let client = session.client else { return }
        withAnimation(.snappy) {
            data.mutate { shelves in
                _ = shelves.take(card.id)
                shelves.put(card, on: archived ? .stopped : home(for: card))
            }
        }
        do {
            try await client.post("show/\(card.id)/follow",
                                  body: FollowRequest(archived: archived), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(.archiveShow(showID: card.id, archived: archived)))
        }
        if archived {
            receipt = nil
            undo = UndoToast(message: "Stopped watching \(card.displayTitle)") {
                await setArchived(card, false)
            }
        }
    }
}

private extension View {
    /// A List row that draws nothing of its own — the content brings its own panel.
    func shelfRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
        listRowInsets(EdgeInsets(top: top, leading: MQ.gutter, bottom: bottom, trailing: MQ.gutter))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

// MARK: - The row

/// Poster, the size of the commitment, where it streams, who else is into it — and a
/// big button off the art that starts it.
struct ShowShelfRow: View {
    let card: ShowCard
    let shelf: ShowShelf
    /// The accessibility path into the show; touch goes through the row's link.
    let onOpen: () -> Void
    let onStart: () async -> Void

    @State private var busy = false

    var body: some View {
        ZStack {
            // A hidden link makes the whole row the way into the show without List
            // drawing a disclosure chevron beside the Start button.
            NavigationLink(value: Navigator.Route.show(card.id)) { EmptyView() }
                .opacity(0)
                .accessibilityHidden(true)

            HStack(alignment: .center, spacing: 12) {
                // For VoiceOver the poster and text are one button that opens the
                // show; the Start button stays its own element beside it.
                HStack(alignment: .center, spacing: 12) {
                    PosterArt(url: card.poster, radius: 8)
                        .frame(width: 62)
                        .opacity(shelf == .stopped ? 0.7 : 1)
                    info
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { onOpen() }

                trailing
            }
        }
    }

    private var accessibilitySummary: String {
        var parts = [card.displayTitle, meta]
        if let when { parts.append(when) }
        if let provider = card.prov?.name, !provider.isEmpty { parts.append("on \(provider)") }
        if let imdb = card.imdb, imdb > 0 { parts.append("IMDb \(String(format: "%.1f", imdb))") }
        if let household = HouseholdSummary.show(card) { parts.append(household.text) }
        return parts.joined(separator: ". ")
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(card.displayTitle)
                    .font(MarqueeFont.body(15, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                if card.stale == true, shelf == .watching {
                    Text("Paused")
                        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(Color.mqInkMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.mqHairlineBold, lineWidth: 1))
                }
            }

            Text(meta)
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkSoft)
                .lineLimit(2)

            if shelf == .watching, card.aired > 0 {
                ProgressBar(fraction: card.progress, height: 4)
                    .frame(maxWidth: 200)
            }

            if let when {
                Text(when)
                    .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.mqBrass)
                    .lineLimit(1)
            }

            ProviderScoreLine(provider: card.prov?.name, network: card.network,
                              imdb: card.imdb, vote: card.vote)

            if let household = HouseholdSummary.show(card) {
                HouseholdLine(summary: household)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var trailing: some View {
        if let episode = card.nextEp, shelf == .watchlist || shelf == .watching {
            Button {
                guard !busy else { return }
                busy = true
                Task {
                    await onStart()
                    busy = false
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: card.watched == 0 ? "play.fill" : "checkmark")
                        .font(.system(size: 17, weight: .bold))
                    Text(card.watched == 0 ? "Start" : "S\(episode.season) E\(episode.number)")
                        .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .foregroundStyle(Color.mqBrassOnFill)
                .frame(width: 64, height: 60)
                .background(Color.mqBrassFill, in: .rect(cornerRadius: 14))
                .contentShape(.rect(cornerRadius: 14))
                .opacity(busy ? 0.5 : 1)
                .scaleEffect(busy ? 0.94 : 1)
                .animation(.spring(duration: 0.25), value: busy)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(card.watched == 0
                                ? "Start \(card.displayTitle). Marks \(episode.code) watched."
                                : "Mark \(episode.code) of \(card.displayTitle) watched")
        } else if card.aired == 0, let next = card.nextAir, !next.isEmpty {
            VStack(spacing: 3) {
                Image(systemName: "bell")
                    .font(.system(size: 15, weight: .semibold))
                Text(MQTime.short(next))
                    .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.mqInkMuted)
            .frame(width: 64, height: 60)
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mqHairline, lineWidth: 1))
            .accessibilityHidden(true)
        }
    }

    /// "2 seasons · 19 eps · ~16 hrs", or for something under way,
    /// "S2 · E4 next · 5 left · ~4 hrs".
    private var meta: String {
        if shelf == .watching {
            guard let episode = card.nextEp else { return "\(card.watched) / \(card.aired) watched" }
            return ["\(episode.code) next", "\(card.remaining) left", LibraryFormat.hours(card.leftMin)]
                .compactMap { $0 }.joined(separator: " · ")
        }
        if card.aired == 0 {
            if let announced = card.nEpisodes, announced > 0 { return "\(announced) episodes announced" }
            return card.network ?? "Not out yet"
        }
        var parts: [String] = []
        if let seasons = card.seasons, seasons > 0 {
            parts.append("\(seasons) season\(seasons == 1 ? "" : "s")")
        }
        parts.append("\(card.aired) ep\(card.aired == 1 ? "" : "s")")
        if shelf != .watchlist, card.watched > 0, card.watched < card.aired {
            parts.append("\(card.watched) watched")
        }
        if let hours = LibraryFormat.hours(card.totalMin) { parts.append(hours) }
        return parts.joined(separator: " · ")
    }

    private var when: String? {
        guard let next = card.nextAir, !next.isEmpty else { return nil }
        if card.aired == 0 { return "Premieres \(MQTime.upcomingLabel(next))" }
        guard shelf != .stopped, shelf != .finished else { return nil }
        return "New episode \(MQTime.upcomingLabel(next))"
    }
}

// MARK: - Can't decide?

/// Three, not thirty: dealt from what you could start tonight.
struct DealSheet: View {
    let pool: [ShowCard]
    let onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hand: [ShowCard] = []
    @State private var deals = 0

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(spacing: 20) {
                    Text("Tonight, maybe\u{2026}")
                        .font(MarqueeFont.wordmark(24, relativeTo: .title2))
                        .foregroundStyle(Color.mqBrass)
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .top, spacing: 12) {
                        ForEach(hand) { card in
                            Button { onPick(card.id) } label: { dealtCard(card) }
                                .buttonStyle(.plain)
                                .transition(dealTransition)
                        }
                    }
                    .frame(maxWidth: 460)

                    Button { deal() } label: {
                        Label("Deal again", systemImage: "dice")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.mqChip)
                    .disabled(pool.count <= hand.count)

                    Spacer(minLength: 0)
                }
                .padding(MQ.gutter)
            }
            .navigationTitle("Can\u{2019}t decide?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.mqGround)
        .sensoryFeedback(.impact(weight: .light), trigger: deals)
        .onAppear { if hand.isEmpty { deal() } }
    }

    private var dealTransition: AnyTransition {
        if reduceMotion { return AnyTransition.opacity }
        return AnyTransition.asymmetric(
            insertion: AnyTransition.scale(scale: 0.85).combined(with: AnyTransition.opacity),
            removal: AnyTransition.opacity)
    }

    private func dealtCard(_ card: ShowCard) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            PosterArt(url: card.poster)
            Text(card.displayTitle)
                .font(.mqTile)
                .foregroundStyle(Color.mqInk)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
            Text(LibraryFormat.hours(card.totalMin) ?? "\(card.aired) eps")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .lineLimit(1)
            if let provider = card.prov?.name, !provider.isEmpty {
                Text(provider)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoft)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the show")
    }

    private func deal() {
        let next = Array(pool.shuffled().prefix(3))
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.75)) {
            hand = next
        }
        deals += 1
    }
}

/// The watchlist on its own page — where Home's "On your watchlist" rail leads.
struct ShowsShelfScreen: View {
    var shelf: ShowShelf = .watchlist

    var body: some View {
        MarqueeScreen {
            ShowsShelf(initialShelf: shelf)
                .padding(.top, 6)
        }
        .navigationTitle("Your shows")
        .navigationBarTitleDisplayMode(.inline)
    }
}
