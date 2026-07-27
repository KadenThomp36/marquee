import Charts
import SwiftUI

/// How a show holds up, season by season.
///
/// Two things carry over from the web client and are worth stating plainly. Ratings
/// come from IMDb's dataset where it has them and TMDB where it doesn't, and the two
/// are drawn differently — filled points for IMDb, hollow for TMDB — rather than
/// silently averaged into one line. And a season's average is vote-weighted for IMDb,
/// so a 500,000-vote finale doesn't count the same as a 40-vote filler episode.
struct RatingsPanel: View {
    let ratings: ShowRatings

    @State private var activeSeason: Int?
    @State private var selectedEpisode: Int?

    private var seasons: [Int] {
        Array(Set(ratings.episodes.map(\.season))).sorted()
    }

    private var season: Int { activeSeason ?? seasons.first ?? 1 }

    private var episodes: [RatedEpisode] {
        ratings.episodes.filter { $0.season == season }.sorted { $0.number < $1.number }
    }

    private var average: SeasonAverage? {
        ratings.seasonAvg.first { $0.season == season }
    }

    /// A band with a little air above and below, so a season that sits between 7.8
    /// and 8.4 doesn't render as a flat line across the middle.
    private var range: ClosedRange<Double> {
        let values = ratings.episodes.map(\.rating)
        guard let low = values.min(), let high = values.max() else { return 0...10 }
        var lower = max(0, low.rounded(.down))
        var upper = min(10, high.rounded(.up))
        if upper - lower < 2 {
            lower = max(0, lower - 1)
            upper = min(10, upper + 1)
        }
        return lower...upper
    }

    var body: some View {
        DetailSection(title: "Ratings", count: overallCaption) {
            VStack(alignment: .leading, spacing: 12) {
                if ratings.seasonAvg.count > 1 { seasonStrip }
                caption
                chart
                    .frame(height: 150)
                    .padding(.top, 2)
                if ratings.isMixed { legend }
            }
            .padding(14)
            .mqPanel()
            .padding(.horizontal, MQ.gutter)
        }
    }

    private var overallCaption: String {
        let values = ratings.episodes.map(\.rating)
        guard !values.isEmpty else { return "" }
        let mean = values.reduce(0, +) / Double(values.count)
        return String(format: "%.1f avg · %@", mean,
                      ratings.source == "imdb" ? "IMDb" : "TMDB")
    }

