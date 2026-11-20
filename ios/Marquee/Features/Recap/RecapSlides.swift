import SwiftUI

// Year in Review, told like a night at the pictures — the same slides, in the same
// order, as the web client. Each slide is drawn on a fixed canvas (at least 360 × 640
// points) that `RecapCanvas` fits to the screen, so the composition holds from an
// iPhone SE to one page of the open Duo. Each is lit by one stage gel; Limelight
// carries the reveals and Archivo the lines.

enum RecapSlide: Hashable {
    case intro, quiz, count, showOfTheYear, persona, primeTime, bigMonth, genres, films
    case readingShelf, readingRecord, household, record, outro

    static func build(_ recap: Recap) -> [RecapSlide] {
        let watched = (recap.episodes ?? 0) + (recap.movies ?? 0) > 0
        var slides: [RecapSlide] = [.intro]
        if watched, RecapQuiz(recap) != nil { slides.append(.quiz) }
        if watched { slides.append(.count) }
        if recap.topShows?.first != nil { slides.append(.showOfTheYear) }
        if recap.persona != nil { slides.append(.persona) }
        if recap.peakHour != nil, recap.hours?.contains(where: { $0 > 0 }) == true { slides.append(.primeTime) }
        if recap.months?.contains(where: { $0 > 0 }) == true { slides.append(.bigMonth) }
        if (recap.genres?.count ?? 0) >= 2 { slides.append(.genres) }
        if recap.topMovies?.isEmpty == false { slides.append(.films) }
        if let reading = recap.reading {
            slides.append(.readingShelf)
            if reading.favourite != nil || reading.topAuthor != nil || reading.longest != nil || reading.fastest != nil {
                slides.append(.readingRecord)
            }
        }
        if let house = recap.household, house.of > 1 { slides.append(.household) }
        if recap.binge != nil || recap.firstWatch != nil || recap.lastWatch != nil { slides.append(.record) }
        slides.append(.outro)
        return slides
    }

    var gel: Color {
        switch self {
        case .intro, .count, .bigMonth, .outro: RecapGel.amber
        case .quiz, .films, .readingRecord: RecapGel.velvet
        case .showOfTheYear, .genres, .readingShelf: RecapGel.teal
        case .persona, .household: RecapGel.violet
        case .primeTime, .record: RecapGel.blue
        }
    }
}

enum RecapGel {
    static let amber = Color(red: 0.941, green: 0.710, blue: 0.267)
    static let velvet = Color(red: 0.761, green: 0.255, blue: 0.310)
    static let teal = Color(red: 0.090, green: 0.639, blue: 0.467)
    static let violet = Color(red: 0.561, green: 0.498, blue: 0.910)
    static let blue = Color(red: 0.224, green: 0.529, blue: 0.898)
    /// The pale brass the big reveals glow in.
    static let light = Color(red: 1.0, green: 0.851, blue: 0.541)
    static let ground = Color(red: 0.047, green: 0.039, blue: 0.027)
    static let ink = Color(red: 0.949, green: 0.925, blue: 0.875)
    static let inkSoft = Color(red: 0.702, green: 0.659, blue: 0.561)
    static let muted = Color(red: 0.486, green: 0.451, blue: 0.376)
}

/// Fits a fixed design canvas (at least 360 × 640) to whatever space it's given.
struct RecapCanvas<Content: View>: View {
    @ViewBuilder var content: Content

    static var minSize: CGSize { CGSize(width: 360, height: 640) }

