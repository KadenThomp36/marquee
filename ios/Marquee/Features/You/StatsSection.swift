import Charts
import SwiftUI

/// The numbers behind a profile: how much, how often, when, and what.
///
/// The charts follow one rule taken from the web client — a colour is either
/// *identity* (a genre keeps its hue everywhere) or *quantity* (one series, one hue).
/// Nothing is coloured just to be colourful.
struct StatsSection: View {
    let stats: Stats
    let advanced: AdvancedStats?

    @State private var heatYear = "all"
    /// What each chart is currently scrubbed to.
    @State private var pickedMonth: String?
    @State private var pickedYear: String?
    @State private var pickedScore: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            headline
            records
            monthByMonth
            watchingLife
            watchClock
            topShows
            genres
            showShelf
            decades
            ratings
            if let advanced, !advanced.isEmpty { deeperCuts(advanced) }
        }
    }

    // MARK: - Tiles

    private var headline: some View {
        StatTileGrid(tiles: [
            StatTile(value: MQTime.duration(minutes: stats.totalMinutes), unit: nil,
                     label: "in front of the screen",
                     detail: "\((stats.totalMinutes / 60).mqGrouped) hours all told",
                     tint: .mqChartAmber, isWide: true),
            StatTile(value: stats.episodes.mqGrouped, unit: nil, label: "episodes",
                     detail: "\(MQTime.duration(minutes: stats.tvMinutes)) of TV",
                     tint: .mqChartBlue),
            StatTile(value: stats.movies.mqGrouped, unit: nil, label: "movies",
                     detail: "\(MQTime.duration(minutes: stats.movieMinutes)) of film",
                     tint: .mqChartViolet),
            StatTile(value: "\(stats.shows)", unit: nil, label: "shows followed",
                     detail: "\(stats.completion?.finished ?? 0) finished",
                     tint: .mqChartAqua),
        ])
    }

    private var records: some View {
        var tiles: [StatTile] = [
            StatTile(value: "\(stats.streak.current)", unit: "days", label: "current streak",
                     detail: "best \(stats.streak.longest) days"
                        + (stats.streak.longestEnd.map { " · ended \(MQTime.medium($0))" } ?? ""),
                     tint: .mqChartGreen),
        ]
        if let bigDay = stats.bigDay {
            tiles.append(StatTile(value: "\(bigDay.count)", unit: "eps",
                                  label: "biggest binge day",
                                  detail: MQTime.medium(bigDay.date)
                                    + (bigDay.top.map { " · mostly \($0)" } ?? ""),
                                  tint: .mqChartOrange))
        }
        tiles.append(StatTile(value: String(format: "%.2f", stats.perDay), unit: nil,
                              label: "watches / day",
                              detail: stats.firstWatch?.watchedAt
                                .map { "since \(MQTime.medium($0))" } ?? "since the start",
                              tint: .mqChartBlue))
        if let first = stats.firstWatch, let title = first.title {
            tiles.append(StatTile(value: title, unit: nil, label: "first ever watch",
                                  detail: MQTime.medium(first.watchedAt), tint: .mqChartPink))
        }
        return StatTileGrid(tiles: tiles)
    }

    // MARK: - Charts

    @ViewBuilder
    private var monthByMonth: some View {
        // The API sends only months with activity; the empty ones matter to the shape
        // of the line, so they're padded back in here.
        let months = lastMonths(24)
        let counts = Dictionary(uniqueKeysWithValues: stats.monthly.map { ($0.ym, $0.count) })
        let points = months.map { (key: $0, value: counts[$0] ?? 0) }
        if points.contains(where: { $0.value > 0 }) {
            ChartCard(title: "Month by month",
                      badge: "\(points.reduce(0) { $0 + $1.value }.mqGrouped) in 24 mo",
                      subtitle: "episodes and films") {
                Chart(points, id: \.key) { point in
                    AreaMark(x: .value("Month", point.key),
                             y: .value("Watched", point.value))
                        .foregroundStyle(LinearGradient(
                            colors: [Color.mqBrass.opacity(0.34), Color.mqBrass.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Month", point.key),
                             y: .value("Watched", point.value))
                        .foregroundStyle(Color.mqBrass)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                        .interpolationMethod(.monotone)

                    if pickedMonth == point.key {
                        RuleMark(x: .value("Month", point.key))
                            .foregroundStyle(Color.mqBrass.opacity(0.4))
                            .annotation(position: .top,
                                        overflowResolution: .init(x: .fit(to: .chart),
                                                                  y: .disabled)) {
                                ChartReadout(caption: MQTime.monthKeyLabel(point.key),
                                             value: "\(point.value) watched")
                            }
                        PointMark(x: .value("Month", point.key),
                                  y: .value("Watched", point.value))
                            .foregroundStyle(Color.mqBrass)
                            .symbolSize(60)
                    }
                }
                .chartXSelection(value: $pickedMonth)
                .sensoryFeedback(.selection, trigger: pickedMonth)
                .chartXAxis {
                    AxisMarks(values: points.map(\.key).filter { $0.hasSuffix("-01") }) { value in
                        AxisValueLabel {
                            if let key = value.as(String.self) {
                                Text(key.prefix(4)).font(.mqCaption)
                            }
                        }
                    }
                }
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 150)
            }
        }
    }

    @ViewBuilder
    private var watchingLife: some View {
        if stats.yearly.count > 1 {
            ChartCard(title: "Your watching life",
                      badge: stats.yearly.first.map { "since \($0.y)" },
                      subtitle: "episodes per year") {
                Chart(stats.yearly) { year in
                    BarMark(x: .value("Year", year.y), y: .value("Episodes", year.c))
                        .foregroundStyle(pickedYear == year.y
                                         ? Color.mqBrass : Color.mqChartAmber)
                        .cornerRadius(3)

                    if pickedYear == year.y {
                        RuleMark(x: .value("Year", year.y))
                            .foregroundStyle(.clear)
                            .annotation(position: .top,
                                        overflowResolution: .init(x: .fit(to: .chart),
                                                                  y: .disabled)) {
                                ChartReadout(caption: year.y,
                                             value: "\(year.c.mqGrouped) episodes")
                            }
                    }
                }
                .chartXSelection(value: $pickedYear)
                .sensoryFeedback(.selection, trigger: pickedYear)
                .chartYAxis { AxisMarks(position: .leading) }
                .frame(height: 140)
            }
        }
    }

    @ViewBuilder
    private var watchClock: some View {
        let years = stats.heatYears ?? ["all": stats.heatmap ?? []]
        let cells = years[heatYear] ?? []
        if !cells.isEmpty {
            ChartCard(title: "The watch clock", badge: nil, subtitle: caption(for: cells)) {
                VStack(alignment: .leading, spacing: 8) {
                    if years.keys.count > 1 {
                        Picker("Year", selection: $heatYear) {
                            Text("All time").tag("all")
                            ForEach(years.keys.filter { $0 != "all" }.sorted().reversed(), id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Color.mqBrass)
                    }
                    WatchClock(cells: cells)
                }
            }
        }
    }

    private func caption(for cells: [[Int]]) -> String {
        let total = cells.reduce(0) { $0 + ($1.count > 2 ? $1[2] : 0) }
        guard total > 0 else { return "no watches recorded for this range" }
        let peak = cells.max { ($0.count > 2 ? $0[2] : 0) < ($1.count > 2 ? $1[2] : 0) }
        guard let peak, peak.count > 2 else { return "when you watch" }
        return "busiest \(WatchClock.weekdayNames[peak[0] % 7]) around \(WatchClock.hourLabel(peak[1]))"
    }

    @ViewBuilder
    private var topShows: some View {
        if !stats.topShows.isEmpty {
            ChartCard(title: "Top shows by time", badge: nil,
                      subtitle: "your biggest commitments") {
                RankedBars(rows: stats.topShows.map {
                    RankedBar(name: $0.title, value: Double($0.mins ?? 0),
                              display: MQTime.duration(minutes: $0.mins ?? 0))
                }, tint: .mqChartAmber)
            }
        }
    }

    @ViewBuilder
    private var genres: some View {
        if !stats.genres.isEmpty {
            ChartCard(title: "Genres", badge: nil, subtitle: "episodes watched, by genre") {
                RankedBars(rows: stats.genres.enumerated().map { index, genre in
                    RankedBar(name: genre.name, value: Double(genre.count),
                              display: genre.count.mqGrouped,
                              // Genre is identity, so each keeps its own hue — and the
                              // same hue across every screen that shows genres.
                              colour: Color.mqCategorical[index % Color.mqCategorical.count])
                })
            }
        }
    }

    @ViewBuilder
    private var showShelf: some View {
        if let completion = stats.completion, completion.total > 0 {
            ChartCard(title: "Show shelf", badge: nil,
                      subtitle: "where your \(completion.total) followed shows stand") {
                let segments: [(String, Int, Color)] = [
                    ("Finished", completion.finished, .mqChartGreen),
                    ("Up to date", completion.upToDate, .mqChartBlue),
                    ("In progress", completion.inProgress, .mqChartAmber),
                    ("Dropped", completion.dropped, .mqChartRed),
                    ("Not started", completion.notStarted, .mqChartNeutral),
                ]
                VStack(alignment: .leading, spacing: 10) {
                    GeometryReader { geometry in
                        HStack(spacing: 0) {
                            ForEach(segments.filter { $0.1 > 0 }, id: \.0) { segment in
                                Rectangle()
                                    .fill(segment.2)
                                    .frame(width: geometry.size.width
                                           * Double(segment.1) / Double(completion.total))
                            }
                        }
                        .clipShape(.capsule)
                    }
                    .frame(height: 12)

                    FlowLayout(spacing: 14, lineSpacing: 6) {
                        ForEach(segments, id: \.0) { segment in
                            HStack(spacing: 5) {
                                Circle().fill(segment.2).frame(width: 7, height: 7)
                                Text(segment.0)
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkSoft)
                                Text("\(segment.1)")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                                    .monospacedDigit()
                            }
                            .opacity(segment.1 > 0 ? 1 : 0.45)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(segment.0), \(segment.1)")
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var decades: some View {
        if let decades = stats.movieDecades, !decades.isEmpty {
            ChartCard(title: "Movies by decade", badge: nil,
                      subtitle: "release decade of what you've seen") {
                RankedBars(rows: decades.map {
                    RankedBar(name: $0.label, value: Double($0.c), display: "\($0.c)")
                }, tint: .mqChartOrange)
            }
        }
    }

    @ViewBuilder
    private var ratings: some View {
        let histogram = (stats.ratingHist ?? [:])
            .compactMap { key, value -> (Int, Int)? in Int(key).map { ($0, value) } }
            .sorted { $0.0 < $1.0 }
        if !histogram.isEmpty {
            let total = histogram.reduce(0) { $0 + $1.1 }
            let mean = Double(histogram.reduce(0) { $0 + $1.0 * $1.1 }) / Double(max(1, total))
            ChartCard(title: "Your ratings", badge: String(format: "avg %.1f", mean),
                      subtitle: "\(total) scored · red low, green high") {
                Chart(histogram, id: \.0) { score, count in
                    BarMark(x: .value("Score", score), y: .value("Titles", count))
                        // The one place a per-bar colour is a scale, not decoration.
                        .foregroundStyle(Color.mqRating(score))
                        .opacity(pickedScore == nil || pickedScore == score ? 1 : 0.45)
                        .cornerRadius(3)

                    if pickedScore == score {
                        RuleMark(x: .value("Score", score))
                            .foregroundStyle(.clear)
                            .annotation(position: .top,
                                        overflowResolution: .init(x: .fit(to: .chart),
                                                                  y: .disabled)) {
                                ChartReadout(caption: "Rated \(score)",
                                             value: count == 1 ? "1 title" : "\(count) titles")
                            }
                    }
                }
                .chartXSelection(value: $pickedScore)
                .sensoryFeedback(.selection, trigger: pickedScore)
                .chartXScale(domain: 1...10)
                .chartXAxis {
                    AxisMarks(values: Array(1...10)) { value in
                        AxisValueLabel {
                            if let score = value.as(Int.self) {
                                Text("\(score)").font(.mqCaption)
                            }
                        }
                    }
                }
                .frame(height: 130)
            }

            if let topRated = stats.topRated, !topRated.isEmpty {
                ChartCard(title: "All-timers", badge: nil, subtitle: "your highest-rated") {
                    VStack(spacing: 0) {
                        ForEach(topRated) { title in
                            HStack {
                                Text(title.title)
                                    .font(.mqSub)
                                    .foregroundStyle(Color.mqInk)
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text("\(title.rating)")
                                    .font(MarqueeFont.body(14, .bold, relativeTo: .caption))
                                    .foregroundStyle(Color.mqRating(title.rating))
                                Text("/10")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                            }
                            .padding(.vertical, 7)
                            .accessibilityElement(children: .combine)
                            if title.id != topRated.last?.id {
                                Divider().overlay(Color.mqHairline)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func deeperCuts(_ advanced: AdvancedStats) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Deeper cuts").padding(.horizontal, MQ.gutter)

            if let total = advanced.moviesTotal, let enriched = advanced.moviesEnriched,
               enriched < total {
                Text("Studios, film countries and movie cast fill in gradually — \(enriched)/\(total) films enriched so far.")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .padding(.horizontal, MQ.gutter)
            }

            if !advanced.networks.isEmpty {
                ChartCard(title: "Networks", badge: nil, subtitle: "TV homes, by episodes") {
                    RankedBars(rows: advanced.networks.map {
                        RankedBar(name: $0.name, value: Double($0.count), display: $0.count.mqGrouped)
                    }, tint: .mqChartBlue)
                }
            }
            if !advanced.studios.isEmpty {
                ChartCard(title: "Studios", badge: nil, subtitle: "film companies, by titles") {
                    RankedBars(rows: advanced.studios.map {
                        RankedBar(name: $0.name, value: Double($0.count), display: "\($0.count)")
                    }, tint: .mqChartViolet)
                }
            }
            if !advanced.actors.isEmpty {
                ChartCard(title: "Most-watched faces", badge: nil,
                          subtitle: "actors across your shows and films") {
                    RankedBars(rows: advanced.actors.map { actor in
                        RankedBar(name: actor.name, value: Double(actor.total),
                                  display: [actor.shows > 0 ? "\(actor.shows) show\(actor.shows == 1 ? "" : "s")" : nil,
                                            actor.movies > 0 ? "\(actor.movies) film\(actor.movies == 1 ? "" : "s")" : nil]
                                    .compactMap { $0 }.joined(separator: " · "),
                                  image: actor.img)
                    }, tint: .mqChartPink)
                }
            }
            if !advanced.directors.isEmpty {
                ChartCard(title: "Creators & directors", badge: nil,
                          subtitle: "whose work you keep coming back to") {
                    RankedBars(rows: advanced.directors.map {
                        RankedBar(name: $0.name, value: Double($0.count),
                                  display: "\($0.count) title\($0.count == 1 ? "" : "s")")
                    }, tint: .mqChartAqua)
                }
            }
            if !advanced.countries.isEmpty {
                ChartCard(title: "Around the world", badge: nil,
                          subtitle: "where your stories are made") {
                    RankedBars(rows: advanced.countries.map {
                        RankedBar(name: $0.name, value: Double($0.count), display: "\($0.count)")
                    }, tint: .mqChartGreen)
                }
            }
        }
    }

    private func lastMonths(_ count: Int) -> [String] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<count).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            let parts = calendar.dateComponents([.year, .month], from: date)
            return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        }
    }
}

// MARK: - Ranked bars

struct RankedBar: Identifiable {
    let id = UUID()
    var name: String
    var value: Double
    var display: String
    var colour: Color?
    var image: String?
}

/// A ranked list where the bar is the point and the number is the caption — easier to
/// read at a glance than a pie, and it survives long names.
struct RankedBars: View {
    let rows: [RankedBar]
    var tint: Color = .mqChartAmber

    private var maximum: Double { max(rows.map(\.value).max() ?? 1, 1) }

    var body: some View {
        VStack(spacing: 9) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 9) {
                    Text("\(index + 1)")
                        .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                        .foregroundStyle(row.colour ?? Color.mqInkMuted)
                        .monospacedDigit()
                        .frame(width: 16, alignment: .trailing)

                    if let image = row.image {
                        RemoteImage(url: image, contentMode: .fill, placeholderSymbol: "person.fill")
                            .frame(width: 26, height: 26)
                            .clipShape(.circle)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(row.name)
                                .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
                                .foregroundStyle(Color.mqInk)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Text(row.display)
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                        }
                        GeometryReader { geometry in
                            Capsule()
                                .fill(row.colour ?? tint)
                                .frame(width: max(4, geometry.size.width * row.value / maximum))
                        }
                        .frame(height: 5)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(index + 1). \(row.name), \(row.display)")
            }
        }
    }
}

/// The watch clock: seven rows of twenty-four cells, darker where you watch more.
struct WatchClock: View {
    /// `[[weekday, hour, count], …]`
    let cells: [[Int]]

    static let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday",
                               "Thursday", "Friday", "Saturday"]
    private static let short = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12 AM"
        case 12: "12 PM"
        case ..<12: "\(hour) AM"
        default: "\(hour - 12) PM"
        }
    }

    private var grid: [[Int]] {
        var out = Array(repeating: Array(repeating: 0, count: 24), count: 7)
        for cell in cells where cell.count >= 3 {
            let day = min(max(cell[0], 0), 6)
            let hour = min(max(cell[1], 0), 23)
            out[day][hour] += cell[2]
        }
        return out
    }

    var body: some View {
        let grid = grid
        let peak = max(grid.flatMap { $0 }.max() ?? 1, 1)
        let total = grid.flatMap { $0 }.reduce(0, +)

        VStack(alignment: .leading, spacing: 3) {
            ForEach(0..<7, id: \.self) { day in
                HStack(spacing: 2) {
                    Text(Self.short[day])
                        .font(MarqueeFont.body(9, .semibold, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                        .frame(width: 26, alignment: .leading)
                    ForEach(0..<24, id: \.self) { hour in
                        let count = grid[day][hour]
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.mqBrass.opacity(count == 0 ? 0.06
                                                        : 0.15 + 0.85 * Double(count) / Double(peak)))
                            .aspectRatio(1, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(Self.weekdayNames[day]) \(Self.hourLabel(hour)), \(count) watched")
                    }
                }
            }
            HStack(spacing: 2) {
                Spacer().frame(width: 26)
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(Self.hourLabel(hour))
                        .font(MarqueeFont.body(8.5, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Watch clock, \(total) watches by weekday and hour")
    }
}
