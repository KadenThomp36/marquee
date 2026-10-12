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

    /// Extra art drawn above the visible frame. The refresh spinner holds the page
    /// down by insetting the scroll view, and that displacement never reaches this
    /// view's geometry — not in scroll space, not in global space — so no amount of
    /// measuring can stretch over it. Instead the image simply extends this far past
    /// the top: offscreen at rest, and already in place whenever the system moves
    /// the content somewhere layout can't see.
    private static let bleed: CGFloat = 120

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

    private static let tintStops: [Gradient.Stop] = [
        .init(color: .clear, location: 0),
        .init(color: .clear, location: 0.44),
        .init(color: Color.mqScrim.opacity(0.16), location: 0.64),
        .init(color: Color.mqScrim.opacity(0.44), location: 0.84),
        .init(color: Color.mqGround, location: 1),
    ]

    /// The stop positions are tuned against the visible height, but the art is drawn
    /// `bleed` taller — re-express each position in the taller run so the visible
    /// portion renders exactly as designed. A gradient extends its first stop's
    /// colour upward, so the bleed continues whatever the top of the ramp shows.
    private static func stretched(_ stops: [Gradient.Stop], over full: CGFloat) -> [Gradient.Stop] {
        stops.map {
            .init(color: $0.color, location: (bleed + $0.location * full) / (full + bleed))
        }
    }

    var body: some View {
        let full = height
        let tall = full + Self.bleed

        ZStack {
            ForEach(Array(Self.layers.enumerated()), id: \.offset) { _, layer in
                FilledArt(url: url, height: tall)
                    .blur(radius: layer.blur)
                    .mask(LinearGradient(stops: Self.stretched(layer.stops, over: full),
                                         startPoint: .top, endPoint: .bottom))
            }
            LinearGradient(stops: Self.stretched(Self.tintStops, over: full),
                           startPoint: .top, endPoint: .bottom)
        }
        .frame(height: tall)
        // Bottom-aligned in the visible frame, so the extra `bleed` hangs out the
        // top. Frames don't clip; the mask below re-clips the sides and bottom the
        // way `.clipped()` used to, while leaving the top open.
        .frame(height: full, alignment: .bottom)
        .mask {
            Color.black.padding(.top, -Self.bleed)
        }
        // Pull down and the banner grows to keep filling the space rather than
        // leaving the page colour behind it. Driven by the scroll geometry during
        // layout, so it tracks the finger exactly and costs no state.
        //
        // Anchored at the bottom: the frame itself has already slid down with the
        // pull, so scaling by 1 + pulled/height from the bottom edge puts the
        // rendered top exactly back at the screen top while the bottom stays glued
        // to the content below it. Scroll space, not global — a presented sheet
        // shoves the whole screen around in global coordinates.
        .visualEffect { view, proxy in
            let pulled = max(0, proxy.frame(in: .scrollView(axis: .vertical)).minY)
            return view.scaleEffect(1 + pulled / max(full, 1), anchor: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
