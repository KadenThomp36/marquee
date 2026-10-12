import SwiftUI

struct ShowScreen: View {
    let showID: Int

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mqTopInset) private var topInset

    private var hasBackdrop: Bool { model.detail?.backdrop?.isEmpty == false }
    @State private var model: ShowModel
    @State private var showingGallery = false
    @State private var showingRequestSheet = false
    @State private var showingRemoveConfirm = false
    @State private var showingEpisodeEditor = false
    @State private var aheadPrompt: AheadPrompt?
    @State private var rating: Int?
    @Namespace private var artNamespace
    /// One decision for the page, shared by every review on it.
    @State private var gate = SpoilerGate()

    init(showID: Int) {
        self.showID = showID
        _model = State(initialValue: ShowModel(showID: showID))
    }

    var body: some View {
        MarqueeScreen {
            if let detail = model.detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero(detail)
                        body(detail)
                        if model.isStale { StaleFooter(cachedAt: model.cachedAt) }
                    }
                    // Pin the column to the viewport. Without this, one over-wide
                    // child (a rail, a chart) widens the whole stack and SwiftUI
                    // centres it — which reads as the entire page drifting left.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 30)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .refreshable { await model.load(session: session, force: false) }
                // Behind the page rather than inside the scrolling column: only out
                // here does ignoring the safe area actually reach the top of the
                // window, instead of being clipped at the scroll view's bounds.
                .background(alignment: .top) {
                    backdrop(detail).ignoresSafeArea(edges: .top)
                }
            } else if let error = model.error {
                LoadFailure(message: error) { await model.load(session: session) }
            } else {
                loadingSkeleton
            }
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarTitleDisplayMode(.inline)
        .environment(gate)
        .onChange(of: model.isComplete) { _, complete in gate.earned = complete }
        .onAppear { gate.earned = model.isComplete }
        .task { await model.load(session: session) }
        .task { await model.loadRatings(session: session) }
        .task { await model.loadProviders(session: session) }
        .task {
            await session.loadRequestConfig()
            await model.loadRequestStatus(session: session)
            await model.pollRequestStatus(session: session)
        }
        .onChange(of: model.detail?.rating) { _, new in rating = new }
        .fullScreenCover(isPresented: $showingGallery) {
            ArtworkGallery(itemType: "show", itemID: showID, title: model.title)
        }
        .sheet(isPresented: $showingRequestSheet) {
            if let status = model.requestStatus {
                SeasonRequestSheet(showID: showID, status: status) {
                    await model.refreshRequestStatus(session: session)
                }
            }
        }
        .sheet(isPresented: $showingEpisodeEditor) {
            CustomEpisodesSheet(showID: showID,
                                defaultSeason: (model.detail?.seasons.last?.season ?? 1)) {
                await model.load(session: session, force: true)
            }
        }
        .confirmationDialog("Remove \(model.title)?",
                            isPresented: $showingRemoveConfirm, titleVisibility: .visible) {
            Button("Remove and delete watch history", role: .destructive) {
                Task {
                    await model.remove(session: session)
                    dismiss()
                }
            }
        } message: {
            Text("This removes the show from your shows and deletes every episode you've marked watched.")
        }
        .confirmationDialog(aheadPrompt?.message ?? "",
                            isPresented: .init(get: { aheadPrompt != nil },
                                               set: { if !$0 { aheadPrompt = nil } }),
                            titleVisibility: .visible) {
            if let prompt = aheadPrompt {
                Button("Mark all \(prompt.behind + 1) up to here") {
                    Task { await mark(prompt.episode, watched: true, scope: .throughHere) }
                    aheadPrompt = nil
                }
                Button("Just this episode") {
                    Task { await mark(prompt.episode, watched: true, scope: .single) }
                    aheadPrompt = nil
                }
                Button("Cancel", role: .cancel) { aheadPrompt = nil }
            }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ detail: ShowDetail) -> some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    Button { showingGallery = true } label: {
                        PosterArt(url: detail.poster, radius: 14)
                            .frame(width: MQ.heroPoster(typeSize))
                            .overlay(alignment: .bottom) {
                                // A nicety, not a necessity — at accessibility text
                                // sizes it would wrap across the artwork it labels.
                                if !typeSize.isAccessibilitySize {
                                    Label("Artwork", systemImage: "photo.on.rectangle")
                                        .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                                        .textCase(.uppercase)
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 5)
                                        .background(.ultraThinMaterial)
                                }
                            }
                            .clipShape(.rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: "art-\(showID)", in: artNamespace)
                    .accessibilityLabel("\(detail.displayTitle) poster. Opens the artwork gallery.")

                    VStack(alignment: .leading, spacing: 7) {
                        if let tagline = detail.info?.tagline, !tagline.isEmpty {
                            Text(tagline)
                                .font(.mqCaption)
                                .italic()
                                .foregroundStyle(Color.mqInkMuted)
                                .lineLimit(2)
                        }
                        ChipRow { chips(detail) }
                        Text(facts(detail))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Beside the poster rather than under it: the column next to a
                        // 2:3 poster is taller than the facts that fill it, and the
                        // stars were sitting in a band of empty space below instead.
                        if detail.followed {
                            StarRating(rating: $rating) { value in
                                Task { await model.rate(value, session: session) }
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                progressBlock(detail)
                actions(detail)
            }
            .padding(.horizontal, MQ.gutter)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func backdrop(_ detail: ShowDetail) -> some View {
        if let backdrop = detail.backdrop {
            FilledArt(url: backdrop, height: 260 + 120)
                .opacity(colorScheme == .light ? 0.15 : 0.28)
                .blur(radius: 3)
                .mask(LinearGradient(colors: [.black, .black, .clear],
                                     startPoint: .top, endPoint: .bottom))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func chips(_ detail: ShowDetail) -> some View {
        if detail.isEnded {
            MetaChip(text: "Ended" + (detail.info?.lastAir.map { " · \($0.prefix(4))" } ?? ""),
                     symbol: "flag.fill")
        }
        if let cert = detail.info?.contentRating, !cert.isEmpty {
            MetaChip(text: cert)
        }
        RatingChip(imdb: detail.info?.imdb, tmdbVote: detail.info?.vote)
        if let networks = detail.info?.networks, !networks.isEmpty {
            MetaChip(text: networks.joined(separator: " · "))
        }
        if let seasons = detail.info?.seasonCount, let episodes = detail.info?.episodeCount {
            MetaChip(text: "\(seasons) season\(seasons == 1 ? "" : "s") · \(episodes) eps")
        }
        if let origin = detail.info?.origin, !origin.isEmpty {
            MetaChip(text: origin)
        }
    }

    private func facts(_ detail: ShowDetail) -> String {
        var parts: [String] = []
        if let status = detail.status, !status.isEmpty { parts.append(status) }
        if !model.yearsSpan.isEmpty { parts.append(model.yearsSpan) }
        if !detail.genreList.isEmpty { parts.append(detail.genreList.joined(separator: ", ")) }
        if let creators = detail.info?.createdBy, !creators.isEmpty {
            parts.append("by \(creators.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    private func progressBlock(_ detail: ShowDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressBar(fraction: model.progress, tint: model.progressTint, height: 9)
            HStack(spacing: 5) {
                Text("\(model.watchedCount)")
                    .foregroundStyle(Color.mqBrass)
                    .monospacedDigit()
                Text("/ \(model.totalWatchable) watched")
                    .foregroundStyle(Color.mqInkSoft)
                if model.remaining > 0 {
                    Text("· \(model.remaining) to go").foregroundStyle(Color.mqInkMuted)
                } else if model.totalWatchable > 0 {
                    Label("complete", systemImage: "checkmark")
                        .foregroundStyle(Color.mqBrass)
                }
            }
            .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
        }
        .frame(maxWidth: 360, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.watchedCount) of \(model.totalWatchable) episodes watched")
    }

    @ViewBuilder
    private func actions(_ detail: ShowDetail) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                watchlistControl(detail)

                if session.requestConfig?.enabled == true, let status = model.requestStatus {
                    RequestButton(status: status) { showingRequestSheet = true }
                }
            }
            .font(.mqSub)

            ChipRow {
                FavoriteChip(itemType: "show", itemID: showID)
                AddToListChip(itemType: "show", itemID: showID, title: model.title)
                ShareLink(item: shareURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.mqChip)

                if session.me?.isAdmin == true {
                    ChipButton(title: "Episodes", symbol: "square.and.pencil") {
                        showingEpisodeEditor = true
                    }
                }
                if let imdbID = detail.info?.imdbID, !imdbID.isEmpty,
                   let url = URL(string: "https://www.imdb.com/title/\(imdbID)/") {
                    Link(destination: url) {
                        Label("IMDb", systemImage: "arrow.up.right.square")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.mqChip)
                }
                if detail.followed {
                    ChipButton(title: "Remove", symbol: "trash", isDestructive: true) {
                        showingRemoveConfirm = true
                    }
                }
            }
        }
    }

    /// One word everywhere: shows go on your watchlist. Not added → "Add to
    /// watchlist"; added but not begun → "On your watchlist" (tap to take it off);
    /// under way → "Watching", with stopping one level down so it's never a single
    /// mis-tap; stopped → "Resume watching".
    @ViewBuilder
    private func watchlistControl(_ detail: ShowDetail) -> some View {
        if !detail.followed {
            Button {
                Task { await model.follow(session: session) }
            } label: {
                Label("Add to watchlist", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mqBrassFill)
            .foregroundStyle(Color.mqBrassOnFill)
        } else if detail.archived {
            Button {
                Task { await model.setArchived(false, session: session) }
            } label: {
                Label("Resume watching", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mqBrassFill)
            .foregroundStyle(Color.mqBrassOnFill)
        } else if model.watchedCount == 0 {
            Button {
                Task { await model.removeFromWatchlist(session: session) }
            } label: {
                Label("On your watchlist", systemImage: "checkmark")
            }
            .buttonStyle(.bordered)
            .tint(Color.mqBrass)
            .accessibilityHint("Removes it from your watchlist")
        } else {
            Menu {
                Button("Stop watching", systemImage: "stop.circle", role: .destructive) {
                    Task { await model.setArchived(true, session: session) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text("Watching")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
            }
            .menuStyle(.button)
            .buttonStyle(.borderedProminent)
            .tint(Color.mqBrassFill)
            .foregroundStyle(Color.mqBrassOnFill)
            .accessibilityHint("Opens a menu to stop watching")
        }
    }

    /// Deep link in the web client's own hash-route shape, so a link shared from the
    /// app opens the same place in a browser.
    private var shareURL: URL {
        session.server.map { $0.baseURL.appendingPathComponent("#/show/\(showID)") }
            ?? URL(string: "https://example.invalid")!
    }

    // MARK: - Body

    @ViewBuilder
    private func body(_ detail: ShowDetail) -> some View {
        if let overview = detail.info?.overview, !overview.isEmpty {
            ExpandableText(text: overview)
                .padding(.horizontal, MQ.gutter)
        }

        if model.watchedCount > 0, model.nextEpisode != nil {
            ContinueWatchingCarousel(model: model) { episode, watched in
                await handleTick(episode, watched: watched)
            }
        }

        WhereToWatch(providers: model.providers,
                     isOnPlex: model.requestStatus?.state == .available)

        if let cast = detail.info?.cast, !cast.isEmpty {
            DetailSection(title: "Cast") { CastStrip(people: cast) }
        }

        if let ratings = model.ratings, ratings.episodes.count >= 4 {
            RatingsPanel(ratings: ratings)
        }

        SeasonAccordion(model: model,
                        seasonStates: model.requestStatus?.seasons ?? [],
                        onTick: handleTick,
                        onSeasonToggle: { season, watched in
                            await model.setSeasonWatched(watched, season: season, session: session)
                        })

        ReviewsSection(itemType: "show", itemID: showID,
                       subject: model.detail?.displayTitle ?? "this show")
    }

    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                SkeletonBlock(height: 177, radius: 14).frame(width: MQ.heroPoster(typeSize))
                VStack(alignment: .leading, spacing: 10) {
                    SkeletonBlock(height: 22, radius: 6)
                    SkeletonBlock(height: 14, radius: 6).frame(width: 160)
                    SkeletonBlock(height: 14, radius: 6).frame(width: 200)
                }
            }
            SkeletonBlock(height: 60)
            SkeletonBlock(height: 60)
        }
        .padding(MQ.gutter)
    }

    // MARK: - Marking

    private struct AheadPrompt: Identifiable {
        let id = UUID()
        let episode: EpisodeRow
        let behind: Int
        var message: String {
            "You're ahead — \(behind) earlier episode\(behind == 1 ? " isn't" : "s aren't") marked yet."
        }
    }

    /// Ticking an episode you haven't earned yet asks rather than assuming: the web
    /// client's "mark all up to here" prompt, kept verbatim because skipping ahead is
    /// almost always a gap you want filled.
    private func handleTick(_ episode: EpisodeRow, watched: Bool) async {
        if watched, episode.season > 0 {
            let behind = model.earlierUnwatched(before: episode)
            if behind > 0 {
                aheadPrompt = AheadPrompt(episode: episode, behind: behind)
                return
            }
        }
        await mark(episode, watched: watched, scope: .single)
    }

    private func mark(_ episode: EpisodeRow, watched: Bool, scope: ShowModel.MarkScope) async {
        await model.setWatched(watched, season: episode.season, number: episode.number,
                               scope: scope, session: session)
    }
}
