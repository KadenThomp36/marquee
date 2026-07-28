import SwiftUI

/// A film. The same hero as a show, minus everything about episodes.
struct MovieScreen: View {
    let movieID: Int

    @Environment(Session.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mqTopInset) private var topInset

    private var hasBackdrop: Bool { movie?.info?.backdrop?.isEmpty == false }
    @State private var movie: MovieDetail?
    @State private var providers: WatchProviders?
    @State private var requestStatus: RequestStatus?
    @State private var error: String?
    @State private var showingGallery = false
    @State private var showingRequestSheet = false
    @State private var rating: Int?

    var body: some View {
        MarqueeScreen {
            if let movie {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        hero(movie)
                        body(movie)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 30)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                // See ShowScreen: the wash belongs behind the page, not inside the
                // scrolling column, or the safe area can't be reached.
                .background(alignment: .top) {
                    heroBackdrop(movie).ignoresSafeArea(edges: .top)
                }
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                SkeletonBlock(height: 240).padding(MQ.gutter)
            }
        }
        .navigationTitle(movie?.displayTitle ?? "Film")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .task { await loadExtras() }
        .fullScreenCover(isPresented: $showingGallery) {
            ArtworkGallery(itemType: "movie", itemID: movieID, title: movie?.displayTitle ?? "")
        }
        .sheet(isPresented: $showingRequestSheet) {
            if let status = requestStatus {
                MovieRequestSheet(movieID: movieID, status: status) { await refreshRequest() }
            }
        }
    }

    @ViewBuilder
    private func heroBackdrop(_ movie: MovieDetail) -> some View {
        if let backdrop = movie.info?.backdrop {
            FilledArt(url: backdrop, height: 250 + 120)
                .opacity(colorScheme == .light ? 0.15 : 0.28)
                .blur(radius: 3)
                .mask(LinearGradient(colors: [.black, .black, .clear],
                                     startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func hero(_ movie: MovieDetail) -> some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    Button { showingGallery = true } label: {
                        PosterArt(url: movie.poster, radius: 14)
                            .frame(width: MQ.heroPoster(typeSize))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(movie.displayTitle) poster. Opens the artwork gallery.")

                    VStack(alignment: .leading, spacing: 7) {
                        if let tagline = movie.info?.tagline, !tagline.isEmpty {
                            Text(tagline)
                                .font(.mqCaption).italic()
                                .foregroundStyle(Color.mqInkMuted)
                                .lineLimit(2)
                        }
                        ChipRow {
                            if let cert = movie.info?.contentRating, !cert.isEmpty {
                                MetaChip(text: cert)
                            }
                            RatingChip(imdb: movie.info?.imdb, tmdbVote: movie.info?.vote)
                            if let runtime = movie.info?.runtime ?? movie.runtime, runtime > 0 {
                                MetaChip(text: "\(runtime / 60)h \(runtime % 60)m")
                            }
                            if let genres = movie.info?.genres, !genres.isEmpty {
                                MetaChip(text: genres.prefix(2).joined(separator: " · "))
                            }
                        }
                        Text(facts(movie))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if movie.isWatched {
                    StarRating(rating: $rating) { value in
                        Task { await rate(value) }
                    }
                }

                HStack(spacing: 8) {
                    Button {
                        Task { await toggleWatched(movie) }
                    } label: {
                        Label(movie.isWatched ? "Watched" : "Mark watched", systemImage: "checkmark")
                            .font(.mqSub)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(movie.isWatched ? Color.mqPanelRaised : Color.mqBrassFill)
                    .foregroundStyle(movie.isWatched ? Color.mqInkSoft : Color.mqBrassOnFill)

                    if movie.state == nil {
                        Button {
                            Task { await setState("watchlist") }
                        } label: {
                            Label("Watchlist", systemImage: "bookmark")
                                .font(.mqSub)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.mqBrass)
                    }

                    if session.requestConfig?.enabled == true, let status = requestStatus {
                        RequestButton(status: status) { showingRequestSheet = true }
                    }
                }

                ChipRow {
                    FavoriteChip(itemType: "movie", itemID: movieID)
                    AddToListChip(itemType: "movie", itemID: movieID, title: movie.displayTitle)
                    ShareLink(item: shareURL) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.mqChip)
                    if let imdbID = movie.info?.imdbID, !imdbID.isEmpty,
                       let url = URL(string: "https://www.imdb.com/title/\(imdbID)/") {
                        Link(destination: url) {
                            Label("IMDb", systemImage: "arrow.up.right.square")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.mqChip)
                    }
                    if movie.state != nil {
                        ChipButton(title: "Remove", symbol: "trash", isDestructive: true) {
                            Task { await setState("none") }
                        }
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func body(_ movie: MovieDetail) -> some View {
        if let overview = movie.info?.overview, !overview.isEmpty {
            ExpandableText(text: overview).padding(.horizontal, MQ.gutter)
        }

        WhereToWatch(providers: providers, isOnPlex: requestStatus?.state == .available)

        if let cast = movie.info?.cast, !cast.isEmpty {
            DetailSection(title: "Cast") { CastStrip(people: cast) }
        }

        ReviewsSection(itemType: "movie", itemID: movieID, hasEarnedSpoilers: movie.isWatched)
    }

    private func facts(_ movie: MovieDetail) -> String {
        var parts: [String] = []
        if let year = movie.year?.value { parts.append(String(year)) }
        if let directors = movie.info?.directors, !directors.isEmpty {
            parts.append("dir. \(directors.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }

    private var shareURL: URL {
        session.server.map { $0.baseURL.appendingPathComponent("#/movie/\(movieID)") }
            ?? URL(string: "https://example.invalid")!
    }

    // MARK: - Actions

    private func load() async {
        guard let client = session.client else { return }
        do {
            let fresh: MovieDetail = try await client.get("movie/\(movieID)")
            movie = fresh
            rating = fresh.myRating
            error = nil
        } catch let failure as APIError {
            if movie == nil { error = failure.errorDescription }
        } catch {
            if movie == nil { self.error = error.localizedDescription }
        }
    }

    private func loadExtras() async {
        guard let client = session.client else { return }
        providers = try? await client.get("watch_providers/movie/\(movieID)", as: WatchProviders.self)
        await session.loadRequestConfig()
        await refreshRequest()
    }

    private func refreshRequest() async {
        guard session.requestConfig?.enabled == true, let client = session.client else { return }
        requestStatus = try? await client.get("request/status/movie/\(movieID)", as: RequestStatus.self)
        guard let status = requestStatus, let movie else { return }
        if status.download != nil {
            LiveDownloads.shared.follow(itemType: "movie", itemID: movieID,
                                        title: movie.displayTitle,
                                        subtitle: movie.year?.text,
                                        poster: movie.poster, status: status, session: session)
        } else if status.state == .available {
            LiveDownloads.shared.finish(itemType: "movie", itemID: movieID)
        }
    }

    private func toggleWatched(_ movie: MovieDetail) async {
        await setState(movie.isWatched ? "none" : "watched")
    }

    private func setState(_ state: String) async {
        guard let client = session.client else { return }
        movie?.state = state == "none" ? nil : state
        do {
            try await client.post("movie/\(movieID)/state",
                                  body: MovieStateRequest(state: state), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .movieState(movieID: movieID, state: state, rating: nil)))
        }
    }

    private func rate(_ value: Int?) async {
        guard let client = session.client, let value else { return }
        movie?.myRating = value
        do {
            try await client.post("movie/\(movieID)/state",
                                  body: MovieStateRequest(state: "watched", rating: value),
                                  as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .movieState(movieID: movieID, state: "watched", rating: value)))
        }
    }
}

/// A film has no seasons, so requesting it is one button and a confirmation.
struct MovieRequestSheet: View {
    let movieID: Int
    let status: RequestStatus
    let onDone: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var sent = false

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(spacing: 18) {
                    Image(systemName: sent ? "checkmark.circle.fill" : "arrow.down.circle")
                        .font(.system(size: 46))
                        .foregroundStyle(Color.mqOverseerr)

                    Text(sent ? "Requested" : status.state.label)
                        .font(MarqueeFont.body(19, .bold, relativeTo: .title3))
                        .foregroundStyle(Color.mqInk)

                    if let download = status.download {
                        DownloadPill(progress: download)
                    }

                    if status.state == .none, !sent {
                        Button {
                            Task { await request() }
                        } label: {
                            Text(busy ? "Requesting…" : "Request this film")
                        }
                        .buttonStyle(.mqPrimary)
                        .disabled(busy)
                    }
                    Spacer()
                }
                .padding(MQ.gutter)
                .padding(.top, 24)
            }
            .navigationTitle("Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.height(340)])
        .presentationBackground(Color.mqGround)
    }

    private func request() async {
        guard let client = session.client else { return }
        busy = true
        defer { busy = false }
        _ = try? await client.post("request",
                                   body: MakeRequest(itemType: "movie", itemID: movieID),
                                   as: RequestResult.self)
        sent = true
        await onDone()
        try? await Task.sleep(for: .seconds(2))
        await onDone()
    }
}
