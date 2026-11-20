import SwiftUI

/// One half of a theatre curtain: velvet in folds, a brass trim down the leading
/// edge, and the hem catching the light.
///
/// Drawn in a `Canvas` rather than built from views — a curtain is a few dozen
/// gradients and it only ever exists for a second, so it shouldn't cost a layout pass.
struct VelvetCurtain: View {
    /// Which side of the stage this half hangs on. The trim runs along the edge that
    /// meets the other half.
    var edge: HorizontalEdge
    /// How far the folds are bunched, 0 hanging flat … 1 drawn right back. Gathered
    /// velvet has tighter, deeper pleats, which is what sells the motion.
    var gather: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            // The cloth itself, opaque — the folds are light and shadow laid over it.
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.velvet))

            // Fold by fold, each lit along its crest and falling into shadow either
            // side. Widths wander a little, as real velvet does; gathered, the folds
            // crowd tighter and run deeper.
            let base = 48 - 20 * gather
            let depth = 0.32 + 0.4 * gather
            var x: CGFloat = edge == .leading ? 0 : -base * 0.4
            var index = 0
            while x < size.width {
                let wander = (sin(Double(index) * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1)
                let width = base * (0.7 + 0.6 * abs(wander))
                let rect = CGRect(x: x, y: 0, width: width + 0.5, height: size.height)
                let gradient = Gradient(stops: [
                    .init(color: Self.shadow.opacity(0.95), location: 0),
                    .init(color: Self.shadow.opacity(0), location: 0.3),
                    .init(color: Self.sheen.opacity(depth), location: 0.52),
                    .init(color: Self.shadow.opacity(0), location: 0.72),
                    .init(color: Self.shadow.opacity(0.95), location: 1),
                ])
                context.fill(Path(rect),
                             with: .linearGradient(gradient,
                                                   startPoint: CGPoint(x: rect.minX, y: 0),
                                                   endPoint: CGPoint(x: rect.maxX, y: 0)))
                x += width
                index += 1
            }

            // Light from above: the top of the curtain sits in the dark of the
            // proscenium, the hem catches the footlights.
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .linearGradient(
                            Gradient(colors: [.black.opacity(0.55), .clear, .clear,
                                              Self.sheen.opacity(0.18)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: 0, y: size.height)))

            // The trim, on the edge that meets the other half.
            let trimX = edge == .leading ? size.width - 5 : 0
            context.fill(Path(CGRect(x: trimX, y: 0, width: 5, height: size.height)),
                         with: .linearGradient(
                            Gradient(colors: [Color.mqBrassOnArt.opacity(0.55),
                                              Color.mqBrassOnArt,
                                              Color.mqBrassOnArt.opacity(0.55)]),
                            startPoint: CGPoint(x: trimX, y: 0),
                            endPoint: CGPoint(x: trimX + 5, y: 0)))
        }
        .accessibilityHidden(true)
    }

    // Pinned, not from the asset catalog: velvet is velvet in daylight too.
    private static let velvet = Color(red: 0.42, green: 0.07, blue: 0.12)
    private static let shadow = Color(red: 0.16, green: 0.02, blue: 0.05)
    private static let sheen = Color(red: 0.86, green: 0.30, blue: 0.34)
}

/// Both halves, meeting at `seam` and drawn back by `openness`.
///
/// Animatable as a whole, so every frame is laid out from the in-between openness —
/// the halves' widths, positions and the bunching of their folds all move together,
/// instead of SwiftUI tweening each frame on its own and the velvet lagging the edge.
struct CurtainPair: View, Animatable {
    /// 0 closed … 1 fully open, each half gone past its edge of the stage.
    var openness: CGFloat
    /// Where the halves meet, in this view's coordinates — on the Duo, the crease.
    var seam: CGFloat?

    nonisolated var animatableData: CGFloat {
        get { openness }
        set { openness = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let seam = seam ?? proxy.size.width / 2
            let leftWidth = seam
            let rightWidth = proxy.size.width - seam
            // A drawn curtain bunches toward its side as it goes, so each half
            // narrows as well as moving off.
            let left = leftWidth * (1 - 0.65 * openness)
            let right = rightWidth * (1 - 0.65 * openness)
            ZStack(alignment: .topLeading) {
                VelvetCurtain(edge: .leading, gather: openness)
                    .frame(width: left)
                    .offset(x: -leftWidth * 0.4 * openness)
                VelvetCurtain(edge: .trailing, gather: openness)
                    .frame(width: right)
                    .offset(x: proxy.size.width - right + rightWidth * 0.4 * openness)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Curtain up

/// Opening the Duo raises the curtain: the two halves meet exactly on the crease and
/// draw back from it, so the moment the inner display lights is the moment the show
/// starts.
///
/// Keyed off the fold appearing, not the hinge: the outer display reports no fold at
/// all and the inner one always does, so "a fold where there wasn't one" is precisely
/// "you just opened the phone" — and it lands in the same layout pass as the new
/// screen instead of whenever the hinge sensor reports in.
private struct CurtainUp: ViewModifier {
    @AppStorage(DuoSettings.curtainKey) private var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var openness: CGFloat = 1
    @State private var showing = false
    @State private var seam: CGFloat?
    @State private var raise: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay {
                if showing {
                    CurtainPair(openness: openness, seam: seam)
                        .ignoresSafeArea()
                }
            }
            .onGeometryChange(for: CGFloat?.self) { proxy in
                proxy.foldLine.flatMap { $0.isVertical ? $0.center.x : nil }
            } action: { old, new in
                guard old == nil, let new, enabled, !reduceMotion else { return }
                play(seam: new)
            }
    }

    private func play(seam: CGFloat) {
        raise?.cancel()
        self.seam = seam
        openness = 0
        showing = true
        raise = Task {
            // One held beat with the curtain down — long enough to register as a
            // curtain, short enough that nobody's waiting for their app.
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.55, 0, 0.25, 1, duration: 0.85)) {
                openness = 1
            } completion: {
                showing = false
            }
        }
    }
}

extension View {
    /// Raise a curtain whenever the Duo opens. Does nothing on any other phone.
    func curtainUpOnUnfold() -> some View { modifier(CurtainUp()) }
}

/// The Duo-only switches, shared between where they're read and where they're set.
enum DuoSettings {
    static let curtainKey = "duo.curtainUp"
    static let screeningRoomKey = "duo.screeningRoom"
}
