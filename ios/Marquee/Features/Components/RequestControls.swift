import SwiftUI

// MARK: - One visual language for every request
//
// Films, shows and books are requested from three different servers (Overseerr for
// the first two, Shelfmark for books), but to the person asking they are one
// feature: say you want it, watch it arrive. So all three speak through the same two
// pieces — a status pill (an icon and a word, tinted by how things stand) and a
// progress track with a readable time left — and the same tones mean the same thing
// everywhere.

/// How a request stands, as a colour family. Never colour alone: every tone travels
/// with an icon and a word.
enum RequestTone: Equatable {
    /// Nothing asked for yet.
    case idle
    /// Asked for, nothing moving yet: pending approval, searching indexers.
    case waiting
    /// Bytes are arriving.
    case working
    /// It's here.
    case ready
    /// Part of it is here.
    case partial
    /// A person has to do something.
    case attention
    /// It stopped and won't restart on its own.
    case failed
    /// Called off, or nobody knows.
    case muted

    var color: Color {
        switch self {
        case .idle: .mqInkSoft
        case .waiting: .mqInkSoft
        case .working: .mqBrass
        case .ready: .mqChartGreen
        case .partial: .mqChartAqua
        case .attention: .mqChartOrange
        case .failed: .mqVelvet
        case .muted: .mqInkMuted
        }
    }

    /// The pill's wash. Neutral tones sit on a panel rather than a tint of grey.
    var wash: Color {
        switch self {
        case .idle, .waiting, .muted: .mqPanelRaised
        default: color.opacity(0.14)
        }
    }

    var edge: Color {
        switch self {
        case .idle, .waiting, .muted: .mqHairlineBold
        default: color.opacity(0.45)
        }
    }
}

/// An icon and a word in a tinted capsule — the status everywhere a request shows.
struct RequestStatusPill: View {
    let label: String
    let symbol: String
    let tone: RequestTone
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            Image(systemName: symbol)
                .font(.system(size: compact ? 9.5 : 11, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text(label)
                .lineLimit(1)
        }
        .font(MarqueeFont.body(compact ? 10.5 : 12, .bold, relativeTo: .caption))
        .foregroundStyle(tone.color)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(tone.wash, in: .capsule)
        .overlay(Capsule().strokeBorder(tone.edge, lineWidth: 1))
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// A download in flight: a track that fills with a spring, the percentage, and the
/// time left in words rather than Sonarr's `00:04:12`.
///
/// `indeterminate` is for the stretch where nothing can be measured — the indexers
/// being searched — and slides a short segment instead of pretending to a number.
struct RequestProgressTrack: View {
    var fraction: Double = 0
    var percent: Int?
    var eta: String?
    /// A second line on the left: the downloader's own words, "Seeding 4 peers".
    var note: String?
    var tone: RequestTone = .working
    var indeterminate = false
    var height: CGFloat = 7

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.mqPanelRaised)
                    Capsule().strokeBorder(Color.mqHairline, lineWidth: 0.5)
                    if indeterminate {
                        Capsule()
                            .fill(LinearGradient(colors: [tone.color.opacity(0), tone.color, tone.color.opacity(0)],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * 0.32)
                            .offset(x: reduceMotion ? proxy.size.width * 0.34
                                    : (sweep ? proxy.size.width * 0.68 : 0))
                    } else {
                        Capsule()
                            .fill(LinearGradient(colors: [tone.color.opacity(0.65), tone.color],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(height, proxy.size.width * min(max(fraction, 0), 1)))
                            .opacity(fraction > 0 ? 1 : 0)
                    }
                }
                .clipShape(.capsule)
            }
            .frame(height: height)
            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: fraction)

            if percent != nil || eta != nil || note != nil {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if let note, !note.isEmpty {
                        Text(note)
                            .foregroundStyle(Color.mqInkSoft)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    if let percent {
                        Text("\(percent)%")
                            .foregroundStyle(tone.color)
                            .monospacedDigit()
                    }
                    if let eta = RequestETA.readable(eta) {
                        Text(eta)
                            .foregroundStyle(Color.mqInkMuted)
                            .monospacedDigit()
                    }
                }
                .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
            }
        }
        .onAppear {
            guard indeterminate, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true)) { sweep = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if indeterminate { return note ?? "Working" }
        var parts = ["\(percent ?? Int((fraction * 100).rounded())) percent"]
        if let eta = RequestETA.readable(eta) { parts.append(eta) }
        if let note { parts.append(note) }
        return parts.joined(separator: ", ")
    }
}

