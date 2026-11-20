import SwiftUI

// MARK: - The tab rail

/// How wide the column down the trailing edge is when the tab bar is a rail, or 0.
///
/// On the iPhone Duo, on both displays, the system puts the tab bar in a vertical rail
/// down the trailing edge, and the outer display stacks the status bar in the same
/// column. SwiftUI reports that column as a trailing safe-area inset (84 pt on the outer
/// display, 84–88 pt opened out) on every screen inside the tab view. A phone in
/// portrait has none, and its bottom tab bar is a bottom inset. So "the tab bar is a
/// rail" is exactly "there's a real trailing inset". It doesn't depend on the size
/// class, which stays compact on the narrow outer display even though the rail is there.
///
/// Art and scrolling rows use this to run under the rail to the screen edge instead
/// of stopping at the column. Profile uses it to move Settings into the rail.
enum TabRail {
    /// A home indicator or rounded corner can leave a few points of side inset. A
    /// rail is never that thin.
    static let threshold: CGFloat = 44

    static func width(trailingInset: CGFloat) -> CGFloat {
        trailingInset >= threshold ? trailingInset : 0
    }
}

private struct TabRailKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// The tab rail's width on this screen, or 0 when the tab bar is along the bottom.
    /// Published by `MarqueeScreen`.
    var mqRailWidth: CGFloat {
        get { self[TabRailKey.self] }
        set { self[TabRailKey.self] = newValue }
    }
}

extension View {
    /// Reads the tab rail's width into `width`, for screens that need it above their
    /// own `MarqueeScreen`. A toolbar, for instance, hangs off the screen itself, and
    /// the environment value is only set inside it.
    func readsTabRail(into width: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { proxy in
            TabRail.width(trailingInset: proxy.safeAreaInsets.trailing)
        } action: { new in
            if width.wrappedValue != new { width.wrappedValue = new }
        }
    }

    /// Draws this view out under the tab rail, to the screen's trailing edge, while
    /// the layout still treats it as ending at the content column. Use it for art,
    /// which should never stop in a hard line at the rail.
    func underTabRail(_ width: CGFloat) -> some View {
        padding(.trailing, -width)
    }
}
