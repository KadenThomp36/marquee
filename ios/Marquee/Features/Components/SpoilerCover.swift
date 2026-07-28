import SwiftUI

/// Whether this screen's spoilers have been shown.
///
/// One gate per screen, shared by everything that could give the plot away — the
/// episode summary and every review under it. Revealing is a decision you make once
/// about this episode, not a thing you do twenty times to twenty cards.
@MainActor
@Observable
final class SpoilerGate {
    /// True when there is nothing to hide: you've already watched it. Set by the
    /// screen once its data arrives, since it isn't known at first render.
    var earned = false
    var revealed = false

    init(earned: Bool = false) {
        self.earned = earned
    }

    var hiding: Bool { !earned && !revealed }
}

/// One cover over everything it protects.
///
/// It does not blur. A blur is a tease — it shows the shape of the thing, smears the
/// layout, and still leaves the badge sitting on top of whatever it lands on. This
/// hides the content outright and puts one deliberate control in its place, sized to
/// itself rather than stretched over however tall the reviews happen to be.
struct SpoilerCover<Content: View>: View {
    /// What's behind it, in plain words: "3 reviews", "the summary".
    let what: String
    /// What you'd be spoiling: "S2 · E6", "this film".
    let subject: String
    var compact = false
    @ViewBuilder var content: Content

    @Environment(SpoilerGate.self) private var gate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirming = false

    var body: some View {
        Group {
            if gate.hiding {
                cover
            } else {
                content
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.28), value: gate.hiding)
    }

    private var cover: some View {
        VStack(spacing: compact ? 8 : 12) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: compact ? 15 : 18, weight: .semibold))
                .foregroundStyle(Color.mqBrassOnFill)
                .frame(width: compact ? 34 : 42, height: compact ? 34 : 42)
                .background(Color.mqBrassFill, in: .circle)

            VStack(spacing: 3) {
                Text("Spoilers ahead")
                    .font(MarqueeFont.wordmark(compact ? 17 : 20, relativeTo: .title3))
                    .foregroundStyle(Color.mqInk)
                Text("\(what) for \(subject). You haven't watched it yet.")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Show anyway") { confirming = true }
                .buttonStyle(.mqChip)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, compact ? 18 : 26)
        .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radius))
        .overlay(RoundedRectangle(cornerRadius: MQ.radius)
            .strokeBorder(Color.mqBrassDim.opacity(0.7), lineWidth: 1))
        .confirmationDialog("Show spoilers for \(subject)?",
                            isPresented: $confirming,
                            titleVisibility: .visible) {
            Button("Show spoilers", role: .destructive) {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    gate.revealed = true
                }
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            // Said once, plainly, so the button above can stay short.
            Text("The summary and every review on this page will be shown. "
                 + "This can't be undone until you leave.")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spoilers ahead. \(what) for \(subject).")
    }
}
