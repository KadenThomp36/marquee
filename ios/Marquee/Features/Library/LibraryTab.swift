import SwiftUI

/// Films, shows and reading in one place.
///
/// The web client keeps Movies and Reading as separate top-level tabs; on a phone
/// that's two tabs spent on "things I've collected". One Library with a segmented
/// control reads better and leaves room for Search to take a tab of its own.
struct LibraryTab: View {
    @Environment(Session.self) private var session
    @State private var path = NavigationPath()
    /// Shows first: the TV watchlist is the household's most-asked-for shelf.
    @State private var section: Section = .shows
    @State private var query = ""

    enum Section: String, CaseIterable, Identifiable {
        case shows = "Shows"
        case films = "Films"
        case reading = "Reading"
        var id: String { rawValue }
    }

    private var available: [Section] {
        session.me?.features?.tracksReading == true
            ? Section.allCases
            : [.shows, .films]
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack(path: $path) {
            MarqueeScreen {
                VStack(spacing: 0) {
                    PageHeading(title: "Library")
                        .padding(.bottom, 10)
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
            // Filters what's already on the shelf. Finding something you *don't*
            // have is the Search tab's job, and the empty state says so.
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Filter your library")
            .marqueeDestinations()
        }
        .routed(into: $path)
        .onChange(of: available.count) { _, _ in
            if !available.contains(section) { section = .shows }
        }
    }
}

/// Watched and watchlist, the two shelves a film can be on.
struct FilmsShelf: View {
    var query: String = ""

    @Environment(Session.self) private var session
    @State private var data = RemoteData<MovieShelves>(cacheKey: "movies")
    /// The watchlist leads: "what shall we watch" is the question, not "what did we".
    @State private var tab: Shelf = .watchlist
    @State private var undo: UndoToast?

    enum Shelf: String, CaseIterable, Identifiable {
        case watchlist = "Watchlist"
        case watched = "Watched"
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
                } else if tab == .watchlist {
                    // Out now first — what you could put on tonight — then what's
                    // still on its way, soonest first.
                    ForEach(watchlistGroups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(group.title, count: "\(group.films.count)")
                                .padding(.horizontal, MQ.gutter)
                            grid(group.films)
                        }
                    }
                } else {
                    grid(films)
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
        .undoBanner($undo)
    }

    private func grid(_ items: [MovieCard]) -> some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(items) { film in
                FilmTile(film: film, shelf: tab) { action in
                    await update(film, action: action)
                }
            }
        }
        .padding(.horizontal, MQ.gutter)
    }

    private struct FilmGroup: Identifiable {
        let title: String
        let films: [MovieCard]
        var id: String { title }
    }

    private var watchlistGroups: [FilmGroup] {
        let today = MQTime.today()
        let out = films.filter { !$0.isUpcoming(today: today) }
        let soon = films.filter { $0.isUpcoming(today: today) }
            .sorted { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }
        var groups: [FilmGroup] = []
        if !out.isEmpty { groups.append(FilmGroup(title: "Out now", films: out)) }
        if !soon.isEmpty { groups.append(FilmGroup(title: "Coming soon", films: soon)) }
        return groups
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
        var spot: (watched: Bool, index: Int)?
        data.mutate { shelves in
            if let index = shelves.watched.firstIndex(where: { $0.id == film.id }) {
                spot = (true, index)
            } else if let index = shelves.watchlist.firstIndex(where: { $0.id == film.id }) {
                spot = (false, index)
            }
            shelves.watched.removeAll { $0.id == film.id }
            shelves.watchlist.removeAll { $0.id == film.id }
            var moved = film
            if action == "watched" {
                moved.state = "watched"
                moved.watchedAt = moved.watchedAt ?? MQTime.stamp()
                shelves.watched.insert(moved, at: 0)
            } else if action == "watchlist" {
                moved.state = "watchlist"
                shelves.watchlist.insert(moved, at: 0)
            }
        }
        do {
            try await client.post("movie/\(film.id)/state",
                                  body: MovieStateRequest(state: action), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .movieState(movieID: film.id, state: action, rating: nil)))
        }
        guard action == "none" else { return }
        // Removing drops the rating and the watch date with it, so the undo hands
        // both back rather than re-adding a blank film.
        let was = spot
        undo = UndoToast(message: "Removed \(film.displayTitle)") {
            data.mutate { shelves in
                if was?.watched == true {
                    shelves.watched.insert(film, at: min(was?.index ?? 0, shelves.watched.count))
                } else {
                    shelves.watchlist.insert(film, at: min(was?.index ?? 0, shelves.watchlist.count))
                }
            }
            _ = try? await client.post(
                "movie/\(film.id)/state",
                body: MovieStateRequest(state: film.state ?? (was?.watched == true ? "watched" : "watchlist"),
                                        rating: film.rating,
                                        watchedAt: film.watchedAt,
                                        addedAt: film.addedAt),
                as: Empty.self)
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
                                .foregroundStyle(Color.mqBrassOnArt)
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        ListBookmark(count: session.listCount("movie", film.id)).padding(6)
                    }
                    .overlay(alignment: .bottomLeading) { householdFaces.padding(6) }
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
                if shelf == .watchlist, let provider = film.prov?.name, !provider.isEmpty {
                    Text(provider)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let household {
                Text(household.text)
            }
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
        .accessibilityLabel(accessibilityText)
        .accessibilityAction(named: "Remove from library") { Task { await perform("none") } }
    }

    private var household: HouseholdSummary? { HouseholdSummary.film(film) }

    private var accessibilityText: String {
        var parts = [film.displayTitle]
        if let year = film.year?.text, !year.isEmpty { parts.append(year) }
        if let household { parts.append(household.text) }
        return parts.joined(separator: ", ")
    }

    /// Who else in the house wants it or has seen it — faces on the art, the words in
    /// the accessibility label and the long-press preview.
    @ViewBuilder
    private var householdFaces: some View {
        if let household {
            HStack(spacing: -5) {
                ForEach(Array(household.people.enumerated()), id: \.offset) { _, person in
                    AvatarView(person: person, size: 20, baseURL: session.server?.baseURL)
                        .overlay(Circle().strokeBorder(Color.mqGround, lineWidth: 1.5))
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if shelf == .watchlist, film.isUpcoming(today: MQTime.today()), let release = film.releaseDate {
            parts.append("Out \(MQTime.short(release))")
        } else if let year = film.year?.text, !year.isEmpty {
            parts.append(year)
        }
        if shelf == .watchlist {
            if let runtime = LibraryFormat.runtime(film.runtime) { parts.append(runtime) }
            if let cert = film.cert, !cert.isEmpty { parts.append(cert) }
        } else if let watchedAt = film.watchedAt, !watchedAt.isEmpty {
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
///
/// What the Shows side of the Library was before the server grew `/api/shows`; kept
/// as the fallback for a server that hasn't been updated yet.
struct LegacyShowsGrid: View {
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
                                .foregroundStyle(Color.mqBrassOnArt)
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
                    // Reserved, so every tile in a rail has the same ideal height —
                    // otherwise the rail sizes itself to whichever tiles it laid out
                    // first and the odd ones out get squeezed or clipped.
                    .lineLimit(2, reservesSpace: true)
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
