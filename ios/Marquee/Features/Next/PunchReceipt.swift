import SwiftUI

/// What you just punched, so you can go and look at it.
struct PunchReceipt: Identifiable, Equatable {
    let id = UUID()
    let showID: Int
    let season: Int
    let number: Int
    let showTitle: String
    let episodeTitle: String?
    let code: String
    let art: String?

    var route: Navigator.Route {
        .episode(showID: showID, season: season, number: number)
    }
}

/// The stub you're left holding.
///
/// The web client raises a toast offering the episode you just marked; on a phone
/// the same idea wants to be something you can actually hit with a thumb, sitting
/// where your thumb already is. So it rises over the tab bar as a piece of glass,
/// carrying the art and a hole punched in its corner — the same hole the card got —
/// and it opens the episode.
struct PunchReceiptBanner: View {
    let receipt: PunchReceipt
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drag: CGFloat = 0

    var body: some View {
        NavigationLink(value: receipt.route) {
            HStack(spacing: 11) {
                stub
                VStack(alignment: .leading, spacing: 1) {
                    Text("Punched")
                        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(Color.mqBrass)
                    Text(receipt.episodeTitle ?? receipt.showTitle)
                        .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                        .lineLimit(1)
                    Text("\(receipt.showTitle) · \(receipt.code)")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mqInkMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, MQ.gutter)
        .offset(y: max(0, drag))
        .gesture(
            DragGesture()
                .onChanged { drag = $0.translation.height }
                .onEnded { value in
                    if value.translation.height > 30 { onDismiss() } else {
                        withAnimation(.snappy) { drag = 0 }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Punched \(receipt.code) of \(receipt.showTitle). Opens the episode.")
        .accessibilityAddTraits(.isButton)
    }

    /// The art, with the corner punched out — the same bite the card took.
    private var stub: some View {
        PosterArt(url: receipt.art, radius: 7)
            .frame(width: 34)
            .mask {
                TicketShape(holeRadius: 4.5,
                            holeInset: CGSize(width: 8, height: 8),
                            cornerRadius: 7)
                    .fill(style: FillStyle(eoFill: true))
            }
    }
}
