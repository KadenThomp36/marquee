import SwiftUI

/// Books and manga. Opt-in per user — the whole section only exists once someone
/// switches a tracking feature on in Settings, exactly as the web client does it.
struct ReadingShelfScreen: View {
    /// Filters the shelves. Distinct from `query`, which searches Hardcover and
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
    @State private var endingSession: ActiveSession?
    @State private var showingStats = false

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
                    shelf("Reading now", sections.reading, section: .reading)
                    shelf("Want to read", sections.want, section: .want)
                    shelf("Finished", sections.finished, section: .finished)
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
        .refreshable { await load(force: true) }
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
        .sheet(isPresented: $showingStats) { ReadingStatsScreen() }
        .sheet(item: $endingSession) { session in
            EndSessionSheet(session: session) { await load(force: true); await loadActive() }
        }
    }

    // MARK: - Pieces

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
                ForEach(active) { session in
                    HStack(spacing: 10) {
                        Circle().fill(Color.mqBrassFill).frame(width: 8, height: 8)
                        Text(session.title ?? "Reading")
                            .font(.mqSub)
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(1)
                        Text(elapsed(since: session.startedAt))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqBrass)
                            .monospacedDigit()
                        Spacer(minLength: 6)
                        Button("End") { endingSession = session }
                            .buttonStyle(.mqChip(on: true))
                    }
                    .padding(11)
                    .background(Color.mqBrassSoft, in: .rect(cornerRadius: MQ.radiusSmall))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Reading \(session.title ?? ""), for \(elapsed(since: session.startedAt))")
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
                                    route: .book(result.hcID),
                                    isPreview: true) { state in
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
                                    route: .manga(result.id),
                                    isPreview: true) { state in
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
                        ReadingTile(item: item, kind: kind, section: section) { action in
                            await perform(action, on: item)
                        }
                    }
                }
                .padding(.horizontal, MQ.gutter)
            }
        }
    }

    private func elapsed(since stamp: String) -> String {
        guard let started = MQTime.date(from: stamp) else { return "" }
        let minutes = max(1, Int(Date().timeIntervalSince(started) / 60))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
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
            // A book tracked in chapters steps a chapter at a time, and the server
            // still stores pages — so convert on the way out, not on the way back.
            let next: Int
            if kind == .book, item.mode == ProgressMode.chapters.rawValue,
               let pages = item.pages, let chapters = item.chapters, chapters > 0 {
                next = min(pages, Int((Double(item.chapterPosition + 1) / Double(chapters)
                                       * Double(pages)).rounded()))
            } else {
                next = min(total ?? .max, (item.progress ?? 0) + 1)
            }
            shelves.mutate { patch(&$0, item: item, progress: next) }
            do {
                try await client.post(path, body: ReadingStateRequest(progress: next), as: Empty.self)
            } catch {
                OfflineStore.shared.enqueue(PendingWrite(
                    .readingProgress(kind: kind.path, itemID: item.id, progress: next)))
            }
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
        case .start:
            shelves.mutate { patch(&$0, item: item, state: .reading) }
            do {
                try await client.post(path, body: ReadingStateRequest(state: .reading), as: Empty.self)
            } catch {
                OfflineStore.shared.enqueue(PendingWrite(
                    .readingState(kind: kind.path, itemID: item.id, state: "reading")))
            }
        case .remove:
            shelves.mutate { remove(&$0, item: item) }
            do {
                try await client.post(path, body: ReadingStateRequest.remove, as: Empty.self)
            } catch {
                OfflineStore.shared.enqueue(PendingWrite(
                    .readingState(kind: kind.path, itemID: item.id, state: "none")))
            }
        }
        if let value = shelves.value { WidgetBridge.publish(reading: value, session: session) }
    }

    /// Move an item between shelves in place, so the grid doesn't blink on every tap.
    private func patch(_ shelves: inout ReadingShelves, item: ReadingItem,
                       state: ReadingState? = nil, progress: Int? = nil) {
        var sections = kind == .book ? shelves.books : shelves.manga
        var found: ReadingItem?
        for keyPath in [\ReadingSections.reading, \ReadingSections.want, \ReadingSections.finished] {
            if let index = sections[keyPath: keyPath].firstIndex(where: { $0.id == item.id }) {
                found = sections[keyPath: keyPath].remove(at: index)
                break
            }
        }
        guard var moved = found else { return }
        if let progress { moved.progress = progress }
        if let state {
            moved.state = state.rawValue
            if state == .finished, moved.finishedAt == nil { moved.finishedAt = MQTime.stamp() }
            if state != .want, moved.startedAt == nil { moved.startedAt = MQTime.stamp() }
        }
        switch moved.readingState {
        case .reading: sections.reading.insert(moved, at: 0)
        case .want: sections.want.insert(moved, at: 0)
        case .finished: sections.finished.insert(moved, at: 0)
        case nil: break
        }
        if kind == .book { shelves.books = sections } else { shelves.manga = sections }
    }

    private func remove(_ shelves: inout ReadingShelves, item: ReadingItem) {
        var sections = kind == .book ? shelves.books : shelves.manga
        sections.reading.removeAll { $0.id == item.id }
        sections.want.removeAll { $0.id == item.id }
        sections.finished.removeAll { $0.id == item.id }
        if kind == .book { shelves.books = sections } else { shelves.manga = sections }
    }
}

