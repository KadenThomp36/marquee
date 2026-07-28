import SwiftUI

/// Films, shows and reading in one place.
///
/// The web client keeps Movies and Reading as separate top-level tabs; on a phone
/// that's two tabs spent on "things I've collected". One Library with a segmented
/// control reads better and leaves room for Search to take a tab of its own.
struct LibraryTab: View {
    @Environment(Session.self) private var session
    @State private var path = NavigationPath()
    @State private var section: Section = .films
    @State private var query = ""

    enum Section: String, CaseIterable, Identifiable {
        case films = "Films"
        case shows = "Shows"
        case reading = "Reading"
        var id: String { rawValue }
    }

    private var available: [Section] {
        session.me?.features?.tracksReading == true
            ? Section.allCases
            : [.films, .shows]
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            MarqueeScreen {
                VStack(spacing: 0) {
                    if available.count > 1 {
                        Picker("Library section", selection: $section) {
                            ForEach(available) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, MQ.gutter)
                        .padding(.bottom, 10)
                    }

                    switch section {
                    case .films: FilmsShelf(query: trimmedQuery)
                    case .shows: ShowsShelf(query: trimmedQuery)
                    case .reading: ReadingShelfScreen(query: trimmedQuery)
                    }
                }
            }
            .navigationTitle("Library")
            // Filters what's already on the shelf. Finding something you *don't*
            // have is the Search tab's job, and the empty state says so.
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Filter your library")
            .marqueeDestinations()
        }
        .routed(into: $path)
        .onChange(of: available.count) { _, _ in
            if !available.contains(section) { section = .films }
        }
    }
}

/// Watched and watchlist, the two shelves a film can be on.
struct FilmsShelf: View {
    var query: String = ""

    @Environment(Session.self) private var session
    @State private var data = RemoteData<MovieShelves>(cacheKey: "movies")
    @State private var tab: Shelf = .watched

    enum Shelf: String, CaseIterable, Identifiable {
        case watched = "Watched"
        case watchlist = "Watchlist"
        var id: String { rawValue }
    }

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 104, maximum: 150, spacing: 12)

    }

    private var films: [MovieCard] {
        guard let value = data.value else { return [] }
        let shelf = tab == .watched ? value.watched : value.watchlist
        guard !query.isEmpty else { return shelf }
        return shelf.filter { $0.displayTitle.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Picker("Shelf", selection: $tab) {
                    ForEach(Shelf.allCases) { shelf in
                        Text("\(shelf.rawValue) · \(count(for: shelf))").tag(shelf)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, MQ.gutter)

                if films.isEmpty, data.value != nil {
                    EmptyLine(query.isEmpty
                              ? "Nothing here yet — find something in Search."
                              : "No film on this shelf matches \u{201C}\(query)\u{201D}.")
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(films) { film in
                            FilmTile(film: film, shelf: tab) { action in
                                await update(film, action: action)
                            }
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }

                if data.isEmpty {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<12, id: \.self) { _ in
                            SkeletonBlock(height: 160, radius: MQ.radiusSmall)
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
                if data.isStale { StaleFooter(cachedAt: data.cachedAt) }
            }
            .padding(.vertical, 6)
        }
        .refreshable { await load(force: true) }
        .task { await load() }
        .task { await session.refreshListMembership() }
    }

    private func count(for shelf: Shelf) -> Int {
        guard let value = data.value else { return 0 }
        return shelf == .watched ? value.watched.count : value.watchlist.count
    }

    private func load(force: Bool = false) async {
        guard let client = session.client else { return }
        await data.load(force: force) { try await client.get("movies", as: MovieShelves.self) }
    }

    private func update(_ film: MovieCard, action: String) async {
        guard let client = session.client else { return }
        data.mutate { shelves in
            shelves.watched.removeAll { $0.id == film.id }
            shelves.watchlist.removeAll { $0.id == film.id }
            if action == "watched" {
                var moved = film
                moved.state = "watched"
                moved.watchedAt = MQTime.stamp()
                shelves.watched.insert(moved, at: 0)
            }
        }
        do {
            try await client.post("movie/\(film.id)/state",
                                  body: MovieStateRequest(state: action), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .movieState(movieID: film.id, state: action, rating: nil)))
        }
    }
}

private struct FilmTile: View {
    let film: MovieCard
    let shelf: FilmsShelf.Shelf
    let perform: (String) async -> Void

    @Environment(Session.self) private var session

