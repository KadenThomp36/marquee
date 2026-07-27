import SwiftUI

/// A swipeable strip of episodes around where you currently are — a dozen behind,
/// a dozen ahead, parked on the next one. It's the fastest way to mark the episode
/// you just finished without hunting for it in the accordion.
struct ContinueWatchingCarousel: View {
    let model: ShowModel
    let onTick: (EpisodeRow, Bool) async -> Void

    @State private var scrolled: String?

    private var window: [EpisodeRow] {
        guard let next = model.nextEpisode,
              let index = model.watchable.firstIndex(where: { $0.id == next.id })
        else { return [] }
        let lower = max(0, index - 12)
        let upper = min(model.watchable.count, index + 13)
        return Array(model.watchable[lower..<upper])
    }

    var body: some View {
        if !window.isEmpty {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(window) { episode in
                        EpisodeSlide(episode: episode,
                                     showID: model.showID,
                                     stillFallback: fallbackImage(for: episode),
                                     isNext: episode.id == model.nextEpisode?.id,
                                     onTick: { await onTick(episode, !episode.watched) })
                            .containerRelativeFrame(.horizontal)
                            .id(episode.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $scrolled, anchor: .center)
            .onAppear { scrolled = model.nextEpisode?.id }
            .onChange(of: model.nextEpisode?.id) { _, next in
                withAnimation(.snappy) { scrolled = next }
            }
        }
    }

    /// Episode still → season poster → show backdrop → show poster. The web client's
    /// fallback chain, kept so a show with no stills still looks composed.
    private func fallbackImage(for episode: EpisodeRow) -> String? {
        if let still = episode.still, !still.isEmpty { return still }
        if let poster = model.detail?.info?.seasonPosters?[String(episode.season)] { return poster }
        if let backdrop = model.detail?.backdrop, !backdrop.isEmpty { return backdrop }
        return model.detail?.poster
    }
}

private struct EpisodeSlide: View {
    let episode: EpisodeRow
    let showID: Int
    let stillFallback: String?
    let isNext: Bool
    let onTick: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                FilledArt(url: stillFallback, height: 168)
                    .saturation(episode.watched ? 0.85 : 1)
                    .brightness(episode.watched ? -0.06 : 0)

                LinearGradient(stops: [.init(color: .clear, location: 0.3),
                                       .init(color: Color.mqPanel, location: 1)],
                               startPoint: .top, endPoint: .bottom)

                HStack(spacing: 7) {
                    Circle()
                        .fill(Color.mqBrassFill)
                        .frame(width: 7, height: 7)
                        .shadow(color: Color.mqBrass, radius: 4)
                        .opacity(isNext && !reduceMotion ? 1 : 0.8)
                        .symbolEffectPulse(active: isNext && !reduceMotion)
                    Text(badge)
                        .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(Color.mqBrassBright)
                }
                .padding(14)
            }
            .frame(height: 168)
            .clipped()

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(episode.code + (episode.airDate.map { " · \(MQTime.medium($0))" } ?? ""))
                        .font(MarqueeFont.body(12, .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.mqBrassBright)
                    NavigationLink(value: Navigator.Route.episode(showID: showID,
                                                                  season: episode.season,
                                                                  number: episode.number)) {
                        Text(episode.displayTitle)
                            .font(MarqueeFont.body(18, .bold, relativeTo: .title3))
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 9) {
                    Button {
                        busy = true
                        Task { await onTick(); busy = false }
                    } label: {
                        Label(episode.watched ? "Watched" : "Mark watched", systemImage: "checkmark")
                            .font(.mqSub)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(episode.watched ? Color.mqPanelRaised : Color.mqBrassFill)
                    .foregroundStyle(episode.watched ? Color.mqInkSoft : Color.mqBrassOnFill)
                    .disabled(busy)

                    NavigationLink(value: Navigator.Route.episode(showID: showID,
                                                                  season: episode.season,
                                                                  number: episode.number)) {
                        Text("Details").font(.mqSub)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.mqBrass)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 15)
            .padding(.top, -6)
        }
        .background(Color.mqPanel)
        .clipShape(.rect(cornerRadius: MQ.radius))
        .overlay(RoundedRectangle(cornerRadius: MQ.radius)
            .strokeBorder(isNext ? Color.mqBrassDim : Color.mqHairline, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        .padding(.horizontal, MQ.gutter)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(badge). \(episode.code). \(episode.displayTitle)")
    }

    private var badge: String {
        if episode.watched { return "Watched" }
        return isNext ? "Continue watching" : "Up next"
    }
}

private extension View {
    /// The blinking "you are here" dot, off under Reduce Motion.
    @ViewBuilder
    func symbolEffectPulse(active: Bool) -> some View {
        if active {
            self.phaseAnimator([1.0, 0.35]) { view, opacity in
                view.opacity(opacity)
            } animation: { _ in .easeInOut(duration: 0.8) }
        } else {
            self
        }
    }
}
