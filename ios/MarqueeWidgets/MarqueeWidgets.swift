import AppIntents
import SwiftUI
import WidgetKit

@main
struct MarqueeWidgetBundle: WidgetBundle {
    var body: some Widget {
        UpNextWidget()
        EpisodesWaitingWidget()
        ReadingWidget()
        DownloadLiveActivity()
    }
}

// MARK: - Timeline

/// Widgets never talk to the server on their own: the app leaves a small snapshot in
/// the shared container after every refresh, and this reads it. A phone that has
/// never paired therefore has nothing to show and nothing to leak.
struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry {
        SnapshotEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now,
                                 snapshot: context.isPreview
                                    ? .preview
                                    : (OfflineStore.shared.readWidgetSnapshot() ?? .empty)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let snapshot = OfflineStore.shared.readWidgetSnapshot() ?? .empty
        // The app refreshes the snapshot whenever it's open; this is the slow safety
        // net for the hours in between.
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: snapshot)],
                            policy: .after(.now.addingTimeInterval(30 * 60))))
    }
}

// MARK: - Up Next

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.kadenthompson.marquee.upnext",
                            provider: SnapshotProvider()) { entry in
            UpNextWidgetView(entry: entry)
                .containerBackground(Color.mqGround, for: .widget)
        }
        .configurationDisplayName("Up Next")
        .description("The next episode waiting for you, with a button to cross it off.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryRectangular, .accessoryInline])
    }
}