    var body: some View {
        NavigationLink(value: Navigator.Route.movie(film.id)) {
            VStack(alignment: .leading, spacing: 6) {
                PosterArt(url: film.poster)
                    .overlay(alignment: .topTrailing) {
                        if let rating = film.rating {
                            Text("\(rating)/10")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqBrass)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        ListBookmark(count: session.listCount("movie", film.id)).padding(6)
                    }
                    .overlay(alignment: .topLeading) { quickActions.padding(6) }

                Text(film.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .mqSecondaryLine()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if shelf == .watchlist {
                Button("Mark watched", systemImage: "checkmark") {
                    Task { await perform("watched") }
                }
            } else {
                Button("Move to watchlist", systemImage: "bookmark") {
                    Task { await perform("watchlist") }
                }
            }
            Button("Remove from library", systemImage: "trash", role: .destructive) {
                Task { await perform("none") }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(film.displayTitle)\(film.year?.text.isEmpty == false ? ", \(film.year!.text)" : "")")
        .accessibilityAction(named: "Remove from library") { Task { await perform("none") } }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let year = film.year?.text, !year.isEmpty { parts.append(year) }
        if let watchedAt = film.watchedAt, !watchedAt.isEmpty {
            parts.append(MQTime.medium(watchedAt))
        }
        return parts.joined(separator: " · ")
    }

    /// Only the action you'd actually reach for lives on the poster. Removing a film
    /// is destructive and rare, so it goes behind a long press rather than putting a
    /// dismiss button on top of every piece of artwork.
    @ViewBuilder
    private var quickActions: some View {
        if shelf == .watchlist {
            tileButton("checkmark", "Mark watched") { await perform("watched") }
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

/// Every show you've watched anything of, newest first, with how far in you are.
struct ShowsShelf: View {
    var query: String = ""

    @Environment(Session.self) private var session
    @State private var data = RemoteData<WatchedPage>(cacheKey: "watched-shows")
    @State private var loadingMore = false

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 104, maximum: 150, spacing: 12)

    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let page = data.value {
                    let items = query.isEmpty ? page.items : page.items.filter {
                        $0.displayTitle.localizedCaseInsensitiveContains(query)
                    }

                    Text(query.isEmpty ? "\(page.total) series"
                                       : "\(items.count) of \(page.total) series")
                        .mqEyebrowStyle()
                        .padding(.horizontal, MQ.gutter)

                    if items.isEmpty {
                        EmptyLine("No series matches \u{201C}\(query)\u{201D}.")
                    }

                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(items) { item in
                            WatchedTile(item: item, kind: "shows")
                        }
                    }
                    .padding(.horizontal, MQ.gutter)

                    if page.next != nil {
                        Button {
                            Task { await loadMore() }
                        } label: {
                            Text(loadingMore ? "Loading…" : "Load more")
                        }
                        .buttonStyle(.mqChip)
                        .disabled(loadingMore)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                    }
                } else if data.isEmpty {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(0..<12, id: \.self) { _ in
                            SkeletonBlock(height: 160, radius: MQ.radiusSmall)
                        }
                    }
                    .padding(.horizontal, MQ.gutter)
                }
            }
            .padding(.vertical, 6)
        }
        .refreshable { await load(force: true) }
        .task { await load() }
    }

    private func load(force: Bool = false) async {
        guard let client = session.client else { return }
        await data.load(force: force) {
            try await client.get("watched/me/shows", query: ["limit": "48"], as: WatchedPage.self)
        }
    }

    private func loadMore() async {
        guard let client = session.client, let offset = data.value?.next else { return }
        loadingMore = true
        defer { loadingMore = false }
        guard let page: WatchedPage = try? await client.get(
            "watched/me/shows", query: ["limit": "48", "offset": String(offset)]) else { return }
        data.mutate { current in
            current.items.append(contentsOf: page.items)
            current.next = page.next
        }
    }
}

/// One card in a "what you've watched" grid.
struct WatchedTile: View {
    let item: WatchedItem
    let kind: String

    @Environment(Session.self) private var session

    var body: some View {
        NavigationLink(value: item.type == "show" ? Navigator.Route.show(item.id)
                                                  : Navigator.Route.movie(item.id)) {
            VStack(alignment: .leading, spacing: 6) {
                PosterArt(url: item.poster)
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
                    .overlay(alignment: .topLeading) {
                        if item.isFinishedSeries {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.mqChartGreen, in: .circle)
                                .padding(6)
                                .accessibilityLabel("Finished")
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        ListBookmark(count: session.listCount(item.type, item.id)).padding(6)
                    }

                Text(item.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .mqSecondaryLine()
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayTitle). \(subtitle)")
    }

    private var subtitle: String {
        if kind == "movies" {
            if let watchedAt = item.watchedAt, !watchedAt.isEmpty { return MQTime.medium(watchedAt) }
            return item.year?.text ?? ""
        }
        let watched = item.watched ?? 0
        let aired = item.aired.map { " / \($0)" } ?? ""
        return "\(watched)\(aired) episode\(watched == 1 && aired.isEmpty ? "" : "s")"
    }
}
