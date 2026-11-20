import SwiftUI

/// The profile banner: sharp along the top, dissolving into the page by the bottom.
///
/// Three layers, each eased rather than linear. Linear ramps were what made the old
/// fade look cheap: every band had a visible start and end, and the colour washed
/// through a muddy grey on its way to the page.
///
/// 1. **A progressive blur.** One `.blur()` can only do a single uniform radius, so
///    this is the same art at stepped radii. Each level is solid from where it
///    fades in all the way to the bottom, and each sits on top of the one before.
///    So every point down the banner is fully covered. (Crossfading neighbouring
///    bands, as before, left the page showing through between them.) The blurs are
///    opaque, so the art doesn't go see-through at the sides.
/// 2. **A legibility scrim** behind the name, numbers and buttons, which stay light
///    over the art in both appearances.
/// 3. **A dissolve** of the whole stack into the page, by opacity and not by
///    blending to the page colour, so it never passes through grey.
///
/// The art also runs under the Duo's tab rail to the screen edge.
///
/// Getting the blur direction wrong is not subtle: run it the other way and the
/// heaviest blur covers the whole banner, which flattens the art into a single wash
/// of its average colour.
struct ProfileBanner: View {
    let url: String
    let height: CGFloat

    @Environment(\.mqRailWidth) private var rail
    @Environment(\.colorScheme) private var colorScheme

    private struct Level {
        let blur: CGFloat
        /// Fades in over this span (unit positions down the visible height), then
        /// stays solid.
        let from: Double
        let to: Double
    }

    /// Extra art drawn above the visible frame. The refresh spinner holds the page
    /// down by insetting the scroll view, and that displacement never reaches this
    /// view's geometry — not in scroll space, not in global space — so no amount of
    /// measuring can stretch over it. Instead the image simply extends this far past
    /// the top: offscreen at rest, and already in place whenever the system moves
    /// the content somewhere layout can't see.
    private static let bleed: CGFloat = 120

    /// The art stays sharp through the top half and only softens as it nears the
    /// page. The overlapping spans make the radius climb smoothly instead of in steps.
    private static let levels: [Level] = [
        Level(blur: 3, from: 0.40, to: 0.58),
        Level(blur: 8, from: 0.50, to: 0.70),
        Level(blur: 16, from: 0.62, to: 0.82),
        Level(blur: 28, from: 0.74, to: 0.94),
    ]

    /// Where the banner gives way to the page. The name, numbers and buttons end
    /// just above where this starts, so they never sit on art that's half gone.
    private static let dissolve = (start: 0.80, end: 1.0)

    /// The stop positions are tuned against the visible height, but the art is drawn
    /// `bleed` taller — re-express each position in the taller run so the visible
    /// portion renders exactly as designed. A gradient extends its first stop's
    /// colour upward, so the bleed continues whatever the top of the ramp shows.
    private static func stretched(_ stops: [Gradient.Stop], over full: CGFloat) -> [Gradient.Stop] {
        stops.map {
            .init(color: $0.color, location: (bleed + $0.location * full) / (full + bleed))
        }
    }

    private func ramp(_ stops: [Gradient.Stop], over full: CGFloat) -> LinearGradient {
        LinearGradient(stops: Self.stretched(stops, over: full), startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let full = height
        let tall = full + Self.bleed

        ZStack {
            FilledArt(url: url, height: tall)
            ForEach(Array(Self.levels.enumerated()), id: \.offset) { _, level in
                FilledArt(url: url, height: tall)
                    .blur(radius: level.blur, opaque: true)
                    .mask(ramp(Scrim.stops(from: 0, to: 1, start: level.from, end: level.to), over: full))
            }
            // Holds off over the sharp top, then deepens behind the identity block.
            // A touch stronger in light mode, where the page it dissolves into is pale
            // and gives the light type less to stand on.
            ramp(Scrim.stops(.mqScrim, from: 0, to: colorScheme == .light ? 0.78 : 0.68,
                             start: 0.30, end: 0.86), over: full)
        }
        // The whole stack dissolves into the page together.
        .mask(ramp(Scrim.stops(from: 1, to: 0, start: Self.dissolve.start, end: Self.dissolve.end),
                   over: full))
        .frame(height: tall)
        // Bottom-aligned in the visible frame, so the extra `bleed` hangs out the
        // top. Frames don't clip; the mask below re-clips the sides and bottom the
        // way `.clipped()` used to, while leaving the top open.
        .frame(height: full, alignment: .bottom)
        .mask {
            Color.black.padding(.top, -Self.bleed)
        }
        // Out under the tab rail to the screen edge. Layout still ends at the
        // content column, so the identity block stays centred on the page.
        .underTabRail(rail)
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
