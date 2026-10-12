import SwiftUI

// Small pieces shared by the Library shelves and the Home rails that open into them.

// MARK: - Undo

/// Something destructive done in a single gesture, and the way back from it.
///
/// The web client raises a toast with one action on it; here it's a slab of glass over
/// the tab bar, where the thumb that just swiped already is — the same place the punch
/// receipt rises.
struct UndoToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let undo: @MainActor () async -> Void

    static func == (lhs: UndoToast, rhs: UndoToast) -> Bool { lhs.id == rhs.id }
}

struct UndoBanner: View {
    let toast: UndoToast
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @State private var drag: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.mqInkMuted)
                .accessibilityHidden(true)
            Text(toast.message)
                .font(MarqueeFont.body(14, .semibold, relativeTo: .subheadline))
                .foregroundStyle(Color.mqInk)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("Undo", action: onUndo)
                .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                .foregroundStyle(Color.mqBrass)
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .contentShape(.rect)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.horizontal, MQ.gutter)
        .offset(y: max(0, drag))
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { drag = max(0, $0.translation.height) }
                .onEnded { value in
                    if value.translation.height > 40 { onDismiss() } else {
                        withAnimation(.snappy) { drag = 0 }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo", onUndo)
    }
}

/// Hangs an undo banner off the bottom of a screen, and takes it away again after a
/// few seconds unless something replaced it first.
struct UndoHost: ViewModifier {
    @Binding var toast: UndoToast?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let current = toast {
                    UndoBanner(toast: current) {
                        toast = nil
                        Task { await current.undo() }
                    } onDismiss: {
                        withAnimation(.easeIn(duration: 0.2)) { toast = nil }
                    }
                    .padding(.bottom, 6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: current.id) { [id = current.id] in
                        try? await Task.sleep(for: .seconds(6))
                        guard !Task.isCancelled, toast?.id == id else { return }
                        withAnimation(.easeIn(duration: 0.25)) { toast = nil }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.82), value: toast?.id)
            .sensoryFeedback(.warning, trigger: toast?.id) { _, new in new != nil }
    }
}

extension View {
    func undoBanner(_ toast: Binding<UndoToast?>) -> some View {
        modifier(UndoHost(toast: toast))
    }
}

// MARK: - Formatting

enum LibraryFormat {
    /// "45 min", "~3.5 hrs", "~16 hrs" — the size of the commitment.
    static func hours(_ minutes: Double?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        if minutes < 60 { return "\(Int(minutes.rounded())) min" }
        let hours = minutes / 60
        if minutes < 180 {
            let tenths = (hours * 10).rounded() / 10
            return tenths == tenths.rounded()
                ? "~\(Int(tenths)) hrs"
                : "~\(String(format: "%.1f", tenths)) hrs"
        }
        return "~\(Int(hours.rounded())) hrs"
    }

    /// "1h 52m" — a film's runtime.
    static func runtime(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        return MQTime.clock(minutes: minutes)
    }
}

// MARK: - The household on one line

/// "Mia finished it · ★9", "On Jo's watchlist too", "Jo is on S2 E3" — who else in the
/// house is into this, in as few words as it takes.
struct HouseholdSummary: Equatable {
    let text: String
    let people: [Person]

    static func show(_ card: ShowCard) -> HouseholdSummary? {
        let members = card.household ?? []
        guard !members.isEmpty else { return nil }
        let aired = card.aired
        let done = members.filter { ($0.watched ?? 0) > 0 && aired > 0 && ($0.watched ?? 0) >= aired }
        let on = members.filter { member in
            let watched = member.watched ?? 0
            return watched > 0 && !(aired > 0 && watched >= aired)
                && member.stopped != true && member.lastEpCode != nil
        }
        let want = members.filter { ($0.watched ?? 0) == 0 && $0.stopped != true }

        var bits: [String] = []
        if let first = done.first {
            bits.append(done.count == 1
                        ? "\(first.displayName) finished it\(star(first.rating?.value))"
                        : "\(names(done.map(\.displayName))) finished it")
        }
        if let first = on.first, let code = first.lastEpCode, bits.count < 2 {
            bits.append("\(first.displayName) is on \(code)")
        }
        if let first = want.first, bits.count < 2 {
            bits.append(want.count == 1 && bits.isEmpty
                        ? "On \(first.displayName)\u{2019}s watchlist too"
                        : "\(names(want.map(\.displayName))) want\(want.count == 1 ? "s" : "") it too")
        }
        guard !bits.isEmpty else { return nil }
        let faces = (done + on + want).prefix(3).map(\.person)
        return HouseholdSummary(text: bits.joined(separator: " · "), people: Array(faces))
    }

