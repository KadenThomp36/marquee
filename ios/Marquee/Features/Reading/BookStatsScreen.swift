import SwiftUI

/// One book's reading, in depth — the web's `#/book/<id>/stats`, natively.
///
/// The finish date is the headline, set in Limelight like an opening date on a
/// marquee, bulbs and all. Under it, quietly: the numbers, the whole book as one strip
/// with every sitting laid across the stretch it covered (coloured by where it came
/// from — Folio on the Palma, this app, the web), a calendar, and chapter pace when
/// Folio sent chapters. The sittings themselves are the facing page: on a phone they
/// follow on below; on the Duo opened out they sit across the fold, gutter on the
/// crease, each one tappable to fix.
struct BookStatsScreen: View {
    let bookID: Int

    @Environment(Session.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var stats: BookStats?
    @State private var error: String?
    @State private var editing: BookStats.Sitting?

    var body: some View {
        MarqueeScreen {
            if let stats {
                if stats.sessions.isEmpty {
                    ScrollView { VStack(alignment: .leading, spacing: 20) {
                        hero(stats)
                        empty
                    } }
                } else {
                    FoldSpread(spacing: 22, refresh: { await load() }) {
                        hero(stats)
                        summary(stats)
                    } trailing: {
                        sittings(stats)
                    }
                }
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                VStack(spacing: 14) {
                    SkeletonBlock(height: 120)
                    SkeletonBlock(height: 170)
                    SkeletonBlock(height: 60)
                }
                .padding(MQ.gutter)
            }
        }
        // The hero already names the book; the bar says what this page is.
        .navigationTitle("Reading stats")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $editing) { sitting in
            SessionEditorSheet(entry: sitting.logEntry, kind: .book,
                               mode: ProgressMode(rawValue: stats?.state?.mode ?? "") ?? .pages,
                               total: stats?.book.pages, chapters: stats?.book.chapters,
                               pages: stats?.book.pages) {
                await load()
            }
        }
    }

    // MARK: - Leading page

