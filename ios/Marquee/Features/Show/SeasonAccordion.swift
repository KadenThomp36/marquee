import SwiftUI

/// The seasons, as an accordion. One open at a time, starting on whichever holds
/// your next episode, with a per-season progress rule and — when Overseerr is wired
/// up — a badge saying whether that season is on Plex, requested, or downloading.
struct SeasonAccordion: View {
    let model: ShowModel
    let seasonStates: [SeasonRequestState]
    let onTick: (EpisodeRow, Bool) async -> Void
    let onSeasonToggle: (Int, Bool) async -> Void

    @Environment(Session.self) private var session
    @State private var sheetEpisode: EpisodeRow?

    var body: some View {
        VStack(spacing: 10) {
            ForEach(model.detail?.seasons ?? []) { block in
                SeasonBlockView(
                    block: block,
                    name: model.detail?.info?.seasonName(block.season) ?? "Season \(block.season)",
                    isOpen: model.openSeason == block.season,
                    requestState: seasonStates.first { $0.number == block.season },
                    showID: model.showID,
                    onToggleOpen: {
                        withAnimation(.snappy(duration: 0.28)) {
                            model.openSeason = model.openSeason == block.season ? nil : block.season
                        }
                    },
                    onMarkAll: { watched in await onSeasonToggle(block.season, watched) },
                    onTick: onTick,
                    onLongPress: { sheetEpisode = $0 })
            }
        }
        .padding(.horizontal, MQ.gutter)
        .sheet(item: $sheetEpisode) { episode in
            EpisodeActionSheet(episode: episode, showID: model.showID) { action in
                switch action {
                case .toggle:
                    await onTick(episode, !episode.watched)
                case .setDate(let date):
                    await model.setWatchDate(date, season: episode.season,
                                             number: episode.number, session: session)
                }
            }
            .presentationDetents([.height(320)])
            .presentationBackground(Color.mqPanelRaised)
        }
    }
}

private struct SeasonBlockView: View {
    let block: SeasonBlock
    let name: String
    let isOpen: Bool
    let requestState: SeasonRequestState?
    let showID: Int
    let onToggleOpen: () -> Void
    let onMarkAll: (Bool) async -> Void
    let onTick: (EpisodeRow, Bool) async -> Void
    let onLongPress: (EpisodeRow) -> Void

    private var watched: Int { block.watchedCount }
    private var total: Int { block.episodes.count }
    private var allWatched: Bool { block.isComplete }

    var body: some View {
        VStack(spacing: 0) {
            header
            if isOpen {
                Divider().overlay(Color.mqHairline)
                VStack(spacing: 0) {
                    ForEach(block.episodes) { episode in
                        EpisodeRowView(episode: episode, showID: showID,
                                       onTick: { await onTick(episode, !episode.watched) },
                                       onLongPress: { onLongPress(episode) })
                        if episode.id != block.episodes.last?.id {
                            Divider().overlay(Color.mqHairline.opacity(0.6)).padding(.leading, 46)
                        }
                    }
                }
            }
        }
        .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
            .strokeBorder(Color.mqHairline, lineWidth: 1))
    }

    private var header: some View {
        VStack(spacing: 9) {
            HStack(spacing: 11) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.mqInkMuted)
                    .rotationEffect(.degrees(isOpen ? 90 : 0))

                Text(name)
                    .font(MarqueeFont.body(14.5, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(1)

                if allWatched {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.mqBrass)
                }

                Spacer(minLength: 6)

                Text("\(watched)/\(total)")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .monospacedDigit()

                Button(allWatched ? "unmark all" : "mark all") {
                    Task { await onMarkAll(!allWatched) }
                }
                .font(MarqueeFont.body(12, .semibold, relativeTo: .caption))
                .foregroundStyle(Color.mqBrass)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.mqBrassSoft, in: .capsule)
                .buttonStyle(.plain)
                .accessibilityLabel(allWatched ? "Unmark all of \(name)" : "Mark all of \(name) watched")
            }

            HStack(spacing: 10) {
                ProgressBar(fraction: total > 0 ? Double(watched) / Double(total) : 0, height: 6)
                if let requestState, requestState.state != .none {
                    SeasonStateBadge(state: requestState)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(.rect)
        .onTapGesture(perform: onToggleOpen)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(name), \(watched) of \(total) watched")
        .accessibilityHint(isOpen ? "Collapse season" : "Expand season")
        .accessibilityAddTraits(.isButton)
    }
}

/// One episode: number, title, when you watched it, air date, and the tick.
private struct EpisodeRowView: View {
    let episode: EpisodeRow
    let showID: Int
    let onTick: () async -> Void
    let onLongPress: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var busy = false

    private var isFuture: Bool { !episode.hasAired(asOf: MQTime.today()) }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(episode.number)")
                .font(.mqNumeric)
                .foregroundStyle(episode.watched ? Color.mqBrass : Color.mqInkMuted)
                .monospacedDigit()
                .frame(width: 28, alignment: .trailing)

