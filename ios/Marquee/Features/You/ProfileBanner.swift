import SwiftUI

/// The profile banner: a *progressive* blur, sharp along the top and dissolving into
/// the page by the bottom.
///
/// One `.blur()` can only do a single uniform radius, so this is five copies of the
/// same art at stepped radii, each revealed through a feathered band so neighbouring
/// levels crossfade into one continuous ramp. The radii and the bands are the same
/// numbers the web client uses in `.pb-l0`…`.pb-l4`.
///
/// Getting the direction wrong is not subtle: run the ramp the other way and the
/// heaviest blur covers the whole banner, which flattens the art into a single wash
/// of its average colour.
struct ProfileBanner: View {
    let url: String
    let height: CGFloat

    private struct Layer {
        let blur: CGFloat
        let stops: [Gradient.Stop]
    }

    private static let layers: [Layer] = [
        Layer(blur: 0, stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.28),
            .init(color: .clear, location: 0.44)]),
        Layer(blur: 4, stops: [
            .init(color: .clear, location: 0.26),
            .init(color: .black, location: 0.40),
            .init(color: .black, location: 0.46),
            .init(color: .clear, location: 0.60)]),
        Layer(blur: 10, stops: [
            .init(color: .clear, location: 0.42),
            .init(color: .black, location: 0.56),
            .init(color: .black, location: 0.62),
            .init(color: .clear, location: 0.76)]),
        Layer(blur: 20, stops: [
            .init(color: .clear, location: 0.58),
            .init(color: .black, location: 0.72),
            .init(color: .black, location: 0.78),
            .init(color: .clear, location: 0.90)]),
        Layer(blur: 34, stops: [
            .init(color: .clear, location: 0.74),
            .init(color: .black, location: 0.88),
            .init(color: .clear, location: 1)]),
    ]

    var body: some View {
        let full = height

        ZStack {
            ForEach(Array(Self.layers.enumerated()), id: \.offset) { _, layer in
                FilledArt(url: url, height: full)
                    .blur(radius: layer.blur)
                    .mask(LinearGradient(stops: layer.stops,
                                         startPoint: .top, endPoint: .bottom))
            }
            tint
        }
        .frame(height: full)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Darkens as it descends and lands exactly on the page colour, so the banner has
    /// no bottom edge to speak of.
    private var tint: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: 0.22),
            .init(color: Color.mqScrim.opacity(0.28), location: 0.44),
            .init(color: Color.mqScrim.opacity(0.6), location: 0.70),
            .init(color: Color.mqGround, location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}
