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

extension View {
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
