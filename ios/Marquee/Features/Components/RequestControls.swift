import SwiftUI

/// The Overseerr button in a detail hero. Shows what state the title is actually in
/// rather than always offering "Request" — asking for something that's already on
/// Plex is the mistake this prevents.
struct RequestButton: View {
    let status: RequestStatus
    let action: () -> Void

    var body: some View {
        switch status.state {
        case .available:
            Label("On Plex", systemImage: "checkmark")
                .font(.mqSub)
                .foregroundStyle(Color.mqPlex)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.mqPlex.opacity(0.12), in: .capsule)
                .overlay(Capsule().strokeBorder(Color.mqPlex.opacity(0.5), lineWidth: 1))
        default:
            VStack(alignment: .leading, spacing: 5) {
                Button(action: action) {
                    Label(status.state == .none ? "Request" : "Manage request",
                          systemImage: "arrow.down.circle")
                        .font(.mqSub)
                }
                .buttonStyle(.bordered)
                .tint(Color.mqOverseerr)

                if let download = status.download {
                    DownloadPill(progress: download)
                }
            }
        }
    }
}

/// Live download progress. Polled only while something is genuinely in flight.
struct DownloadPill: View {
    let progress: DownloadProgress

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(Color.mqPanelRaised)
                .frame(width: 52, height: 6)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color.mqOverseerr)
                        .frame(width: 52 * progress.fraction)
                }
            Text("\(progress.progress)%").monospacedDigit()
            if let eta = progress.eta { Text("· \(eta)") }
        }
        .font(MarqueeFont.body(11.5, .bold, relativeTo: .caption2))
        .foregroundStyle(Color.mqOverseerr)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Downloading, \(progress.progress) percent"
            + (progress.eta.map { ", \($0) left" } ?? ""))
    }
}

/// Per-season request picker — the same shape Overseerr itself uses: an overall
/// verdict up top, then one row per season with its own state, and checkboxes only
/// on the seasons that aren't already spoken for.
struct SeasonRequestSheet: View {
    let showID: Int
    let status: RequestStatus
    let onDone: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int> = []
    @State private var busy = false
    @State private var justRequested: Set<Int> = []

    private var seasons: [SeasonRequestState] { status.seasons ?? [] }
    private var selectable: [SeasonRequestState] { seasons.filter(\.isSelectable) }

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        overall
                        VStack(spacing: 0) {
                            ForEach(seasons) { season in
                                row(season)
                                if season.id != seasons.last?.id {
                                    Divider().overlay(Color.mqHairline)
                                }
                            }
                        }
                        .mqPanel()

                        if !selectable.isEmpty {
                            Button {
                                if selected.count == selectable.count {
                                    selected.removeAll()
                                } else {
                                    selected = Set(selectable.map(\.number))
                                }
                            } label: {
                                Label("Select all not on Plex",
                                      systemImage: selected.count == selectable.count
                                        ? "checkmark.square.fill" : "square")
                                    .font(.mqSub)
                            }
                            .buttonStyle(.mqQuiet)
                        }
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle(selectable.isEmpty ? "Request" : "Request seasons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(selectable.isEmpty ? "Close" : "Cancel") { dismiss() }
                }
                if !selectable.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(selected.isEmpty
                               ? "Request"
                               : "Request \(selected.count)") {
                            Task { await request() }
                        }
                        .disabled(selected.isEmpty || busy)
                        .fontWeight(.bold)
                    }
                }
            }
        }
        .presentationBackground(Color.mqGround)
    }

    private var overall: some View {
        let available = seasons.count { $0.state == .available }
        let downloading = seasons.count { $0.state == .downloading }
        let requested = seasons.count { $0.state.isRequested && $0.state != .downloading }

        let headline: String
        if !seasons.isEmpty, available == seasons.count {
            headline = "All \(seasons.count) seasons on Plex"
        } else if downloading > 0 {
            headline = "Downloading \(downloading) season\(downloading == 1 ? "" : "s")"
        } else if available > 0 {
            headline = "\(available) of \(seasons.count) seasons on Plex"
        } else if requested > 0 {
            headline = "Requested — waiting to download"
        } else {
            headline = "Not on Plex yet"
        }

        return VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(MarqueeFont.body(14.5, .bold, relativeTo: .subheadline))
                .foregroundStyle(available > 0 || downloading > 0 ? Color.mqBrass : Color.mqInk)
            if let download = status.download {
                ProgressBar(fraction: download.fraction, height: 6)
                Text("\(download.progress)% overall"
                     + (download.eta.map { " · \($0) left" } ?? ""))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoft)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(available > 0 ? Color.mqBrassSoft : Color.mqPanel,
                    in: .rect(cornerRadius: MQ.radiusSmall))
        .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
            .strokeBorder(available > 0 ? Color.mqBrassDim : Color.mqHairline, lineWidth: 1))
    }

    private func row(_ season: SeasonRequestState) -> some View {
        let isPending = justRequested.contains(season.number)
        let isSelected = selected.contains(season.number)
        return HStack(spacing: 13) {
            if season.isSelectable, !isPending {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 21))
                    .foregroundStyle(isSelected ? Color.mqBrass : Color.mqHairlineBold)
            } else {
                Circle()
                    .fill(season.state == .available ? Color.mqBrassFill : Color.mqPanelRaised)
                    .frame(width: 21, height: 21)
                    .overlay(Circle().strokeBorder(Color.mqHairlineBold, lineWidth: 1))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Season \(season.number)")
                    .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                Text(isPending ? "just requested"
                     : "\(season.episodes) episode\(season.episodes == 1 ? "" : "s")")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
            }
            Spacer(minLength: 6)

            if isPending {
                Text("Requested")
                    .font(MarqueeFont.body(11.5, .bold, relativeTo: .caption2))
                    .foregroundStyle(Color.mqInkSoft)
            } else if season.state != .none {
                SeasonStateBadge(state: season)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(.rect)
        .onTapGesture {
            guard season.isSelectable, !isPending else { return }
            if isSelected { selected.remove(season.number) } else { selected.insert(season.number) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(season.isSelectable && !isPending ? .isButton : [])
        .accessibilityValue(isSelected ? "Selected" : season.state.label)
    }

    private func request() async {
        guard let client = session.client, !selected.isEmpty else { return }
        busy = true
        defer { busy = false }
        let numbers = Array(selected).sorted()
        do {
            _ = try await client.post("request",
                                      body: MakeRequest(itemType: "show", itemID: showID,
                                                        seasons: numbers),
                                      as: RequestResult.self)
            justRequested.formUnion(numbers)
            selected.removeAll()
            // Overseerr takes a beat to reflect a new request, so ask twice.
            await onDone()
            try? await Task.sleep(for: .seconds(3))
            await onDone()
            dismiss()
        } catch {
            busy = false
        }
    }
}
