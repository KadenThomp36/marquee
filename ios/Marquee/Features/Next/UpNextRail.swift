import SwiftUI

/// The Up Next rail, and the one piece of this app that had to be ported exactly.
///
/// It is a single horizontal scroll view holding two things: everything you've
/// already watched, laid out oldest-to-newest off-screen to the *left*, and the
/// queue itself starting at the gutter. On load it parks so the first queue card sits
/// where your thumb is; scroll left and you fall backwards through Today, Yesterday,
/// This week, Last month, each capped by a vertical divider naming it.
struct UpNextRail: View {
    let upNext: [ShowCard]
    let recent: [WatchEntry]
    let onPunch: (ShowCard) async -> Void

    @State private var anchor: RailEntry.ID?
    @State private var hasParked = false

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .center, spacing: MQ.railGap) {
                ForEach(entries) { entry in
                    switch entry {
                    case .past(let watch):
                        WatchedMiniCard(entry: watch, showsWho: false, isPast: true)
                    case .divider(let label, _):
                        DayDivider(label: label)
                    case .next(let show):
                        PunchCard(show: show, onPunch: onPunch)
                            .frame(width: MQ.upNextWidth)
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .scrollPosition(id: $anchor, anchor: .leading)
        .onAppear(perform: park)
        .onChange(of: upNext.first?.id) { _, _ in
            // The first card changing means one was crossed off — re-park so the
            // queue stays under your thumb instead of drifting.
            hasParked = false
            park()
        }
    }

    /// Park on the first queue card, so history starts off-screen to the left.
    private func park() {
        guard !hasParked else { return }
        guard let first = entries.first(where: { if case .next = $0 { true } else { false } })
        else { return }
        hasParked = true
        anchor = first.id
    }

    /// Past watches oldest-first with a divider closing each bucket on its right,
    /// then the queue.
    private var entries: [RailEntry] {
        var out: [RailEntry] = []

        // `recent` arrives newest first; walk it into consecutive same-bucket runs.
        var buckets: [(label: String, items: [WatchEntry])] = []
        for watch in recent {
            let label = MQTime.bucketLabel(watch.watchedAt)
            if buckets.last?.label == label {
                buckets[buckets.count - 1].items.append(watch)
            } else {
                buckets.append((label, [watch]))
            }
        }

        for (index, bucket) in buckets.reversed().enumerated() {
            out.append(contentsOf: bucket.items.reversed().map(RailEntry.past))
            out.append(.divider(bucket.label, index))
        }
        out.append(contentsOf: upNext.map(RailEntry.next))
        return out
    }
}

enum RailEntry: Identifiable, Hashable {
    case past(WatchEntry)
    case divider(String, Int)
    case next(ShowCard)

    var id: String {
        switch self {
        case .past(let watch): "past:\(watch.id)"
        case .divider(let label, let index): "div:\(index):\(label)"
        case .next(let show): "next:\(show.id)"
        }
    }
}

/// A rail of punch cards with no history behind it — "haven't watched in a while".
struct ShowCardRail: View {
    let shows: [ShowCard]
    let onPunch: (ShowCard) async -> Void

    var body: some View {
        HorizontalRail {
            ForEach(shows) { show in
                PunchCard(show: show, onPunch: onPunch)
                    .frame(width: 158)
            }
        }
    }
}

// MARK: - The card

/// Poster, progress, and the one button that matters.
struct PunchCard: View {
    let show: ShowCard
    let onPunch: (ShowCard) async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var punching = false
    @State private var punched = false
    @Namespace private var glass

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationLink(value: Navigator.Route.show(show.id)) {
                PosterArt(url: show.poster, radius: MQ.radius)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("card.show.\(show.id)")

            scrim
            info
        }
        // Clip the art and its scrim, then hang the controls on top — clipping last
        // would shave the punch button against the card's rounded corner.
        .clipShape(.rect(cornerRadius: MQ.radius))
        .overlay(alignment: .topLeading) {
            if show.isEnded { EndedTag().padding(9) }
        }
        .overlay(alignment: .topTrailing) {
            if show.nextEp != nil { punchButton.padding(7) }
        }
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .sensoryFeedback(.success, trigger: punched)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var scrim: some View {
        LinearGradient(
            stops: [.init(color: .clear, location: 0.36),
                    .init(color: Color.mqScrim.opacity(0.55), location: 0.62),
                    .init(color: Color.mqScrim.opacity(0.95), location: 0.9)],
            startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(show.displayTitle)
                .font(MarqueeFont.body(14.5, .bold, relativeTo: .subheadline))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(episodeLine)
                .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
                .foregroundStyle(Color.mqBrassBright)
                .lineLimit(2)

            if let subline {
                Text(subline)
                    .font(.mqCaption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }

            ProgressBar(fraction: show.progress, percentLabel: true)
                .padding(.top, 5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var punchButton: some View {
        GlassEffectContainer {
            Button {
                guard !punching else { return }
                punching = true
                punched.toggle()
                Task {
                    await onPunch(show)
                    punching = false
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 17, weight: .bold))
                    // Fixed bright brass, not the appearance-aware one: this glass
                    // circle always sits on poster art, which is dark either way.
                    .foregroundStyle(Color(red: 1, green: 0.851, blue: 0.541))
                    .frame(width: 44, height: 44)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .glassEffectID("punch-\(show.id)", in: glass)
            .opacity(punching ? 0.45 : 1)
            .scaleEffect(punching && !reduceMotion ? 0.86 : 1)
            .animation(.spring(duration: 0.3), value: punching)
        }
        .accessibilityLabel(show.nextEp.map { "Mark \($0.code) of \(show.displayTitle) watched" }
                            ?? "Mark watched")
        .accessibilityAddTraits(.isButton)
    }

    private var episodeLine: String {
        if let episode = show.nextEp {
            let title = episode.title.map { " \($0)" } ?? ""
            return episode.code + title
        }
        if let next = show.nextAir, !next.isEmpty {
            return "returns \(MQTime.medium(next))"
        }
        return show.isEnded ? "series complete" : "waiting for new episodes"
    }

    private var subline: String? {
        guard show.remaining > 0 else { return nil }
        var text = "\(show.remaining) left"
        if let hours = show.hoursRemaining, hours >= 1 {
            text += hours < 10
                ? " · \(String(format: "%.1f", hours)) hrs to go"
                : " · \(Int(hours.rounded())) hrs to go"
        }
        return text
    }

    private var accessibilityLabel: String {
        var parts = [show.displayTitle, episodeLine]
        parts.append("\(show.watched) of \(show.aired) watched, \(show.percent) percent")
        return parts.joined(separator: ". ")
    }
}

/// The amber fill that every progress reading in the app uses.
struct ProgressBar: View {
    let fraction: Double
    var percentLabel = false
    var tint: ProgressTint = .brass
    var height: CGFloat = 6

    enum ProgressTint {
        case brass, complete, stopped

        var gradient: [Color] {
            switch self {
            case .brass: [.mqBrassDim, .mqBrassFill, .mqBrassBright]
            case .complete: [.mqChartViolet.opacity(0.7), .mqChartViolet]
            case .stopped: [.mqVelvet.opacity(0.7), .mqVelvet]
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.45))
                    Capsule()
                        .fill(LinearGradient(colors: tint.gradient,
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geometry.size.width * min(max(fraction, 0), 1)))
                }
            }
            .frame(height: height)

            if percentLabel {
                Text("\(Int((min(max(fraction, 0), 1) * 100).rounded()))%")
                    .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                    .foregroundStyle(Color.mqBrassBright)
                    .monospacedDigit()
                    .frame(minWidth: 30, alignment: .trailing)
            }
        }
        .animation(.spring(duration: 0.55), value: fraction)
        .accessibilityHidden(true)
    }
}

struct EndedTag: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "flag.fill").font(.system(size: 8))
            Text("Ended")
        }
        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 7))
        .accessibilityLabel("Ended")
    }
}