    var body: some View {
        GeometryReader { proxy in
            let scale = max(0.1, min(proxy.size.width / Self.minSize.width, proxy.size.height / Self.minSize.height))
            content
                .frame(width: proxy.size.width / scale, height: proxy.size.height / scale)
                .scaleEffect(scale)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// The ground every slide stands on: its gel from above, a little spill below.
struct RecapStage: View {
    let gel: Color

    var body: some View {
        ZStack {
            RecapGel.ground
            RadialGradient(colors: [gel.opacity(0.46), .clear], center: UnitPoint(x: 0.5, y: -0.06),
                           startRadius: 0, endRadius: 420)
                .scaleEffect(x: 1.5, y: 1, anchor: .top)
            RadialGradient(colors: [gel.opacity(0.14), .clear], center: UnitPoint(x: 0.5, y: 1.1),
                           startRadius: 0, endRadius: 260)
        }
        // the widened wash would otherwise spill across the crease onto the facing page
        .clipped()
        .accessibilityHidden(true)
    }
}

// MARK: - Words and numbers

enum RecapText {
    static func hours(_ minutes: Int?) -> Int { Int((Double(minutes ?? 0) / 60).rounded()) }

    static func hoursLabel(_ minutes: Int?) -> String {
        let total = minutes ?? 0
        if total < 60 { return "\(total) min" }
        let h = Double(total) / 60
        return h < 10 ? String(format: "%.1f hrs", h) : "\(Int(h.rounded())) hrs"
    }

    /// What a number of hours is like — the line under the quiz's answer.
    static func compare(_ minutes: Int?) -> String {
        let h = Double(minutes ?? 0) / 60
        if h < 1 { return "" }
        if h < 8 {
            let films = max(1, Int((h / 2).rounded()))
            return "About \(films) feature film\(films == 1 ? "" : "s")' worth."
        }
        if h < 24 { return "That's a whole waking day, start to finish." }
        let days = h / 24, flights = Int((h / 22).rounded())
        let dayText = days < 10 ? String(format: "%.1f", days) : "\(Int(days.rounded()))"
        return "That's \(dayText) days back to back" + (flights >= 2 ? " — or \(flights) flights from London to Sydney." : ".")
    }

    static func hour(_ h: Int?) -> String {
        guard let h else { return "" }
        if h == 0 { return "midnight" }
        if h == 12 { return "noon" }
        return "\(h % 12 == 0 ? 12 : h % 12) \(h < 12 ? "am" : "pm")"
    }

    /// A day inside the year being reviewed doesn't need the year again.
    static func day(_ stamp: String?) -> String {
        MQTime.date(from: stamp)?.formatted(.dateTime.month(.abbreviated).day()) ?? ""
    }

    static func plural(_ n: Int, _ one: String, _ many: String? = nil) -> String {
        "\(n.mqGrouped) \(n == 1 ? one : (many ?? one + "s"))"
    }

    static let glyph: [String: String] = [
        "owl": "🦉", "lark": "🌅", "weekender": "🛋️", "cinephile": "🎬", "bookworm": "📚",
        "binger": "🍿", "devotee": "📺", "explorer": "🧭", "regular": "☕",
    ]
}

/// The guessing game: the true number and two that are believably off, in an order
/// that stays the same on every replay.
struct RecapQuiz: Equatable {
    let truth: Int
    let options: [Int]
    let isHours: Bool

    init?(_ recap: Recap) {
        let hrs = RecapText.hours(recap.minutes)
        isHours = hrs >= 4
        let truth = isHours ? hrs : (recap.episodes ?? 0) + (recap.movies ?? 0)
        guard truth >= 2 else { return nil }
        func nice(_ v: Double) -> Int {
            v < 20 ? max(1, Int(v.rounded())) : v < 200 ? Int((v / 5).rounded()) * 5 : Int((v / 10).rounded()) * 10
        }
        var lo = nice(Double(truth) * 0.55), hi = nice(Double(truth) * 1.75)
        if lo == truth { lo = max(1, truth - 1) }
        if hi == truth { hi = truth + 2 }
        let opts = [lo, truth, hi]
        let order = [[1, 0, 2], [0, 2, 1], [2, 1, 0]][recap.year % 3]
        self.truth = truth
        self.options = order.map { opts[$0] }
    }
}

// MARK: - Furniture

private struct Say: View {
    let text: String
    var body: some View {
        Text(text)
            .font(MarqueeFont.canvasBody(18, .semibold))
            .foregroundStyle(RecapGel.ink)
            .multilineTextAlignment(.center)
    }
}

private struct BigNumber: View {
    let text: String
    var size: CGFloat = 100
    var gel: Color = RecapGel.amber
    var body: some View {
        Text(text)
            .font(MarqueeFont.canvasDisplay(size))
            .foregroundStyle(RecapGel.light)
            .shadow(color: gel.opacity(0.55), radius: 26)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .monospacedDigit()
    }
}

private struct Unit: View {
    let text: String
    var body: some View {
        Text(text).font(MarqueeFont.canvasBody(17, .bold)).foregroundStyle(RecapGel.ink)
            .multilineTextAlignment(.center)
    }
}

private struct Meta: View {
    let text: String
    var body: some View {
        Text(text).font(MarqueeFont.canvasBody(14.5)).foregroundStyle(RecapGel.inkSoft)
            .multilineTextAlignment(.center).lineSpacing(2)
    }
}

/// "**12** new shows" — bold figure, quiet words.
private struct Fact: View {
    let figure: String
    let words: String
    var body: some View {
        (Text(figure).font(MarqueeFont.canvasBody(15, .heavy)).foregroundStyle(RecapGel.ink)
         + Text(" " + words).font(MarqueeFont.canvasBody(15)).foregroundStyle(RecapGel.inkSoft))
            .multilineTextAlignment(.center)
    }
}

/// A slide's column: centred, with the margins the canvas was designed with. The
/// lines rise in, in order, when the slide arrives (unless motion is reduced).
private struct Column<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: spacing) { content }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 30)
            .padding(.top, 58)
            .padding(.bottom, 40)
    }
}

