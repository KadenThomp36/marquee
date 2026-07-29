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

    /// The ramp holds off far longer than it used to. Blurring from a quarter of the
    /// way down meant the picture was gone before you'd taken it in; the art now stays
    /// sharp through the top half and only dissolves as it reaches the page.
    private static let layers: [Layer] = [
        Layer(blur: 0, stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.46),
            .init(color: .clear, location: 0.60)]),
        Layer(blur: 4, stops: [
            .init(color: .clear, location: 0.44),
            .init(color: .black, location: 0.57),
            .init(color: .black, location: 0.63),
            .init(color: .clear, location: 0.74)]),
        Layer(blur: 10, stops: [
            .init(color: .clear, location: 0.60),
            .init(color: .black, location: 0.71),
            .init(color: .black, location: 0.77),
            .init(color: .clear, location: 0.87)]),
        Layer(blur: 20, stops: [
            .init(color: .clear, location: 0.74),
            .init(color: .black, location: 0.84),
            .init(color: .black, location: 0.90),
            .init(color: .clear, location: 0.96)]),
        Layer(blur: 34, stops: [
            .init(color: .clear, location: 0.87),
            .init(color: .black, location: 0.95),
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
        // Pull down and the banner grows to keep filling the space rather than
        // leaving the page colour behind it. Driven by the scroll geometry during
        // layout, so it tracks the finger exactly and costs no state.
        .visualEffect { view, proxy in
            let pulled = max(0, proxy.frame(in: .scrollView(axis: .vertical)).minY)
            return view.scaleEffect(1 + pulled / max(full, 1), anchor: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Darkens as it descends and lands exactly on the page colour, so the banner has
    /// no bottom edge to speak of.
    private var tint: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: 0.44),
            .init(color: Color.mqScrim.opacity(0.16), location: 0.64),
            .init(color: Color.mqScrim.opacity(0.44), location: 0.84),
            .init(color: Color.mqGround, location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}