/// The vertical rule that names a bucket of past watches.
struct DayDivider: View {
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Rectangle().fill(Color.mqHairline).frame(width: 1)
            Text(label)
                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(Color.mqInkMuted)
                .fixedSize()
                // Rotation doesn't change a view's layout bounds, so the column has to
                // reserve the *rotated* footprint or the label spills over its neighbours.
                .rotationEffect(.degrees(90))
                .frame(width: 12, height: 92)
            Rectangle().fill(Color.mqHairline).frame(width: 1)
        }
        .frame(width: 22)
        .padding(.vertical, 6)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A small card for something already watched — yours, or a housemate's.
struct WatchedMiniCard: View {
    let entry: WatchEntry
    var showsWho = false
    var isPast = false

    @Environment(Session.self) private var session

    var body: some View {
        NavigationLink(value: destination) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottom) {
                    PosterArt(url: entry.poster)
                    if isPast {
                        LinearGradient(colors: [.clear, Color.mqScrim.opacity(0.9)],
                                       startPoint: .center, endPoint: .bottom)
                        Text(MQTime.short(entry.watchedAt))
                            .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqBrassBright)
                            .padding(.bottom, 4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if entry.count > 1 {
                        Text("\(entry.count)")
                            .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqBrassOnFill)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.mqBrassFill, in: .capsule)
                            .padding(5)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if showsWho, let who = entry.by {
                        AvatarView(person: who, size: 20, baseURL: session.server?.baseURL)
                            .overlay(Circle().strokeBorder(Color.mqGround, lineWidth: 2))
                            .padding(5)
                    }
                }
                .clipShape(.rect(cornerRadius: MQ.radiusSmall))
                // A past watch is history, not a call to action — it recedes.
                .saturation(isPast ? 0.55 : 1)
                .opacity(isPast ? 0.78 : 1)

                Text(entry.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(isPast ? Color.mqInkSoft : Color.mqInk)
                    .lineLimit(1)

                if let code = entry.code {
                    Text(code + (entry.count > 1 ? " +\(entry.count - 1)" : ""))
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqBrassBright)
                        .lineLimit(1)
                }

