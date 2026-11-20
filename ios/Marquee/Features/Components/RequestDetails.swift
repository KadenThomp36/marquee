import SwiftUI

// MARK: - What's behind a request pill
//
// Tap a pill (a film's, a show's or a book's) and the sheet that opens says the same
// three things in the same shape: what's already there (on Plex, in Calibre), what's
// on its way (the copy, its size, how far along), and who asked for it and when, with
// a way to delete a request you're allowed to. The pieces below are shared by all
// three sheets, so they read as one feature.

/// "2 hours ago", from either kind of time this app sees. Overseerr writes ISO 8601
/// in UTC (`2026-11-18T09:12:44.000Z`); Marquee's own stamps are naive local time.
enum RequestWhen {
    static func relative(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        if let date = iso(raw) { return date.formatted(.relative(presentation: .named)) }
        return MQTime.relative(raw)
    }

    private static func iso(_ raw: String) -> Date? {
        // Only a string carrying a zone is UTC; a naive stamp parsed as UTC would be
        // off by the household's offset.
        guard raw.hasSuffix("Z") || raw.dropFirst(19).contains("+") || raw.dropFirst(19).contains("-")
        else { return nil }
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = precise.date(from: raw) { return date }
        return ISO8601DateFormatter().date(from: raw)
    }
}

/// A titled group in a request sheet: an eyebrow, then a panel.
struct RequestDetailSection<Content: View>: View {
    let title: String
    var count: Int?
    @ViewBuilder var content: Content

    init(_ title: String, count: Int? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).mqEyebrowStyle()
                if let count, count > 1 {
                    Text("\(count)")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .monospacedDigit()
                }
            }
            .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .mqPanel(radius: MQ.radius)
        }
    }
}

/// A divider between rows in a `RequestDetailSection`, inset past the icon column.
struct RequestDetailDivider: View {
    var body: some View {
        Divider().overlay(Color.mqHairline).padding(.leading, 50)
    }
}

/// One fact in a section: a tinted symbol, a headline and a quieter line under it.
struct RequestFactRow<Trailing: View>: View {
    let symbol: String
    var tone: RequestTone = .muted
    let headline: String
    var detail: String?
    /// Release names are long and dense; they get a tighter face and three lines.
    var dense = false
    @ViewBuilder var trailing: Trailing