private struct Rise: ViewModifier {
    let order: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.12 * Double(order))) { shown = true }
            }
    }
}

private extension View {
    func rise(_ order: Int) -> some View { modifier(Rise(order: order)) }
}

/// Counts up from zero when it arrives.
private struct CountUp: View {
    let value: Int
    var size: CGFloat = 100
    var gel: Color = RecapGel.amber
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BigNumber(text: shown.mqGrouped, size: size, gel: gel)
            .contentTransition(.numericText(value: Double(shown)))
            .accessibilityLabel(value.mqGrouped)
            .task {
                guard !reduceMotion, value > 0 else { shown = value; return }
                let steps = 24
                for step in 1...steps {
                    try? await Task.sleep(for: .milliseconds(Int(min(1400, 500 + Double(value) * 4)) / steps))
                    let k = Double(step) / Double(steps)
                    shown = Int((Double(value) * (1 - pow(1 - k, 3))).rounded())
                }
                shown = value
            }
    }
}

// MARK: - The slides

struct RecapSlideView: View {
    let slide: RecapSlide
    let recap: Recap
    let isMe: Bool
    var name: String
    @Binding var quizAnswer: Int?
    var onShare: () -> Void = {}
    var onReplay: () -> Void = {}

    var body: some View {
        ZStack {
            RecapStage(gel: slide.gel)
            content
        }
        .environment(\.colorScheme, .dark)
    }

    private var your: String { isMe ? "Your" : "Their" }
    private var you: String { isMe ? "You" : "They" }

    @ViewBuilder
    private var content: some View {
        switch slide {
        case .intro: RecapIntro(year: recap.year, title: "\(your) year in lights")
        case .quiz: if let quiz = RecapQuiz(recap) { RecapQuizView(quiz: quiz, recap: recap, isMe: isMe, answer: $quizAnswer) }
        case .count: count
        case .showOfTheYear: showOfTheYear
        case .persona: persona
        case .primeTime: primeTime
        case .bigMonth: bigMonth
        case .genres: genres
        case .films: films
        case .readingShelf: readingShelf
        case .readingRecord: readingRecord
        case .household: household
        case .record: record
        case .outro: outro
        }
    }

    private var count: some View {
        Column {
            Say(text: "\(you) pressed play on").rise(0)
            CountUp(value: recap.episodes ?? 0, size: 112).rise(1)
            Unit(text: recap.episodes == 1 ? "episode" : "episodes").rise(2)
            VStack(spacing: 7) {
                if let movies = recap.movies, movies > 0 { Fact(figure: "\(movies)", words: movies == 1 ? "film" : "films") }
                if let fresh = recap.newShows, fresh > 0 { Fact(figure: "\(fresh)", words: fresh == 1 ? "new show" : "new shows") }
                if let days = recap.daysWatched, days > 0 { Fact(figure: "\(days)", words: "days with something on") }
            }
            .padding(.top, 10)
            .rise(3)
        }
    }

