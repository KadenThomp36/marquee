import SwiftUI

// MARK: - Eased fades

/// Gradients whose opacity follows an ease-in-out curve instead of a straight line.
///
/// A two-stop linear fade has visible "corners" where the ramp starts and stops.
/// The eye picks up the sudden change in slope (Mach bands), so a photo seems to end
/// in a line rather than melt into the page. Polished apps draw their scrims as
/// many-stop gradients along an eased curve. The slope starts at zero, peaks in
/// the middle and goes back to zero, so neither end of the fade has an edge to find.
/// The curve is the sine ease-in-out from Andreas Larsen's "easing gradients" work,
/// which is what most scrim generators use.
enum Scrim {
    /// The ease: 0 → 1 with a zero slope at both ends.
    static func ease(_ t: Double) -> Double {
        let t = min(max(t, 0), 1)
        return (1 - cos(.pi * t)) / 2
    }

    /// Stops that take `color` from `from` opacity to `to` opacity between `start` and
    /// `end` (unit positions along the gradient), held flat outside that span.
    static func stops(_ color: Color = .black,
                      from: Double, to: Double,
                      start: Double, end: Double,
                      steps: Int = 14) -> [Gradient.Stop] {
        var stops: [Gradient.Stop] = []
        if start > 0 { stops.append(.init(color: color.opacity(from), location: 0)) }
        for index in 0...steps {
            let t = Double(index) / Double(steps)
            let value = from + (to - from) * ease(t)
            stops.append(.init(color: color.opacity(value), location: start + (end - start) * t))
        }
        if end < 1 { stops.append(.init(color: color.opacity(to), location: 1)) }
        return stops
    }

    /// A mask that keeps everything down to `start` and is gone by `end`. Pass it to
    /// `.mask` to dissolve art into whatever is behind it.
    static func fadeOut(start: Double, end: Double = 1) -> LinearGradient {
        LinearGradient(stops: stops(from: 1, to: 0, start: start, end: end),
                       startPoint: .top, endPoint: .bottom)
    }

    /// The reverse: clear down to `start`, solid from `end`.
    static func fadeIn(start: Double, end: Double) -> LinearGradient {
        LinearGradient(stops: stops(from: 0, to: 1, start: start, end: end),
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The faint wash of backdrop art behind a film, show or episode hero.
///
/// It's drawn under the tab rail, so on the Duo it reaches the screen edge instead
/// of stopping at the rail's column. It fades out along the eased curve, so the page
/// doesn't seem to start at a line.
struct BackdropWash: View {
    let url: String?
    let height: CGFloat
    /// How strong the art is. The film and show pages keep it faint so the hero
    /// reads over it; an episode's still is the hero itself.
    var opacity: Double = 1
    var blur: CGFloat = 0
    /// Where the fade begins, as a fraction of the height.
    var fadeFrom: Double = 0.35

    @Environment(\.mqRailWidth) private var rail

    var body: some View {
        FilledArt(url: url, height: height)
            // Opaque, so the blur doesn't pull transparency in from outside the frame
            // and leave the sides of the wash see-through. Blurred before it's faded:
            // an opaque blur would throw the fade away.
            .blur(radius: blur, opaque: blur > 0)
            .opacity(opacity)
            .mask(Scrim.fadeOut(start: fadeFrom))
            .underTabRail(rail)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
