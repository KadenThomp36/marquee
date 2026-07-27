import Charts
import SwiftUI

/// The in-depth reading numbers: pace, streaks, the clock, month by month.
///
/// Books count in pages and manga in chapters, so the same block is rendered twice
/// with a different unit rather than merged into one meaningless total.
struct ReadingStatsScreen: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var stats = RemoteData<ReadingStatsResponse>(cacheKey: "reading-stats")

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        if let value = stats.value {
                            if session.me?.features?.tracksBooks == true, let books = value.books {
                                block("Books", books, unit: "pages")
                            }
                            if session.me?.features?.tracksManga == true, let manga = value.manga {
                                block("Manga", manga, unit: "chapters")
                            }
                        } else if stats.isEmpty {
                            VStack(spacing: 12) {
                                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 92) }
                            }
                            .padding(.horizontal, MQ.gutter)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .task { await load() }
        }
        .presentationBackground(Color.mqGround)
    }

    @ViewBuilder
    private func block(_ name: String, _ stats: ReadingStats, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(name).mqEyebrowStyle().padding(.horizontal, MQ.gutter)

            if stats.isEmpty {
                EmptyLine("No \(unit) logged yet — start a session or punch some progress.")
            } else {
                StatTileGrid(tiles: tiles(stats, unit: unit))

                if let daily = stats.daily30, daily.contains(where: { $0.units > 0 }) {
                    ChartCard(title: "Last 30 days",
                              badge: "\(stats.totals.month.mqGrouped) \(unit)") {
                        Chart(daily) { day in
                            BarMark(x: .value("Day", MQTime.date(from: day.date) ?? Date(),
                                              unit: .day),
                                    y: .value(unit.capitalized, day.units))
                                .foregroundStyle(Color.mqChartAmber)
                                .cornerRadius(2)
                        }
                        .chartYAxis { AxisMarks(position: .leading) }
                        .frame(height: 130)
                    }
                }

                if let monthly = stats.monthly, monthly.count > 1 {
                    ChartCard(title: "Month by month",
                              badge: "\(monthly.reduce(0) { $0 + $1.units }.mqGrouped) total") {
                        Chart(monthly) { month in
                            AreaMark(x: .value("Month", month.key),
                                     y: .value(unit.capitalized, month.units))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.mqBrass.opacity(0.35), Color.mqBrass.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom))
                                .interpolationMethod(.monotone)
                            LineMark(x: .value("Month", month.key),
                                     y: .value(unit.capitalized, month.units))
                                .foregroundStyle(Color.mqBrass)
                                .interpolationMethod(.monotone)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                                AxisValueLabel {
                                    if let key = value.as(String.self) {
                                        Text(key.suffix(2)).font(.mqCaption)
                                    }
                                }
                            }
                        }
                        .frame(height: 140)
                    }
                }

                if let clock = stats.clock, clock.contains(where: { $0 > 0 }) {
                    ChartCard(title: "Reading clock", badge: nil,
                              subtitle: "minutes in timed sessions, by hour") {
                        Chart(Array(clock.enumerated()), id: \.offset) { hour, minutes in
                            BarMark(x: .value("Hour", hour),
                                    y: .value("Minutes", minutes))
                                .foregroundStyle(Color.mqChartBlue)
                                .cornerRadius(2)
                        }
                        .chartXAxis {
                            AxisMarks(values: [0, 6, 12, 18]) { value in
                                AxisValueLabel {
                                    if let hour = value.as(Int.self) {
                                        Text(hourLabel(hour)).font(.mqCaption)
                                    }
                                }
                            }
                        }
                        .frame(height: 120)
                    }
                }

                records(stats, unit: unit)
            }
        }
    }

    private func tiles(_ stats: ReadingStats, unit: String) -> [StatTile] {
        var out: [StatTile] = [
            StatTile(value: stats.totals.month.mqGrouped, unit: unit,
                     label: "this month", detail: "\(stats.totals.week) this week · \(stats.totals.all.mqGrouped) all time",
                     tint: .mqChartAmber, isWide: true),
            StatTile(value: "\(stats.finished.year)", unit: nil, label: "finished this year",
                     detail: "\(stats.finished.all) all time · \(stats.readingNow) in progress",
                     tint: .mqChartBlue),
            StatTile(value: "\(stats.streak.current)", unit: "days", label: "reading streak",
                     detail: "best \(stats.streak.longest) days", tint: .mqChartGreen),
        ]
        if let pace = stats.pace {
            out.append(StatTile(value: String(format: "%.1f", pace), unit: "\(unit)/hr",
                                label: "reading pace",
                                detail: stats.avgSessionMin.map { "avg session \($0) min" },
                                tint: .mqChartViolet))
        } else {
            out.append(StatTile(value: "\(stats.totals.sessions)", unit: nil,
                                label: "progress updates",
                                detail: "\(stats.totals.timedSessions) timed sessions",
                                tint: .mqChartViolet))
        }
        return out
    }

    @ViewBuilder
    private func records(_ stats: ReadingStats, unit: String) -> some View {
        let items: [StatTile] = [
            stats.fastest.map { StatTile(value: "\($0.days)", unit: "days",
                                         label: "fastest finish", detail: $0.title,
                                         tint: .mqChartOrange) },
            stats.longest.map { StatTile(value: $0.units.mqGrouped, unit: unit,
                                         label: "longest finished", detail: $0.title,
                                         tint: .mqChartPink) },
            stats.bigDay.map { StatTile(value: "\($0.units)", unit: unit,
                                        label: "biggest day", detail: MQTime.medium($0.date),
                                        tint: .mqChartAqua) },
        ].compactMap { $0 }
        if !items.isEmpty { StatTileGrid(tiles: items) }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: "12a"
        case 12: "12p"
        case ..<12: "\(hour)a"
        default: "\(hour - 12)p"
        }
    }

    private func load() async {
        guard let client = session.client else { return }
        await stats.load { try await client.get("reading/stats", as: ReadingStatsResponse.self) }
    }
}

