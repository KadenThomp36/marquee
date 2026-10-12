import SwiftUI

/// Year in Review — the full-screen, story-style slideshow.
///
/// Same slides and the same order as the web client, driven the way a phone expects:
/// tap the right half to go on, the left half to go back, swipe either way, and a row
/// of progress segments along the top says how far through you are. It is deliberately
/// not a `TabView(.page)` — the tap targets and the segment bar are the whole point.
struct RecapScreen: View {
    let year: Int
    /// nil means "me".
    var username: String?

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recap: Recap?
    @State private var failure: String?
    @State private var index = 0

    private var slides: [RecapSlide] { recap.map(RecapSlide.build) ?? [] }

    var body: some View {
        Group {
            if let recap, !slides.isEmpty {
                content(recap)
            } else if let failure {
                LoadFailure(message: failure) { await load() }
            } else {
                ProgressView().tint(Color.mqBrass)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Foreground respects the safe area so the segment bar clears the status bar;
        // the ground and its wash of poster art bleed behind it.
        .background {
            ZStack {
                Color.mqGround
                backdrop
            }
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        // A story wants the whole screen. The tab bar in particular was covering the
        // last line of every slide.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !slides.isEmpty { segments }
        }
        .task { await load() }
    }

    // MARK: - Chrome

    /// A wash of the year's favourite poster, far enough back to read over.
    private var backdrop: some View {
        Group {
            if let poster = recap?.topShows?.first?.poster {
                FilledArt(url: poster, height: 900)
                    .blur(radius: 60)
                    .opacity(0.35)
                    .accessibilityHidden(true)
            }
        }
    }

    private func content(_ recap: Recap) -> some View {
        ZStack {
            slides[min(index, slides.count - 1)].view(recap: recap, isMe: isMe)
                .id(index)
                .transition(reduceMotion ? .opacity
                            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                          removal: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .overlay { tapZones }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { drag in
                    if drag.translation.width < -40 { advance(1) }
                    else if drag.translation.width > 40 { advance(-1) }
                }
        )
    }

    private var segments: some View {
        HStack(spacing: 12) {
            segmentBar
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.mqInkSoft)
                    .frame(width: 30, height: 30)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.vertical, 8)
    }

    private var segmentBar: some View {
        HStack(spacing: 4) {
            ForEach(slides.indices, id: \.self) { slot in
                Capsule()
                    .fill(slot <= index ? Color.mqBrass : Color.mqInkMuted.opacity(0.3))
                    .frame(height: 3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Slide \(index + 1) of \(slides.count)")
    }

    /// Left third goes back, the rest goes on — the grammar every story UI uses.
    private var tapZones: some View {
        HStack(spacing: 0) {
            Color.clear
                .contentShape(.rect)
                .onTapGesture { advance(-1) }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Previous")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Goes back one slide")
            Color.clear
                .contentShape(.rect)
                .onTapGesture { advance(1) }
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Next")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Goes on one slide")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Behaviour

    private var isMe: Bool {
        guard let username else { return true }
        return username.lowercased() == (session.me?.username ?? "").lowercased()
    }

    private func advance(_ step: Int) {
        let next = index + step
        guard next >= 0 else { return }
        guard next < slides.count else {
            dismiss()
            return
        }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { index = next }
    }

    private func load() async {
        guard let client = session.client else { return }
        let path = isMe ? "recap/\(year)"
                        : "profile/\(username ?? "")/recap/\(year)"
        do {
            let fresh: Recap = try await client.get(path)
            recap = fresh
            failure = fresh.hasData == false
                ? "There's nothing to look back on for \(year) yet."
                : nil
            // Seeing it counts as seen, so it stops being offered on next launch.
            if isMe, fresh.hasData == true {
                _ = try? await client.post("recap/\(year)/seen", as: Empty.self)
            }
        } catch let error as APIError {
            failure = error.errorDescription
        } catch {
            failure = error.localizedDescription
        }
    }
}
