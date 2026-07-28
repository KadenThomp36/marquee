import SwiftUI

/// Which slides a given year earns. A quiet year simply gets fewer of them — the
/// order matches the web client so the two tell the same story.
enum RecapSlide: Hashable {
    case intro
    case numbers
    case showOfTheYear
    case shapeOfYear
    case genres
    case films
    case forTheRecord
    case outro

    static func build(_ recap: Recap) -> [RecapSlide] {
        var slides: [RecapSlide] = [.intro, .numbers]
        if recap.topShows?.first != nil { slides.append(.showOfTheYear) }
        if recap.months?.contains(where: { $0 > 0 }) == true { slides.append(.shapeOfYear) }
        if recap.genres?.isEmpty == false { slides.append(.genres) }
        if recap.topMovies?.isEmpty == false { slides.append(.films) }
        if recap.binge != nil || recap.firstWatch != nil || recap.lastWatch != nil {
            slides.append(.forTheRecord)
        }
        slides.append(.outro)
        return slides
    }

    @ViewBuilder
    func view(recap: Recap, isMe: Bool) -> some View {
        switch self {
        case .intro: RecapIntro(recap: recap, isMe: isMe)
        case .numbers: RecapNumbers(recap: recap)
        case .showOfTheYear: RecapTopShow(recap: recap)
        case .shapeOfYear: RecapShape(recap: recap)
        case .genres: RecapGenres(recap: recap)
        case .films: RecapFilms(recap: recap)
        case .forTheRecord: RecapRecord(recap: recap)
        case .outro: RecapOutro(recap: recap, isMe: isMe)
        }
    }
}

// MARK: - Shared furniture

/// Every slide is the same shape: a small brass caption, then the thing itself,
/// centred with room to breathe.
private struct Slide<Content: View>: View {
    let caption: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 22) {
            Text(caption)
                .mqEyebrowStyle()
                .foregroundStyle(Color.mqBrass)
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 34)
        .padding(.bottom, 28)
    }
}

private func hours(_ minutes: Int?) -> String {
    let total = minutes ?? 0
    if total < 60 { return "\(total) min" }
    let h = Double(total) / 60
    return h < 10 ? String(format: "%.1f hrs", h) : "\(Int(h.rounded())) hrs"
}

// MARK: - Slides

private struct RecapIntro: View {
    let recap: Recap
    let isMe: Bool

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Year in Review").mqEyebrowStyle().foregroundStyle(Color.mqBrass)
            Text(String(recap.year))
                .font(MarqueeFont.wordmark(76, relativeTo: .largeTitle))
                .foregroundStyle(Color.mqBrass)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("\(isMe ? "Your" : "Their") year on the couch — let's rewind it.")
                .font(.mqBody)
                .foregroundStyle(Color.mqInkSoft)
                .multilineTextAlignment(.center)
            Spacer()
            Text("tap to begin ›")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, MQ.gutter)
        .padding(.vertical, 40)
    }
}

private struct RecapNumbers: View {
    let recap: Recap

    var body: some View {
        Slide(caption: "By the numbers") {
            FlowLayout(spacing: 18, lineSpacing: 20, alignment: .center) {
                figure(hours(recap.minutes), "watched")
                figure((recap.episodes ?? 0).mqGrouped, "episodes")
                figure((recap.movies ?? 0).mqGrouped, "movies")
                figure("\(recap.newShows ?? 0)", "new shows")
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(MarqueeFont.wordmark(30, relativeTo: .title))
                .foregroundStyle(Color.mqInk)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(MarqueeFont.body(11, .semibold, relativeTo: .caption2))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.mqInkMuted)
        }
        .frame(minWidth: 128)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}

private struct RecapTopShow: View {
    let recap: Recap

