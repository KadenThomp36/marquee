import SwiftUI

// MARK: - The hinge

/// The iPhone Duo's hinge, as the rest of the app needs to know it.
///
/// Read for *effects and modes* — the screening room when the phone is propped
/// half-open, the curtain on the way open — never for layout. Layout follows the fold
/// itself (`FoldLine`), which is what Apple's reserved regions describe exactly; the
/// hinge angle arrives at whatever rate the system feels like.
///
/// On every other phone, and on anything before iOS 27.1, `posture` stays `.none`
/// and nothing that reads it changes.
@MainActor
@Observable
final class Hinge {
    static let shared = Hinge()

    enum Posture: Equatable, Sendable {
        /// No hinge — every phone but one, and the Duo's hierarchy before it's on screen.
        case none
        case closed
        /// Propped open: on a table like a laptop, or held like a book.
        case halfOpen
        case open
    }

    private(set) var posture: Posture = .none
    /// 0° shut, 180° flat. `nil` without a hinge.
    private(set) var degrees: Double?

    private init() {}

    fileprivate func update(posture: Posture, degrees: Double?) {
        if self.posture != posture { self.posture = posture }
        // Only republish a change worth redrawing for — the sensor reports fractions
        // of a degree, and every view reading this would re-render for each one.
        if let degrees, let old = self.degrees, abs(old - degrees) < 1 { return }
        self.degrees = degrees
    }
}

private struct HingeObserver: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                guard let hinge = context.hinge else {
                    Hinge.shared.update(posture: .none, degrees: nil)
                    return
                }
                let posture: Hinge.Posture = switch hinge.status {
                case .closed: .closed
                case .partiallyOpen: .halfOpen
                case .fullyOpen: .open
                default: .none
                }
                Hinge.shared.update(posture: posture, degrees: hinge.angle.degrees)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Feed `Hinge.shared`. Applied once, at the root.
    func observesHinge() -> some View { modifier(HingeObserver()) }
}

// MARK: - The fold

/// Where the crease runs across a view, in that view's own coordinates.
///
/// Comes from the system's division region, asked for *including* inactive ones — so
/// it's known while the phone lies flat, when the crease is still there to look at
/// even though nothing is bent. That's what lets a page settle its columns once and
/// keep them, instead of reflowing every time the hinge moves.
struct FoldLine: Equatable {
    /// The crease plus the margin the system wants kept clear around it.
    var frame: CGRect
    /// True while the phone is actually bent: anything placed across it now is
    /// genuinely hard to read.
    var isActive: Bool

    /// A crease running top to bottom — two pages side by side, like a book.
    var isVertical: Bool { frame.height >= frame.width }
    var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
}

extension GeometryProxy {
    /// The crease across this view, if the device has one and it crosses this view.
    /// The Duo's outer display reports none at all, so a closed phone reads `nil`.
    var foldLine: FoldLine? {
        guard #available(iOS 27.1, *) else { return nil }
        let bounds = CGRect(origin: .zero, size: size)
        guard let region = reservedRegions(kind: .division, options: [.includeInactive]).first,
              region.frame.intersects(bounds)
        else { return nil }
        return FoldLine(frame: region.frame, isActive: region.isActive)
    }
}

// MARK: - Two pages

/// How a detail page divides into two, or doesn't.
struct SpreadPages: Equatable {
    var leading: CGFloat
    var gap: CGFloat
    var trailing: CGFloat

    /// The narrowest a page can be and still hold what a phone screen holds.
    static let minimumPage: CGFloat = 320

    /// Two pages either side of a vertical crease, or — on a wide screen without one,
    /// an iPad — either side of the middle. `nil` means one column.
    init?(width: CGFloat, fold: FoldLine?) {
        if let fold, fold.isVertical {
            let leading = max(0, fold.frame.minX)
            let trailing = max(0, width - fold.frame.maxX)
            guard leading >= Self.minimumPage, trailing >= Self.minimumPage else { return nil }
            self.leading = leading
            self.gap = fold.frame.width
            self.trailing = trailing
        } else if fold == nil, width >= 2 * Self.minimumPage + 120 {
            let gap: CGFloat = 28
            // A touch more for the leading page, where the hero lives.
            self.leading = ((width - gap) * 0.52).rounded()
            self.gap = gap
            self.trailing = width - gap - leading
        } else {
            return nil
        }
    }
}

/// A detail page that becomes an open book on the Duo's inner display.
///
/// Phone-sized, it's the one scrolling column it always was: `leading`, then
/// `trailing`, in that order. Opened out, the two halves become facing pages that
/// scroll on their own, with the crease falling in the gutter between them — so the
/// hero and the facts sit on one side, the episodes on the other, and nothing you
/// need to read is ever folded in half.
struct FoldSpread<Leading: View, Trailing: View>: View {
    var spacing: CGFloat = 24
    var refresh: (@MainActor @Sendable () async -> Void)?
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        GeometryReader { proxy in
            if let pages = SpreadPages(width: proxy.size.width, fold: proxy.foldLine) {
                HStack(spacing: 0) {
                    page { leading }
                        .frame(width: pages.leading)
                    FoldGutter()
                        .frame(width: pages.gap)
                    page { trailing }
                        .frame(width: pages.trailing)
                }
            } else {
                page {
                    leading
                    trailing
                }
            }
        }
    }

    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: spacing) {
                content()
            }
            // Pin the column to the page; see ShowScreen for why.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 30)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .refreshable(ifAny: refresh)
    }
}

/// The strip over the crease: a hairline, faded at both ends like the gutter of a
/// printed book, so the two pages read as one spread rather than two panels.
private struct FoldGutter: View {
    var body: some View {
        LinearGradient(colors: [.clear, Color.mqHairline, Color.mqHairline, .clear],
                       startPoint: .top, endPoint: .bottom)
            .frame(width: 1)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}

private extension View {
    /// `.refreshable` only when there's something to refresh — an always-attached
    /// one draws a spinner that does nothing.
    @ViewBuilder
    func refreshable(ifAny action: (@MainActor @Sendable () async -> Void)?) -> some View {
        if let action {
            refreshable { await action() }
        } else {
            self
        }
    }
}
