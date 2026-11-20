import SwiftUI

/// Year in Review — the full-screen, story-style show.
///
/// Same slides and the same order as the web client, driven the way a phone expects:
/// tap the right side to go on, the left to go back, swipe either way, pull down to
/// leave, and a row of segments along the top says how far through you are. The
/// guessing game holds its slide until it's answered.
///
/// On the Duo opened out it reads like a programme: two slides a spread, one either
/// side of the crease, and a tap turns the page.
struct RecapScreen: View {
    let year: Int
    /// nil means "me".
    var username: String?
    /// Set when it was presented by itself (the once-a-year pop-up) rather than pushed.
    var presentedModally = false

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var recap: Recap?
    @State private var failure: String?
    @State private var index = 0
    @State private var quizAnswer: Int?
    @State private var sharing = false

    private var slides: [RecapSlide] { recap.map(RecapSlide.build) ?? [] }

    var body: some View {
        GeometryReader { proxy in
            let spread = SpreadPages(width: proxy.size.width, fold: proxy.foldLine)
            ZStack {
                RecapGel.ground.ignoresSafeArea()
                if let recap, !slides.isEmpty {
                    show(recap, spread: spread)
                } else if let failure {
                    LoadFailure(message: failure) { await load() }
                } else {
                    ProgressView().tint(Color.mqBrass)
                }
            }
            .overlay(alignment: .top) {
                if !slides.isEmpty { segments(step: spread == nil ? 1 : 2) }
            }
        }
        .environment(\.colorScheme, .dark)
        .navigationBarBackButtonHidden(true)
        // A story wants the whole screen; the tab bar was covering the last line.
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .statusBarHidden(!slides.isEmpty)
        .task { await load() }
        .sheet(isPresented: $sharing) {
            if let recap { ShareSheet(items: [shareText(recap)]) }
        }
    }

    // MARK: - The show

    @ViewBuilder
    private func show(_ recap: Recap, spread: SpreadPages?) -> some View {
        Group {
            if let spread {
                // two facing pages; the crease falls in the gutter between them
                let left = index - index % 2
                HStack(spacing: 0) {
                    page(recap, at: left).frame(width: spread.leading)
                    RecapGel.ground.frame(width: spread.gap)
                    Group {
                        if left + 1 < slides.count { page(recap, at: left + 1) } else { RecapStage(gel: RecapGel.amber) }
                    }
                    .frame(width: spread.trailing)
                }
                .ignoresSafeArea()
            } else {
                page(recap, at: index).ignoresSafeArea()
            }
        }
        .contentShape(.rect)
        .overlay { tapZones(step: spread == nil ? 1 : 2) }
        .gesture(
            DragGesture(minimumDistance: 24)
                .onEnded { drag in
                    let step = spread == nil ? 1 : 2
                    if drag.translation.height > 110, abs(drag.translation.width) < 60 { close() }
                    else if drag.translation.width < -40 { advance(step) }
                    else if drag.translation.width > 40 { advance(-step) }
                }
        )
    }

    private func page(_ recap: Recap, at slot: Int) -> some View {
        let slide = slides[min(slot, slides.count - 1)]
        return RecapCanvas {
            RecapSlideView(slide: slide, recap: recap, isMe: isMe, name: displayName,
                           quizAnswer: $quizAnswer,
                           onShare: { sharing = true },
                           onReplay: { withAnimation(reduceMotion ? nil : .snappy) { index = 0 } })
        }
        .background(RecapStage(gel: slide.gel))
        .clipped()
        .id(slot)
        .transition(reduceMotion ? .opacity
                    : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
    }

    private func segments(step: Int) -> some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(slides.indices, id: \.self) { slot in
                    Capsule()
                        .fill(slot <= index + (step - 1) ? RecapGel.ink : RecapGel.ink.opacity(0.22))
                        .frame(height: 3)
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Slide \(index + 1) of \(slides.count)")
            Button { close() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RecapGel.ink)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.25), in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 8)
    }

    /// Left third goes back, the rest goes on — the grammar every story uses. Buttons
    /// inside a slide (the quiz, share) sit above these and keep their taps.
    private func tapZones(step: Int) -> some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { advance(-step) }
                    .frame(width: proxy.size.width * 0.3)
                    .accessibilityLabel("Previous")
                    .accessibilityAddTraits(.isButton)
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture { advance(step) }
                    .accessibilityLabel("Next")
                    .accessibilityAddTraits(.isButton)
            }
        }
        // the slide's own buttons (the quiz's answers, share) keep their taps
        .allowsHitTesting(!onQuiz(step: step) && !onOutro(step: step))
        .padding(.top, 60)
    }

    // MARK: - Behaviour

    private var isMe: Bool {
        guard let username else { return true }
        return username.lowercased() == (session.me?.username ?? "").lowercased()
    }

    private var displayName: String {
        isMe ? (session.me?.name ?? "") : (username ?? "")
    }

    private func visible(step: Int) -> [RecapSlide] {
        let start = step == 2 ? index - index % 2 : index
        return Array(slides[start..<min(slides.count, start + step)])
    }

    /// The unanswered quiz is on screen — its own buttons take the taps.
    private func onQuiz(step: Int) -> Bool { quizAnswer == nil && visible(step: step).contains(.quiz) }
    private func onOutro(step: Int) -> Bool { visible(step: step).contains(.outro) }

    private func advance(_ step: Int) {
        if step > 0, onQuiz(step: step) { return }
        let next = (step == 2 || step == -2) ? (index - index % 2) + step : index + step
        guard next >= 0 else { return }
        guard next < slides.count else { close(); return }
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { index = next }
    }

    private func close() { dismiss() }

    private func shareText(_ recap: Recap) -> String {
        var bits: [String] = []
        if (recap.episodes ?? 0) + (recap.movies ?? 0) > 0 {
            bits.append("\(RecapText.hours(recap.minutes)) hours watched, \(RecapText.plural(recap.episodes ?? 0, "episode")), "
                        + RecapText.plural(recap.movies ?? 0, "film"))
        }
        if let books = recap.reading?.books, books > 0 { bits.append("\(RecapText.plural(books, "book")) read") }
        let persona = recap.persona.map { " (\($0.title))" } ?? ""
        let top = recap.topShows?.first.map { " Show of the year: \($0.title)." } ?? ""
        // Text only, and no link: a recap URL would name the server, and this is the
        // one screen most likely to be shared outside the household.
        return "\(isMe ? "My" : "Their") \(recap.year) on Marquee\(persona): \(bits.joined(separator: ", ")).\(top)"
    }

    private func load() async {
        guard let client = session.client else { return }
        let path = isMe ? "recap/\(year)" : "profile/\(username ?? "")/recap/\(year)"
        do {
            let fresh: Recap = try await client.get(path)
            recap = fresh
            failure = fresh.locked == true
                ? "\(year)'s Year in Review premieres \(fresh.release.map { "on " + MQTime.medium($0) } ?? "at the end of the year")."
                : fresh.hasData == false ? "There's nothing to look back on for \(year) yet." : nil
            if fresh.locked == true { recap = nil }
            // Seeing it counts as seen, so it doesn't pop up again on any device.
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

/// The system share sheet, for plain text.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