    var body: some View {
        let show = recap.topShows?.first
        let runners = (recap.topShows ?? []).filter { $0.poster != nil }.dropFirst().prefix(4)

        Slide(caption: "Show of the year") {
            VStack(spacing: 16) {
                if let show {
                    PosterArt(url: show.poster, radius: MQ.radius)
                        .frame(width: 190)
                        .shadow(color: .black.opacity(0.45), radius: 22, y: 10)
                    Text(show.title)
                        .font(MarqueeFont.wordmark(28, relativeTo: .title2))
                        .foregroundStyle(Color.mqInk)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                    Text("\(show.eps) episodes · \(hours(show.mins))")
                        .font(.mqSub)
                        .foregroundStyle(Color.mqBrass)
                }
                if !runners.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(Array(runners), id: \.id) { runner in
                            PosterArt(url: runner.poster, radius: 7)
                                .frame(width: 46)
                                .accessibilityLabel(runner.title)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }
}

private struct RecapShape: View {
    let recap: Recap

    private static let initials = ["J", "F", "M", "A", "M", "J",
                                   "J", "A", "S", "O", "N", "D"]

    var body: some View {
        let months = recap.months ?? []
        let peak = max(months.max() ?? 1, 1)

        Slide(caption: "The shape of your year") {
            VStack(spacing: 16) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(months.enumerated()), id: \.offset) { slot, value in
                        VStack(spacing: 6) {
                            Capsule()
                                .fill(Color.mqBrassFill)
                                // A month with nothing in it still gets a nub, so the
                                // row reads as twelve months rather than a gap.
                                .frame(height: max(4, 150 * CGFloat(value) / CGFloat(peak)))
                            Text(Self.initials[slot % 12])
                                .font(MarqueeFont.body(10, .semibold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqInkMuted)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(MQTime.monthName(slot)): \(value) watches")
                    }
                }
                .frame(height: 180, alignment: .bottom)

                if let busiest = recap.busiestMonth {
                    Text("Busiest in \(busiest) · \(recap.busiestMonthCount ?? 0) watches")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                }
            }
        }
    }
}

private struct RecapGenres: View {
    let recap: Recap

    var body: some View {
        let genres = recap.genres ?? []
        let peak = max(genres.map(\.count).max() ?? 1, 1)

        Slide(caption: "Your top genres") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(genres) { genre in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(genre.name)
                                .font(.mqSub)
                                .foregroundStyle(Color.mqInk)
                            Spacer(minLength: 8)
                            Text("\(genre.count)")
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                                .monospacedDigit()
                        }
                        GeometryReader { proxy in
                            Capsule()
                                .fill(Color.mqBrassFill)
                                .frame(width: max(6, proxy.size.width
                                                  * CGFloat(genre.count) / CGFloat(peak)))
                        }
                        .frame(height: 7)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct RecapFilms: View {
    let recap: Recap

    var body: some View {
        Slide(caption: "Films you loved") {
            VStack(spacing: 12) {
                ForEach((recap.topMovies ?? []).prefix(5), id: \.id) { film in
                    HStack(spacing: 12) {
                        PosterArt(url: film.poster, radius: 6).frame(width: 40)
                        Text(film.title)
                            .font(.mqSub)
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(2)
                        Spacer(minLength: 8)
                        if let rating = film.rating, rating > 0 {
                            Text("\(rating)/10")
                                .font(MarqueeFont.body(13, .bold, relativeTo: .caption))
                                .foregroundStyle(Color.mqRating(rating))
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct RecapRecord: View {
    let recap: Recap

    var body: some View {
        Slide(caption: "For the record") {
            VStack(spacing: 14) {
                if let binge = recap.binge, binge.count > 0 {
                    row("Biggest binge", "\(binge.count) eps",
                        [MQTime.medium(binge.date), binge.top.map { "mostly \($0)" }]
                            .compactMap { $0 }.joined(separator: " · "))
                }
                if let first = recap.firstWatch, let title = first.title {
                    row("Kicked off with", title, first.watchedAt.map(MQTime.medium) ?? "")
                }
                if let last = recap.lastWatch, let title = last.title {
                    row("Most recently", title, last.watchedAt.map(MQTime.medium) ?? "")
                }
            }
        }
    }

    private func row(_ kicker: String, _ headline: String, _ detail: String) -> some View {
        VStack(spacing: 3) {
            Text(kicker)
                .font(MarqueeFont.body(10.5, .semibold, relativeTo: .caption2))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.mqInkMuted)
            Text(headline)
                .font(MarqueeFont.wordmark(21, relativeTo: .title3))
                .foregroundStyle(Color.mqInk)
                .multilineTextAlignment(.center)
            if !detail.isEmpty {
                Text(detail)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .mqPanel()
        .accessibilityElement(children: .combine)
    }
}

private struct RecapOutro: View {
    let recap: Recap
    let isMe: Bool

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text(String(recap.year))
                .font(MarqueeFont.wordmark(40, relativeTo: .title))
                .foregroundStyle(Color.mqBrass)
            Text("That's a wrap.")
                .font(MarqueeFont.wordmark(34, relativeTo: .largeTitle))
                .foregroundStyle(Color.mqInk)
                .multilineTextAlignment(.center)
            Text("\(hours(recap.minutes)) · \((recap.episodes ?? 0).mqGrouped) episodes "
                 + "· \(recap.movies ?? 0) films")
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
                .multilineTextAlignment(.center)
            Spacer()
            // Text only, and no link: a recap URL would name the server, and this is
            // the one screen most likely to be shared outside the household.
            ShareLink(item: shareText) {
                Label("Share your \(recap.year)", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.mqPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, MQ.gutter)
        .padding(.vertical, 40)
    }

    private var shareText: String {
        "\(isMe ? "My" : "Their") \(recap.year) on Marquee — \(hours(recap.minutes)) watched, "
        + "\((recap.episodes ?? 0).mqGrouped) episodes, \(recap.movies ?? 0) movies."
    }
}
