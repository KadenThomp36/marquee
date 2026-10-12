import SwiftUI

/// Search, and — when you haven't typed anything — the discovery rails behind it:
/// trending, "because you watched X", the acclaimed shelves.
///
/// Every tile carries what you already know about the title: whether you follow it,
/// whether it's on a shelf, and whether it's already on one of your lists.
struct SearchScreen: View {
    var initialQuery: String = ""

    @Environment(Session.self) private var session
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var discover = RemoteData<DiscoverResponse>(cacheKey: "discover")
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    /// Books and manga, for someone with reading switched on.
    @State private var bookResults: [BookSearchResult] = []
    @State private var mangaResults: [MangaSearchResult] = []
    @State private var scope: Scope = .all

    enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case screen = "Shows & films"
        case books = "Books"
        case manga = "Manga"
        var id: String { rawValue }
    }

    private var features: UserFeatures? { session.me?.features }

    /// The scopes worth offering — none at all unless reading is on.
    private var scopes: [Scope] {
        var out: [Scope] = [.all, .screen]
        if features?.tracksBooks == true { out.append(.books) }
        if features?.tracksManga == true { out.append(.manga) }
        return out.count > 2 ? out : []
    }

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 108, maximum: 160, spacing: 13)

    }

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if query.trimmingCharacters(in: .whitespaces).count >= 2 {
                        resultsGrid
                    } else {
                        discoverRails
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .mqTopEdgeBlur()
            .mqBareNavigationBar()
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: Text(searchPrompt))
        .onChange(of: query) { _, new in scheduleSearch(new) }
        .task {
            if !initialQuery.isEmpty { query = initialQuery }
            await loadDiscover()
            await session.refreshListMembership()
        }
    }

    private var searchPrompt: String {
        features?.tracksReading == true ? "Shows, films & books" : "Shows & films"
    }

    private var showsScreen: Bool { scope == .all || scope == .screen }
    private var showsBooks: Bool {
        features?.tracksBooks == true && (scope == .all || scope == .books)
    }
    private var showsManga: Bool {
        features?.tracksManga == true && (scope == .all || scope == .manga)
    }

    private var nothingFound: Bool {
        (!showsScreen || results.isEmpty)
            && (!showsBooks || bookResults.isEmpty)
            && (!showsManga || mangaResults.isEmpty)
    }

    @ViewBuilder
    private var resultsGrid: some View {
        if !scopes.isEmpty {
            Picker("Search in", selection: $scope) {
                ForEach(scopes) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, MQ.gutter)
        }

        if searching, nothingFound {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<9, id: \.self) { _ in
                    SkeletonBlock(height: 170, radius: MQ.radiusSmall)
                }
            }
            .padding(.horizontal, MQ.gutter)
        } else if nothingFound {
            EmptyLine("No matches for “\(query)”.")
        } else {
            // With everything in one list, each kind gets a heading; a single
            // scope doesn't need one.
            let headed = scope == .all && !scopes.isEmpty

            if showsScreen, !results.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if headed {
                        SectionHeader("Shows & films", count: "\(results.count)")
                            .padding(.horizontal, MQ.gutter)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(results) { result in
                            QuickAddTile(result: result) { await add(result, state: $0) }
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
            }

            if showsBooks, !bookResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if headed {
                        SectionHeader("Books", count: "\(bookResults.count)")
                            .padding(.horizontal, MQ.gutter)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(bookResults) { book in
                            AddableTile(cover: book.cover, title: book.displayTitle,
                                        subtitle: [book.author, book.year?.text]
                                            .compactMap { $0 }.filter { !$0.isEmpty }
                                            .joined(separator: " · "),
                                        score: book.communityRating,
                                        route: .bookPreview(book.hcID)) { state in
                                await addBook(book, state: state)
                            }
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
            }

            if showsManga, !mangaResults.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    if headed {
                        SectionHeader("Manga", count: "\(mangaResults.count)")
                            .padding(.horizontal, MQ.gutter)
                    }
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(mangaResults) { series in
                            AddableTile(cover: series.cover, title: series.displayTitle,
                                        subtitle: [series.origin, series.year?.text]
                                            .compactMap { $0 }.filter { !$0.isEmpty }
                                            .joined(separator: " · "),
                                        score: series.score,
                                        route: .manga(series.id)) { state in
                                await addManga(series, state: state)
                            }
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
            }
        }
    }

    @ViewBuilder
    private var discoverRails: some View {
        if let sections = discover.value?.sections {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    PlainRailHeader(title: section.title)
                    HorizontalRail {
                        ForEach(section.items) { item in
                            QuickAddTile(result: item) { await add(item, state: $0) }
                                .frame(width: MQ.tileWidth)
                        }
                    }
                }
            }
        } else if discover.isEmpty {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        SkeletonBlock(height: 16, radius: 5).frame(width: 170)
                        HorizontalRail {
                            ForEach(0..<5, id: \.self) { _ in
                                SkeletonBlock(height: 186, radius: MQ.radiusSmall)
                                    .frame(width: MQ.tileWidth)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
        } else {
            EmptyLine("Nothing to suggest yet — follow a few shows first.")
        }
    }

    // MARK: - Actions

    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            bookResults = []
            mangaResults = []
            searching = false
            return
        }
        searching = true
        // Hardcover and AniList want a little more to go on than TMDB does.
        let wantsBooks = features?.tracksBooks == true && trimmed.count >= 3
        let wantsManga = features?.tracksManga == true && trimmed.count >= 3
        searchTask = Task {
            // Type-ahead, but not a request per keystroke.
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled, let client = session.client else { return }
            async let screen = Self.fetchScreen(client, trimmed)
            async let books = Self.fetchBooks(client, trimmed, enabled: wantsBooks)
            async let manga = Self.fetchManga(client, trimmed, enabled: wantsManga)
            let (foundScreen, foundBooks, foundManga) = await (screen, books, manga)
            guard !Task.isCancelled else { return }
            results = foundScreen
            bookResults = foundBooks
            mangaResults = foundManga
            searching = false
        }
    }

    private nonisolated static func fetchScreen(_ client: MarqueeClient,
                                                _ query: String) async -> [SearchResult] {
        (try? await client.get("search", query: ["q": query], as: SearchResponse.self))?.results ?? []
    }

    private nonisolated static func fetchBooks(_ client: MarqueeClient, _ query: String,
                                               enabled: Bool) async -> [BookSearchResult] {
        guard enabled else { return [] }
        return (try? await client.get("books/search", query: ["q": query],
                                      as: BookSearchResponse.self))?.results ?? []
    }

    private nonisolated static func fetchManga(_ client: MarqueeClient, _ query: String,
                                               enabled: Bool) async -> [MangaSearchResult] {
        guard enabled else { return [] }
        return (try? await client.get("manga/search", query: ["q": query],
                                      as: MangaSearchResponse.self))?.results ?? []
    }

    /// Straight onto the Want to read shelf — or Reading, from the tile's second button.
    private func addBook(_ result: BookSearchResult, state: ReadingState) async {
        guard let client = session.client else { return }
        _ = try? await client.post("books/add",
                                   body: AddBookRequest(from: result, state: state),
                                   as: AddedResponse.self)
    }

    private func addManga(_ result: MangaSearchResult, state: ReadingState) async {
        guard let client = session.client else { return }
        _ = try? await client.post("manga/add",
                                   body: AddMangaRequest(id: result.id, state: state),
                                   as: AddedResponse.self)
    }

    private func loadDiscover() async {
        guard let client = session.client else { return }
        await discover.load {
            try await client.get("discover", as: DiscoverResponse.self)
        }
    }

    /// Follow a show, or shelve a film, straight from the tile.
    private func add(_ result: SearchResult, state: String) async {
        guard let client = session.client else { return }
        _ = try? await client.post("add",
                                   body: AddRequest(type: result.type, id: result.id,
                                                    state: result.isShow ? nil : state),
                                   as: Empty.self)
        // Reflect it on the tile immediately.
        if let index = results.firstIndex(where: { $0.id == result.id && $0.type == result.type }) {
            if result.isShow { results[index].followed = true } else { results[index].state = state }
        }
        if var sections = discover.value?.sections {
            for sectionIndex in sections.indices {
                if let itemIndex = sections[sectionIndex].items.firstIndex(where: {
                    $0.id == result.id && $0.type == result.type
                }) {
                    if result.isShow { sections[sectionIndex].items[itemIndex].followed = true }
                    else { sections[sectionIndex].items[itemIndex].state = state }
                }
            }
            discover.replace(DiscoverResponse(sections: sections))
        }
    }
}