                if showsWho, let who = entry.by {
                    Text("\(who.name) · \(MQTime.short(entry.watchedAt))")
                        .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                        .lineLimit(1)
                }
            }
            .frame(width: MQ.watchedWidth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var destination: Navigator.Route {
        if isPast, let season = entry.season, let number = entry.number {
            return .episode(showID: entry.showID, season: season, number: number)
        }
        return .show(entry.showID)
    }

    private var accessibilityLabel: String {
        var parts = [entry.displayTitle]
        if let code = entry.code { parts.append(code) }
        if entry.count > 1 { parts.append("\(entry.count) episodes") }
        if let who = entry.by { parts.append("watched by \(who.name)") }
        parts.append(MQTime.relative(entry.watchedAt))
        return parts.joined(separator: ", ")
    }
}

/// An episode airing soon.
struct CalendarCard: View {
    let episode: UpcomingEpisode

    var body: some View {
        NavigationLink(value: Navigator.Route.episode(showID: episode.showID,
                                                      season: episode.season,
                                                      number: episode.number)) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .bottom) {
                    PosterArt(url: episode.poster)
                    LinearGradient(colors: [.clear, Color.mqScrim.opacity(0.9)],
                                   startPoint: .center, endPoint: .bottom)
                    Text(MQTime.short(episode.airDate))
                        .font(MarqueeFont.body(10.5, .bold, relativeTo: .caption2))
                        .foregroundStyle(Color.mqBrassBright)
                        .padding(.bottom, 4)
                }
                .clipShape(.rect(cornerRadius: MQ.radiusSmall))

                Text(episode.showTitle ?? "")
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(1)
                Text(episode.code)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqBrassBright)
                    .lineLimit(1)
            }
            .frame(width: MQ.watchedWidth)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(episode.showTitle ?? ""), \(episode.code), airs \(MQTime.medium(episode.airDate))")
    }
}

/// A household review on the home screen.
struct ReviewTeaserRow: View {
    let review: ReviewTeaser
    @Environment(Session.self) private var session

    var body: some View {
        NavigationLink(value: review.type == "show"
                       ? Navigator.Route.show(review.id) : Navigator.Route.movie(review.id)) {
            HStack(alignment: .top, spacing: 11) {
                PosterArt(url: review.poster, radius: 7)
                    .frame(width: 46)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        AvatarView(person: review.by, size: 20, baseURL: session.server?.baseURL)
                        Text(review.by.name)
                            .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
                            .foregroundStyle(Color.mqInk)
                        Spacer(minLength: 4)
                        if let rating = review.rating {
                            Label("\(rating)", systemImage: "star.fill")
                                .font(MarqueeFont.body(12, .bold, relativeTo: .caption))
                                .foregroundStyle(Color.mqBrass)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    Text(review.title ?? "")
                        .font(MarqueeFont.body(13, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                        .lineLimit(1)
                    if let body = review.body, !body.isEmpty {
                        Text(body)
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mqPanel()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// The search/discover tile: poster, type badge, list bookmark, quick-add.
struct PosterTile: View {
    let result: SearchResult
    var width: CGFloat = MQ.tileWidth

    @Environment(Session.self) private var session

    var body: some View {
        NavigationLink(value: result.isShow ? Navigator.Route.show(result.id)
                                            : Navigator.Route.movie(result.id)) {
            VStack(alignment: .leading, spacing: 6) {
                PosterArt(url: result.poster)
                    .overlay(alignment: .topLeading) {
                        TypeBadge(isShow: result.isShow).padding(6)
                    }
                    .overlay(alignment: .topTrailing) {
                        if let vote = result.vote, vote > 0 {
                            Label(String(format: "%.1f", vote), systemImage: "star.fill")
                                .font(MarqueeFont.body(10, .bold, relativeTo: .caption2))
                                .foregroundStyle(Color.mqBrass)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.ultraThinMaterial, in: .capsule)
                                .padding(6)
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        ListBookmark(count: session.listCount(result.type, result.id))
                            .padding(6)
                    }

                Text(result.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text([result.year?.text, result.stateLabel].compactMap { $0 }
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .mqSecondaryLine()
            }
            .frame(width: width, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.displayTitle), \(result.isShow ? "TV" : "film")\(result.year?.text.isEmpty == false ? ", \(result.year!.text)" : "")")
    }
}

struct TypeBadge: View {
    let isShow: Bool

    var body: some View {
        Text(isShow ? "TV" : "FILM")
            .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
            .tracking(0.7)
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: .capsule)
            .accessibilityHidden(true)
    }
}

/// "This is already on one of your lists" — the marker every tile carries.
struct ListBookmark: View {
    let count: Int

    var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                Image(systemName: "bookmark.fill").font(.system(size: 9))
                if count > 1 {
                    Text("\(count)")
                        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(Color.mqBrassBright)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 6))
            .accessibilityLabel(count > 1 ? "On \(count) of your lists" : "On one of your lists")
        }
    }
}
