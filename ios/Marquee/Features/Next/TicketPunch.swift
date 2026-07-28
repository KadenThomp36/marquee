import SwiftUI

/// A rounded rectangle with a bite taken out of it.
///
/// Drawn as one path filled even-odd, so the circle is a genuine hole — you see
/// through the card to whatever is behind it, not a dark dot painted on top. The
/// radius is the animatable value, which is what lets the punch bite rather than
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

/// What a punch does, in the order it does it.
///
/// Split into named beats because the whole point is that they are separable. Run
/// them together and the card simply vanishes to the left; the punch has to land,
/// and then be *seen* to have landed, before anything moves.
enum PunchBeat {
    /// The die is coming down. The card takes the pressure.
    case biting
    /// Through. The hole is open, the chad is out, and the card sits there punched.
    case punched
    /// Lifted off the spike, tilted, about to go.
    case lifted
    /// Gone, off to the left where history lives.
    case gone

    var holeIsOpen: Bool { self != .biting }
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
    let beat: PunchBeat

    private var gone: Bool { beat == .gone }

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
            // Paper has thickness: the cut edge catches light on one side and falls
            // into shadow on the other. Without this the hole reads as a sticker.
            .overlay(alignment: .topTrailing) { cutEdge }
            .overlay(alignment: .topTrailing) { shockRing }
            .overlay(alignment: .topTrailing) { chad }
            .compositingGroup()
            // The die presses the card down; releasing it lets the card rise.
            .scaleEffect(pressure, anchor: .topTrailing)
            .shadow(color: .black.opacity(gone ? 0 : shadowStrength),
                    radius: beat == .lifted ? 26 : 16,
                    y: beat == .lifted ? 18 : 9)
            // Off the spike, a tip, and away down the rail into history.
            .rotationEffect(.degrees(rotation), anchor: .topTrailing)
            .scaleEffect(gone ? 0.45 : 1, anchor: .topTrailing)
            .offset(x: gone ? -360 : 0, y: gone ? -44 : (beat == .lifted ? -10 : 0))
            .opacity(gone ? 0 : 1)
    }

    // MARK: - The punch itself

    /// A hair of compression as the die bites, springing back once it's through.
    private var pressure: CGFloat {
        switch beat {
        case .biting: 0.972
        case .punched: 1
        case .lifted: 1.045
        case .gone: 1
        }
    }

    private var shadowStrength: Double {
        beat == .lifted ? 0.65 : 0.4
    }

    private var rotation: Double {
        switch beat {
        case .biting, .punched: 0
        case .lifted: -3.5
        case .gone: -17
        }
    }

    /// The lit and shadowed lip of the cut, drawn just inside the hole.
    private var cutEdge: some View {
        Circle()
            .strokeBorder(
                LinearGradient(colors: [.black.opacity(0.85), .white.opacity(0.28)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 1.6)
            .frame(width: holeRadius * 2, height: holeRadius * 2)
            .padding(.top, max(0, holeInset.height - holeRadius))
            .padding(.trailing, max(0, holeInset.width - holeRadius))
            .opacity(holeRadius > 1 ? 1 : 0)
            .allowsHitTesting(false)
    }

    /// A brass ring thrown off at the moment of impact, gone almost at once.
    private var shockRing: some View {
        Circle()
            .strokeBorder(Color.mqBrassOnArt, lineWidth: 2.5)
            .frame(width: holeRadius * 2, height: holeRadius * 2)
            .padding(.top, max(0, holeInset.height - holeRadius))
            .padding(.trailing, max(0, holeInset.width - holeRadius))
            .scaleEffect(beat.holeIsOpen ? 3.4 : 0.6)
            .opacity(beat == .biting ? 0.9 : 0)
            .allowsHitTesting(false)
    }

    /// The little disc of card the punch knocked out, tumbling away. This is the
    /// detail that makes it a punch rather than a hole appearing.
    private var chad: some View {
        Circle()
            .fill(Color(red: 0.13, green: 0.11, blue: 0.09))
            .overlay(Circle().strokeBorder(Color.mqBrassOnArt.opacity(0.55), lineWidth: 1))
            .frame(width: holeRadius * 2, height: holeRadius * 2)
            .padding(.top, max(0, holeInset.height - holeRadius))
            .padding(.trailing, max(0, holeInset.width - holeRadius))
            .rotationEffect(.degrees(beat.holeIsOpen ? 220 : 0))
            .offset(x: beat.holeIsOpen ? 26 : 0,
                    y: beat.holeIsOpen ? 84 : 0)
            .opacity(beat == .biting ? 1 : 0)
            .allowsHitTesting(false)
    }

    // MARK: - The face

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
