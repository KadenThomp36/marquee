import SwiftUI

/// Books and manga. Opt-in per user — the whole section only exists once someone
/// switches a tracking feature on in Settings, exactly as the web client does it.
struct ReadingShelfScreen: View {
    /// Filters the shelves. Distinct from `addQuery`, which searches Hardcover and
    /// AniList for things you *don't* have yet.
    var query: String = ""

    @Environment(Session.self) private var session

    @State private var shelves = RemoteData<ReadingShelves>(cacheKey: "reading")
    @State private var active: [ActiveSession] = []
    @State private var kind: ReadingKind = .book
    @State private var addQuery = ""
    @State private var bookResults: [BookSearchResult] = []
    @State private var mangaResults: [MangaSearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var progressTarget: ReadingProgressTarget?
    @State private var showingStats = false
    @State private var undo: UndoToast?
    @State private var incrementTick = 0

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 104, maximum: 150, spacing: 12)

    }

    private var features: UserFeatures? { session.me?.features }

    private var sections: ReadingSections? {
        guard let value = shelves.value else { return nil }
        return kind == .book ? value.books : value.manga
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                kindPicker
                liveSessions
                addField

                if !addQuery.isEmpty { searchResults }

                if let sections {
                    ForEach(ReadingState.shelfOrder, id: \.self) { state in
                        shelf(title(for: state), sections.items(in: state), section: state)
                    }
                    if sections.all.isEmpty {
                        EmptyLine("Nothing on the shelf yet — search above to add your first \(kind == .book ? "book" : "series").")
                    }
                } else if shelves.isEmpty {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonBlock(height: 160, radius: MQ.radiusSmall)
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
                if shelves.isStale { StaleFooter(cachedAt: shelves.cachedAt) }
            }
            .padding(.vertical, 6)
        }
        .refreshable {
            await load(force: true)
            await loadActive()
        }
        .task { await load() }
        .task { await loadActive() }
        .onChange(of: addQuery) { _, new in scheduleSearch(new) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showingStats = true } label: {
                    Image(systemName: "chart.xyaxis.line")
                }
                .accessibilityLabel("Reading stats")
            }
        }
        .sensoryFeedback(.increase, trigger: incrementTick)
        .undoBanner($undo)
        .sheet(isPresented: $showingStats) { ReadingStatsScreen() }
        .sheet(item: $progressTarget) { target in
            ReadingProgressSheet(target: target) { outcome in
                await apply(outcome, to: target)
            }
        }
    }

    // MARK: - Pieces

    private func title(for state: ReadingState) -> String {
        switch state {
        case .reading: "Reading now"
        case .want: "Want to read"
        case .paused: "Paused"
        case .finished: "Finished"
        case .dnf: "Didn\u{2019}t finish"
        }
    }

    @ViewBuilder
    private var kindPicker: some View {
        if features?.tracksBooks == true, features?.tracksManga == true {
            Picker("Kind", selection: $kind) {
                Text("Books").tag(ReadingKind.book)
                Text("Manga").tag(ReadingKind.manga)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MQ.gutter)
        }
    }

    @ViewBuilder
    private var liveSessions: some View {
        if !active.isEmpty {
            VStack(spacing: 8) {
                ForEach(active) { live in
                    HStack(spacing: 10) {
                        Circle().fill(Color.mqBrassFill).frame(width: 8, height: 8)
                        Text(live.title ?? "Reading")
                            .font(.mqSub)
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(1)
                        if let started = MQTime.date(from: live.startedAt) {
                            Text(started, style: .timer)
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqBrass)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 6)
                        Button("End") { progressTarget = target(for: live) }
                            .buttonStyle(.mqChip(on: true))
                    }
                    .padding(11)
                    .background(Color.mqBrassSoft, in: .rect(cornerRadius: MQ.radiusSmall))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Reading \(live.title ?? ""), session running")
                    .accessibilityAction(named: "End session") { progressTarget = target(for: live) }
                }
            }
            .padding(.horizontal, MQ.gutter)
        }
    }

    private var addField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.mqInkMuted)
            TextField(kind == .book ? "Add a book — search Hardcover"
                                    : "Add manga · manhwa · manhua", text: $addQuery)
                .font(.mqBody)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !addQuery.isEmpty {
                Button { addQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.mqInkMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .mqPanel()
        .padding(.horizontal, MQ.gutter)
    }

    @ViewBuilder
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Results").mqEyebrowStyle().padding(.horizontal, MQ.gutter)
            LazyVGrid(columns: columns, spacing: 16) {
                if kind == .book {
                    ForEach(bookResults) { result in
                        AddableTile(cover: result.cover, title: result.displayTitle,
                                    subtitle: [result.author, result.year?.text]
                                        .compactMap { $0 }.filter { !$0.isEmpty }
                                        .joined(separator: " · "),
                                    score: result.communityRating,
                                    route: .bookPreview(result.hcID)) { state in
                            await addBook(result, state: state)
                        }
                    }
                } else {
                    ForEach(mangaResults) { result in
                        AddableTile(cover: result.cover, title: result.displayTitle,
                                    subtitle: [result.origin, result.year?.text]
                                        .compactMap { $0 }.filter { !$0.isEmpty }
                                        .joined(separator: " · "),
                                    score: result.score,
                                    route: .manga(result.id)) { state in
                            await addManga(result, state: state)
                        }
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
        }
    }

    /// Narrow a shelf to the library filter, matching title or author.
    private func matching(_ items: [ReadingItem]) -> [ReadingItem] {
        guard !query.isEmpty else { return items }
        return items.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query)
                || ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    @ViewBuilder
    private func shelf(_ title: String, _ unfiltered: [ReadingItem],
                       section: ReadingState) -> some View {
        let items = matching(unfiltered)
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(title) · \(items.count)").mqEyebrowStyle()
                    .padding(.horizontal, MQ.gutter)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(items) { item in
                        ReadingTile(item: item, kind: kind, section: section,
                                    isLive: liveSession(for: item) != nil) { action in
                            await perform(action, on: item)
                        }
                    }
                }
                .padding(.horizontal, MQ.gutter)
            }
        }
    }

    private func liveSession(for item: ReadingItem) -> ActiveSession? {
        active.first { $0.kind == kind.rawValue && $0.itemID == item.id }
    }

    /// A running session's sheet, seeded with the shelf's copy of the title when we
    /// have it — that's the one with the current position in it.
    private func target(for live: ActiveSession) -> ReadingProgressTarget {
        let sections = live.readingKind == .book ? shelves.value?.books : shelves.value?.manga
        if let item = sections?.all.first(where: { $0.id == live.itemID }) {
            return ReadingProgressTarget(item: item, kind: live.readingKind, live: live)
        }
        return ReadingProgressTarget(session: live, progress: nil)
    }

    // MARK: - Data

    private func load(force: Bool = false) async {
        guard let client = session.client else { return }
        await shelves.load(force: force) { try await client.get("reading", as: ReadingShelves.self) }
        if let value = shelves.value {
            WidgetBridge.publish(reading: value, session: session)
        }
        if features?.tracksBooks != true, features?.tracksManga == true { kind = .manga }
    }

    private func loadActive() async {
        guard let client = session.client else { return }
        active = (try? await client.get("reading/active", as: ActiveSessionsResponse.self))?
            .sessions ?? []
    }

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else {
            bookResults = []
            mangaResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled, let client = session.client else { return }
            if kind == .book {
                let response: BookSearchResponse? = try? await client.get(
                    "books/search", query: ["q": trimmed])
                if !Task.isCancelled { bookResults = response?.results ?? [] }
            } else {
                let response: MangaSearchResponse? = try? await client.get(
                    "manga/search", query: ["q": trimmed])
                if !Task.isCancelled { mangaResults = response?.results ?? [] }
            }
        }
    }

    private func addBook(_ result: BookSearchResult, state: ReadingState) async {
        guard let client = session.client else { return }
        _ = try? await client.post("books/add",
                                   body: AddBookRequest(from: result, state: state),
                                   as: AddedResponse.self)
        addQuery = ""
        await load(force: true)
    }

    private func addManga(_ result: MangaSearchResult, state: ReadingState) async {
        guard let client = session.client else { return }
        _ = try? await client.post("manga/add",
                                   body: AddMangaRequest(id: result.id, state: state),
                                   as: AddedResponse.self)
        addQuery = ""
        await load(force: true)
    }

    private func perform(_ action: ReadingTile.Action, on item: ReadingItem) async {
        guard let client = session.client else { return }
        let path = "\(kind.path)/\(item.id)/state"
        let total = item.total(for: kind)

        switch action {
        case .increment:
            let next = item.incrementedProgress(for: kind)
            // Reaching the end is a decision, not a side effect of "+1": the sheet
            // opens at the last chapter and offers "Finished it".
            if let total, next >= total {
                progressTarget = ReadingProgressTarget(item: item, kind: kind,
                                                       live: liveSession(for: item))
                return
            }
            incrementTick += 1
            shelves.mutate { patch(&$0, item: item, progress: next) }
            do {
                try await client.post(path, body: ReadingStateRequest(progress: next), as: Empty.self)
            } catch {
                OfflineStore.shared.enqueue(PendingWrite(
                    .readingProgress(kind: kind.path, itemID: item.id, progress: next)))
            }
        case .progress:
            progressTarget = ReadingProgressTarget(item: item, kind: kind,
                                                   live: liveSession(for: item))
            return
        case .finish:
            shelves.mutate { patch(&$0, item: item, state: .finished, progress: total) }
            do {
                try await client.post(path,
                                      body: ReadingStateRequest(state: .finished, progress: total),
                                      as: Empty.self)
            } catch {
                OfflineStore.shared.enqueue(PendingWrite(
                    .readingState(kind: kind.path, itemID: item.id, state: "finished")))
            }
        case .move(let state):
            shelves.mutate { patch(&$0, item: item, state: state) }
            do {
                try await client.post(path, body: ReadingStateRequest(state: state), as: Empty.self)
            } catch {
                OfflineStore.shared.enqueue(PendingWrite(
                    .readingState(kind: kind.path, itemID: item.id, state: state.rawValue)))
            }
        case .remove:
            await remove(item)
        }
        if let value = shelves.value { WidgetBridge.publish(reading: value, session: session) }
    }

    /// Removing takes the dates, rating and any live session with it; the undo hands
    /// everything but the session back through `/restore`.
    private func remove(_ item: ReadingItem) async {
        guard let client = session.client else { return }
        let removedKind = kind
        var spot: (state: ReadingState, index: Int)?
        shelves.mutate { value in
            var sections = removedKind == .book ? value.books : value.manga
            if let found = sections.take(item.id) { spot = (found.state, found.index) }
            if removedKind == .book { value.books = sections } else { value.manga = sections }
        }
        active.removeAll { $0.kind == removedKind.rawValue && $0.itemID == item.id }
        do {
            try await client.post("\(removedKind.path)/\(item.id)/state",
                                  body: ReadingStateRequest.remove, as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .readingState(kind: removedKind.path, itemID: item.id, state: "none")))
        }
        let was = spot
        undo = UndoToast(message: "Removed \(item.displayTitle)") {
            shelves.mutate { value in
                var sections = removedKind == .book ? value.books : value.manga
                sections.put(item, in: was?.state ?? item.readingState ?? .want, at: was?.index ?? 0)
                if removedKind == .book { value.books = sections } else { value.manga = sections }
            }
            let request = RestoreReadingRequest(from: item, state: was?.state ?? .want)
            do {
                try await client.post("\(removedKind.path)/\(item.id)/restore",
                                      body: request, as: Empty.self)
            } catch {
                // An older server has no /restore — the plain state write gets the
                // title back on its shelf, if not its dates.
                _ = try? await client.post("\(removedKind.path)/\(item.id)/state",
                                           body: ReadingStateRequest(state: was?.state ?? .want,
                                                                     progress: item.progress),
                                           as: Empty.self)
            }
        }
    }

    /// The sheet saved something — reflect it without a refetch where we can.
    private func apply(_ outcome: ReadingProgressOutcome, to target: ReadingProgressTarget) async {
        switch outcome {
        case .progress(let value), .sessionEnded(let value):
            shelves.mutate { value2 in
                patchByID(&value2, kind: target.kind, id: target.itemID) { item in
                    item.progress = max(value, target.live == nil ? 0 : (item.progress ?? 0))
                }
            }
        case .finished(let total):
            shelves.mutate { value in
                patchByID(&value, kind: target.kind, id: target.itemID, moveTo: .finished) { item in
                    item.progress = total
                    item.state = ReadingState.finished.rawValue
                    if item.finishedAt == nil { item.finishedAt = MQTime.stamp() }
                }
            }
        case .discarded:
            break
        }
        if target.live != nil { await loadActive() }
        if let value = shelves.value { WidgetBridge.publish(reading: value, session: session) }
    }

    private func patchByID(_ value: inout ReadingShelves, kind: ReadingKind, id: Int,
                           moveTo: ReadingState? = nil, change: (inout ReadingItem) -> Void) {
        var sections = kind == .book ? value.books : value.manga
        guard let found = sections.take(id) else { return }
        var item = found.item
        change(&item)
        if let moveTo {
            sections.put(item, in: moveTo)
        } else {
            sections.put(item, in: found.state, at: found.index)
        }
        if kind == .book { value.books = sections } else { value.manga = sections }
    }

    /// Move an item between shelves in place, so the grid doesn't blink on every tap.
    private func patch(_ shelves: inout ReadingShelves, item: ReadingItem,
                       state: ReadingState? = nil, progress: Int? = nil) {
        var sections = kind == .book ? shelves.books : shelves.manga
        guard let found = sections.take(item.id) else { return }
        var moved = found.item
        if let progress { moved.progress = progress }
        if let state {
            moved.state = state.rawValue
            if state == .finished, moved.finishedAt == nil { moved.finishedAt = MQTime.stamp() }
            if state == .reading || state == .finished, moved.startedAt == nil {
                moved.startedAt = MQTime.stamp()
            }
            sections.put(moved, in: state)
        } else {
            sections.put(moved, in: found.state, at: found.index)
        }
        if kind == .book { shelves.books = sections } else { shelves.manga = sections }
    }
}