    private var showOfTheYear: some View {
        let shows = recap.topShows ?? []
        let top = shows.first
        let share = (recap.tvMinutes ?? 0) > 0 ? Int((100 * Double(top?.mins ?? 0) / Double(recap.tvMinutes ?? 1)).rounded()) : 0
        return Column(spacing: 10) {
            Say(text: "Show of the year").rise(0)
            ZStack {
                // a follow-spot from the flies
                LinearGradient(colors: [Color.white.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
                    .mask(Triangle())
                    .frame(width: 260, height: 300)
                    .offset(y: -40)
                    .accessibilityHidden(true)
                PosterArt(url: top?.poster, radius: 9)
                    .frame(width: 158)
                    .shadow(color: .black.opacity(0.6), radius: 24, y: 14)
            }
            .rise(1)
            Text(top?.title ?? "")
                .font(MarqueeFont.canvasDisplay(30))
                .foregroundStyle(RecapGel.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.6)
                .rise(2)
            Meta(text: "\(RecapText.plural(top?.eps ?? 0, "episode")), \(RecapText.hoursLabel(top?.mins))"
                 + (share >= 10 ? " — \(share)% of \(isMe ? "your" : "their") TV time" : ""))
                .rise(3)
            if shows.count > 1 {
                HStack(alignment: .top, spacing: 9) {
                    ForEach(Array(shows.dropFirst().prefix(4).enumerated()), id: \.offset) { offset, show in
                        VStack(spacing: 4) {
                            PosterArt(url: show.poster, radius: 5)
                                .overlay(alignment: .topLeading) {
                                    Text("\(offset + 2)")
                                        .font(MarqueeFont.canvasDisplay(11))
                                        .foregroundStyle(RecapGel.ground)
                                        .frame(width: 19, height: 19)
                                        .background(RecapGel.ink, in: .circle)
                                        .offset(x: -5, y: -5)
                                }
                            Text(show.title)
                                .font(MarqueeFont.canvasBody(10))
                                .foregroundStyle(RecapGel.inkSoft)
                                .lineLimit(2).multilineTextAlignment(.center)
                        }
                        .frame(width: 62)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Number \(offset + 2), \(show.title)")
                    }
                }
                .padding(.top, 6)
                .rise(4)
            }
        }
    }

    private var persona: some View {
        let persona = recap.persona
        return Column(spacing: 12) {
            Say(text: isMe ? "This year, you were" : "This year, they were").rise(0)
            PersonaStamp(glyph: RecapText.glyph[persona?.key ?? ""] ?? "🎟️", year: recap.year, gel: slide.gel)
                .frame(width: 210, height: 210)
                .padding(.vertical, 8)
            Text(persona?.title ?? "")
                .font(MarqueeFont.canvasDisplay(34))
                .foregroundStyle(RecapGel.ink)
                .multilineTextAlignment(.center)
                .rise(2)
            Meta(text: persona?.line ?? "").rise(3)
        }
    }

    private var primeTime: some View {
        let hours = recap.hours ?? []
        let peak = max(1, hours.max() ?? 1)
        return Column(spacing: 10) {
            Say(text: "\(your) prime time").rise(0)
            BigNumber(text: RecapText.hour(recap.peakHour), size: 72, gel: slide.gel).rise(1)
            VStack(spacing: 4) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(hours.enumerated()), id: \.offset) { hour, value in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(hour == recap.peakHour ? RecapGel.light : RecapGel.ink.opacity(0.22))
                            .frame(height: max(3, 92 * CGFloat(value) / CGFloat(peak)))
                            .shadow(color: hour == recap.peakHour ? RecapGel.light.opacity(0.6) : .clear, radius: 8)
                    }
                }
                .frame(height: 92, alignment: .bottom)
                HStack(spacing: 0) {
                    ForEach(["midnight", "6am", "noon", "6pm"], id: \.self) { label in
                        Text(label).font(MarqueeFont.canvasBody(10)).foregroundStyle(RecapGel.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.top, 10)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Most of it around \(RecapText.hour(recap.peakHour))")
            .rise(2)
            VStack(spacing: 7) {
                if let weekday = recap.peakWeekday { Fact(figure: "\(weekday)s", words: "were \(isMe ? "your" : "their") night") }
                if let streak = recap.streak, streak.days >= 3 {
                    Fact(figure: "\(streak.days) days", words: "in a row, \(RecapText.day(streak.start)) to \(RecapText.day(streak.end))")
                }
            }
            .padding(.top, 8)
            .rise(3)
        }
    }

    private static let initials = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private var bigMonth: some View {
        let months = recap.months ?? []
        let peak = max(1, months.max() ?? 1)
        let best = months.firstIndex(of: peak) ?? 0
        return Column(spacing: 10) {
            Say(text: "The big month was").rise(0)
            BigNumber(text: MQTime.monthName(best).prefix(3).description, size: 84, gel: slide.gel).rise(1)
            Unit(text: RecapText.plural(months[safe: best] ?? 0, "episode")).rise(2)
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(months.enumerated()), id: \.offset) { slot, value in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3.5)
                            .fill(slot == best ? RecapGel.light : RecapGel.ink.opacity(0.2))
                            .frame(height: max(3, 130 * CGFloat(value) / CGFloat(peak)))
                            .shadow(color: slot == best ? RecapGel.light.opacity(0.5) : .clear, radius: 10)
                        Text(Self.initials[slot % 12])
                            .font(MarqueeFont.canvasBody(10, slot == best ? .heavy : .medium))
                            .foregroundStyle(slot == best ? RecapGel.light : RecapGel.muted)
                    }
                }
            }
            .frame(height: 150, alignment: .bottom)
            .padding(.top, 14)
            .accessibilityHidden(true)
            .rise(3)
        }
    }

    private var genres: some View {
        let genres = recap.genres ?? []
        let peak = max(1, genres.map(\.count).max() ?? 1)
        return Column(spacing: 10) {
            Say(text: isMe ? "You kept coming back to" : "They kept coming back to").rise(0)
            BigNumber(text: genres.first?.name ?? "", size: 58, gel: slide.gel).rise(1)
            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(genres.enumerated()), id: \.offset) { offset, genre in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(genre.name).font(MarqueeFont.canvasBody(14, .semibold)).foregroundStyle(RecapGel.ink)
                        GeometryReader { proxy in
                            Capsule().fill(slide.gel.opacity(offset == 0 ? 1 : 0.5))
                                .frame(width: max(8, proxy.size.width * CGFloat(genre.count) / CGFloat(peak)))
                        }
                        .frame(height: 8)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 16)
            .rise(2)
        }
    }

    private var films: some View {
        let films = Array((recap.topMovies ?? []).prefix(5))
        let rated = films.contains { ($0.rating ?? 0) > 0 }
        let mid = Double(films.count - 1) / 2
        return Column(spacing: 10) {
            Say(text: rated ? (isMe ? "Films you loved" : "Films they loved") : "On the big screen").rise(0)
            HStack(alignment: .bottom, spacing: films.count > 3 ? -14 : -6) {
                ForEach(Array(films.enumerated()), id: \.offset) { offset, film in
                    let o = Double(offset) - mid
                    VStack(spacing: 6) {
                        PosterArt(url: film.poster, radius: 7)
                            .shadow(color: .black.opacity(0.65), radius: 14, y: 8)
                            .overlay(alignment: .topTrailing) {
                                if let rating = film.rating, rating > 0 {
                                    Text("\(rating)")
                                        .font(MarqueeFont.canvasDisplay(15))
                                        .foregroundStyle(Color(red: 0.13, green: 0.09, blue: 0.01))
                                        .frame(width: 32, height: 32)
                                        .background(RecapGel.amber, in: .circle)
                                        .offset(x: 6, y: -8)
                                }
                            }
                        Text(film.title)
                            .font(MarqueeFont.canvasBody(10.5))
                            .foregroundStyle(RecapGel.inkSoft)
                            .lineLimit(2).multilineTextAlignment(.center)
                    }
                    .frame(width: films.count == 1 ? 160 : 108)
                    .rotationEffect(.degrees(o * (films.count > 3 ? 6 : 8)), anchor: .bottom)
                    .offset(y: -abs(o) * -6)
                    .zIndex(-abs(o))
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 26)
            .rise(1)
        }
    }

    private var readingShelf: some View {
        let r = recap.reading
        let total = (r?.books ?? 0) + (r?.manga ?? 0)
        let covers = Array((r?.covers ?? []).prefix(7))
        let mid = Double(covers.count - 1) / 2
        let b = r?.books ?? 0, m = r?.manga ?? 0
        let what = b > 0 && m > 0 ? "\(RecapText.plural(b, "book")) and \(m) manga"
            : b > 0 ? (b == 1 ? "book, cover to cover" : "books, cover to cover") : "manga, start to finish"
        return Column(spacing: 10) {
            Say(text: "Between the covers").rise(0)
            if !covers.isEmpty {
                ZStack(alignment: .bottom) {
                    ForEach(Array(covers.enumerated()), id: \.offset) { offset, cover in
                        let o = Double(offset) - mid
                        CoverArt(url: cover.cover, radius: 6)
                            .frame(width: 92)
                            .shadow(color: .black.opacity(0.6), radius: 10, y: 6)
                            .rotationEffect(.degrees(o * 7), anchor: .bottom)
                            .offset(x: o * 34, y: abs(o) * 6)
                            .zIndex(-abs(o))
                    }
                }
                .frame(height: 160)
                .padding(.bottom, 16)
                .accessibilityHidden(true)
                .rise(1)
            }
            if total > 0 {
                CountUp(value: total, size: 96, gel: slide.gel).rise(2)
                Unit(text: what).rise(2)
            } else {
                Meta(text: "Pages turned, nothing finished yet. The best kind of unfinished business.").rise(2)
            }
            VStack(spacing: 6) {
                if let pages = r?.pages, pages > 0 { Fact(figure: pages.mqGrouped, words: "pages") }
                else if let chapters = r?.chapters, chapters > 0 { Fact(figure: chapters.mqGrouped, words: "chapters") }
                if let minutes = r?.minutes, minutes >= 60 { Fact(figure: "\(RecapText.hours(minutes).mqGrouped) hours", words: "reading") }
                if let busiest = r?.busiestMonth, (r?.busiestMonthUnits ?? 0) > 0 { Fact(figure: busiest, words: "was the big month") }
            }
            .padding(.top, 6)
            .rise(3)
            if let goal = r?.goal, let target = goal.target, target > 0 {
                let met = (goal.done ?? 0) >= target
                Label(met ? "Goal of \(target) books, reached" : "\(goal.done ?? 0) of a \(target)-book goal",
                      systemImage: met ? "checkmark" : "flag")
                    .font(MarqueeFont.canvasBody(13, .bold))
                    .foregroundStyle(met ? Color(red: 0.13, green: 0.09, blue: 0.01) : RecapGel.inkSoft)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(met ? RecapGel.amber : Color.white.opacity(0.07), in: .capsule)
                    .rise(4)
            }
        }
    }

    private var readingRecord: some View {
        let r = recap.reading
        var rows: [(String, String, String)] = []
        if let author = r?.topAuthor { rows.append(("Most-read author", author.name, "\(author.count) books, \(author.pages.mqGrouped) pages")) }
        if let longest = r?.longest { rows.append(("Longest book", longest.title, "\((longest.pages ?? 0).mqGrouped) pages")) }
        if let fastest = r?.fastest { rows.append(("Fastest finish", fastest.title, fastest.days <= 1 ? "in a single day" : "in \(fastest.days) days")) }
        return Column(spacing: 16) {
            Say(text: "\(your) reading, on the record").rise(0)
            if let fav = r?.favourite {
                HStack(spacing: 14) {
                    CoverArt(url: fav.cover, radius: 6).frame(width: 90)
                        .shadow(color: .black.opacity(0.6), radius: 10, y: 6)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Favourite read").font(MarqueeFont.canvasBody(11.5, .semibold)).foregroundStyle(RecapGel.inkSoft)
                        Text(fav.title).font(MarqueeFont.canvasBody(21, .heavy)).foregroundStyle(RecapGel.ink).lineLimit(3)
                        if let author = fav.author { Text(author).font(MarqueeFont.canvasBody(13)).foregroundStyle(RecapGel.inkSoft) }
                        if let rating = fav.rating {
                            (Text("\(rating)").font(MarqueeFont.canvasDisplay(32)).foregroundStyle(RecapGel.light)
                             + Text("/10").font(MarqueeFont.canvasBody(12)).foregroundStyle(RecapGel.muted))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .rise(1)
            }
            RecordList(rows: rows).rise(2)
        }
    }

    private var household: some View {
        let house = recap.household ?? RecapHousehold(rank: 1, of: 1)
        let headline = house.rank == 1 ? "No. 1" : house.rank == house.of ? "Last" : "No. \(house.rank)"
        let line = house.rank == 1 ? "Nobody in the house watched more. Someone has to hold the remote."
            : house.rank == house.of ? "Everyone else watched more. Maybe you were out living a life."
            : "\(house.rank - 1) \(house.rank - 1 == 1 ? "person" : "people") watched more, \(house.of - house.rank) watched less."
        return Column(spacing: 12) {
            Say(text: "In a household of \(house.of)").rise(0)
            BigNumber(text: headline, size: 84, gel: slide.gel).rise(1)
            Meta(text: line).rise(2)
        }
    }

    private var record: some View {
        var rows: [(String, String, String)] = []
        if let binge = recap.binge, binge.count > 0 {
            rows.append(("Biggest binge", "\(binge.count) episodes",
                         RecapText.day(binge.date) + (binge.top.map { ", mostly \($0)" } ?? "")))
        }
        if let first = recap.firstWatch, let title = first.title { rows.append(("Opened with", title, RecapText.day(first.watchedAt))) }
        if let last = recap.lastWatch, let title = last.title,
           last.title != recap.firstWatch?.title || last.watchedAt != recap.firstWatch?.watchedAt {
            rows.append((recap.final == true ? "Closed with" : "Most recently", title, RecapText.day(last.watchedAt)))
        }
        return Column(spacing: 18) {
            Say(text: "For the record").rise(0)
            RecordList(rows: rows).rise(1)
        }
    }

    private var outro: some View {
        Column(spacing: 18) {
            Say(text: "That's a wrap on \(String(recap.year)).").rise(0)
            RecapTicket(recap: recap, isMe: isMe, name: name)
                .frame(width: 272)
                .rotationEffect(.degrees(-2))
                .shadow(color: .black.opacity(0.6), radius: 24, y: 14)
                .rise(1)
            HStack(spacing: 10) {
                Button(action: onShare) { Label("Share", systemImage: "square.and.arrow.up") }
                    .buttonStyle(.mqPrimary)
                Button("Watch again", action: onReplay)
                    .buttonStyle(.mqQuiet)
            }
            .font(MarqueeFont.canvasBody(15, .bold))
            .rise(2)
        }
    }
}

private struct RecordList: View {
    let rows: [(String, String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.0).font(MarqueeFont.canvasBody(12, .semibold)).foregroundStyle(RecapGel.inkSoft)
                        .frame(width: 96, alignment: .leading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.1).font(MarqueeFont.canvasBody(19, .heavy)).foregroundStyle(RecapGel.ink).lineLimit(2)
                        Text(row.2).font(MarqueeFont.canvasBody(12.5)).foregroundStyle(RecapGel.muted)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1) }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX - 4, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX + 4, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

// MARK: - The countdown leader

private struct RecapIntro: View {
    let year: Int
    let title: String
    @State private var step = 3
    @State private var sweep: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if step > 0 {
                ZStack {
                    Circle().fill(RecapGel.ink.opacity(0.06))
                    Circle()
                        .trim(from: 0, to: sweep)
                        .stroke(RecapGel.ink.opacity(0.18), style: StrokeStyle(lineWidth: 100))
                        .rotationEffect(.degrees(-90))
                        .padding(50)
                    Circle().strokeBorder(RecapGel.ink.opacity(0.5), lineWidth: 3)
                    Rectangle().fill(RecapGel.ink.opacity(0.3)).frame(width: 1, height: 320)
                    Rectangle().fill(RecapGel.ink.opacity(0.3)).frame(width: 320, height: 1)
                    Text("\(step)")
                        .font(MarqueeFont.canvasDisplay(120))
                        .foregroundStyle(RecapGel.ink)
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 220, height: 220)
                .transition(.scale(scale: 1.4).combined(with: .opacity))
                .accessibilityHidden(true)
            } else {
                VStack(spacing: 8) {
                    Text(String(year))
                        .font(MarqueeFont.canvasDisplay(118))
                        .foregroundStyle(RecapGel.light)
                        .shadow(color: RecapGel.amber.opacity(0.5), radius: 40)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(title)
                        .font(MarqueeFont.canvasBody(19, .semibold))
                        .foregroundStyle(RecapGel.ink)
                }
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }
            VStack {
                Spacer()
                if step == 0 {
                    Text("Tap to roll film")
                        .font(MarqueeFont.canvasBody(13))
                        .foregroundStyle(RecapGel.inkSoft)
                        .transition(.opacity)
                        .padding(.bottom, 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard !reduceMotion else { step = 0; return }
            for remaining in [3, 2, 1] {
                step = remaining
                sweep = 0
                withAnimation(.linear(duration: 0.6)) { sweep = 1 }
                try? await Task.sleep(for: .milliseconds(600))
            }
            withAnimation(.spring(duration: 0.7, bounce: 0.3)) { step = 0 }
        }
    }
}

// MARK: - The guessing game

private struct RecapQuizView: View {
    let quiz: RecapQuiz
    let recap: Recap
    let isMe: Bool
    @Binding var answer: Int?

    var body: some View {
        Column(spacing: 14) {
            if let answer {
                Text(answer == quiz.truth ? "Spot on." : "Not quite.")
                    .font(MarqueeFont.canvasBody(24, .bold))
                    .foregroundStyle(RecapGel.ink)
                CountUp(value: quiz.truth, size: 120, gel: RecapGel.velvet)
                Unit(text: quiz.isHours ? "hours of watching" : "episodes and films")
                Meta(text: RecapText.compare(recap.minutes)).padding(.top, 6)
            } else {
                Text(question)
                    .font(MarqueeFont.canvasBody(24, .bold))
                    .foregroundStyle(RecapGel.ink)
                    .multilineTextAlignment(.center)
                    .rise(0)
                VStack(spacing: 10) {
                    ForEach(quiz.options, id: \.self) { option in
                        Button {
                            withAnimation(.spring(duration: 0.45, bounce: 0.25)) { answer = option }
                        } label: {
                            Text(option.mqGrouped)
                                .font(MarqueeFont.canvasDisplay(34))
                                .foregroundStyle(RecapGel.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.07), in: .rect(cornerRadius: 16))
                                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14)) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(option) \(quiz.isHours ? "hours" : "")")
                    }
                }
                .padding(.top, 14)
                .rise(1)
            }
        }
    }

    private var question: String {
        let who = isMe ? "do you think you" : "do you think they"
        return quiz.isHours ? "How many hours \(who) spent watching?" : "How many episodes and films \(who) watched?"
    }
}

// MARK: - The persona stamp

private struct PersonaStamp: View {
    let glyph: String
    let year: Int
    let gel: Color
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let ring = Array("MARQUEE · CERTIFIED · \(year) · MARQUEE · CERTIFIED · \(year) · ")
        ZStack {
            Circle().strokeBorder(gel, lineWidth: 3)
            Circle().fill(gel.opacity(0.12)).padding(3)
            Circle().strokeBorder(gel.opacity(0.6), lineWidth: 2).padding(40)
            ForEach(Array(ring.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(MarqueeFont.canvasBody(13, .heavy))
                    .foregroundStyle(gel)
                    .offset(y: -84)
                    .rotationEffect(.degrees(Double(index) / Double(ring.count) * 360))
            }
            Text(glyph).font(.system(size: 64)).shadow(color: .black.opacity(0.5), radius: 8, y: 4)
        }
        .rotationEffect(.degrees(-9))
        .scaleEffect(landed || reduceMotion ? 1 : 1.8)
        .opacity(landed || reduceMotion ? 1 : 0)
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.45).delay(0.2)) { landed = true } }
        .accessibilityHidden(true)
    }
}

