import SwiftUI

struct YouTab: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ProfileScreen(username: nil)
                .marqueeDestinations()
        }
        .routed(into: $path)
    }
}

/// Who you are on this server: the identity strip, the favourites you picked, what
/// you've watched, and the numbers behind it. Someone else's profile is the same
/// screen with the editing taken away.
struct ProfileScreen: View {
    /// nil means "me".
    var username: String?

    @Environment(Session.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.mqTopInset) private var topInset
    @State private var profile: ProfilePayload?
    @State private var stats: Stats?
    @State private var advanced: AdvancedStats?
    @State private var shows: WatchedPage?
    @State private var films: WatchedPage?
    @State private var lists: [ListCard] = []
    @State private var members: [Person] = []
    @State private var editing = false
    @State private var pickingBanner = false
    @State private var pickingFavorite = false
    @State private var confirmingUnpair = false

    private var isMe: Bool {
        guard let username else { return true }
        return username.lowercased() == (session.me?.username ?? "").lowercased()
    }
    private var who: String { isMe ? "me" : (username ?? "me") }
    private var hasBanner: Bool { profile?.banner?.isEmpty == false }

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    if let profile {
                        identity(profile)
                        favorites(profile)
                        recapTeaser(profile)
                        watchedRails
                        listsSection
                        if isMe { hubLinks }
                        household
                        numbers
                        if isMe { signOut }
                    } else {
                        VStack(spacing: 14) {
                            SkeletonBlock(height: 190, radius: 0)
                            SkeletonBlock(height: 90).padding(.horizontal, MQ.gutter)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 30)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .ignoresSafeArea(.container, edges: hasBanner ? .top : [])
            .refreshable { await loadAll() }
        }
        .navigationTitle(isMe ? "You" : (profile?.person.name ?? "Profile"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isMe {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Navigator.Route.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .task { await loadAll() }
        .sheet(isPresented: $editing) {
            EditProfileSheet(profile: profile) { await loadProfile() }
        }
        .sheet(isPresented: $pickingBanner) {
            BannerPickerSheet { await loadProfile() }
        }
        .sheet(isPresented: $pickingFavorite) {
            FavoritePickerSheet { await loadProfile() }
        }
    }

    // MARK: - Identity

    private func identity(_ profile: ProfilePayload) -> some View {
        ZStack(alignment: .top) {
            if let banner = profile.banner, !banner.isEmpty {
                ProfileBanner(url: resolved(banner), height: 300 + topInset)
            }

            VStack(spacing: 10) {
                AvatarView(person: profile.person, size: 96, baseURL: session.server?.baseURL)
                    .overlay(Circle().strokeBorder(Color.mqGround, lineWidth: 3))
                    .padding(.top, hasBanner ? 168 + topInset : 12)

                VStack(spacing: 2) {
                    Text(profile.person.name)
                        .font(MarqueeFont.body(21, .bold, relativeTo: .title2))
                        .foregroundStyle(Color.mqInk)
                    Text(subtitle(profile))
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }

                if let headline = profile.headline { headlineRow(headline) }

                if isMe {
                    HStack(spacing: 8) {
                        Button("Edit profile") { editing = true }
                            .buttonStyle(.mqChip)
                        Button("Change banner") { pickingBanner = true }
                            .buttonStyle(.mqChip)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, MQ.gutter)
        }
    }

    private func subtitle(_ profile: ProfilePayload) -> String {
        var parts = ["@\(profile.username)"]
        if profile.isAdmin == true { parts.append("admin") }
        if let since = profile.memberSince, !since.isEmpty {
            parts.append("since \(MQTime.medium(since))")
        }
        return parts.joined(separator: " · ")
    }

    private func headlineRow(_ headline: Headline) -> some View {
        FlowLayout(spacing: typeSize.isAccessibilitySize ? 24 : 10,
                   lineSpacing: 8, alignment: .center) {
            headlinePill(headline.shows, "shows")
            headlinePill(headline.episodes, "episodes")
            headlinePill(headline.movies, "movies")
            headlinePill(headline.hours, "hours")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private func headlinePill(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value.mqGrouped)
                .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
                .foregroundStyle(Color.mqBrass)
                .monospacedDigit()
            Text(label)
                .font(MarqueeFont.body(10.5, .semibold, relativeTo: .caption2))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(Color.mqInkMuted)
        }
        .frame(minWidth: 70)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Sections

    @ViewBuilder
    private func favorites(_ profile: ProfilePayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Favorites").padding(.horizontal, MQ.gutter)
            if profile.favorites.isEmpty, !isMe {
                Text("No favorites picked yet.")
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkMuted)
                    .padding(.horizontal, MQ.gutter)
            } else {
                HorizontalRail {
                    ForEach(profile.favorites) { favorite in
                        NavigationLink(value: favorite.type == "show"
                                       ? Navigator.Route.show(favorite.id)
                                       : Navigator.Route.movie(favorite.id)) {
                            VStack(alignment: .leading, spacing: 5) {
                                PosterArt(url: favorite.poster)
                                Text(favorite.displayTitle)
                                    .font(.mqTile)
                                    .foregroundStyle(Color.mqInk)
                                    .lineLimit(1)
                                Text(favorite.year?.text ?? "")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                            }
                            .frame(width: 104)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if isMe {
                                Button("Remove favorite", systemImage: "star.slash", role: .destructive) {
                                    Task { await removeFavorite(favorite) }
                                }
                            }
                        }
                    }
                    if isMe {
                        Button { pickingFavorite = true } label: {
                            VStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.mqBrass)
                                Text("Add favorite")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkSoft)
                            }
                            .frame(width: 104, height: 156)
                            .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
                            .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
                                .strokeBorder(Color.mqHairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func recapTeaser(_ profile: ProfilePayload) -> some View {
        if let year = profile.recapYears.first {
            NavigationLink(value: Navigator.Route.recap(year: year,
                                                        username: isMe ? nil : profile.username)) {
                recapCard(kicker: "Year in Review",
                          title: "\(isMe ? "Your" : profile.person.shortName + "'s") \(year), wrapped",
                          detail: "A slideshow of everything watched in \(year)",
                          locked: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("card.recap")
            .padding(.horizontal, MQ.gutter)
        } else if isMe, profile.recapSoon == true {
            recapCard(kicker: "Year in Review",
                      title: "\(profile.recapYear ?? Calendar.current.component(.year, from: Date())) is still being written",
                      detail: "Your wrapped slideshow unlocks in December",
                      locked: true)
                .padding(.horizontal, MQ.gutter)
        }
    }

    private func recapCard(kicker: String, title: String, detail: String, locked: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(kicker).mqEyebrowStyle().foregroundStyle(Color.mqBrass)
                Text(title)
                    .font(MarqueeFont.wordmark(19, relativeTo: .title3))
                    .foregroundStyle(Color.mqInk)
                Text(detail)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
            }
            Spacer(minLength: 6)
            Image(systemName: locked ? "lock.fill" : "chevron.right")
                .foregroundStyle(Color.mqBrass)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: MQ.radius)
                .fill(Color.mqPanel)
                .overlay(alignment: .topTrailing) {
                    RadialGradient(colors: [Color.mqBrass.opacity(0.22), .clear],
                                   center: .topTrailing, startRadius: 0, endRadius: 190)
                }
                .clipShape(.rect(cornerRadius: MQ.radius))
        }
        .overlay(RoundedRectangle(cornerRadius: MQ.radius)
            .strokeBorder(Color.mqBrassDim.opacity(0.6), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var watchedRails: some View {
        if let shows, !shows.items.isEmpty {
            watchedRail(shows, kind: "shows",
                        title: isMe ? "Shows you've watched" : "Shows watched")
        }
        if let films, !films.items.isEmpty {
            watchedRail(films, kind: "movies",
                        title: isMe ? "Films you've watched" : "Films watched")
        }
    }

    private func watchedRail(_ page: WatchedPage, kind: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).mqEyebrowStyle()
                Spacer(minLength: 8)
                NavigationLink {
                    WatchedGridScreen(username: username, kind: kind)
                } label: {
                    HStack(spacing: 3) {
                        Text("\(page.total) · Show all")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
                    }
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqBrass)
                }
            }
            .padding(.horizontal, MQ.gutter)

            HorizontalRail {
                ForEach(page.items, id: \.uniqueID) { item in
                    WatchedTile(item: item, kind: kind).frame(width: MQ.watchedWidth)
                }
            }
        }
    }

    @ViewBuilder
    private var listsSection: some View {
        if !lists.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(isMe ? "My lists" : "Shared lists", count: "\(lists.count)")
                    .padding(.horizontal, MQ.gutter)
                HorizontalRail {
                    ForEach(lists) { list in
                        ListCardView(list: list).frame(width: 172)
                    }
                }
            }
        }
    }

    private var hubLinks: some View {
        VStack(spacing: 0) {
            hubLink("My Lists", "bookmark", destination: .list(0), custom: AnyView(ListsScreen()))
            Divider().overlay(Color.mqHairline).padding(.leading, 46)
            hubLink("History", "clock.arrow.circlepath", destination: .history, custom: nil)
        }
        .mqPanel()
        .padding(.horizontal, MQ.gutter)
    }

    @ViewBuilder
    private func hubLink(_ title: String, _ symbol: String,
                         destination: Navigator.Route, custom: AnyView?) -> some View {
        Group {
            if let custom {
                NavigationLink { custom } label: { hubLabel(title, symbol) }
            } else {
                NavigationLink(value: destination) { hubLabel(title, symbol) }
            }
        }
        .buttonStyle(.plain)
    }

    private func hubLabel(_ title: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color.mqBrass)
                .frame(width: 22)
            Text(title)
                .font(.mqSub)
                .foregroundStyle(Color.mqInk)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.mqInkMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var household: some View {
        if members.count > 1 {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Household", count: "\(members.count)")
                    .padding(.horizontal, MQ.gutter)
                HorizontalRail(spacing: 16) {
                    ForEach(members) { member in
                        NavigationLink(value: Navigator.Route.profile(member.username ?? "")) {
                            VStack(spacing: 6) {
                                AvatarView(person: member, size: 54,
                                           baseURL: session.server?.baseURL)
                                Text(member.name + (member.isMe == true ? " (you)" : ""))
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkSoft)
                                    .lineLimit(1)
                            }
                            .frame(width: 76)
                        }
                        .buttonStyle(.plain)
                        .disabled(member.username == nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var numbers: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(isMe ? "Your numbers" : "\(profile?.person.shortName ?? "Their") numbers")
                .padding(.horizontal, MQ.gutter)
            if let stats {
                StatsSection(stats: stats, advanced: advanced)
            } else {
                StatTileGrid(tiles: [
                    StatTile(value: "—", unit: nil, label: "loading", detail: nil, tint: .mqChartAmber),
                ])
            }
        }
    }

    private var signOut: some View {
        Button(role: .destructive) { confirmingUnpair = true } label: {
            Text("Unpair this device")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.mqQuiet)
        .padding(.horizontal, MQ.gutter)
        .confirmationDialog("Unpair this device?", isPresented: $confirmingUnpair,
                            titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                Task {
                    WidgetBridge.clear()
                    await session.unpair()
                }
            }
        } message: {
            Text("Marquee forgets your server address and signs this device out. Your history stays on the server.")
        }
    }

    private func resolved(_ path: String) -> String {
        path.hasPrefix("http") ? path : (session.server?.baseURL.absoluteString ?? "") + path
    }

    // MARK: - Loading

    private func loadAll() async {
        await loadProfile()
        async let statsTask: Void = loadStats()
        async let watchedTask: Void = loadWatched()
        async let listsTask: Void = loadLists()
        async let membersTask: Void = loadMembers()
        _ = await (statsTask, watchedTask, listsTask, membersTask)
    }

    private func loadProfile() async {
        guard let client = session.client else { return }
        let path = isMe ? "profile" : "profile/\(username ?? "")"
        profile = try? await client.get(path, as: ProfilePayload.self)
    }

    private func loadStats() async {
        guard let client = session.client else { return }
        let base = isMe ? "stats" : "profile/\(username ?? "")/stats"
        stats = try? await client.get(base, as: Stats.self)
        advanced = try? await client.get(isMe ? "stats/advanced" : "\(base)/advanced",
                                         as: AdvancedStats.self)
    }

    private func loadWatched() async {
        guard let client = session.client else { return }
        shows = try? await client.get("watched/\(who)/shows", query: ["limit": "14"],
                                      as: WatchedPage.self)
        films = try? await client.get("watched/\(who)/movies", query: ["limit": "14"],
                                      as: WatchedPage.self)
    }

    private func loadLists() async {
        guard let client = session.client, let name = profile?.username else { return }
        lists = (try? await client.get("user/\(name)/lists", as: UserListsResponse.self))?.lists ?? []
    }

    private func loadMembers() async {
        guard let client = session.client else { return }
        members = (try? await client.get("members", as: MembersResponse.self))?.members ?? []
    }

    private func removeFavorite(_ favorite: Favorite) async {
        guard let client = session.client else { return }
        profile?.favorites.removeAll { $0.uniqueID == favorite.uniqueID }
        _ = try? await client.delete("favorites/\(favorite.type)/\(favorite.id)",
                                     as: FavoritesResponse.self)
    }
}

/// `GET /api/user/{username}/lists`
struct UserListsResponse: Codable, Sendable, Equatable {
    var user: Person
    var isMe: Bool
    var lists: [ListCard]

    enum CodingKeys: String, CodingKey {
        case user, lists
        case isMe = "is_me"
    }
}