    private var seasonStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(ratings.seasonAvg) { entry in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            activeSeason = entry.season
                            selectedEpisode = nil
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Text("S\(entry.season)")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(entry.season == season
                                                 ? Color.mqInkSoft : Color.mqInkMuted)
                            Text(String(format: "%.2f", entry.avg))
                                .font(MarqueeFont.body(14.5, .bold, relativeTo: .subheadline))
                                .foregroundStyle(entry.season == season
                                                 ? Color.mqBrass
                                                 : (entry.isIMDb ? Color.mqInkSoft : Color.mqInkMuted))
                                .monospacedDigit()
                            // A sliver under each pill encodes that season's average
                            // against the show's own range — the shape of the run.
                            Capsule().fill(Color.mqPanelRaised)
                                .frame(width: 28, height: 3)
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.mqBrass)
                                        .frame(width: 28 * fraction(of: entry.avg))
                                        .opacity(entry.season == season ? 1 : 0.55)
                                }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(entry.season == season ? Color.mqPanelRaised : .clear,
                                    in: .rect(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(entry.season == season ? Color.mqBrassDim : .clear,
                                          lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Season \(entry.season), average \(String(format: "%.2f", entry.avg))"
                        + (entry.isIMDb ? ", IMDb weighted by votes" : ", TMDB"))
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func fraction(of value: Double) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    private var caption: some View {
        HStack(spacing: 6) {
            Text("Season \(season) · \(episodes.count) episode\(episodes.count == 1 ? "" : "s")")
                .foregroundStyle(Color.mqInkSoft)
            if let average {
                Text("avg \(String(format: "%.2f", average.avg))")
                    .foregroundStyle(Color.mqBrass)
                    .fontWeight(.bold)
                if !average.isIMDb {
                    Text("TMDB").foregroundStyle(Color.mqInkMuted)
                }
            }
        }
        .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
    }

    private var chart: some View {
        Chart {
            if let average {
                RuleMark(y: .value("Season average", average.avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.mqBrass.opacity(0.4))
            }

            ForEach(episodes) { episode in
                AreaMark(x: .value("Episode", episode.number),
                         y: .value("Rating", episode.rating))
                    .foregroundStyle(LinearGradient(
                        colors: [Color.mqBrass.opacity(0.18), Color.mqBrass.opacity(0.01)],
                        startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)

                LineMark(x: .value("Episode", episode.number),
                         y: .value("Rating", episode.rating))
                    .foregroundStyle(Color.mqBrass)
                    .lineStyle(StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)

                PointMark(x: .value("Episode", episode.number),
                          y: .value("Rating", episode.rating))
                    // Hollow means "IMDb hasn't rated this one — the number is TMDB's".
                    .symbol(episode.isIMDb ? .circle : .circle)
                    .symbolSize(episodes.count <= 24 ? 26 : 14)
                    .foregroundStyle(episode.isIMDb ? Color.mqBrass : Color.mqPanel)
                    .opacity(episode.isIMDb ? 0.9 : 1)

                if !episode.isIMDb {
                    PointMark(x: .value("Episode", episode.number),
                              y: .value("Rating", episode.rating))
                        .symbol(.circle)
                        .symbolSize(episodes.count <= 24 ? 26 : 14)
                        .foregroundStyle(.clear)
                        .annotation(position: .overlay) {
                            Circle()
                                .strokeBorder(Color.mqBrass.opacity(0.75), lineWidth: 1.2)
                                .frame(width: episodes.count <= 24 ? 6 : 4.5,
                                       height: episodes.count <= 24 ? 6 : 4.5)
                        }
                }
            }
        }
        .chartYScale(domain: range)
        .chartXAxis {
            AxisMarks(preset: .aligned, values: .automatic(desiredCount: 6)) { value in
                AxisValueLabel {
                    if let number = value.as(Int.self) {
                        Text("\(number)")
                            .font(MarqueeFont.body(10.5, .semibold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading,
                      values: [range.lowerBound, range.upperBound]) { value in
                AxisGridLine().foregroundStyle(Color.mqHairline)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(String(format: "%.0f", number))
                            .font(MarqueeFont.body(10.5, .semibold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
            }
        }
        .chartXSelection(value: $selectedEpisode)
        .chartOverlay { proxy in
            if let selectedEpisode,
               let episode = episodes.first(where: { $0.number == selectedEpisode }) {
                ScrubReadout(episode: episode, proxy: proxy)
            }
        }
        .accessibilityChartDescriptor(RatingsDescriptor(season: season, episodes: episodes))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            Label {
                Text("IMDb")
            } icon: {
                Circle().fill(Color.mqBrass).frame(width: 7, height: 7)
            }
            Label {
                Text("TMDB fallback")
            } icon: {
                Circle().strokeBorder(Color.mqBrass, lineWidth: 1.2).frame(width: 7, height: 7)
            }
        }
        .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
        .foregroundStyle(Color.mqInkMuted)
    }
}

/// The value bubble that follows your finger along the line.
private struct ScrubReadout: View {
    let episode: RatedEpisode
    let proxy: ChartProxy

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("E\(episode.number)\(episode.title.map { " · \($0)" } ?? "")")
                .font(MarqueeFont.body(11, .semibold, relativeTo: .caption2))
                .foregroundStyle(Color.mqInkSoft)
                .lineLimit(1)
            HStack(spacing: 5) {
                Text(String(format: "%.1f", episode.rating))
                    .font(MarqueeFont.body(14, .bold, relativeTo: .caption))
                    .foregroundStyle(Color.mqBrass)
                Text(episode.isIMDb ? "IMDb" : "TMDB")
                    .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                    .foregroundStyle(Color.mqInkMuted)
                if let votes = episode.votes, votes > 0 {
                    Text("· \(RatingChip.compact(votes)) votes")
                        .font(MarqueeFont.body(9.5, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: .rect(cornerRadius: 9))
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }
}

/// VoiceOver gets the whole season as a navigable series rather than a picture.
private struct RatingsDescriptor: AXChartDescriptorRepresentable {
    let season: Int
    let episodes: [RatedEpisode]

    func makeChartDescriptor() -> AXChartDescriptor {
        let x = AXNumericDataAxisDescriptor(
            title: "Episode",
            range: Double(episodes.first?.number ?? 1)...Double(episodes.last?.number ?? 1),
            gridlinePositions: []) { "Episode \(Int($0))" }
        let y = AXNumericDataAxisDescriptor(
            title: "Rating", range: 0...10, gridlinePositions: []) {
                String(format: "%.1f out of 10", $0)
            }
        let series = AXDataSeriesDescriptor(
            name: "Season \(season)",
            isContinuous: true,
            dataPoints: episodes.map {
                AXDataPoint(x: Double($0.number), y: $0.rating,
                            additionalValues: [],
                            label: "\($0.title ?? "Episode \($0.number)"), \($0.isIMDb ? "IMDb" : "TMDB")")
            })
        return AXChartDescriptor(title: "Season \(season) ratings",
                                 summary: nil, xAxis: x, yAxis: y, series: [series])
    }
}