struct UpNextWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var shows: [WidgetShow] { entry.snapshot.upNext }

    var body: some View {
        if !entry.snapshot.isPaired {
            UnpairedFace()
        } else if shows.isEmpty {
            CaughtUpFace()
        } else {
            switch family {
            case .accessoryInline:
                Text(inlineText)
            case .accessoryRectangular:
                rectangular
            case .systemSmall:
                small(shows[0])
            case .systemLarge:
                large
            default:
                medium(shows[0])
            }
        }
    }

    private var inlineText: String {
        guard let show = shows.first else { return "All caught up" }
        return "\(show.title) \(show.episodeCode ?? "")"
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("UP NEXT")
                .font(.system(size: 10, weight: .bold))
                .widgetAccentable()
            if let show = shows.first {
                Text(show.title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                Text(show.episodeTitle ?? show.episodeCode ?? "")
                    .font(.system(size: 12))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func small(_ show: WidgetShow) -> some View {
        ZStack(alignment: .bottomLeading) {
            WidgetPoster(url: show.poster)
            LinearGradient(colors: [.clear, .black.opacity(0.92)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(show.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(show.episodeCode ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.mqBrassBright)
            }
            .padding(10)
        }
        .overlay(alignment: .topTrailing) { punchButton(show).padding(8) }
        .widgetURL(deepLink(show))
    }

    private func medium(_ show: WidgetShow) -> some View {
        HStack(spacing: 12) {
            WidgetPoster(url: show.poster)
                .frame(width: 68)
                .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text("UP NEXT")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.mqInkMuted)
                Text(show.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(1)
                Text([show.episodeCode, show.episodeTitle].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mqBrassBright)
                    .lineLimit(2)
                Spacer(minLength: 0)
                WidgetProgress(fraction: show.progress)
            }
            Spacer(minLength: 0)
            punchButton(show)
        }
        .widgetURL(deepLink(show))
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("UP NEXT")
                .font(.system(size: 9, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Color.mqInkMuted)
            ForEach(shows.prefix(4)) { show in
                HStack(spacing: 10) {
                    WidgetPoster(url: show.poster)
                        .frame(width: 40)
                        .clipShape(.rect(cornerRadius: 6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(show.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(1)
                        Text(show.episodeCode ?? "")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.mqBrassBright)
                    }
                    Spacer(minLength: 0)
                    punchButton(show)
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// A real button, not a deep link: the point of Up Next is that crossing something
    /// off takes one tap from wherever you are.
    private func punchButton(_ show: WidgetShow) -> some View {
        Button(intent: MarkNextEpisodeIntent(
            show: ShowEntity(id: show.id, name: show.title, subtitle: show.episodeCode))) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.mqBrassOnFill)
                .frame(width: 32, height: 32)
                .background(Color.mqBrassFill, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mark \(show.episodeCode ?? "next episode") of \(show.title) watched")
    }

    private func deepLink(_ show: WidgetShow) -> URL? {
        URL(string: "marquee://show/\(show.id)")
    }
}

// MARK: - Episodes waiting

struct EpisodesWaitingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.kadenthompson.marquee.waiting",
                            provider: SnapshotProvider()) { entry in
            EpisodesWaitingView(entry: entry)
                .containerBackground(Color.mqGround, for: .widget)
        }
        .configurationDisplayName("Episodes Waiting")
        .description("How much is stacked up across everything you follow.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
    }
}

struct EpisodesWaitingView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if !entry.snapshot.isPaired {
            UnpairedFace()
        } else {
            switch family {
            case .accessoryInline:
                Text("\(entry.snapshot.episodesWaiting) episodes waiting")
            case .accessoryCircular:
                Gauge(value: Double(min(entry.snapshot.episodesWaiting, 50)), in: 0...50) {
                    Image(systemName: "play.rectangle.on.rectangle")
                } currentValueLabel: {
                    Text("\(entry.snapshot.episodesWaiting)")
                }
                .gaugeStyle(.accessoryCircular)
            default:
                VStack(spacing: 4) {
                    Text("\(entry.snapshot.episodesWaiting)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.mqBrass)
                        .minimumScaleFactor(0.5)
                    Text(entry.snapshot.episodesWaiting == 1 ? "episode waiting" : "episodes waiting")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.mqInkSoft)
                        .multilineTextAlignment(.center)
                }
                .widgetURL(URL(string: "marquee://next"))
            }
        }
    }
}

// MARK: - Reading

struct ReadingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "dev.kadenthompson.marquee.reading",
                            provider: SnapshotProvider()) { entry in
            ReadingWidgetView(entry: entry)
                .containerBackground(Color.mqGround, for: .widget)
        }
        .configurationDisplayName("Currently Reading")
        .description("How far through you are.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct ReadingWidgetView: View {
    let entry: SnapshotEntry
    @Environment(\.widgetFamily) private var family

    private var reads: [WidgetRead] { entry.snapshot.reading }

    var body: some View {
        if !entry.snapshot.isPaired {
            UnpairedFace()
        } else if reads.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "book.closed")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.mqInkMuted)
                Text("Nothing on the go")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mqInkSoft)
            }
        } else if family == .accessoryRectangular {
            VStack(alignment: .leading, spacing: 2) {
                Text(reads[0].title).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                ProgressView(value: reads[0].fraction).widgetAccentable()
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(reads.prefix(family == .systemMedium ? 3 : 1)) { read in
                    HStack(spacing: 10) {
                        WidgetPoster(url: read.cover)
                            .frame(width: family == .systemSmall ? 44 : 38)
                            .clipShape(.rect(cornerRadius: 5))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(read.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.mqInk)
                                .lineLimit(2)
                            WidgetProgress(fraction: read.fraction)
                            if let total = read.total {
                                Text("\(read.progress) / \(total)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.mqInkMuted)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .widgetURL(URL(string: "marquee://library"))
        }
    }
}

// MARK: - Shared pieces

struct WidgetPoster: View {
    let url: String?

    var body: some View {
        // A widget timeline can't await a download, so art comes from the small cache
        // the app keeps in the shared container; anything missing falls back cleanly.
        ZStack {
            Color.mqPanelRaised
            if let image = ArtCache.shared.image(for: url) {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "film")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.mqInkMuted.opacity(0.6))
            }
        }
        .aspectRatio(MQ.posterAspect, contentMode: .fit)
        .clipped()
    }
}

struct WidgetProgress: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.mqInkMuted.opacity(0.25))
                Capsule().fill(Color.mqBrassFill)
                    .frame(width: max(3, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 5)
    }
}

struct UnpairedFace: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Marquee")
                .font(MarqueeFont.wordmark(17, relativeTo: .headline))
                .foregroundStyle(Color.mqBrass)
            Text("Open the app to pair with your server.")
                .font(.system(size: 11))
                .foregroundStyle(Color.mqInkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(6)
    }
}

struct CaughtUpFace: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(Color.mqBrass)
            Text("All caught up")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.mqInkSoft)
        }
    }
}

extension WidgetSnapshot {
    /// What the widget gallery shows while it's being placed.
    static let preview = WidgetSnapshot(
        updatedAt: .now,
        upNext: [WidgetShow(id: 1, title: "The Long Weekend", poster: nil,
                            episodeCode: "S4 · E7", episodeTitle: "Small Hours",
                            season: 4, number: 7, watched: 31, aired: 36)],
        reading: [WidgetRead(id: 1, kind: "book", title: "The Glasshouse Year",
                             cover: nil, progress: 184, total: 452)],
        episodesWaiting: 12,
        isPaired: true)
}
