import SwiftUI

/// Everything you've watched, newest first.
///
/// Two things make this readable rather than a wall: runs of the same show on the
/// same day collapse into one row with an episode range, and the timeline is broken
/// by month and by day so scrolling back has landmarks.
struct HistoryScreen: View {
    @Environment(Session.self) private var session
    @State private var tab: Kind = .tv
    @State private var tvGroups: [TVHistoryGroup] = []
    @State private var movieItems: [MovieHistoryItem] = []
    @State private var cursor: String?
    @State private var done = false
    @State private var loading = false

    enum Kind: String, CaseIterable, Identifiable {
        case tv = "Shows"
        case movie = "Movies"
        var id: String { rawValue }
        var query: String { self == .tv ? "tv" : "movie" }
    }

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                    Picker("Kind", selection: $tab) {
                        ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, MQ.gutter)
                    .padding(.bottom, 14)

                    if tab == .tv { tvTimeline } else { movieTimeline }

                    if !done {
                        ProgressView()
                            .tint(Color.mqBrass)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .task { await loadMore() }
                    } else if tvGroups.isEmpty && movieItems.isEmpty {
                        EmptyLine("Nothing here yet.")
                    } else {
                        Text("That's everything.")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 22)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: tab) { _, _ in reset() }
    }

    // MARK: - Timelines

    @ViewBuilder
    private var tvTimeline: some View {
        var lastMonth = ""
        var lastDay = ""
        ForEach(tvGroups) { group in
            let month = String(group.day.prefix(7))
            let showMonth = month != lastMonth
            let showDay = group.day != lastDay
            let _ = {
                lastMonth = month
                lastDay = group.day
            }()

            if showMonth { MonthRule(day: group.day) }
            if showDay { DayRule(day: group.day) }

            NavigationLink(value: Navigator.Route.show(group.showID)) {
                HStack(spacing: 12) {
                    PosterArt(url: group.poster, radius: 7).frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.title ?? "")
                            .font(MarqueeFont.body(14.5, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(1)
                        Text(episodeLine(group))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 6)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(group.eps.count) ep\(group.eps.count == 1 ? "" : "s")")
                            .font(MarqueeFont.body(12, .bold, relativeTo: .caption))
                            .foregroundStyle(Color.mqBrass)
                        Text(String(format: "%.1f hrs", Double(group.minutes) / 60))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
                .padding(.vertical, 9)
                .padding(.horizontal, MQ.gutter)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(group.title ?? ""), \(episodeLine(group)), \(group.eps.count) episodes")
        }
    }

    @ViewBuilder
    private var movieTimeline: some View {
        var lastMonth = ""
        var lastDay = ""
        ForEach(movieItems) { item in
            let day = String(item.watchedAt.prefix(10))
            let month = String(day.prefix(7))
            let showMonth = month != lastMonth
            let showDay = day != lastDay
            let _ = {
                lastMonth = month
                lastDay = day
            }()

            if showMonth { MonthRule(day: day) }
            if showDay { DayRule(day: day) }

            NavigationLink(value: Navigator.Route.movie(item.id)) {
                HStack(spacing: 12) {
                    PosterArt(url: item.poster, radius: 7).frame(width: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title ?? "")
                            .font(MarqueeFont.body(14.5, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(1)
                        Text([item.year?.text,
                              item.runtime.map { String(format: "%.1f hrs", Double($0) / 60) }]
                                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                    }
                    Spacer(minLength: 6)
                    if let rating = item.rating {
                        Text("\(rating)")
                            .font(MarqueeFont.body(14, .bold, relativeTo: .caption))
                            .foregroundStyle(Color.mqRating(rating))
                        + Text("/10")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
                .padding(.vertical, 9)
                .padding(.horizontal, MQ.gutter)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
        }
    }

    /// "S2 E4–9 · First → Last" — a run reads as a range, not nine rows.
    private func episodeLine(_ group: TVHistoryGroup) -> String {
        let episodes = group.episodes.sorted { ($0.season, $0.number) < ($1.season, $1.number) }
        guard !episodes.isEmpty else { return "" }

        var bySeason: [Int: [Int]] = [:]
        for episode in episodes { bySeason[episode.season, default: []].append(episode.number) }
        let ranges = bySeason.keys.sorted().map { season -> String in
            let numbers = bySeason[season]!.sorted()
            var runs: [String] = []
            var start = numbers[0]
            var previous = numbers[0]
            for number in numbers.dropFirst() {
                if number == previous + 1 { previous = number; continue }
                runs.append(start == previous ? "E\(start)" : "E\(start)–\(previous)")
                start = number
                previous = number
            }
            runs.append(start == previous ? "E\(start)" : "E\(start)–\(previous)")
            return "S\(season) \(runs.joined(separator: ", "))"
        }.joined(separator: " · ")

        let first = episodes.first?.title
        let last = episodes.last?.title
        if episodes.count == 1, let first, !first.isEmpty { return "\(ranges) · \(first)" }
        if let first, let last, !first.isEmpty, !last.isEmpty {
            return "\(ranges) · \(first) → \(last)"
        }
        return ranges
    }

    // MARK: - Paging

    private func reset() {
        tvGroups = []
        movieItems = []
        cursor = nil
        done = false
    }

    private func loadMore() async {
        guard !loading, !done, let client = session.client else { return }
        loading = true
        defer { loading = false }

        var query = ["type": tab.query]
        if let cursor { query["cursor"] = cursor }

        if tab == .tv {
            guard let page: TVHistoryPage = try? await client.get("history", query: query) else {
                done = true
                return
            }
            // A giant day can be split across pages; merge the halves rather than
            // showing the same show twice under the same date.
            for group in page.items {
                if let index = tvGroups.firstIndex(where: {
                    $0.day == group.day && $0.showID == group.showID
                }) {
                    tvGroups[index].eps.append(contentsOf: group.eps)
                    tvGroups[index].minutes += group.minutes
                } else {
                    tvGroups.append(group)
                }
            }
            cursor = page.cursor
            done = page.cursor == nil
        } else {
            guard let page: MovieHistoryPage = try? await client.get("history", query: query) else {
                done = true
                return
            }
            movieItems.append(contentsOf: page.items)
            cursor = page.cursor
            done = page.cursor == nil
        }
    }
}

private struct MonthRule: View {
    let day: String

    var body: some View {
        HStack(spacing: 10) {
            Text(MQTime.monthLabel(day))
                .font(MarqueeFont.wordmark(17, relativeTo: .title3))
                .foregroundStyle(Color.mqBrass)
            Rectangle().fill(Color.mqHairline).frame(height: 1)
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 22)
        .padding(.bottom, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct DayRule: View {
    let day: String

    var body: some View {
        Text(MQTime.dayLabel(day))
            .mqEyebrowStyle()
            .padding(.horizontal, MQ.gutter)
            .padding(.top, 10)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The full grid behind a profile's watched rail, split by the year you watched it.
struct WatchedGridScreen: View {
    var username: String?
    var kind: String

    @Environment(Session.self) private var session
    @State private var items: [WatchedItem] = []
    @State private var total = 0
    @State private var next: Int?
    @State private var loading = false
    @State private var selected: String

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 104, maximum: 150, spacing: 12)

    }
    private var who: String { username ?? "me" }

    init(username: String?, kind: String) {
        self.username = username
        self.kind = kind
        _selected = State(initialValue: kind)
    }

    private var years: [(year: String, items: [WatchedItem])] {
        var groups: [(String, [WatchedItem])] = []
        for item in items {
            let year = String((item.watchedAt ?? "").prefix(4))
            let key = year.isEmpty ? "?" : year
            if groups.last?.0 == key { groups[groups.count - 1].1.append(item) }
            else { groups.append((key, [item])) }
        }
        return groups.map { (year: $0.0, items: $0.1) }
    }

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Picker("Kind", selection: $selected) {
                        Text("Shows").tag("shows")
                        Text("Films").tag("movies")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, MQ.gutter)

                    Text("\(total) \(selected == "shows" ? "series" : "films")")
                        .mqEyebrowStyle()
                        .padding(.horizontal, MQ.gutter)

                    ForEach(years, id: \.year) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Text(group.year == "?" ? "No date" : group.year)
                                    .font(MarqueeFont.wordmark(21, relativeTo: .title2))
                                    .foregroundStyle(Color.mqBrass)
                                Text("\(group.items.count)")
                                    .mqEyebrowStyle()
                                Rectangle()
                                    .fill(LinearGradient(colors: [Color.mqHairlineBold, .clear],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(height: 1)
                            }
                            .padding(.horizontal, MQ.gutter)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(group.items, id: \.uniqueID) { item in
                                    WatchedTile(item: item, kind: selected)
                                }
                            }
                            .padding(.horizontal, MQ.gutter)
                        }
                    }

                    if next != nil {
                        Button { Task { await loadMore() } } label: {
                            Text(loading ? "Loading…" : "Load more")
                        }
                        .buttonStyle(.mqChip)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
            }
        }
        .navigationTitle("Watched")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selected) { await load() }
    }

    private func load() async {
        guard let client = session.client else { return }
        items = []
        next = nil
        guard let page: WatchedPage = try? await client.get(
            "watched/\(who)/\(selected)", query: ["limit": "48"]) else { return }
        items = page.items
        total = page.total
        next = page.next
    }

    private func loadMore() async {
        guard let client = session.client, let offset = next else { return }
        loading = true
        defer { loading = false }
        guard let page: WatchedPage = try? await client.get(
            "watched/\(who)/\(selected)",
            query: ["limit": "48", "offset": String(offset)]) else { return }
        items.append(contentsOf: page.items)
        next = page.next
    }
}
