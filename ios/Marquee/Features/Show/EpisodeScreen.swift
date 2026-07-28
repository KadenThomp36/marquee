import SwiftUI

/// One episode. The still runs to the edges, the overview stays behind a curtain
/// until you've watched it, and the only button that matters is the big one.
struct EpisodeScreen: View {
    let showID: Int
    let season: Int
    let number: Int

    @Environment(Session.self) private var session
    @State private var episode: EpisodeDetail?
    @State private var error: String?
    @State private var aheadPrompt = false
    @State private var busy = false
    /// One decision for the whole page: summary and comments reveal together.
    @State private var gate = SpoilerGate()

    var body: some View {
        MarqueeScreen {
            if let episode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 214)
                        details(episode)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 30)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .background(alignment: .top) {
                    still(episode).ignoresSafeArea(edges: .top)
                }
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                VStack(spacing: 14) {
                    SkeletonBlock(height: 210, radius: 0)
                    SkeletonBlock(height: 24).frame(width: 240).padding(.horizontal, MQ.gutter)
                }
            }
        }
        .navigationTitle(episode?.showTitle ?? "Episode")
        .navigationBarTitleDisplayMode(.inline)
        .environment(gate)
        .onChange(of: episode?.watched) { _, watched in gate.earned = watched ?? false }
        .task { await load() }
        .confirmationDialog(aheadMessage, isPresented: $aheadPrompt, titleVisibility: .visible) {
            if let episode, let behind = episode.earlierUnwatched {
                Button("Mark all \(behind + 1) up to here") {
                    Task { await mark(watched: true, previous: true) }
                }
                Button("Just this episode") {
                    Task { await mark(watched: true, previous: false) }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func still(_ episode: EpisodeDetail) -> some View {
        // Still → season poster → show backdrop → show poster: whatever exists, so a
        // show with no episode art still gets a hero rather than a grey box.
        let art = [episode.still, episode.seasonPoster, episode.showBackdrop, episode.showPoster]
            .compactMap { $0 }.first { !$0.isEmpty }
        // Tall enough to cover the bar it now reaches up under as well as the hero.
        FilledArt(url: art, height: 214 + 120)
            .mask(LinearGradient(stops: [.init(color: .black, location: 0.55),
                                         .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func details(_ episode: EpisodeDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(episode.displayTitle)
                    .font(MarqueeFont.body(24, .bold, relativeTo: .title))
                    .foregroundStyle(Color.mqInk)

                HStack(spacing: 6) {
                    Text(episode.code)
                        .foregroundStyle(Color.mqBrass)
                        .fontWeight(.bold)
                    if let runtime = episode.runtime, runtime > 0 {
                        Text("· \(runtime) min")
                    }
                    if let air = episode.airDate, !air.isEmpty {
                        Text("· \(MQTime.medium(air))")
                    }
                }
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)

                HStack(spacing: 8) {
                    RatingChip(imdb: episode.imdb, tmdbVote: episode.extra?.vote ?? episode.rating)
                    if episode.watched, let watchedAt = episode.watchedAt {
                        Text("watched \(MQTime.medium(watchedAt))")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
                .padding(.top, 2)
            }

            if let overview = episode.overview, !overview.isEmpty {
                SpoilerCover(what: "The summary",
                             subject: episode.code,
                             compact: true) {
                    Text(overview)
                        .font(.mqBody)
                        .foregroundStyle(Color.mqInkSoft)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            credits(episode)
            markButton(episode)

            if let guests = episode.extra?.guests, !guests.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Guest stars").mqEyebrowStyle()
                    CastStrip(people: guests)
                        .padding(.horizontal, -MQ.gutter)
                }
            }

            ReviewsSection(itemType: "episode", itemID: episode.reviewKey,
                           subject: episode.code)
                .padding(.horizontal, -MQ.gutter)

            episodeNav(episode)
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, -44)
    }

    @ViewBuilder
    private func credits(_ episode: EpisodeDetail) -> some View {
        let directors = episode.extra?.directors ?? []
        let writers = episode.extra?.writers ?? []
        if !directors.isEmpty || !writers.isEmpty {
            FlowLayout(spacing: 18, lineSpacing: 10) {
                if !directors.isEmpty {
                    creditBlock("Directed by", directors.joined(separator: ", "))
                }
                if !writers.isEmpty {
                    creditBlock("Written by", writers.joined(separator: ", "))
                }
            }
        }
    }

    private func creditBlock(_ label: String, _ names: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).mqEyebrowStyle()
            Text(names)
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
        }
        .accessibilityElement(children: .combine)
    }

    private func markButton(_ episode: EpisodeDetail) -> some View {
        HStack(spacing: 10) {
            Button {
                Task { await tapMark(episode) }
            } label: {
                Label(episode.watched ? "Watched" : "Mark watched", systemImage: "checkmark")
                    .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(episode.watched ? Color.mqBrassFill : Color.clear)
            .foregroundStyle(episode.watched ? Color.mqBrassOnFill : Color.mqBrass)
            .overlay {
                if !episode.watched {
                    Capsule().strokeBorder(Color.mqBrass, lineWidth: 1.5)
                }
            }
            .disabled(busy)
            .sensoryFeedback(.success, trigger: episode.watched)

            ShareLink(item: shareURL) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.mqChip)
            .accessibilityLabel("Share episode")
        }
    }

    private func episodeNav(_ episode: EpisodeDetail) -> some View {
        HStack {
            if let prev = episode.prev {
                NavigationLink(value: Navigator.Route.episode(showID: showID,
                                                              season: prev.season,
                                                              number: prev.number)) {
                    Label("Previous", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(.mqSub)
                }
                .buttonStyle(.mqChip)
            }
            Spacer(minLength: 8)
            if let next = episode.next {
                NavigationLink(value: Navigator.Route.episode(showID: showID,
                                                              season: next.season,
                                                              number: next.number)) {
                    HStack(spacing: 5) {
                        Text("Next episode")
                        Image(systemName: "chevron.right")
                    }
                    .font(.mqSub)
                }
                .buttonStyle(.mqChip)
            }
        }
        .padding(.top, 8)
    }

    private var shareURL: URL {
        session.server.map {
            $0.baseURL.appendingPathComponent("#/show/\(showID)/e/\(season)/\(number)")
        } ?? URL(string: "https://example.invalid")!
    }

    private var aheadMessage: String {
        guard let behind = episode?.earlierUnwatched, behind > 0 else { return "" }
        return "You're ahead — \(behind) earlier episode\(behind == 1 ? " isn't" : "s aren't") marked yet."
    }

    // MARK: - Actions

    private func load() async {
        guard let client = session.client else { return }
        do {
            episode = try await client.get("show/\(showID)/episode/\(season)/\(number)",
                                           as: EpisodeDetail.self)
            error = nil
        } catch let failure as APIError {
            if episode == nil { error = failure.errorDescription }
        } catch {
            if episode == nil { self.error = error.localizedDescription }
        }
    }

    private func tapMark(_ episode: EpisodeDetail) async {
        if !episode.watched, season > 0, (episode.earlierUnwatched ?? 0) > 0 {
            aheadPrompt = true
            return
        }
        await mark(watched: !episode.watched, previous: false)
    }

    private func mark(watched: Bool, previous: Bool) async {
        guard let client = session.client else { return }
        busy = true
        defer { busy = false }
        episode?.watched = watched
        if watched, episode?.watchedAt == nil { episode?.watchedAt = MQTime.stamp() }
        if previous { episode?.earlierUnwatched = 0 }

        let request = MarkEpisodeRequest(season: season, number: number,
                                         unwatch: watched ? nil : true,
                                         previous: previous ? true : nil)
        do {
            let response: MarkResponse = try await client.post("show/\(showID)/watch", body: request)
            if let earned = response.celebrate, !earned.isEmpty { session.enqueue(earned) }
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .markEpisode(showID: showID, season: season, number: number,
                             unwatch: !watched, previous: previous)))
        }
    }
}
