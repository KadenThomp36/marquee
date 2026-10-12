import SwiftUI

/// The page naming itself, as content rather than chrome.
///
/// The navigation bar holds no title on these screens — not a pinned one, and not a
/// large one that collapses into a pinned one either. The heading is simply the first
/// thing in the scroll view, so it scrolls away like everything else and animates back
/// when you return to the top. What's left behind is the soft scroll edge, with the
/// content passing under the status bar.
///
/// Whatever the page's one action is rides along on the right, level with the title,
/// because with no bar there is nowhere else for it to go.
struct PageHeading<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    init(title: String,
         subtitle: String? = nil,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.mqTitle)
                    .foregroundStyle(Color.mqInk)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)
            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MQ.gutter)
        .padding(.bottom, 4)
    }
}

/// A soft gradient blur across the top, once content has gone under it.
///
/// Hiding the navigation bar takes the system's scroll edge effect with it — there's
/// no bar left to host one — so the page grows its own. It fades in when content
/// passes beneath, and it's a gradient rather than a hard band so there's no edge
/// where the blur stops.
private struct TopEdgeBlur: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var under = false

    func body(content: Content) -> some View {
        content
            // A Bool, not the offset: publishing the offset itself would re-run the
            // body on every frame of every scroll.
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > 6
            } action: { _, new in
                guard new != under else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) { under = new }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(reduceTransparency ? AnyShapeStyle(Color.mqGround)
                                             : AnyShapeStyle(.ultraThinMaterial))
                    .mask {
                        LinearGradient(stops: [.init(color: .black, location: 0),
                                               .init(color: .black, location: 0.5),
                                               .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    .frame(height: 104)
                    .ignoresSafeArea(edges: .top)
                    .opacity(under ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

/// Fades and settles back as it passes under the top of the screen.
///
/// Driven by `visualEffect`, which is handed the geometry during layout — so the
/// heading animates continuously with the scroll without any state changing, and
/// therefore without re-running the page's body sixty times a second.
private struct HeadingScrollEffect: ViewModifier {
    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
            let gone = min(max(-y / 64, 0), 1)
            return view
                .opacity(1 - gone)
                .scaleEffect(1 - gone * 0.08, anchor: .bottomLeading)
                .offset(y: gone * 14)
        }
    }
}

extension View {
    /// The page's own soft top edge, for screens with no navigation bar to provide one.
    func mqTopEdgeBlur() -> some View {
        modifier(TopEdgeBlur())
    }

    /// Makes a heading fade away as it scrolls off, and come back as you return.
    func mqHeadingEffect() -> some View {
        modifier(HeadingScrollEffect())
    }

    /// No navigation bar at all.
    ///
    /// For a tab's own screen, where there's nothing to go back to: the bar would be
    /// empty, and an empty bar still reserves a strip of the screen and puts a hard
    /// edge under the status bar. Without it the content runs all the way up and the
    /// scroll edge effect does the rest.
    func mqBareNavigationBar() -> some View {
        toolbar(.hidden, for: .navigationBar)
    }

    /// A bar kept only for the back button, with nothing written in it.
    ///
    /// Pushed screens still need the way back, but they don't need to be named twice —
    /// the heading in the content says where you are.
    func mqUntitledNavigationBar() -> some View {
        navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
    }
}