    init(symbol: String, tone: RequestTone = .muted, headline: String, detail: String? = nil,
         dense: Bool = false, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.symbol = symbol
        self.tone = tone
        self.headline = headline
        self.detail = detail
        self.dense = dense
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            RequestSymbol(symbol: symbol, tone: tone)
            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(dense ? MarqueeFont.body(13, .semibold, relativeTo: .subheadline)
                                : MarqueeFont.body(15, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(dense ? 3 : 2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// The round, tinted symbol at the head of every row: the same wash and edge as
/// the status pills, so a row and its pill are visibly the same tone.
struct RequestSymbol: View {
    let symbol: String
    let tone: RequestTone

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tone.color)
            .frame(width: 26, height: 26)
            .background(tone.wash, in: .circle)
            .overlay(Circle().strokeBorder(tone.edge, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

/// Who asked and when, with a status pill and, when the server allows it, the way to
/// delete the request.
struct RequesterRow: View {
    let name: String?
    let isMine: Bool
    let when: String?
    /// "4K", "Seasons 3–4"…
    var extras: [String] = []
    var pill: RequestStatusPill?
    var canDelete = false
    var deleting = false
    var onDelete: () -> Void = {}

    private var who: String { isMine ? "You" : (name?.isEmpty == false ? name! : "Someone") }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 13) {
                // The person's own initial, even on your own row: "You" would make
                // every one of yours a Y.
                Text(String((name?.isEmpty == false ? name! : who).prefix(1)).uppercased())
                    .font(MarqueeFont.body(12, .bold, relativeTo: .caption))
                    .foregroundStyle(isMine ? Color.mqBrass : Color.mqInkSoft)
                    .frame(width: 26, height: 26)
                    .background(isMine ? Color.mqBrassSoft : Color.mqPanelRaised, in: .circle)
                    .overlay(Circle().strokeBorder(isMine ? Color.mqBrassDim : Color.mqHairlineBold, lineWidth: 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(askedLine)
                        .font(MarqueeFont.body(15, .bold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                    if !extras.isEmpty {
                        Text(extras.joined(separator: " · "))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
                Spacer(minLength: 4)
                pill
            }
            .accessibilityElement(children: .combine)

            if canDelete {
                Button(action: onDelete) {
                    if deleting {
                        ProgressView().controlSize(.small).tint(Color.mqVelvet)
                    } else {
                        Label("Delete request", systemImage: "trash")
                    }
                }
                .buttonStyle(.mqChip(on: false, destructive: true))
                .disabled(deleting)
                .padding(.leading, 39)
                .accessibilityHint("Asks before deleting")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var askedLine: String {
        let ago = RequestWhen.relative(when)
        return ago.isEmpty ? "\(who) asked" : "\(who) asked \(ago)"
    }
}

// MARK: - Films and shows

extension OverseerrRequest {
    /// Overseerr's words, as a pill.
    var pill: RequestStatusPill {
        let words = status ?? "Requested"
        let (symbol, tone): (String, RequestTone) = switch words.lowercased() {
        case let s where s.contains("waiting") || s.contains("pending"): ("clock", .waiting)
        case let s where s.contains("approved"): ("checkmark.seal.fill", .working)
        case let s where s.contains("declined"): ("xmark.octagon.fill", .failed)
        case let s where s.contains("failed"): ("exclamationmark.triangle.fill", .failed)
        case let s where s.contains("completed") || s.contains("available"): ("checkmark.circle.fill", .ready)
        default: ("clock", .muted)
        }
        return RequestStatusPill(label: words, symbol: symbol, tone: tone, compact: true)
    }

    var extras: [String] {
        var parts: [String] = []
        if let seasons, !seasons.isEmpty { parts.append(RequestDetailText.seasons(seasons)) }
        if is4k == true { parts.append("4K") }
        return parts
    }
}

enum RequestDetailText {
    /// "Season 3", "Seasons 1–3", "Seasons 1, 3 and 5".
    static func seasons(_ numbers: [Int]) -> String {
        let sorted = Array(Set(numbers)).sorted()
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if sorted.count == 1 { return "Season \(first)" }
        if last - first + 1 == sorted.count { return "Seasons \(first)\u{2013}\(last)" }
        let words = sorted.map(String.init)
        return "Seasons " + words.dropLast().joined(separator: ", ") + " and " + (words.last ?? "")
    }

    /// The file at a glance: "4K · Dolby Vision · HEVC · EAC3 5.1 · 58.2 GB".
    static func headline(_ file: PlexFile, isShow: Bool) -> String {
        var parts: [String] = []
        if let resolution = file.resolution, !resolution.isEmpty {
            parts.append(file.mixed == true ? "Mostly \(resolution)" : resolution)
        }
        if let hdr = file.hdr, !hdr.isEmpty { parts.append(hdr) }
        if let video = file.video, !video.isEmpty { parts.append(video) }
        if let audio = file.audio, !audio.isEmpty { parts.append(audio) }
        if let size = file.size, !size.isEmpty { parts.append(size) }
        return parts.isEmpty ? (isShow ? "On Plex" : "On Plex, details unknown") : parts.joined(separator: " · ")
    }

    /// The rest: "MKV · 62.4 Mbps · 2 copies", or for a show "64 episodes".
    static func detail(_ file: PlexFile, isShow: Bool) -> String {
        var parts: [String] = []
        if isShow {
            if let episodes = file.episodes {
                parts.append("\(episodes) episode\(episodes == 1 ? "" : "s")")
            }
        } else {
            if let container = file.container, !container.isEmpty { parts.append(container) }
            if let bitrate = file.bitrate, !bitrate.isEmpty { parts.append(bitrate) }
            if let copies = file.copies, copies > 1 { parts.append("\(copies) copies") }
        }
        return parts.joined(separator: " · ")
    }
}

/// The details half of a film's or show's request sheet: On Plex, Downloading, and
/// Requests. It loads `request/detail` itself and deletes requests itself, then
/// tells the screen to refresh its pill.
///
/// `sample` short-circuits all of that for the debug gallery: nothing is fetched,
/// and deleting only removes the row from the sample.
struct RequestDetailsPanel: View {
    let itemType: String
    let itemID: Int
    var sample: RequestDetail?
    var onChanged: () async -> Void = {}

    @Environment(Session.self) private var session
    @State private var detail: RequestDetail?
    @State private var loaded = false
    @State private var confirming: OverseerrRequest?
    @State private var deleting: Int?
    @State private var failure: String?
    @State private var deletedTick = 0

    private var isShow: Bool { itemType == "show" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let detail, detail.enabled != false {
                if detail.unavailable == true {
                    Label("Overseerr didn\u{2019}t answer, so the request details can\u{2019}t be shown right now.",
                          systemImage: "wifi.exclamationmark")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                } else {
                    sections(detail)
                }
            } else if !loaded {
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(height: 12).frame(width: 90)
                    SkeletonBlock(height: 64, radius: MQ.radius)
                }
                .accessibilityLabel("Loading request details")
            }

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqVelvet)
            }
        }
        .animation(.snappy, value: detail)
        .sensoryFeedback(.success, trigger: deletedTick)
        .task { await load() }
        .confirmationDialog(confirmTitle, isPresented: Binding(
            get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                            titleVisibility: .visible, presenting: confirming) { request in
            Button("Delete request", role: .destructive) { Task { await delete(request) } }
            Button("Keep it", role: .cancel) {}
        } message: { _ in
            Text("Overseerr forgets the request\(isShow ? " for those seasons" : ""). Whatever is already on Plex stays.")
        }
    }

    @ViewBuilder
    private func sections(_ detail: RequestDetail) -> some View {
        if let file = detail.file {
            RequestDetailSection("On Plex") {
                RequestFactRow(symbol: "play.rectangle.fill", tone: .ready,
                               headline: RequestDetailText.headline(file, isShow: isShow),
                               detail: RequestDetailText.detail(file, isShow: isShow))
            }
        }

        let downloads = detail.downloads ?? []
        if !downloads.isEmpty {
            RequestDetailSection("Downloading", count: downloads.count) {
                ForEach(Array(downloads.enumerated()), id: \.offset) { index, download in
                    downloadRow(download)
                    if index < downloads.count - 1 { RequestDetailDivider() }
                }
            }
        }

        let requests = detail.requests ?? []
        if !requests.isEmpty {
            RequestDetailSection(requests.count == 1 ? "Request" : "Requests", count: requests.count) {
                ForEach(requests) { request in
                    RequesterRow(name: request.requestedBy, isMine: request.mine == true,
                                 when: request.createdAt, extras: request.extras, pill: request.pill,
                                 canDelete: request.canDelete == true, deleting: deleting == request.id) {
                        confirming = request
                    }
                    if request.id != requests.last?.id { RequestDetailDivider() }
                }
            }
        } else if detail.file == nil, downloads.isEmpty {
            Text("Nobody has asked for this yet.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
        }
    }

    private func downloadRow(_ download: RequestDownload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            RequestFactRow(symbol: "arrow.down.circle.fill", tone: .working,
                           headline: download.title ?? "A release", detail: downloadDetail(download),
                           dense: true)
            RequestProgressTrack(fraction: Double(download.progress ?? 0) / 100,
                                 percent: download.progress,
                                 eta: download.eta,
                                 note: download.progress == nil ? download.status?.capitalized : nil,
                                 indeterminate: download.progress == nil,
                                 height: 5)
                .padding(.leading, 53)
                .padding(.trailing, 14)
                .padding(.bottom, 12)
        }
    }

    private func downloadDetail(_ download: RequestDownload) -> String {
        var parts: [String] = []
        if let season = download.season {
            parts.append(download.episode.map { "S\(season) \u{00B7} E\($0)" } ?? "Season \(season)")
        }
        if let size = download.size, !size.isEmpty { parts.append(size) }
        return parts.joined(separator: " · ")
    }

    private var confirmTitle: String {
        guard let confirming else { return "Delete this request?" }
        if confirming.mine == true { return "Delete your request?" }
        return "Delete \(confirming.requestedBy ?? "their")\u{2019}s request?"
    }

    private func load() async {
        defer { loaded = true }
        if let sample {
            if detail == nil { detail = sample }
            return
        }
        guard let client = session.client else { return }
        if let fetched = try? await client.get("request/detail/\(itemType)/\(itemID)", as: RequestDetail.self) {
            detail = fetched
        }
    }

    private func delete(_ request: OverseerrRequest) async {
        failure = nil
        if sample != nil {
            detail?.requests?.removeAll { $0.id == request.id }
            deletedTick += 1
            return
        }
        guard let client = session.client else { return }
        deleting = request.id
        defer { deleting = nil }
        do {
            _ = try await client.post("request/\(request.id)/delete", as: RequestResult.self)
            detail?.requests?.removeAll { $0.id == request.id }
            deletedTick += 1
            await onChanged()
            await load()
        } catch {
            failure = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
