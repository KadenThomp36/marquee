import SwiftUI

// The two rails Home gained alongside Up Next: what you're reading, and the shows
// you've added but not begun.

// MARK: - Continue reading

/// A book or manga in progress, built like an Up Next card: the cover fills it,
/// progress sits inside, and the round button logs reading. Manga and chapter-mode
/// books step +1 chapter; page books open the progress sheet — one tap must never
/// "finish" a 400-page book. With a session running, the button ends it.
struct ContinueReadingCard: View {
    let item: ReadingItem
    let live: ActiveSession?
    let onIncrement: () async -> Void
    let onLog: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var busy = false
    @State private var bumped = 0

    private var kind: ReadingKind { item.readingKind }
    private var plusable: Bool { live == nil && item.supportsIncrement(for: kind) }

    var body: some View {
        NavigationLink(value: kind == .book ? Navigator.Route.book(item.id)
                                            : Navigator.Route.manga(item.id)) {
            CoverArt(url: item.cover, radius: MQ.radius)
        }
        .buttonStyle(.plain)
        .overlay { scrim }
        .overlay(alignment: .bottom) { info }
        .clipShape(.rect(cornerRadius: MQ.radius))
        .overlay(alignment: .topLeading) { kindBadge.padding(9) }
        .overlay(alignment: .topTrailing) { actionButton.padding(7) }
        .shadow(color: .black.opacity(colorScheme == .light ? 0.12 : 0.3),
                radius: colorScheme == .light ? 7 : 12,
                y: colorScheme == .light ? 3 : 6)
        .sensoryFeedback(.increase, trigger: bumped)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityText)
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
            Text(item.displayTitle)
                .font(MarqueeFont.body(14.5, .bold, relativeTo: .subheadline))
                .foregroundStyle(Color.mqInkOnArt)
                .lineLimit(2)

            Text(item.progressLabel(for: kind))
                .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
                .foregroundStyle(Color.mqBrassOnArt)
                .lineLimit(1)

            if let subline {
                Text(subline)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoftOnArt)
                    .lineLimit(2)
            }

            if item.total(for: kind) != nil {
                ProgressBar(fraction: item.fraction(for: kind), percentLabel: true, onArtwork: true)
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
    }

    private var subline: String? {
        if live != nil { return "Reading now" }
        if let pace = item.paceLine { return pace }
        if kind == .book { return item.author }
        return item.origin
    }

    private var kindBadge: some View {
        HStack(spacing: 4) {
            if live != nil {
                Circle().fill(Color.mqBrassOnArt).frame(width: 6, height: 6)
            }
            Text(live != nil ? "Live" : (kind == .book ? "Book" : (item.origin ?? "Manga")))
        }
        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
        .textCase(.uppercase)
        .tracking(0.6)
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 7))
        .accessibilityHidden(true)
    }

    private var actionButton: some View {
        Button {
            if plusable {
                guard !busy else { return }
                busy = true
                bumped += 1
                Task {
                    await onIncrement()
                    busy = false
                }
            } else {
                onLog()
            }
        } label: {
            Image(systemName: live != nil ? "stop.fill" : (plusable ? "plus" : "slider.horizontal.3"))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.mqBrassOnFill)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.tint(Color.mqBrassOnArt.opacity(0.78)).interactive(), in: .circle)
        .opacity(busy ? 0.45 : 1)
        .scaleEffect(busy && !reduceMotion ? 0.88 : 1)
        .animation(.spring(duration: 0.3), value: busy)
        .accessibilityLabel(actionLabel)
    }

    /// A plain String, so the label overloads don't have to solve a nested ternary of
    /// interpolated literals.
    private var actionLabel: String {
        if live != nil { return "End the session on \(item.displayTitle)" }
        if plusable { return "Read one more chapter of \(item.displayTitle)" }
        return "Log progress on \(item.displayTitle)"
    }

    private var accessibilityText: String {
        var parts = [item.displayTitle, item.progressLabel(for: kind)]
        if let subline { parts.append(subline) }
        return parts.joined(separator: ". ")
    }
}

// MARK: - On your watchlist

/// A show you've added but not begun — Home's door into the Shows watchlist.
struct WatchlistRailCard: View {
    let show: ShowCard

    var body: some View {
        NavigationLink(value: Navigator.Route.show(show.id)) {
            VStack(alignment: .leading, spacing: 6) {
                PosterArt(url: show.poster)
                    .overlay(alignment: .bottomLeading) {
                        if let household = HouseholdSummary.show(show), let first = household.people.first {
                            HouseholdPip(person: first).padding(5)
                        }
                    }
                Text(show.displayTitle)
                    .font(.mqTile)
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Text(subline)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .mqSecondaryLine()
            }
            .frame(width: MQ.tileWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var subline: String {
        if show.aired == 0, let next = show.nextAir, !next.isEmpty {
            return "Premieres \(MQTime.upcomingLabel(next))"
        }
        let parts = [show.prov?.name ?? show.network, LibraryFormat.hours(show.totalMin)]
            .compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? (show.year?.text ?? "") : parts.joined(separator: " · ")
    }

    private var accessibilityText: String {
        var parts = [show.displayTitle, subline]
        if let household = HouseholdSummary.show(show) { parts.append(household.text) }
        return parts.filter { !$0.isEmpty }.joined(separator: ". ")
    }
}

/// One housemate's face on a poster corner.
private struct HouseholdPip: View {
    let person: Person
    @Environment(Session.self) private var session

    var body: some View {
        AvatarView(person: person, size: 20, baseURL: session.server?.baseURL)
            .overlay(Circle().strokeBorder(Color.mqGround, lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

/// Up Next is empty but the watchlist isn't: say where to go next, not just that
/// you're done.
struct EmptyQueuePrompt: View {
    let waiting: Int

    var body: some View {
        NavigationLink {
            ShowsShelfScreen(shelf: .watchlist)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.tv")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.mqBrass)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing in the queue")
                        .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                        .foregroundStyle(Color.mqInk)
                    Text("\(waiting) show\(waiting == 1 ? "" : "s") on your watchlist — start one tonight.")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mqInkMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mqPanel()
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MQ.gutter)
    }
}