/// Sonarr and Radarr report time left as `HH:MM:SS`, or `D.HH:MM:SS` past a day.
enum RequestETA {
    static func readable(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), !raw.isEmpty else { return nil }
        var days = 0.0
        var clock = Substring(raw)
        if let colon = raw.firstIndex(of: ":"), let dot = raw[..<colon].firstIndex(of: ".") {
            days = Double(raw[..<dot]) ?? 0
            clock = raw[raw.index(after: dot)...]
        }
        let parts = clock.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 3 else { return raw }
        let seconds = days * 86_400 + parts[0] * 3600 + parts[1] * 60 + parts[2]
        if seconds < 60 { return "under a minute left" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min left" }
        let hours = minutes / 60, rest = minutes % 60
        if hours < 24 { return rest == 0 ? "\(hours) h left" : "\(hours) h \(rest) min left" }
        let wholeDays = hours / 24, restHours = hours % 24
        return restHours == 0 ? "\(wholeDays) d left" : "\(wholeDays) d \(restHours) h left"
    }
}

/// The moment a request goes in: a check that lands with a spring and a haptic, so a
/// tap that sends something to another server feels like it did.
struct RequestConfirmation: View {
    let title: String
    var detail: String?

    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.mqBrassSoft)
                    .frame(width: 86, height: 86)
                    .scaleEffect(landed ? 1 : 0.6)
                Circle()
                    .strokeBorder(Color.mqBrassDim, lineWidth: 1.5)
                    .frame(width: 86, height: 86)
                    .scaleEffect(landed ? 1.18 : 0.9)
                    .opacity(landed ? 0 : 1)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(Color.mqBrass)
                    .scaleEffect(landed ? 1 : 0.3)
                    .rotationEffect(.degrees(landed ? 0 : -18))
            }
            Text(title)
                .font(MarqueeFont.body(19, .bold, relativeTo: .title3))
                .foregroundStyle(Color.mqInk)
            if let detail {
                Text(detail)
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.mqGround.opacity(0.94))
        .sensoryFeedback(.success, trigger: landed) { _, new in new }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                          : .spring(response: 0.45, dampingFraction: 0.6)) { landed = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Overseerr

extension RequestState {
    var tone: RequestTone {
        switch self {
        case .none: .idle
        case .pending, .processing: .waiting
        case .downloading: .working
        case .partial: .partial
        case .available: .ready
        case .unknown: .muted
        }
    }

    var symbol: String {
        switch self {
        case .none: "circle.dashed"
        case .pending: "clock"
        case .processing: "magnifyingglass"
        case .downloading: "arrow.down.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .available: "checkmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    /// What the pill says — plainer than Overseerr's own words.
    var pillLabel: String {
        switch self {
        case .none: "Not on Plex"
        case .pending: "Requested"
        case .processing: "Searching"
        case .downloading: "Downloading"
        case .partial: "Partly on Plex"
        case .available: "On Plex"
        case .unknown: "Status unknown"
        }
    }
}

extension SeasonRequestState {
    var pill: RequestStatusPill {
        if state == .downloading, let progress {
            return RequestStatusPill(label: "\(progress)%", symbol: state.symbol, tone: state.tone, compact: true)
        }
        return RequestStatusPill(label: state.pillLabel, symbol: state.symbol, tone: state.tone, compact: true)
    }
}

/// The Overseerr control in a detail hero. Shows where the title actually stands
/// rather than always offering "Request" — asking for something that's already on
/// Plex is the mistake this prevents. Anything already asked for is a tappable pill
/// that opens the sheet with the details.
struct RequestButton: View {
    let status: RequestStatus
    let action: () -> Void

    var body: some View {
        switch status.state {
        case .available where !(status.seasons ?? []).contains(where: \.isSelectable):
            RequestStatusPill(label: status.state.pillLabel, symbol: status.state.symbol,
                              tone: .ready)
        case .none:
            Button(action: action) {
                Label("Request", systemImage: "arrow.down.to.line.circle")
                    .font(.mqSub)
            }
            .buttonStyle(.bordered)
            .tint(Color.mqBrass)
            .accessibilityHint("Ask Overseerr to get it onto Plex")
        default:
            VStack(alignment: .leading, spacing: 7) {
                Button(action: action) {
                    HStack(spacing: 5) {
                        RequestStatusPill(label: label, symbol: shown.symbol, tone: shown.tone)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(label). Opens the request.")

                if let download = status.download {
                    RequestProgressTrack(fraction: download.fraction, percent: download.progress,
                                         eta: download.eta, height: 5)
                        .frame(maxWidth: 210)
                }
            }
        }
    }

    /// A running download outranks whatever Overseerr calls the request overall.
    private var shown: RequestState { status.download != nil ? .downloading : status.state }

    private var label: String {
        if status.download != nil { return "Downloading" }
        if status.state == .available || status.state == .partial,
           (status.seasons ?? []).contains(where: \.isSelectable) {
            return "Request more"
        }
        return status.state.pillLabel
    }
}

/// Live download progress in a single line. Polled only while something is in flight.
struct DownloadPill: View {
    let progress: DownloadProgress

    var body: some View {
        RequestProgressTrack(fraction: progress.fraction, percent: progress.progress,
                             eta: progress.eta, height: 5)
            .frame(maxWidth: 210)
    }
}

/// One segment per season, coloured by where it stands — the whole show's request
/// state at a glance before reading a single row.
private struct SeasonStrip: View {
    let seasons: [SeasonRequestState]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(seasons) { season in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(season.state == .none ? Color.mqPanelRaised : season.state.tone.color.opacity(0.28))
                        if season.state == .downloading {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(season.state.tone.color)
                                .frame(width: proxy.size.width * Double(season.progress ?? 0) / 100)
                        } else if season.state != .none {
                            RoundedRectangle(cornerRadius: 3).fill(season.state.tone.color)
                        }
                    }
                }
                .frame(height: 10)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Per-season request picker, the shape Overseerr itself uses: a verdict and a strip
/// up top, then one row per season with its own state — and a check only on the
/// seasons nobody has asked for yet.
struct SeasonRequestSheet: View {
    let showID: Int
    let status: RequestStatus
    let onDone: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<Int> = []
    @State private var busy = false
    @State private var confirmed: [Int]?
    @State private var failure: String?

    private var seasons: [SeasonRequestState] { status.seasons ?? [] }
    private var selectable: [SeasonRequestState] { seasons.filter(\.isSelectable) }
    private var allSelected: Bool { !selectable.isEmpty && selected.count == selectable.count }

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        overview

                        if !selectable.isEmpty { selectAll }

                        VStack(spacing: 0) {
                            ForEach(seasons) { season in
                                row(season)
                                if season.id != seasons.last?.id {
                                    Divider().overlay(Color.mqHairline).padding(.leading, 50)
                                }
                            }
                        }
                        .mqPanel(radius: MQ.radius)

                        if let failure {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqVelvet)
                        }
                    }
                    .padding(MQ.gutter)
                }
                .safeAreaInset(edge: .bottom) {
                    if !selectable.isEmpty { requestBar }
                }
            }
            .overlay {
                if let confirmed {
                    RequestConfirmation(
                        title: "Requested",
                        detail: confirmed.count == 1
                            ? "Season \(confirmed[0]) is on its way to Plex."
                            : "\(confirmed.count) seasons are on their way to Plex.")
                    .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: confirmed)
            .navigationTitle(selectable.isEmpty ? "Request" : "Request seasons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationBackground(Color.mqGround)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private var overview: some View {
        let available = seasons.count { $0.state == .available }
        let downloading = seasons.count { $0.state == .downloading }
        let asked = seasons.count { $0.state.isRequested && $0.state != .downloading }
        let open = selectable.count

        let headline: String
        if !seasons.isEmpty, available == seasons.count {
            headline = seasons.count == 1 ? "On Plex" : "All \(seasons.count) seasons on Plex"
        } else if downloading > 0 {
            headline = "Downloading \(downloading) season\(downloading == 1 ? "" : "s")"
        } else if available > 0 {
            headline = "\(available) of \(seasons.count) seasons on Plex"
        } else if asked > 0 {
            headline = "Requested, waiting to download"
        } else {
            headline = "Not on Plex yet"
        }

        var counts: [String] = []
        if available > 0 { counts.append("\(available) on Plex") }
        if downloading > 0 { counts.append("\(downloading) downloading") }
        if asked > 0 { counts.append("\(asked) requested") }
        if open > 0 { counts.append("\(open) not requested") }

        return VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text(headline)
                    .font(MarqueeFont.body(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.mqInk)
                Spacer(minLength: 8)
                let shown: RequestState = status.download != nil ? .downloading : status.state
                RequestStatusPill(label: shown.pillLabel, symbol: shown.symbol, tone: shown.tone, compact: true)
            }
            if seasons.count > 1 { SeasonStrip(seasons: seasons) }
            if let download = status.download {
                RequestProgressTrack(fraction: download.fraction, percent: download.progress,
                                     eta: download.eta,
                                     note: download.active > 1 ? "\(download.active) downloads running" : nil)
            }
            if !counts.isEmpty {
                Text(counts.joined(separator: ", "))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel(radius: MQ.radius)
        .accessibilityElement(children: .combine)
    }

    private var selectAll: some View {
        Button {
            selected = allSelected ? [] : Set(selectable.map(\.number))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(allSelected ? Color.mqBrass : Color.mqHairlineBold)
                Text(allSelected ? "Clear selection" : "Select every season not on Plex")
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInk)
                Spacer()
                Text("\(selectable.count)")
                    .font(.mqNumeric)
                    .foregroundStyle(Color.mqInkMuted)
                    .monospacedDigit()
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .mqPanel(radius: MQ.radius)
    }

    private func row(_ season: SeasonRequestState) -> some View {
        let isSelected = selected.contains(season.number)
        return HStack(spacing: 14) {
            Group {
                if season.isSelectable {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.mqBrass : Color.mqHairlineBold)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Image(systemName: season.state.symbol)
                        .foregroundStyle(season.state.tone.color)
                }
            }
            .font(.system(size: 21))
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text("Season \(season.number)")
                    .font(MarqueeFont.body(15, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                Text(rowDetail(season))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .monospacedDigit()
            }
            Spacer(minLength: 6)

            if !season.isSelectable { season.pill }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .background(isSelected ? Color.mqBrassSoft : .clear)
        .contentShape(.rect)
        .onTapGesture {
            guard season.isSelectable else { return }
            withAnimation(.snappy(duration: 0.18)) {
                if isSelected { selected.remove(season.number) } else { selected.insert(season.number) }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(season.isSelectable ? .isButton : [])
        .accessibilityValue(season.isSelectable ? (isSelected ? "Selected" : "Not selected")
                                                : season.state.pillLabel)
    }

    private func rowDetail(_ season: SeasonRequestState) -> String {
        var parts = ["\(season.episodes) episode\(season.episodes == 1 ? "" : "s")"]
        if season.state == .downloading, let eta = RequestETA.readable(season.eta) { parts.append(eta) }
        return parts.joined(separator: " · ")
    }

    private var requestBar: some View {
        Button {
            Task { await request() }
        } label: {
            if busy {
                ProgressView().tint(Color.mqBrassOnFill)
            } else {
                Text(selected.isEmpty ? "Pick seasons to request"
                     : selected.count == 1 ? "Request season \(selected.first ?? 0)"
                     : "Request \(selected.count) seasons")
            }
        }
        .buttonStyle(.mqPrimary)
        .disabled(selected.isEmpty || busy)
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color.mqGround.opacity(0.96))
    }

    private func request() async {
        guard let client = session.client, !selected.isEmpty else { return }
        busy = true
        failure = nil
        defer { busy = false }
        let numbers = Array(selected).sorted()
        do {
            _ = try await client.post("request",
                                      body: MakeRequest(itemType: "show", itemID: showID,
                                                        seasons: numbers),
                                      as: RequestResult.self)
            selected.removeAll()
            confirmed = numbers
            await onDone()
            // Overseerr takes a beat to reflect a new request, so ask twice.
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
            try? await Task.sleep(for: .seconds(2))
            await onDone()
        } catch {
            failure = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// A film has no seasons, so requesting it is one button — and the same pill, track
/// and confirmation as everything else.
struct MovieRequestSheet: View {
    let movieID: Int
    let status: RequestStatus
    let onDone: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false
    @State private var sent = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(headline)
                            .font(MarqueeFont.body(19, .bold, relativeTo: .title3))
                            .foregroundStyle(Color.mqInk)
                        Spacer(minLength: 8)
                        let shown: RequestState = status.download != nil ? .downloading : status.state
                        RequestStatusPill(label: shown.pillLabel, symbol: shown.symbol, tone: shown.tone)
                    }

                    if let download = status.download {
                        RequestProgressTrack(fraction: download.fraction, percent: download.progress,
                                             eta: download.eta)
                    }

                    Text(explainer)
                        .font(.mqSub)
                        .foregroundStyle(Color.mqInkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    if let failure {
                        Label(failure, systemImage: "exclamationmark.triangle")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqVelvet)
                    }

                    Spacer(minLength: 0)

                    if status.state == .none {
                        Button {
                            Task { await request() }
                        } label: {
                            if busy { ProgressView().tint(Color.mqBrassOnFill) } else { Text("Request this film") }
                        }
                        .buttonStyle(.mqPrimary)
                        .disabled(busy)
                    }
                }
                .padding(MQ.gutter)
                .padding(.top, 8)
            }
            .overlay {
                if sent {
                    RequestConfirmation(title: "Requested",
                                        detail: "Overseerr will fetch it and put it on Plex.")
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: sent)
            .navigationTitle("Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationDetents([.height(330), .medium])
        .presentationBackground(Color.mqGround)
    }

    private var shown: RequestState { status.download != nil ? .downloading : status.state }

    private var headline: String {
        switch shown {
        case .none: "Not on Plex yet"
        case .available: "Ready to watch"
        case .downloading: "On its way"
        case .unknown: "Overseerr didn\u{2019}t answer"
        default: "Requested"
        }
    }

    private var explainer: String {
        switch shown {
        case .none: "Ask Overseerr for it and it lands on Plex once it\u{2019}s downloaded. Everyone in the house can see the request."
        case .pending: "Waiting for approval in Overseerr."
        case .processing: "Approved. Radarr is looking for a copy."
        case .downloading: "Downloading now. It appears on Plex when it finishes."
        case .partial, .available: "It\u{2019}s on Plex."
        case .unknown: "The request server didn\u{2019}t answer. Try again in a bit."
        }
    }

    private func request() async {
        guard let client = session.client else { return }
        busy = true
        failure = nil
        defer { busy = false }
        do {
            _ = try await client.post("request",
                                      body: MakeRequest(itemType: "movie", itemID: movieID),
                                      as: RequestResult.self)
            sent = true
            await onDone()
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
            try? await Task.sleep(for: .seconds(2))
            await onDone()
        } catch {
            failure = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Samples

#if DEBUG
enum RequestSamples {
    static func season(_ number: Int, _ status: String, progress: Int? = nil, eta: String? = nil) -> SeasonRequestState {
        SeasonRequestState(number: number, episodes: 8 + number, status: status, progress: progress, eta: eta)
    }

    static let none = RequestStatus(enabled: true, status: "none")
    static let pending = RequestStatus(enabled: true, status: "pending")
    static let processing = RequestStatus(enabled: true, status: "processing")
    static let downloading = RequestStatus(enabled: true, status: "processing",
                                           download: DownloadProgress(active: 1, progress: 62, eta: "00:14:40"))
    static let available = RequestStatus(enabled: true, status: "available")
    static let show = RequestStatus(
        enabled: true, status: "partial",
        download: DownloadProgress(active: 2, progress: 38, eta: "01:22:05"),
        seasons: [season(1, "available"), season(2, "available"), season(3, "downloading", progress: 38, eta: "01:22:05"),
                  season(4, "pending"), season(5, "none"), season(6, "none")])
}

#Preview("Overseerr controls") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            RequestButton(status: RequestSamples.none) {}
            RequestButton(status: RequestSamples.pending) {}
            RequestButton(status: RequestSamples.processing) {}
            RequestButton(status: RequestSamples.downloading) {}
            RequestButton(status: RequestSamples.show) {}
            RequestButton(status: RequestSamples.available) {}
        }
        .padding()
    }
    .background(Color.mqGround)
}
#endif