    static func film(_ film: MovieCard) -> HouseholdSummary? {
        let members = film.household ?? []
        guard !members.isEmpty else { return nil }
        let done = members.filter { $0.state == "watched" }
        let want = members.filter { $0.state == "watchlist" }

        var bits: [String] = []
        if let first = done.first {
            bits.append(done.count == 1
                        ? "\(first.displayName) watched it\(star(first.rating?.value))"
                        : "\(names(done.map(\.displayName))) watched it")
        }
        if let first = want.first, bits.count < 2 {
            bits.append(want.count == 1 && bits.isEmpty
                        ? "On \(first.displayName)\u{2019}s watchlist too"
                        : "\(names(want.map(\.displayName))) want\(want.count == 1 ? "s" : "") it too")
        }
        guard !bits.isEmpty else { return nil }
        let faces = (done + want).prefix(3).map(\.person)
        return HouseholdSummary(text: bits.joined(separator: " · "), people: Array(faces))
    }

    private static func names(_ all: [String]) -> String {
        switch all.count {
        case 0: ""
        case 1: all[0]
        case 2: "\(all[0]) & \(all[1])"
        default: "\(all[0]) +\(all.count - 1)"
        }
    }

    private static func star(_ rating: Int?) -> String {
        guard let rating, rating > 0 else { return "" }
        return " · \u{2605}\(rating)"
    }
}

struct HouseholdLine: View {
    let summary: HouseholdSummary

    @Environment(Session.self) private var session

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: -5) {
                ForEach(Array(summary.people.enumerated()), id: \.offset) { _, person in
                    AvatarView(person: person, size: 18, baseURL: session.server?.baseURL)
                        .overlay(Circle().strokeBorder(Color.mqGround, lineWidth: 1.5))
                }
            }
            .accessibilityHidden(true)
            Text(summary.text)
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkSoft)
                .lineLimit(1)
        }
    }
}

/// "Netflix · IMDb 8.4" — where it streams and whether it's any good, as one quiet line.
struct ProviderScoreLine: View {
    var provider: String?
    /// Shown dimmer, when there's no streaming answer but the show has a network.
    var network: String?
    var imdb: Double?
    var vote: Double?

    var body: some View {
        if hasContent {
            HStack(spacing: 6) {
                if let provider, !provider.isEmpty {
                    Label(provider, systemImage: "play.tv")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Color.mqInkSoft)
                } else if let network, !network.isEmpty {
                    Text(network).foregroundStyle(Color.mqInkMuted)
                }
                if let imdb, imdb > 0 {
                    HStack(spacing: 3) {
                        Text("IMDb")
                            .font(MarqueeFont.body(8.5, .bold, relativeTo: .caption2))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color(red: 0.961, green: 0.773, blue: 0.094),
                                        in: .rect(cornerRadius: 2.5))
                        Text(String(format: "%.1f", imdb)).foregroundStyle(Color.mqInk)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("IMDb \(String(format: "%.1f", imdb))")
                } else if let vote, vote > 0 {
                    Label(String(format: "%.1f", vote), systemImage: "star.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Color.mqBrass)
                }
            }
            .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
            .lineLimit(1)
        }
    }

    private var hasContent: Bool {
        (provider?.isEmpty == false) || (network?.isEmpty == false)
            || (imdb ?? 0) > 0 || (vote ?? 0) > 0
    }
}
