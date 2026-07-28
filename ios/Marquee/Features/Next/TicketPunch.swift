import SwiftUI

/// A rounded rectangle with a bite taken out of it.
///
/// Drawn as one path filled even-odd, so the circle is a genuine hole — you see
/// whatever is behind the ticket through it, not a dark dot painted on top. The
/// radius is the animatable value, which is what lets the punch pop rather than
/// simply appear.
struct TicketShape: Shape {
    var holeRadius: CGFloat
    /// Where the hole lands, measured in from the top-right corner.
    var holeInset: CGSize
    var cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { holeRadius }
        set { holeRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path(roundedRect: rect, cornerRadius: cornerRadius)
        guard holeRadius > 0.5 else { return path }
        let centre = CGPoint(x: rect.maxX - holeInset.width,
                             y: rect.minY + holeInset.height)
        path.addEllipse(in: CGRect(x: centre.x - holeRadius,
                                   y: centre.y - holeRadius,
                                   width: holeRadius * 2,
                                   height: holeRadius * 2))
        return path
    }
}

/// The stub that tears off when you punch an episode.
///
/// It is a cinema ticket, not a copy of the poster — which is both more on-theme and
/// avoids the card's art having to load a second time behind the animation. Punched,
/// it lifts off its spike and sails left into the history that lives at that end of
/// the rail. The rail's leading edge already fades, so the stub dissolves exactly
/// where watched cards come from.
struct TicketStub: View {
    let title: String
    let episodeLine: String
    /// Drives the whole flight: false is "just punched", true is "gone".
    let departed: Bool
    let holeRadius: CGFloat

    private let corner: CGFloat = 7
    private let holeInset = CGSize(width: 20, height: 21)

    var body: some View {
        ticket
            .mask {
                TicketShape(holeRadius: holeRadius,
                            holeInset: holeInset,
                            cornerRadius: corner)
                    .fill(style: FillStyle(eoFill: true))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(departed ? 0 : 0.5), radius: 14, y: 8)
            // Off the spike, a tip, and away.
            .rotationEffect(.degrees(departed ? -14 : 0), anchor: .topTrailing)
            .scaleEffect(departed ? 0.55 : 1, anchor: .topTrailing)
            .offset(x: departed ? -320 : 0, y: departed ? -30 : 0)
            .opacity(departed ? 0 : 1)
    }

    private var ticket: some View {
        HStack(spacing: 0) {
            stubEnd
            perforation
            details
        }
        .frame(height: 84)
        .background(paper)
        .clipShape(.rect(cornerRadius: corner))
        .overlay {
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(Color(red: 0.36, green: 0.25, blue: 0.06).opacity(0.55),
                              lineWidth: 1)
        }
        .padding(.horizontal, 3)
    }

    /// The counterfoil: the narrow end a real ticket keeps.
    private var stubEnd: some View {
        Text("ADMIT\nONE")
            .font(MarqueeFont.body(8, .bold, relativeTo: .caption2))
            .tracking(1)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(red: 0.36, green: 0.25, blue: 0.06).opacity(0.7))
            .fixedSize()
            .frame(width: 34)
    }

    private var perforation: some View {
        Rectangle()
            .fill(Color(red: 0.36, green: 0.25, blue: 0.06).opacity(0.35))
            .frame(width: 1)
            .mask {
                // A dashed line reads as a tear-off edge; a solid rule reads as a box.
                VStack(spacing: 3) {
                    ForEach(0..<14, id: \.self) { _ in
                        Rectangle().frame(height: 3)
                    }
                }
            }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Marquee")
                .font(MarqueeFont.wordmark(9.5, relativeTo: .caption2))
                .foregroundStyle(Color(red: 0.36, green: 0.25, blue: 0.06).opacity(0.65))
                .lineLimit(1)
                .fixedSize()
            Text(title)
                .font(MarqueeFont.body(13, .bold, relativeTo: .caption))
                .foregroundStyle(Color(red: 0.14, green: 0.10, blue: 0.03))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(episodeLine)
                .font(MarqueeFont.body(10, .semibold, relativeTo: .caption2))
                .foregroundStyle(Color(red: 0.42, green: 0.29, blue: 0.04))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 9)
        // Room for the punch hole, which sits in the top-right corner.
        .padding(.trailing, 26)
    }

    /// Warm stock, so the ticket reads as paper against the poster behind it.
    private var paper: some View {
        LinearGradient(colors: [Color(red: 0.976, green: 0.945, blue: 0.867),
                                Color(red: 0.925, green: 0.874, blue: 0.761)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