            NavigationLink(value: Navigator.Route.episode(showID: showID,
                                                          season: episode.season,
                                                          number: episode.number)) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(episode.displayTitle)
                        .font(MarqueeFont.body(14, .regular, relativeTo: .subheadline))
                        .foregroundStyle(episode.watched ? Color.mqInkMuted : Color.mqInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if episode.watched, let watchedAt = episode.watchedAt {
                        Text("Watched \(MQTime.medium(watchedAt))")
                            .font(MarqueeFont.body(11, .semibold, relativeTo: .caption2))
                            .foregroundStyle(Color.mqBrass.opacity(0.8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // The air date is the first thing to go when text gets large.
            if typeSize <= .xxLarge, let airDate = episode.airDate, !airDate.isEmpty {
                Text(MQTime.short(airDate))
                    .font(MarqueeFont.body(11.5, .regular, relativeTo: .caption2))
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(1)
            }

            TickButton(isOn: episode.watched, busy: busy) {
                busy = true
                Task { await onTick(); busy = false }
            }
            .accessibilityLabel(episode.watched
                                ? "Mark \(episode.code) unwatched"
                                : "Mark \(episode.code) watched")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            if episode.watched {
                LinearGradient(colors: [Color.mqBrassSoft.opacity(0.5), .clear],
                               startPoint: .leading, endPoint: .trailing)
            }
        }
        .opacity(isFuture ? 0.45 : 1)
        .contextMenu { contextActions }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(episode.code). \(episode.displayTitle)")
    }

    @ViewBuilder
    private var contextActions: some View {
        Button(episode.watched ? "Mark unwatched" : "Mark watched",
               systemImage: episode.watched ? "minus.circle" : "checkmark.circle") {
            Task { await onTick() }
        }
        Button("Edit watch date…", systemImage: "calendar", action: onLongPress)
            .disabled(!episode.watched)
    }
}

/// The circular tick that crosses an episode off.
struct TickButton: View {
    let isOn: Bool
    var busy = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isOn ? Color.mqBrassOnFill : Color.mqHairlineBold)
                .frame(width: 34, height: 34)
                .background {
                    Circle()
                        .fill(isOn ? Color.mqBrassFill : .clear)
                        .overlay(Circle().strokeBorder(isOn ? Color.mqBrassFill : Color.mqHairlineBold,
                                                       lineWidth: 2))
                }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .scaleEffect(busy && !reduceMotion ? 0.88 : 1)
        .animation(.spring(duration: 0.28), value: isOn)
        .animation(.spring(duration: 0.2), value: busy)
        .sensoryFeedback(.impact(weight: .light), trigger: isOn)
    }
}

/// Per-season Overseerr state, shown on the progress row.
struct SeasonStateBadge: View {
    let state: SeasonRequestState

    var body: some View {
        switch state.state {
        case .downloading:
            HStack(spacing: 6) {
                Capsule().fill(Color.mqPanelRaised)
                    .frame(width: 34, height: 5)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.mqBrassFill)
                            .frame(width: 34 * Double(state.progress ?? 0) / 100)
                    }
                Text("\(state.progress ?? 0)%")
                    .monospacedDigit()
                if let eta = state.eta { Text("· \(eta)") }
            }
            .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
            .foregroundStyle(Color.mqBrass)
            .accessibilityLabel("Downloading, \(state.progress ?? 0) percent")
        case .available:
            Label("On Plex", systemImage: "checkmark")
                .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                .foregroundStyle(Color.mqBrassBright)
        default:
            Label(state.state.label, systemImage: "arrow.down.circle")
                .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                .foregroundStyle(Color.mqInkSoft)
        }
    }
}

/// The long-press sheet: toggle, or correct the date you actually watched it.
private struct EpisodeActionSheet: View {
    let episode: EpisodeRow
    let showID: Int
    let perform: (Action) async -> Void

    enum Action {
        case toggle
        case setDate(String)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        Task { await perform(.toggle); dismiss() }
                    } label: {
                        Label(episode.watched ? "Mark unwatched" : "Mark watched",
                              systemImage: episode.watched ? "minus.circle" : "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.mqBrass)

                    if episode.watched {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Watched on").mqEyebrowStyle()
                            DatePicker("Watched on", selection: $date,
                                       in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Color.mqBrass)
                            Button("Save date") {
                                // Midday, so a timezone nudge can't slide it a day.
                                let stamp = MQTime.today(date) + "T12:00:00"
                                Task { await perform(.setDate(stamp)); dismiss() }
                            }
                            .buttonStyle(.mqChip)
                        }
                    }

                    NavigationLink(value: Navigator.Route.episode(showID: showID,
                                                                  season: episode.season,
                                                                  number: episode.number)) {
                        Label("Episode details", systemImage: "info.circle")
                    }
                    .buttonStyle(.mqChip)

                    Spacer()
                }
                .padding(MQ.gutter)
            }
            .navigationTitle("\(episode.code) · \(episode.displayTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            date = MQTime.date(from: episode.watchedAt) ?? Date()
        }
    }
}
