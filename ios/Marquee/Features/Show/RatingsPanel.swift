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
    @State private var readoutWidth: CGFloat = 0

    private var seasons: [Int] {
        Array(Set(ratings.episodes.map(\.season))).sorted()
    }

    private var season: Int { activeSeason ?? seasons.first ?? 1 }

    private var episodes: [RatedEpisode] {
        ratings.episodes
            // Specials arrive numbered 0 and there is no episode zero to plot.
            .filter { $0.season == season && $0.number > 0 }
            .sorted { $0.number < $1.number }
    }

    /// The x band the line actually occupies, so the axis can't invent an episode 0
    /// at one end or a phantom episode past the finale at the other.
    private var episodeRange: ClosedRange<Int> {
        let numbers = episodes.map(\.number)
        guard let first = numbers.min(), let last = numbers.max() else { return 1...1 }
        return first...max(first, last)
    }

    /// Ticks that land on real episode numbers and keep clear of the ends.
    ///
    /// The plot runs to both screen edges, so a label on the first or last episode is
    /// half off the screen — which reads as a clipping bug rather than a bleed. The
    /// caption already says how many episodes there are; the ticks only have to give
    /// the eye somewhere to land in between.
    private var axisValues: [Int] {
        let low = episodeRange.lowerBound
        let high = episodeRange.upperBound
        let span = high - low
        guard span > 2 else { return [] }
        let step = max(1, Int((Double(span) / 4).rounded()))
        return Array(stride(from: low + step, to: high, by: step))
    }

    private var average: SeasonAverage? {
        ratings.seasonAvg.first { $0.season == season }
    }

    /// The band the *shown season* occupies, with a little air either side.
    ///
    /// Taken from this season rather than the whole show: a run that dips once in
    /// series three used to stretch every other season's axis down to meet it, so a
    /// season sitting between 7.2 and 8.7 was drawn inside a 6-to-10 frame and spent
    /// most of its height as empty space.
    private var range: ClosedRange<Double> {
        let values = episodes.map(\.rating)
        guard let low = values.min(), let high = values.max() else { return 0...10 }
        let air = max(0.3, (high - low) * 0.22)
        return max(0, low - air)...min(10, high + air)
    }

    private var best: RatedEpisode? {
        episodes.max { $0.rating < $1.rating }
    }

    var body: some View {
        DetailSection(title: "Ratings", count: overallCaption) {
            VStack(alignment: .leading, spacing: 12) {
                if ratings.seasonAvg.count > 1 {
                    seasonStrip.padding(.horizontal, MQ.gutter)
                }
                caption.padding(.horizontal, MQ.gutter)
                // Full width, no panel: the run of a season is the picture, and it
                // reads better as a band across the page than as a chart in a box
                // inset twice from the edges.
                chart
                    .frame(height: 190)
                    .padding(.top, 4)
                if ratings.isMixed { legend.padding(.horizontal, MQ.gutter) }
            }
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
                        // The sliver that used to sit under each average is gone: it
                        // encoded the same number twice, in a form too small to read.
                        VStack(spacing: 2) {
                            Text("S\(entry.season)")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .tracking(0.6)
                                .foregroundStyle(entry.season == season
                                                 ? Color.mqBrassOnFill.opacity(0.75)
                                                 : Color.mqInkMuted)
                            Text(String(format: "%.2f", entry.avg))
                                .font(MarqueeFont.body(15, .bold, relativeTo: .subheadline))
                                .foregroundStyle(entry.season == season
                                                 ? Color.mqBrassOnFill
                                                 : (entry.isIMDb ? Color.mqInkSoft : Color.mqInkMuted))
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(entry.season == season
                                    ? AnyShapeStyle(Color.mqBrassFill)
                                    : AnyShapeStyle(Color.mqPanel),
                                    in: .rect(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .strokeBorder(entry.season == season ? .clear : Color.mqHairline,
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

    /// The average is written on the chart itself now, so this says the things the
    /// picture can't: which season, how many episodes, and whose numbers they are.
    private var caption: some View {
        HStack(spacing: 6) {
            Text("Season \(season)")
                .foregroundStyle(Color.mqInk)
                .fontWeight(.bold)
            Text("·").foregroundStyle(Color.mqInkMuted)
            Text("\(episodes.count) episode\(episodes.count == 1 ? "" : "s")")
                .foregroundStyle(Color.mqInkSoft)
            if let average, !average.isIMDb {
                Text("· TMDB").foregroundStyle(Color.mqInkMuted)
            }
        }
        .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
    }

    private var chart: some View {
        Chart {
            if let average {
                RuleMark(y: .value("Season average", average.avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .foregroundStyle(Color.mqBrass.opacity(0.45))
                    // The number sits on the line it describes. An axis of bare
                    // bounds told you the frame; this tells you the season.
                    .annotation(position: .top, alignment: .leading, spacing: 3) {
                        Text("avg \(String(format: "%.2f", average.avg))")
                            .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqBrass)
                            .padding(.leading, MQ.gutter)
                    }
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
                    // The season's high point, named. One number worth reading beats
                    // a column of axis ticks nobody looks at.
                    .annotation(position: .top, spacing: 4) {
                        if episode.id == best?.id, selectedEpisode == nil {
                            Text(String(format: "%.1f", episode.rating))
                                .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqInk)
                        }
                    }

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
        .chartXScale(domain: Double(episodeRange.lowerBound)...Double(episodeRange.upperBound))
        // A monotone curve overshoots its own data, and Charts doesn't clip by
        // default — which is how the fill ended up spilling below the grid.
        .chartPlotStyle { plot in plot.clipped() }
        // Bleeds to both edges; only the axis numbers keep to the gutter.
        .chartXAxis {
            AxisMarks(preset: .aligned, values: axisValues.map(Double.init)) { value in
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text("\(Int(number))")
                            .font(MarqueeFont.body(10.5, .semibold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
            }
        }

        // No y axis. Its only labels were the two ends of a computed frame, which
        // said nothing about the show — the average rule and the season's high point
        // carry the numbers now, and a couple of faint rules carry the shape.
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.mqHairline.opacity(0.6))
            }
        }
        .chartXSelection(value: $selectedEpisode)
        // A tick under the finger, the way every other scrubbable control on the
        // system behaves.
        .sensoryFeedback(.selection, trigger: selectedEpisode)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                if let selectedEpisode,
                   let episode = episodes.first(where: { $0.number == selectedEpisode }),
                   let anchor = proxy.plotFrame {
                    let plot = geometry[anchor]
                    let x = (proxy.position(forX: Double(selectedEpisode)) ?? 0) + plot.minX

                    Rectangle()
                        .fill(Color.mqBrass.opacity(0.35))
                        .frame(width: 1, height: plot.height)
                        .position(x: x, y: plot.midY)

                    ScrubReadout(episode: episode)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                            readoutWidth = width
                        }
                        // Follows the finger, but stops at the edges rather than
                        // hanging off the panel.
                        .position(x: min(max(x, plot.minX + readoutWidth / 2),
                                         plot.maxX - readoutWidth / 2),
                                  y: plot.minY + 2)
                }
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
        .fixedSize()
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
