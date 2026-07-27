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
        }
        .navigationTitle("Discover")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Shows & films")
        .onChange(of: query) { _, new in scheduleSearch(new) }
        .task {
            if !initialQuery.isEmpty { query = initialQuery }
            await loadDiscover()
            await session.refreshListMembership()
        }
    }

    @ViewBuilder
    private var resultsGrid: some View {
        if searching, results.isEmpty {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(0..<9, id: \.self) { _ in
                    SkeletonBlock(height: 170, radius: MQ.radiusSmall)
                }
            }
            .padding(.horizontal, MQ.gutter)
        } else if results.isEmpty {
            EmptyLine("No matches for “\(query)”.")
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(results) { result in
                    QuickAddTile(result: result) { await add(result, state: $0) }
                }
            }
            .padding(.horizontal, MQ.gutter)
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
            searching = false
            return
        }
        searching = true
        searchTask = Task {
            // Type-ahead, but not a request per keystroke.
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled, let client = session.client else { return }
            let response: SearchResponse? = try? await client.get("search", query: ["q": trimmed])
            guard !Task.isCancelled else { return }
            results = response?.results ?? []
            searching = false
        }
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
                    .lineLimit(2)
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
                .accessibilityLabel(result.isShow ? "Following" : "On your shelf")
        } else {
            VStack(spacing: 6) {
                tileButton(symbol: "plus",
                           label: result.isShow ? "Follow" : "Add to watchlist") {
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
