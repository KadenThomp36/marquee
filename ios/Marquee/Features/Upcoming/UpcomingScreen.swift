import SwiftUI

/// What's coming, grouped by the day it lands. Episodes from the shows you follow,
/// plus films on your watchlist that haven't opened yet.
struct UpcomingScreen: View {
    @Environment(Session.self) private var session
    @State private var data = RemoteData<UpcomingResponse>(cacheKey: "upcoming")

    private struct Day: Identifiable {
        let date: String
        var episodes: [UpcomingEpisode] = []
        var movies: [UpcomingMovie] = []
        var id: String { date }
    }

    private var days: [Day] {
        guard let value = data.value else { return [] }
        var byDate: [String: Day] = [:]
        for episode in value.episodes {
            byDate[episode.airDate, default: Day(date: episode.airDate)].episodes.append(episode)
        }
        for movie in value.movies {
            byDate[movie.releaseDate, default: Day(date: movie.releaseDate)].movies.append(movie)
        }
        return byDate.values.sorted { $0.date < $1.date }
    }

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 26) {
                    PageHeading(title: "Upcoming",
                                subtitle: "The next 90 days")
                        .mqHeadingEffect()
                    if days.isEmpty, data.value != nil {
                        EmptyLine("Nothing scheduled in the next 90 days.")
                    }
                    ForEach(days) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(MQTime.upcomingLabel(day.date))
                                    .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
                                    .foregroundStyle(Color.mqInk)
                                Text(MQTime.medium(day.date))
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                            }
                            .padding(.horizontal, MQ.gutter)
                            .accessibilityAddTraits(.isHeader)

                            VStack(spacing: 8) {
                                ForEach(day.episodes) { episode in
                                    UpcomingRow(poster: episode.poster,
                                                title: episode.showTitle ?? "",
                                                subtitle: "\(episode.code) · \(episode.title ?? "TBA")",
                                                tag: "EPISODE",
                                                route: .episode(showID: episode.showID,
                                                                season: episode.season,
                                                                number: episode.number))
                                }
                                ForEach(day.movies) { movie in
                                    UpcomingRow(poster: movie.poster,
                                                title: movie.title ?? "",
                                                subtitle: "release day",
                                                tag: "FILM",
                                                route: .movie(movie.id))
                                }
                            }
                            .padding(.horizontal, MQ.gutter)
                        }
                    }
                    if data.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(0..<5, id: \.self) { _ in SkeletonBlock(height: 68) }
                        }
                        .padding(.horizontal, MQ.gutter)
                    }
                    if data.isStale { StaleFooter(cachedAt: data.cachedAt) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .mqTopEdgeBlur()
            .refreshable { await load(force: true) }
            .mqBareNavigationBar()
        }
        .task { await load() }
    }

    private func load(force: Bool = false) async {
        guard let client = session.client else { return }
        await data.load(force: force) {
            try await client.get("upcoming", as: UpcomingResponse.self)
        }
        // Hand the air dates to the system while we have them. These fire on the day
        // whether or not the app is ever opened again, which is the only part of
        // notifications that doesn't depend on iOS granting a background slot.
        if let episodes = data.value?.episodes {
            await Notifications.shared.scheduleAirDates(episodes)
        }
    }
}

private struct UpcomingRow: View {
    let poster: String?
    let title: String
    let subtitle: String
    let tag: String
    let route: Navigator.Route

    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                PosterArt(url: poster, radius: 8).frame(width: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MarqueeFont.body(14.5, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(tag)
                    .font(MarqueeFont.body(9, .bold, relativeTo: .caption2))
                    .tracking(0.8)
                    .foregroundStyle(Color.mqInkMuted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mqInkMuted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mqPanel()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}