    private func hero(_ stats: BookStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom, spacing: 14) {
                CoverArt(url: stats.book.cover, radius: 9).frame(width: 70)
                VStack(alignment: .leading, spacing: 3) {
                    Text(stats.book.displayTitle)
                        .font(MarqueeFont.body(21, .bold, relativeTo: .title2))
                        .foregroundStyle(Color.mqInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if let author = stats.book.author, !author.isEmpty {
                        Text(author).font(.mqSub).foregroundStyle(Color.mqInkSoft)
                    }
                    if let whereLine = whereLine(stats) {
                        Text(whereLine)
                            .font(MarqueeFont.body(13, .semibold, relativeTo: .subheadline))
                            .foregroundStyle(Color.mqBrass)
                            .monospacedDigit()
                            .padding(.top, 3)
                    }
                }
            }
            if let live = stats.live, let started = MQTime.date(from: live.startedAt) {
                HStack(spacing: 10) {
                    Circle().fill(Color.mqChartGreen).frame(width: 8, height: 8)
                    Text("Reading now").font(.mqSub).foregroundStyle(Color.mqInkSoft)
                    Spacer()
                    Text(started, style: .timer)
                        .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                        .foregroundStyle(Color.mqInk)
                        .monospacedDigit()
                }
                .padding(11)
                .mqPanel()
                .accessibilityElement(children: .combine)
            } else if let recent = stats.recentFolio {
                FolioSyncedLine(recent: recent, verb: "Synced from")
            }
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 10)
    }

    private func whereLine(_ stats: BookStats) -> String? {
        guard let state = stats.state else { return nil }
        if state.readingState == .finished {
            return "Finished \(MQTime.medium(state.finishedAt))"
        }
        guard let fraction = state.fraction else { return nil }
        let pct = Int((fraction * 100).rounded())
        if let pages = stats.book.pages {
            return "\(pct)% read · page \(state.progress ?? 0) of \(pages)"
        }
        return "\(pct)% read"
    }

    @ViewBuilder
    private func summary(_ stats: BookStats) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            MarqueeSign(stats: stats)
            numbers(stats)
            section("The book, sitting by sitting") {
                BookRibbon(stats: stats)
                FlowLayout(spacing: 14, lineSpacing: 6) {
                    ForEach(stats.sources) { source in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2.5)
                                .fill(SittingSource.color(source.source))
                                .frame(width: 10, height: 10)
                            Text(source.label).font(.mqCaption).foregroundStyle(Color.mqInkSoft)
                            Text("\(source.sessions) · \(BookStatsFormat.duration(source.minutes))")
                                .font(.mqCaption).foregroundStyle(Color.mqInkMuted).monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                    }
                    if stats.totals.checkpoints > 0 {
                        HStack(spacing: 6) {
                            Capsule().fill(Color.mqBrassDim).frame(width: 10, height: 4)
                            Text("progress updates").font(.mqCaption).foregroundStyle(Color.mqInkSoft)
                            Text("\(stats.totals.checkpoints)").font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                        }
                    }
                }
            }
            section("When you read it", trailing: "^[\(stats.totals.days) day](inflect: true)") {
                ReadingCalendar(days: stats.days)
            }
            if !stats.chapters.isEmpty {
                section("Chapter by chapter") {
                    Text("Time in each chapter, from Folio, and how fast it went — tinted when it's quicker or slower than your usual for this book.")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    ChapterPace(chapters: stats.chapters)
                }
            }
        }
        .padding(.horizontal, MQ.gutter)
    }

    private func numbers(_ stats: BookStats) -> some View {
        let pace: (String, String) = if let pph = stats.pace.pagesPerHour {
            ("\(Int(pph.rounded()))", "pages an hour")
        } else if let pct = stats.pace.pctPerHour {
            ("\(pct.formatted(.number.precision(.fractionLength(0...1))))%", "of the book an hour")
        } else {
            ("—", "pace, after timed sittings")
        }
        let cells: [(String, String)] = [
            (BookStatsFormat.duration(stats.totals.minutes), "reading time"),
            ("\(stats.totals.sessions)", stats.totals.sessions == 1 ? "sitting" : "sittings"),
            pace,
            (stats.totals.avgMinutes.map(BookStatsFormat.duration) ?? "—", "typical sitting"),
        ]
        let columns = typeSize.isAccessibilitySize ? 1 : 2
        return Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 14) {
            ForEach(Array(stride(from: 0, to: cells.count, by: columns)), id: \.self) { row in
                GridRow {
                    ForEach(row..<min(row + columns, cells.count), id: \.self) { index in
                        HStack(spacing: 0) {
                            if index % columns != 0 {
                                Rectangle().fill(Color.mqHairline).frame(width: 1).padding(.trailing, 14)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cells[index].0)
                                    .font(MarqueeFont.body(22, .heavy, relativeTo: .title2))
                                    .foregroundStyle(Color.mqInk)
                                    .monospacedDigit()
                                Text(cells[index].1).font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, trailing: LocalizedStringKey? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(title).mqEyebrowStyle()
                Rectangle().fill(Color.mqHairline).frame(height: 1)
                if let trailing {
                    Text(trailing).font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No sittings yet. Start a session on the book’s page, or read it in Folio — every sitting lands here with its time, pages and chapters.")
                .font(.mqBody)
                .foregroundStyle(Color.mqInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel(radius: MQ.radius)
        .padding(.horizontal, MQ.gutter)
    }

    // MARK: - Facing page

    @ViewBuilder
    private func sittings(_ stats: BookStats) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            section("Sittings", trailing: "\(stats.sessions.filter { !$0.checkpoint }.count)") {
                Text("Tap one to fix its date, length or pages.")
                    .font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            }
            ForEach(monthGroups(stats.sessions), id: \.key) { group in
                Text(group.title)
                    .font(MarqueeFont.body(13, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                    .padding(.top, 16)
                    .padding(.bottom, 2)
                    .accessibilityAddTraits(.isHeader)
                ForEach(group.items) { sitting in
                    Button { editing = sitting } label: {
                        SittingRow(sitting: sitting, pages: stats.book.pages)
                    }
                    .buttonStyle(.plain)
                    if sitting.id != group.items.last?.id {
                        Divider().overlay(Color.mqHairline).padding(.leading, 52)
                    }
                }
            }
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 10)
    }

    private struct MonthGroup { let key: String; let title: String; let items: [BookStats.Sitting] }

    private func monthGroups(_ sittings: [BookStats.Sitting]) -> [MonthGroup] {
        var order: [String] = []
        var byMonth: [String: [BookStats.Sitting]] = [:]
        for sitting in sittings {
            let key = String(sitting.startedAt.prefix(7))
            if byMonth[key] == nil { order.append(key) }
            byMonth[key, default: []].append(sitting)
        }
        return order.map { key in
            let title = MQTime.date(from: key + "-01")?.formatted(.dateTime.month(.wide).year()) ?? key
            return MonthGroup(key: key, title: title, items: byMonth[key] ?? [])
        }
    }

    // MARK: - Loading

    private func load() async {
        guard let client = session.client else { return }
        do {
            stats = try await client.get("book/\(bookID)/stats", as: BookStats.self)
            error = nil
        } catch let failure as APIError {
            if stats == nil { error = failure.errorDescription }
        } catch {
            if stats == nil { self.error = error.localizedDescription }
        }
    }
}

// MARK: - Pieces

enum BookStatsFormat {
    /// "34 min", "3 h 43 min" — reading time in words that read aloud well.
    static func duration(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes) min"
            : "\(minutes / 60) h" + (minutes % 60 > 0 ? " \(minutes % 60) min" : "")
    }
}

/// Where a sitting came from, as a colour that means the same thing everywhere: the
/// legend, the strip, the row's pill.
enum SittingSource {
    static func color(_ source: String?) -> Color {
        switch source {
        case "folio": .mqChartAqua
        case "ios": .mqChartBlue
        case "web": .mqChartViolet
        default: .mqChartYellow
        }
    }
}

/// "Synced from Boox Palma 2 hr ago — 40 min, up to Chapter 19."
struct FolioSyncedLine: View {
    let recent: RecentFolio
    var verb = "Read on"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "book.pages")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.mqChartAqua)
                .accessibilityHidden(true)
            Text(line)
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.mqChartAqua.opacity(0.08), in: .rect(cornerRadius: MQ.radiusSmall))
        .overlay {
            RoundedRectangle(cornerRadius: MQ.radiusSmall)
                .strokeBorder(Color.mqChartAqua.opacity(0.3), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var line: AttributedString {
        var device = AttributedString(recent.device)
        device.foregroundColor = .mqInk
        device.font = MarqueeFont.body(13, .bold, relativeTo: .subheadline)
        var details = [BookStatsFormat.duration(recent.minutes)]
        if let pages = recent.pages, pages > 0 { details.append("\(pages) pages") }
        if let chapter = recent.chapter, !chapter.isEmpty { details.append("up to \(chapter)") }
        return AttributedString("\(verb) ") + device
            + AttributedString(" \(MQTime.relative(recent.endedAt)) — \(details.joined(separator: ", "))")
    }
}

/// The finish date, lit like an opening date on a marquee: a row of bulbs along the
/// top and bottom, the date in Limelight with a warm glow, the arithmetic under it.
private struct MarqueeSign: View {
    let stats: BookStats
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if let content {
            VStack(alignment: .leading, spacing: 4) {
                Text(content.kicker)
                    .font(MarqueeFont.body(13, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInkSoft)
                if let date = content.date {
                    Text(date)
                        .font(MarqueeFont.wordmark(50, relativeTo: .largeTitle))
                        .foregroundStyle(Color.mqBrass)
                        .shadow(color: reduceTransparency ? .clear : Color.mqBrassFill.opacity(0.45), radius: 14)
                        .padding(.vertical, 2)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Text(content.line)
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: MQ.radius)
                    .fill(Color.mqPanel)
                    .overlay { if content.date != nil { Bulbs().padding(.horizontal, 12) } }
            }
            .overlay {
                RoundedRectangle(cornerRadius: MQ.radius)
                    .strokeBorder(content.date != nil ? Color.mqBrassDim : Color.mqHairline, lineWidth: 1)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private struct Content { var kicker: String; var date: String?; var line: String }

    private var content: Content? {
        let state = stats.state
        if state?.readingState == .finished, let finished = MQTime.date(from: state?.finishedAt) {
            return Content(kicker: "Finished",
                           date: finished.formatted(.dateTime.month(.abbreviated).day()),
                           line: "\(stats.totals.days) day\(stats.totals.days == 1 ? "" : "s") of reading, \(BookStatsFormat.duration(stats.totals.minutes)) in all")
        }
        if let forecast = stats.forecast, let date = MQTime.date(from: forecast.date) {
            let rate = forecast.unit == "pct"
                ? "\((forecast.perDay ?? 0).formatted(.number.precision(.fractionLength(0...1))))% a day"
                : "\((forecast.perDay ?? 0).formatted(.number.precision(.fractionLength(0...1)))) pages a day"
            var line = "\(forecast.days) day\(forecast.days == 1 ? "" : "s") at your recent \(rate)"
            if let hours = forecast.hoursLeft {
                line += " — about \(BookStatsFormat.duration(Int((hours * 60).rounded()))) of reading left"
            }
            return Content(kicker: "Finishing around",
                           date: date.formatted(.dateTime.month(.abbreviated).day()), line: line)
        }
        if state?.readingState == .reading {
            return Content(kicker: "No finish date yet", date: nil,
                           line: "A forecast appears after a few sittings in the last three weeks.")
        }
        return nil
    }
}

/// The marquee's bulbs — evenly spaced dots along the top and bottom edges.
private struct Bulbs: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 15
            let count = max(2, Int(size.width / step))
            let gap = size.width / CGFloat(count)
            for row in [CGFloat(8), size.height - 8] {
                for index in 0...count {
                    let x = CGFloat(index) * gap
                    let rect = CGRect(x: x - 1.5, y: row - 1.5, width: 3, height: 3)
                    context.fill(Path(ellipseIn: rect), with: .color(.mqBrassBright.opacity(0.85)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The whole book as one strip, start to end, with every sitting laid across the
/// stretch it covered and a marker where you are now.
private struct BookRibbon: View {
    let stats: BookStats

    private var here: Double? {
        guard let fraction = stats.state?.fraction, fraction < 1 else { return nil }
        return fraction
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(Color.mqPanelRaised)
                    ForEach(stats.sessions.reversed()) { sitting in
                        if let span = sitting.span(pages: stats.book.pages) {
                            let barWidth = max(3, (span.end - span.start) * width)
                            Rectangle()
                                .fill(sitting.checkpoint ? Color.mqBrassDim : SittingSource.color(sitting.source))
                                .opacity(sitting.checkpoint ? 0.75 : 0.92)
                                .frame(width: barWidth, height: sitting.checkpoint ? 6 : 32)
                                .offset(x: span.start * width)
                        }
                    }
                    ForEach([0.25, 0.5, 0.75], id: \.self) { tick in
                        Rectangle().fill(Color.mqGround).frame(width: 2, height: 32)
                            .offset(x: tick * width - 1)
                    }
                }
                .frame(height: 32)
                .clipShape(.rect(cornerRadius: 5))
                .overlay(alignment: .leading) {
                    if let here {
                        VStack(spacing: 0) {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.mqBrassFill)
                            Rectangle().fill(Color.mqBrassFill).frame(width: 2, height: 40)
                        }
                        .offset(x: here * width - 5, y: -2)
                        .accessibilityHidden(true)
                    }
                }
            }
            .frame(height: 40)

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    scaleLabel("start").frame(maxWidth: .infinity, alignment: .leading)
                    scaleLabel("end").frame(maxWidth: .infinity, alignment: .trailing)
                    ForEach([0.25, 0.5, 0.75], id: \.self) { mark in
                        // the marker's own label wins when they'd overlap
                        if here.map({ abs($0 - mark) > 0.09 }) ?? true {
                            scaleLabel("\(Int(mark * 100))%").position(x: mark * width, y: 7)
                        }
                    }
                    if let here {
                        Text("you’re here")
                            .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqBrass)
                            .fixedSize()
                            .padding(.horizontal, 4)
                            .background(Color.mqGround)
                            .position(x: min(max(here * width, 34), width - 34), y: 7)
                    }
                }
            }
            .frame(height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func scaleLabel(_ text: String) -> some View {
        Text(text)
            .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
            .foregroundStyle(Color.mqInkMuted)
            .fixedSize()
    }

    private var accessibilityText: String {
        let timed = stats.sessions.filter { !$0.checkpoint }.count
        var text = "\(timed) sittings across the book"
        if let here { text += ". You're \(Int((here * 100).rounded()))% through" }
        return text
    }
}

/// A calendar of the days you read it: one square per day, brighter for more time,
/// weeks running left to right and the last ~half year shown.
private struct ReadingCalendar: View {
    let days: [BookStats.Day]
    /// Measured, so the canvas is exactly as tall as seven rows plus the month line.
    @State private var width: CGFloat = 340

    private static let gap: CGFloat = 3
    private static let top: CGFloat = 16
    private static func cell(width: CGFloat, weeks: Int) -> CGFloat {
        min(20, (width - gap * CGFloat(weeks - 1)) / CGFloat(weeks))
    }

    private var model: (weeks: Int, start: Date, cells: [Date: Double], max: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let first = days.first.flatMap { MQTime.date(from: $0.date) } ?? today
        let span = (calendar.dateComponents([.day], from: first, to: today).day ?? 0) / 7 + 1
        let weeks = min(26, max(14, span))
        let weekday = calendar.component(.weekday, from: today) - 1   // Sunday = 0
        let start = calendar.date(byAdding: .day, value: -weekday - 7 * (weeks - 1), to: today) ?? today
        var cells: [Date: Double] = [:]
        for day in days {
            if let date = MQTime.date(from: day.date) {
                cells[calendar.startOfDay(for: date)] = day.minutes > 0 ? day.minutes : 0.01
            }
        }
        return (weeks, start, cells, max(1, cells.values.max() ?? 1))
    }

    var body: some View {
        let model = model
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        VStack(alignment: .leading, spacing: 10) {
            Canvas { context, size in
                let gap = Self.gap
                let top = Self.top
                let cell = Self.cell(width: size.width, weeks: model.weeks)
                var lastMonth = -1
                var labels: [(Int, String)] = []
                for week in 0..<model.weeks {
                    guard let weekStart = calendar.date(byAdding: .day, value: 7 * week, to: model.start)
                    else { continue }
                    let month = calendar.component(.month, from: weekStart)
                    if month != lastMonth {
                        lastMonth = month
                        if week < model.weeks - 1 {
                            labels.append((week, weekStart.formatted(.dateTime.month(.abbreviated))))
                        }
                    }
                    for row in 0..<7 {
                        guard let day = calendar.date(byAdding: .day, value: row, to: weekStart) else { continue }
                        let rect = CGRect(x: CGFloat(week) * (cell + gap), y: top + CGFloat(row) * (cell + gap),
                                          width: cell, height: cell)
                        let path = Path(roundedRect: rect, cornerRadius: 3)
                        if day > today {
                            context.stroke(path, with: .color(.mqHairline), lineWidth: 1)
                            continue
                        }
                        context.fill(path, with: .color(.mqPanelRaised))
                        if let minutes = model.cells[day] {
                            let alpha = minutes < 1 ? 0.14 : 0.2 + 0.8 * (minutes / model.max).squareRoot()
                            context.fill(path, with: .color(.mqBrassFill.opacity(alpha)))
                        }
                        if day == today {
                            context.stroke(path, with: .color(.mqInkSoft), lineWidth: 1.2)
                        }
                    }
                }
                // a partial first month would crowd the next label — keep only those with room
                for (index, label) in labels.enumerated()
                where index + 1 >= labels.count || labels[index + 1].0 - label.0 >= 3 {
                    context.draw(Text(label.1).font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
                                    .foregroundStyle(Color.mqInkMuted),
                                 at: CGPoint(x: CGFloat(label.0) * (cell + gap), y: 0), anchor: .topLeading)
                }
            }
            .frame(height: Self.top + 7 * Self.cell(width: min(width, CGFloat(model.weeks) * 23), weeks: model.weeks) + 6 * Self.gap)
            .frame(maxWidth: CGFloat(model.weeks) * 23)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }

            HStack(spacing: 5) {
                Text("less").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                ForEach([0.2, 0.45, 0.7, 1.0], id: \.self) { alpha in
                    RoundedRectangle(cornerRadius: 3).fill(Color.mqBrassFill.opacity(alpha))
                        .frame(width: 12, height: 12)
                }
                Text("more time").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Read on \(days.filter { $0.minutes >= 1 }.count) days")
    }
}

/// Time in each chapter as a bar, with the pace beside it — printed pages an hour
/// (or % without a page count) from Folio's chapter fractions, screens turned only as
/// the fallback — tinted when it's well off your usual, comparing like with like.
private struct ChapterPace: View {
    let chapters: [BookStats.Chapter]
    @State private var showingAll = false
    private static let cap = 12

    private static func pace(_ value: Double, unit: String?) -> String {
        switch unit {
        case "pages": "\(Int(value.rounded())) p/hr"
        case "pct": "\(value.formatted(.number.precision(.fractionLength(value < 10 ? 1 : 0))))%/hr"
        default: "\(Int(value.rounded())) screens/hr"
        }
    }

    var body: some View {
        let longest = max(1, chapters.map(\.minutes).max() ?? 1)
        var averages: [String: Double] = [:]
        for unit in Set(chapters.map { $0.paceUnit ?? "screens" }) {
            let values = chapters.filter { ($0.paceUnit ?? "screens") == unit }.compactMap(\.perHour)
            if !values.isEmpty { averages[unit] = values.reduce(0, +) / Double(values.count) }
        }
        let shown = showingAll ? chapters : Array(chapters.prefix(Self.cap))
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(shown) { chapter in
                HStack(spacing: 10) {
                    Text(chapter.title)
                        .font(.mqSub)
                        .foregroundStyle(Color.mqInkSoft)
                        .lineLimit(1)
                        .frame(width: 90, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.mqPanelRaised)
                            Capsule().fill(Color.mqBrassFill)
                                .frame(width: max(4, proxy.size.width * chapter.minutes / longest))
                        }
                    }
                    .frame(height: 8)
                    Text(BookStatsFormat.duration(Int(chapter.minutes.rounded())))
                        .font(.mqCaption).foregroundStyle(Color.mqInkSoft).monospacedDigit()
                        .frame(minWidth: 44, alignment: .trailing)
                    if let perHour = chapter.perHour {
                        let unit = chapter.paceUnit ?? "screens"
                        let ratio = averages[unit].map { perHour / $0 } ?? 1
                        Text(Self.pace(perHour, unit: chapter.paceUnit))
                            .font(.mqCaption).monospacedDigit()
                            .foregroundStyle(ratio > 1.12 ? Color.mqChartAqua
                                             : ratio < 0.88 ? Color.mqChartOrange : Color.mqInkMuted)
                            .frame(width: 92, alignment: .trailing)   // bars end together
                            .minimumScaleFactor(0.8)
                    }
                }
                .accessibilityElement(children: .combine)
            }
            if chapters.count > Self.cap && !showingAll {
                Button("Show all \(chapters.count) chapters") { showingAll = true }
                    .buttonStyle(.mqChip)
                    .padding(.top, 2)
            }
        }
    }
}

/// One sitting on the facing page: the day, its length and pages, the chapters it
/// crossed, a sliver showing where in the book it ran, and where it came from.
private struct SittingRow: View {
    let sitting: BookStats.Sitting
    let pages: Int?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(day.map { "\(Calendar.current.component(.day, from: $0))" } ?? "")
                    .font(MarqueeFont.body(sitting.checkpoint ? 16 : 20, .heavy, relativeTo: .title3))
                    .foregroundStyle(sitting.checkpoint ? Color.mqInkSoft : Color.mqInk)
                    .monospacedDigit()
                Text(day?.formatted(.dateTime.weekday(.abbreviated)) ?? "")
                    .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
                    .foregroundStyle(Color.mqInkMuted)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                if sitting.checkpoint {
                    Text(pages != nil ? "Progress set to page \(sitting.to)" : "Progress update")
                        .font(.mqSub).foregroundStyle(Color.mqInkSoft)
                } else {
                    HStack(spacing: 6) {
                        Text(BookStatsFormat.duration(sitting.minutes))
                            .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                            .foregroundStyle(Color.mqInk)
                        if let gain { Text(gain).font(.mqSub).foregroundStyle(Color.mqBrass) }
                    }
                    .monospacedDigit()
                }
                Text(detail)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                if let span = sitting.span(pages: pages) {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.mqPanelRaised)
                            Capsule().fill(SittingSource.color(sitting.source))
                                .frame(width: max(3, (span.end - span.start) * proxy.size.width))
                                .offset(x: span.start * proxy.size.width)
                        }
                    }
                    .frame(height: 3)
                    .padding(.top, 3)
                    .accessibilityHidden(true)
                }
            }
            Spacer(minLength: 4)
            Text(sitting.sourceLabel)
                .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                .foregroundStyle(SittingSource.color(sitting.source))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(SittingSource.color(sitting.source).opacity(0.15), in: .capsule)
        }
        .padding(.vertical, 11)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edits this sitting")
    }

    private var day: Date? { MQTime.date(from: sitting.startedAt) }

    private var gain: String? {
        if pages != nil, let gained = sitting.pages { return "+\(gained) page\(gained == 1 ? "" : "s")" }
        if let span = sitting.span(pages: pages) { return "+\(Int(((span.end - span.start) * 100).rounded()))%" }
        return nil
    }

    private var detail: String {
        var parts: [String] = []
        if let day { parts.append(day.formatted(date: .omitted, time: .shortened)) }
        if pages != nil, sitting.pages != nil {
            parts.append("p. \(sitting.from) → \(sitting.to)")
        } else if let span = sitting.span(pages: pages) {
            parts.append("\(Int((span.start * 100).rounded()))% → \(Int((span.end * 100).rounded()))%")
        }
        if let start = sitting.startChapter, let end = sitting.endChapter, start != end {
            parts.append("\(start) → \(end)")
        } else if let chapter = sitting.endChapter ?? sitting.startChapter {
            parts.append(chapter)
        }
        if sitting.source == "folio", let wall = sitting.wallMinutes, wall > sitting.minutes + 4 {
            parts.append("\(wall - sitting.minutes) min idle left out")
        }
        return parts.joined(separator: " · ")
    }
}