/// A poster tile with the one or two actions that make sense for its type.
struct QuickAddTile: View {
    let result: SearchResult
    let add: (String) async -> Void

    @Environment(Session.self) private var session
    @State private var busy = false

    var body: some View {
        NavigationLink(value: result.isShow ? Navigator.Route.show(result.id)
                                            : Navigator.Route.movie(result.id)) {
            VStack(alignment: .leading, spacing: 6) {
                PosterArt(url: result.poster)
                    .overlay(alignment: .topLeading) { TypeBadge(isShow: result.isShow).padding(6) }
                    .overlay(alignment: .bottomTrailing) {
                        ListBookmark(count: session.listCount(result.type, result.id)).padding(6)
                    }
                    .overlay(alignment: .topTrailing) { actions.padding(6) }

                Text(result.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text([result.year?.text, result.stateLabel]
                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(result.displayTitle), \(result.isShow ? "TV" : "film")")
    }

    @ViewBuilder
    private var actions: some View {
        if result.alreadyHave {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mqBrass)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: .circle)
                .accessibilityLabel(result.isShow ? "On your watchlist" : "On your shelf")
        } else {
            VStack(spacing: 6) {
                tileButton(symbol: "plus",
                           label: "Add to watchlist") {
                    await add("watchlist")
                }
                if !result.isShow {
                    tileButton(symbol: "checkmark", label: "Mark watched") {
                        await add("watched")
                    }
                }
            }
        }
    }

    private func tileButton(symbol: String, label: String,
                            action: @escaping () async -> Void) -> some View {
        Button {
            busy = true
            Task { await action(); busy = false }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.mqInk)
                .frame(width: 30, height: 30)
                .background(.ultraThinMaterial, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(busy)
        .accessibilityLabel(label)
    }
}