// MARK: - Tiles

struct ReadingTile: View {
    let item: ReadingItem
    let kind: ReadingKind
    let section: ReadingState
    let perform: (Action) async -> Void

    enum Action { case increment, finish, start, remove }

    var body: some View {
        NavigationLink(value: kind == .book ? Navigator.Route.book(item.id)
                                            : Navigator.Route.manga(item.id)) {
            VStack(alignment: .leading, spacing: 6) {
                CoverArt(url: item.cover)
                    .overlay(alignment: .topTrailing) {
                        if let rating = item.rating {
                            Text("\(rating)/10")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqBrass)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .topLeading) { actions.padding(6) }
                    .overlay(alignment: .bottom) { statusStrip }

                Text(item.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(1)

                if section == .reading, item.total(for: kind) != nil {
                    ProgressBar(fraction: item.fraction(for: kind), percentLabel: true)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if section != .reading {
                Button("Start reading", systemImage: "book") { Task { await perform(.start) } }
            }
            if section != .finished {
                Button("Mark finished", systemImage: "checkmark") { Task { await perform(.finish) } }
            }
            Button("Remove from shelf", systemImage: "trash", role: .destructive) {
                Task { await perform(.remove) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayTitle). \(item.progressLabel(for: kind))")
        .accessibilityAction(named: "Remove from shelf") { Task { await perform(.remove) } }
    }

    private var subtitle: String {
        var parts: [String] = []
        if kind == .book, let author = item.author, !author.isEmpty { parts.append(author) }
        if kind == .manga, let origin = item.origin { parts.append(origin) }
        if section == .reading { parts.append(item.progressLabel(for: kind)) }
        if section == .finished, let finished = item.finishedAt, !finished.isEmpty {
            parts.append(MQTime.medium(finished))
        }
        return parts.joined(separator: " · ")
    }

    private var statusStrip: some View {
        HStack(spacing: 3) {
            if item.readingState == .finished {
                Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
            }
            Text(item.readingState == .finished ? "Read"
                 : item.readingState == .reading ? "Reading" : "Not read")
        }
        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
        .foregroundStyle(item.readingState == .finished ? Color.mqBrassOnFill : .white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .background(item.readingState == .finished ? Color.mqBrassFill.opacity(0.9)
                                                   : Color.mqScrim.opacity(0.75))
    }

    /// The poster carries the move you make often; removing something from the shelf
    /// is a long press, not a button on the artwork.
    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 6) {
            switch section {
            case .reading:
                if item.supportsIncrement(for: kind) {
                    tileButton("plus", "Read one more chapter") { await perform(.increment) }
                }
                tileButton("checkmark", "Finished it") { await perform(.finish) }
            case .want:
                tileButton("book", "Start reading") { await perform(.start) }
            case .finished:
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
private struct AddableTile: View {
    let cover: String?
    let title: String
    let subtitle: String
    let score: Double?
    let route: Navigator.Route
    let isPreview: Bool
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
                                .foregroundStyle(Color.mqBrass)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        if added {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.mqBrass)
                                .frame(width: 28, height: 28)
                                .background(.ultraThinMaterial, in: .circle)
                                .padding(6)
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

/// "Where did you get to?" — the only question ending a session asks.
struct EndSessionSheet: View {
    let session: ActiveSession
    let onDone: () async -> Void

    @Environment(Session.self) private var appSession
    @Environment(\.dismiss) private var dismiss
    @State private var position = 0

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(alignment: .leading, spacing: 18) {
                    Text(session.title ?? "")
                        .font(MarqueeFont.body(19, .bold, relativeTo: .title3))
                        .foregroundStyle(Color.mqInk)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Where did you get to?").mqEyebrowStyle()
                        HStack(spacing: 10) {
                            Button { position = max(0, position - 1) } label: {
                                Image(systemName: "minus").frame(width: 38, height: 38)
                            }
                            .buttonStyle(.mqChip)

                            TextField("0", value: $position, format: .number)
                                .keyboardType(.numberPad)
                                .font(MarqueeFont.body(22, .bold, relativeTo: .title2))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .mqPanel()

                            Button {
                                position = min(session.total ?? .max, position + 1)
                            } label: {
                                Image(systemName: "plus").frame(width: 38, height: 38)
                            }
                            .buttonStyle(.mqChip)
                        }
                        Text(session.total.map { "of \($0) \(session.readingKind.unit)" }
                             ?? session.readingKind.unit)
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                    }

                    Button("Save session") { Task { await end(discard: false) } }
                        .buttonStyle(.mqPrimary)

                    Button("Discard this session") { Task { await end(discard: true) } }
                        .buttonStyle(.mqQuiet)
                        .frame(maxWidth: .infinity)

                    Spacer()
                }
                .padding(MQ.gutter)
            }
            .navigationTitle("End session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationDetents([.height(400)])
        .presentationBackground(Color.mqGround)
        .onAppear { position = session.startPos ?? 0 }
    }

    private func end(discard: Bool) async {
        guard let client = appSession.client else { return }
        _ = try? await client.post("\(session.kind)/\(session.itemID)/session/end",
                                   body: EndSessionRequest(pos: discard ? nil : position,
                                                           discard: discard ? true : nil),
                                   as: Empty.self)
        await onDone()
        dismiss()
    }
}
