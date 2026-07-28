import SwiftUI

/// A page name that isn't there until you need it.
///
/// A pinned inline title is the worst of both worlds: it repeats a heading the page
/// already shows, and it sits in the bar forever taking up the top of the screen. A
/// large title is no better once collapsed — it pins too, just later.
///
/// So the bar starts empty. Every screen already opens with its own heading in
/// Marquee's own type — the greeting, a poster hero, a section name — and that
/// heading *is* the title while you can see it. Scroll it under the bar and the name
/// fades into the toolbar to take over; scroll back and it goes away again. The bar
/// only ever holds a title when the page can't show you one itself.
///
/// Applied to the scroll view, so the offset it watches is that scroll view's own.
struct MarqueePageTitle: ViewModifier {
    let title: String
    /// How far the page's own heading has to travel before the bar takes over. Roughly
    /// the height of a heading block; a page with a tall hero passes a larger number.
    let handover: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y > handover
            } action: { _, past in
                guard past != showing else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    showing = past
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(MarqueeFont.body(16, .bold, relativeTo: .headline))
                        .foregroundStyle(Color.mqInk)
                        .lineLimit(1)
                        .opacity(showing ? 1 : 0)
                        // VoiceOver reads the heading in the content instead, and
                        // shouldn't be told the name twice.
                        .accessibilityHidden(!showing)
                }
            }
    }
}

extension View {
    /// The page's name, shown in the bar only once the page's own heading has gone.
    ///
    /// `handover` is where the page stops being able to name itself: past a short
    /// heading that's about 60pt, past a poster hero rather more.
    func mqPageTitle(_ title: String, handover: CGFloat = 60) -> some View {
        modifier(MarqueePageTitle(title: title, handover: handover))
    }
}

/// The page naming itself, in Marquee's own type rather than the system's.
///
/// Pairs with `mqPageTitle`: this is what the bar stays empty for. A page that has a
/// hero or a greeting already has one of these in spirit and doesn't need it twice.
struct PageHeading: View {
    let title: String
    var subtitle: String?

    var body: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MQ.gutter)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
