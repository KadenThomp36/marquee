import SwiftUI

/// A rounded rectangle with a bite taken out of it.
///
/// Drawn as one path filled even-odd, so the circle is a genuine hole — you see
/// through the card to whatever is behind it, not a dark dot painted on top. The
/// radius is the animatable value, which is what lets the punch pop rather than
/// simply appear.
struct TicketShape: Shape {
    var holeRadius: CGFloat
    /// Where the hole lands, measured in from the top-right corner. This is the
    /// centre of the punch button, so the hole opens exactly under the check.
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

/// The card, frozen as it was the moment you punched it.
///
/// The live card advances to the next episode straight away — that is what marking
/// one does — so the thing that flies away has to be a copy holding the old values.
/// It wears the same face, so what lifts off is unmistakably the card you just
/// tapped, with a hole punched clean through where the check was.
///
/// Drawing the poster twice costs nothing: `ArtLoader` already has it decoded, so
/// this renders on its first frame instead of flashing a placeholder.
struct PunchedTicket: View {
    let poster: String?
    let title: String
    let episodeLine: String
    let subline: String?
    let progress: Double
    /// Centre of the punch button, in from the card's top-right corner.
    let holeInset: CGSize
    let holeRadius: CGFloat
    /// Drives the whole flight: false is "just punched", true is "gone".
    let departed: Bool

    var body: some View {
        PosterArt(url: poster, radius: MQ.radius)
            .overlay { scrim }
            .overlay(alignment: .bottom) { info }
            .mask {
                TicketShape(holeRadius: holeRadius,
                            holeInset: holeInset,
                            cornerRadius: MQ.radius)
                    .fill(style: FillStyle(eoFill: true))
            }
            .compositingGroup()
            .shadow(color: .black.opacity(departed ? 0 : 0.55), radius: 20, y: 12)
            // Off the spike, a tip, and away down the rail into history.
            .rotationEffect(.degrees(departed ? -15 : 0), anchor: .topTrailing)
            .scaleEffect(departed ? 0.48 : 1, anchor: .topTrailing)
            .offset(x: departed ? -340 : 0, y: departed ? -26 : 0)
            .opacity(departed ? 0 : 1)
    }

    private var scrim: some View {
        LinearGradient(
            stops: [.init(color: .clear, location: 0.36),
                    .init(color: Color.mqScrim.opacity(0.55), location: 0.62),
                    .init(color: Color.mqScrim.opacity(0.95), location: 0.9)],
            startPoint: .top, endPoint: .bottom)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(MarqueeFont.body(14.5, .bold, relativeTo: .subheadline))
                .foregroundStyle(Color.mqInkOnArt)
                .lineLimit(2)
            Text(episodeLine)
                .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
                .foregroundStyle(Color.mqBrassOnArt)
                .lineLimit(2)
            if let subline {
                Text(subline)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoftOnArt)
                    .lineLimit(1)
            }
            ProgressBar(fraction: progress, percentLabel: true, onArtwork: true)
                .padding(.top, 5)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