// MARK: - Tiles

struct ReadingTile: View {
    let item: ReadingItem
    let kind: ReadingKind
    let section: ReadingState
    var isLive = false
    let perform: (Action) async -> Void

    enum Action {
        case increment
        /// Open the progress sheet.
        case progress
        /// The long-press "Mark finished": deliberate, so it may skip the sheet.
        case finish
        case move(ReadingState)
        case remove
    }

    var body: some View {
        NavigationLink(value: kind == .book ? Navigator.Route.book(item.id)
                                            : Navigator.Route.manga(item.id)) {
            VStack(alignment: .leading, spacing: 6) {
                CoverArt(url: item.cover)
                    .overlay(alignment: .topTrailing) {
                        if let rating = item.rating {
                            Text("\(rating)/10")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqBrassOnArt)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .topLeading) { actions.padding(6) }
                    .overlay(alignment: .bottom) { statusStrip }
                    .opacity(section == .dnf ? 0.75 : 1)

                Text(item.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(1)

                if section == .reading, let pace = item.paceLine {
                    Text(pace)
                        .font(MarqueeFont.body(11, .semibold, relativeTo: .caption2))
                        .foregroundStyle(item.newChapters > 0 ? Color.mqBrass : Color.mqInkSoft)
                        .lineLimit(1)
                }

                if section == .reading || section == .paused, item.total(for: kind) != nil {
                    // The bar is the way in to logging progress, as on the web.
                    Button { Task { await perform(.progress) } } label: {
                        ProgressBar(fraction: item.fraction(for: kind), percentLabel: true)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Update progress, \(item.progressLabel(for: kind))")
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Update progress", systemImage: "slider.horizontal.3") {
                Task { await perform(.progress) }
            }
            if section != .reading {
                Button(section == .paused ? "Pick it back up" : "Start reading", systemImage: "book") {
                    Task { await perform(.move(.reading)) }
                }
            }
            if section == .reading {
                Button("Pause", systemImage: "pause") { Task { await perform(.move(.paused)) } }
            }
            if section != .finished {
                Button("Mark finished", systemImage: "checkmark") { Task { await perform(.finish) } }
            }
            if section == .reading || section == .paused {
                Button("Didn\u{2019}t finish", systemImage: "xmark.circle") {
                    Task { await perform(.move(.dnf)) }
                }
            }
            Button("Remove from shelf", systemImage: "trash", role: .destructive) {
                Task { await perform(.remove) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayTitle). \(item.progressLabel(for: kind))")
        .accessibilityAction(named: "Update progress") { Task { await perform(.progress) } }
        .accessibilityAction(named: "Remove from shelf") { Task { await perform(.remove) } }
    }

    private var subtitle: String {
        var parts: [String] = []
        if kind == .book, let author = item.author, !author.isEmpty { parts.append(author) }
        if kind == .manga, let origin = item.origin { parts.append(origin) }
        if section == .reading || section == .paused || section == .dnf {
            parts.append(item.progressLabel(for: kind))
        }
        if section == .finished, let finished = item.finishedAt, !finished.isEmpty {
            parts.append(MQTime.medium(finished))
        }
        return parts.joined(separator: " · ")
    }

    private var statusText: String {
        if isLive { return "Reading now" }
        switch item.readingState {
        case .finished: return "Read"
        case .reading: return "Reading"
        case .paused: return "Paused"
        case .dnf: return "Didn\u{2019}t finish"
        case .want, nil: return "Not read"
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 3) {
            if item.readingState == .finished {
                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
            } else if isLive {
                Circle().fill(Color.mqBrassOnFill).frame(width: 5, height: 5)
            }
            Text(statusText)
        }
        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
        .foregroundStyle(item.readingState == .finished || isLive ? Color.mqBrassOnFill : .white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .background(item.readingState == .finished || isLive ? Color.mqBrassFill.opacity(0.9)
                                                              : Color.mqScrim.opacity(0.75))
    }

    /// The poster carries the move you make often. A "+1" where a chapter is the
    /// unit; otherwise the progress sheet — never a one-tap "finished", which on a
    /// 400-page book is one stray tap from a wrong finish date.
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 6) {
            switch section {
            case .reading:
                if item.supportsIncrement(for: kind) {
                    tileButton("plus", "Read one more chapter") { await perform(.increment) }
                }
                tileButton("slider.horizontal.3", isLive ? "End session" : "Update progress") {
                    await perform(.progress)
                }
            case .want:
                tileButton("book", "Start reading") { await perform(.move(.reading)) }
            case .paused:
                tileButton("play.fill", "Pick it back up") { await perform(.move(.reading)) }
            case .finished, .dnf:
                EmptyView()
            }
        }
    }

    private func tileButton(_ symbol: String, _ label: String,
                            action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.mqInk)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A search result you can put straight on a shelf.
struct AddableTile: View {
    let cover: String?
    let title: String
    let subtitle: String
    let score: Double?
    let route: Navigator.Route
    let add: (ReadingState) async -> Void

    @State private var added = false

    var body: some View {
        NavigationLink(value: route) {
            VStack(alignment: .leading, spacing: 6) {
                CoverArt(url: cover)
                    .overlay(alignment: .topTrailing) {
                        if let score {
                            Label(String(format: "%.1f", score), systemImage: "star.fill")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqBrassOnArt)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if added {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.mqBrassOnArt)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: .circle)
                                .padding(6)
                                .accessibilityLabel("On your shelf")
                        } else {
                            VStack(spacing: 6) {
                                button("bookmark", "Want to read") { await add(.want) }
                                button("book", "Start reading now") { await add(.reading) }
                            }
                            .padding(6)
                        }
                    }

                Text(title)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: added) { _, new in new }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    private func button(_ symbol: String, _ label: String,
                        action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action(); added = true }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.mqInk)
                .frame(width: 28, height: 28)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