// MARK: - The ticket

/// The summary that ends the show — persona, top five, the big numbers, admit one.
struct RecapTicket: View {
    let recap: Recap
    let isMe: Bool
    let name: String

    private static let paper = Color(red: 0.965, green: 0.906, blue: 0.769)
    private static let stub = Color(red: 0.937, green: 0.851, blue: 0.651)
    private static let ink = Color(red: 0.165, green: 0.114, blue: 0.024)
    private static let rust = Color(red: 0.639, green: 0.325, blue: 0.043)
    private static let wine = Color(red: 0.486, green: 0.122, blue: 0.173)
    private static let brown = Color(red: 0.420, green: 0.329, blue: 0.157)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Marquee").font(MarqueeFont.canvasDisplay(20)).foregroundStyle(Self.rust)
                Spacer()
                Text(String(recap.year)).font(MarqueeFont.canvasDisplay(30)).foregroundStyle(Self.ink)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Self.ink).frame(height: 2) }
            if let persona = recap.persona {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isMe ? "You were" : "They were").font(MarqueeFont.canvasBody(10.5, .bold)).foregroundStyle(Self.brown)
                    Text(persona.title).font(MarqueeFont.canvasDisplay(23)).foregroundStyle(Self.wine)
                }
                .padding(.top, 12)
            }
            let shows = Array((recap.topShows ?? []).prefix(5))
            if !shows.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(shows.enumerated()), id: \.offset) { offset, show in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(offset + 1)").font(MarqueeFont.canvasDisplay(12)).foregroundStyle(Self.rust).frame(width: 12)
                            Text(show.title).font(MarqueeFont.canvasBody(12.5, .bold)).foregroundStyle(Self.ink).lineLimit(1)
                            Spacer(minLength: 4)
                            Text("\(RecapText.hours(show.mins)) hrs").font(MarqueeFont.canvasBody(10.5, .semibold))
                                .foregroundStyle(Self.brown).monospacedDigit()
                        }
                        .padding(.vertical, 4.5)
                        .overlay(alignment: .bottom) {
                            Line().stroke(Self.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1)
                        }
                    }
                }
                .padding(.top, 8)
            }
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                      spacing: 10) {
                ForEach(numbers, id: \.1) { value, label in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(value).font(MarqueeFont.canvasDisplay(24)).foregroundStyle(Self.ink).monospacedDigit()
                        Text(label).font(MarqueeFont.canvasBody(10.5, .semibold)).foregroundStyle(Self.brown)
                    }
                }
            }
            .padding(.vertical, 14)
            HStack {
                Text("ADMIT ONE").font(MarqueeFont.canvasBody(10, .heavy)).tracking(1.2).foregroundStyle(Self.brown)
                Spacer()
                Text(name).font(MarqueeFont.canvasBody(12.5, .bold)).foregroundStyle(Self.ink).lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(Self.stub)
            .overlay(alignment: .top) {
                Line().stroke(Self.ink.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [4, 3])).frame(height: 2)
            }
            .padding(.horizontal, -18)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .background(Self.paper)
        // the punched notches either side of the tear line
        .mask {
            GeometryReader { proxy in
                let y = proxy.size.height - 44
                let notches = Path { p in
                    p.addEllipse(in: CGRect(x: -8, y: y - 8, width: 16, height: 16))
                    p.addEllipse(in: CGRect(x: proxy.size.width - 8, y: y - 8, width: 16, height: 16))
                }
                Path(roundedRect: CGRect(origin: .zero, size: proxy.size), cornerRadius: 12)
                    .subtracting(notches)
                    .fill()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var numbers: [(String, String)] {
        var out: [(String, String)] = []
        let watched = (recap.episodes ?? 0) + (recap.movies ?? 0) > 0
        if watched {
            out.append((RecapText.hours(recap.minutes).mqGrouped, "hours watched"))
            out.append(((recap.episodes ?? 0).mqGrouped, recap.episodes == 1 ? "episode" : "episodes"))
            out.append(("\(recap.movies ?? 0)", recap.movies == 1 ? "film" : "films"))
        }
        if let books = recap.reading?.books, books > 0 { out.append(("\(books)", books == 1 ? "book" : "books")) }
        else if let manga = recap.reading?.manga, manga > 0 { out.append(("\(manga)", "manga")) }
        else if watched { out.append(("\(recap.daysWatched ?? 0)", "days with a show")) }
        return Array(out.prefix(4))
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