// MARK: - Shared stat pieces

struct StatTile: Identifiable {
    let id = UUID()
    var value: String
    var unit: String?
    var label: String
    var detail: String?
    var tint: Color
    var isWide = false
}

/// The jewel-box tiles: a tinted number, a label, and the context underneath.
struct StatTileGrid: View {
    let tiles: [StatTile]

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 150, spacing: 10)

    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(tiles) { tile in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(tile.value)
                            .font(MarqueeFont.body(tile.isWide ? 27 : 22, .bold, relativeTo: .title))
                            .foregroundStyle(tile.tint)
                            .monospacedDigit()
                        if let unit = tile.unit {
                            Text(unit)
                                .font(MarqueeFont.body(11, .semibold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqInkMuted)
                        }
                    }
                    Text(tile.label)
                        .font(MarqueeFont.body(12, .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.mqInkSoft)
                    if let detail = tile.detail {
                        Text(detail)
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(13)
                .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
                .overlay(alignment: .leading) {
                    Rectangle().fill(tile.tint).frame(width: 3)
                        .clipShape(.rect(topLeadingRadius: MQ.radiusSmall,
                                         bottomLeadingRadius: MQ.radiusSmall))
                }
                .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
                    .strokeBorder(Color.mqHairline, lineWidth: 1))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(tile.value) \(tile.unit ?? "") \(tile.label). \(tile.detail ?? "")")
            }
        }
        .padding(.horizontal, MQ.gutter)
    }
}

/// A titled card that holds one chart.
struct ChartCard<Content: View>: View {
    let title: String
    var badge: String?
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.mqInk)
                Spacer(minLength: 8)
                if let badge {
                    Text(badge)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqBrass)
                        .monospacedDigit()
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel()
        .padding(.horizontal, MQ.gutter)
    }
}
