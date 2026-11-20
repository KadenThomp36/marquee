import SwiftUI
import UIKit

/// Folio — the household's own e-reader app on a Boox Palma — reporting to this
/// account. Per account, like everything in Settings: you switch it on for yourself
/// and pair your own reader, with the same six-digit code the phone app pairs with.
/// The reader shows up here the moment Folio registers.
struct FolioPanel: View {
    @Environment(Session.self) private var session

    @State private var state: FolioIntegration?
    @State private var pairing: PairCode?
    @State private var pairingUntil: Date?
    @State private var unpairing: FolioDevice?
    @State private var failed = false
    @State private var matching: FolioWaiting?
    @State private var ignoring: FolioWaiting?
    @State private var lookingAgain: String?
    @State private var notice: String?

    var body: some View {
        Panel(title: "Folio", symbol: "book.pages",
              note: "Your reader sends every sitting here — time, pages and chapters — and your shelf keeps up on its own.") {
            if let state {
                VStack(alignment: .leading, spacing: 0) {
                    Toggle(isOn: Binding(get: { state.enabled },
                                         set: { value in Task { await update(.init(enabled: value)) } })) {
                        label("Send reading from Folio",
                              state.enabled ? "On. Sittings from your reader land on your shelf."
                                            : "Off. Your reader keeps its sittings until you switch this back on.")
                    }
                    .tint(Color.mqBrassFill)

                    if state.enabled {
                        Divider().overlay(Color.mqHairline).padding(.vertical, 8)
                        Toggle(isOn: Binding(get: { state.autoCapture },
                                             set: { value in Task { await update(.init(autoCapture: value)) } })) {
                            label("Record sittings automatically",
                                  "This controls recording on the reader. On, Folio times a sitting from opening a book to putting it down. Off, it records only the sittings you start on the reader. Folio picks up a change the next time it syncs.")
                        }
                        .tint(Color.mqBrassFill)

                        Divider().overlay(Color.mqHairline).padding(.top, 8)
                        devices(state.devices)
                        pairBlock
                        if let waiting = state.waiting, !waiting.isEmpty {
                            waitingSection(waiting)
                        }
                        // outside the section, so resolving the last one still says so
                        if let notice {
                            Label(notice, systemImage: "checkmark.circle")
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqBrass)
                                .padding(.top, 12)
                                .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                }
            } else if failed {
                Text("Couldn’t reach your server for this.")
                    .font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            } else {
                Text("Loading…").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            }
        }
        .task { await load() }
        .sheet(item: $matching) { waiting in
            FolioMatchSheet(waiting: waiting) { request in
                await match(request)
            }
        }
        .confirmationDialog("Ignore \u{201C}\(ignoring?.title ?? "")\u{201D}?",
                            isPresented: .init(get: { ignoring != nil },
                                               set: { if !$0 { ignoring = nil } }),
                            titleVisibility: .visible) {
            Button("Ignore this file", role: .destructive) {
                if let waiting = ignoring { Task { await ignore(waiting) } }
                ignoring = nil
            }
        } message: {
            Text("Its \(ignoring?.sittings ?? 0) sitting\(ignoring?.sittings == 1 ? " is" : "s are") dropped, and Folio\u{2019}s sittings in this file won\u{2019}t be kept from now on. For personal documents, not books.")
        }
        .confirmationDialog("Unpair \(unpairing?.displayName ?? "this reader")?",
                            isPresented: .init(get: { unpairing != nil },
                                               set: { if !$0 { unpairing = nil } }),
                            titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                if let device = unpairing { Task { await unpair(device) } }
                unpairing = nil
            }
        } message: {
            Text("It stops syncing until you pair it again. Sittings already here stay.")
        }
    }

    @ViewBuilder
    private func devices(_ devices: [FolioDevice]) -> some View {
        if devices.isEmpty {
            Text("No reader paired yet.")
                .font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                .padding(.vertical, 12)
        }
        ForEach(devices) { device in
            HStack(spacing: 11) {
                Image(systemName: "book.pages")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(device.signedIn == false ? Color.mqInkMuted : Color.mqChartAqua)
                    .frame(width: 34, height: 34)
                    .background(Color.mqPanelRaised, in: .rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.displayName)
                        .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.mqInk)
                    Text(detail(for: device))
                        .font(.mqCaption)
                        .foregroundStyle(device.signedIn == false ? Color.mqVelvet : Color.mqInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(device.sessionsSynced)")
                        .font(MarqueeFont.body(16, .heavy, relativeTo: .headline))
                        .foregroundStyle(Color.mqInk)
                        .monospacedDigit()
                    Text(device.sessionsSynced == 1 ? "sitting" : "sittings")
                        .font(MarqueeFont.body(10.5, .medium, relativeTo: .caption2))
                        .foregroundStyle(Color.mqInkMuted)
                }
                Menu {
                    Button("Unpair \(device.displayName)", role: .destructive) { unpairing = device }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.mqInkMuted)
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .accessibilityLabel("Options for \(device.displayName)")
            }
            .padding(.vertical, 11)
            .accessibilityElement(children: .combine)
            .accessibilityAction(named: "Unpair") { unpairing = device }
            Divider().overlay(Color.mqHairline)
        }
    }

    @ViewBuilder
    private var pairBlock: some View {
        if let pairing, let until = pairingUntil {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ForEach(Array(pairing.code.enumerated()), id: \.offset) { _, digit in
                        Text(String(digit))
                            .font(MarqueeFont.wordmark(30, relativeTo: .title))
                            .foregroundStyle(Color.mqBrass)
                            .frame(minWidth: 26)
                            .padding(.bottom, 3)
                            .overlay(alignment: .bottom) {
                                Rectangle().fill(Color.mqBrassDim).frame(height: 2)
                            }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Pairing code \(pairing.code.map(String.init).joined(separator: " "))")
                Text("Type this into Folio when its setup asks for a Marquee pairing code. It works once.")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(until.timeIntervalSince(context.date)))
                    Text(left > 0 ? "Expires in \(left / 60):\(String(format: "%02d", left % 60))"
                                  : "That code expired.")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .monospacedDigit()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(Color.mqPanelRaised, in: .rect(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.mqBrassDim, lineWidth: 1) }
            .padding(.top, 12)
            .task(id: pairing.code) { await watchForReader(until: until) }
        } else {
            Button {
                Task { await startPairing() }
            } label: {
                Label("Pair a reader", systemImage: "plus")
            }
            .buttonStyle(.mqChip)
            .padding(.top, 12)
        }
    }

    // MARK: - Waiting for a book

    /// Sittings Folio sent for a file Marquee can't place yet. Nothing is lost: they're
    /// kept, Marquee keeps looking, and Match / Ignore settle one by hand.
    private func waitingSection(_ waiting: [FolioWaiting]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Waiting for a book")
                    .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                Text("\(waiting.count)")
                    .font(MarqueeFont.body(11, .bold, relativeTo: .caption2))
                    .foregroundStyle(Color.mqBrass)
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Color.mqBrassSoft, in: .capsule)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text("Folio sent these sittings, but Marquee can\u{2019}t tell which book they belong to yet. They\u{2019}re kept safe. Match one to put its sittings on your shelf, or ignore personal documents.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            ForEach(waiting) { item in
                waitingRow(item)
                if item.id != waiting.last?.id { Divider().overlay(Color.mqHairline) }
            }
        }
        .padding(.top, 18)
    }

    private func waitingRow(_ item: FolioWaiting) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // a dashed, coverless tile: "no book yet", without an alarm colour
            Text(String(item.title.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
                .font(MarqueeFont.body(15, .heavy, relativeTo: .headline))
                .foregroundStyle(Color.mqInkMuted)
                .frame(width: 36, height: 54)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.mqHairlineBold, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.byline).font(.mqCaption).foregroundStyle(Color.mqInkSoft)
                Text(meta(item)).font(.mqCaption).foregroundStyle(Color.mqInkMuted).monospacedDigit()
                Text(why(item))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Match") { matching = item }
                        .buttonStyle(.mqChip(on: true))
                    Button("Ignore") { ignoring = item }
                        .buttonStyle(.mqChip)
                    if item.reason != nil {
                        Button(lookingAgain == item.key ? "Looking\u{2026}" : "Look now") {
                            Task { await lookAgain(item) }
                        }
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqBrass)
                        .disabled(lookingAgain != nil)
                    }
                }
                .padding(.top, 5)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
    }

    private func meta(_ item: FolioWaiting) -> String {
        var parts = ["\(item.sittings) sitting\(item.sittings == 1 ? "" : "s")"]
        if item.minutes > 0 { parts.append(BookStatsFormat.duration(item.minutes)) }
        if let first = MQTime.date(from: item.firstAt) {
            parts.append("since \(first.formatted(.dateTime.month(.abbreviated).day()))")
        }
        return parts.joined(separator: " · ")
    }

    private func why(_ item: FolioWaiting) -> String {
        var next = ""
        if let date = MQTime.date(from: item.nextAttemptAt) {
            next = Calendar.current.isDateInToday(date)
                ? " Looking again at \(date.formatted(date: .omitted, time: .shortened))."
                : " Looking again \(date.formatted(.dateTime.weekday(.wide)))."
        }
        switch item.reason {
        case "unavailable": return "Hardcover isn\u{2019}t answering right now.\(next)"
        case "no match": return "Hardcover doesn\u{2019}t know this file\u{2019}s book.\(next)"
        default: return "Looking it up\u{2026}"
        }
    }

    private func label(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                .foregroundStyle(Color.mqInk)
            Text(detail)
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detail(for device: FolioDevice) -> String {
        guard device.signedIn != false else { return "Signed out — unpair it, then pair it again" }
        var parts: [String] = []
        if let synced = device.lastSyncAt, !synced.isEmpty {
            parts.append("Synced \(MQTime.relative(synced))")
        } else {
            parts.append("Paired, waiting for its first sync")
        }
        if let version = device.appVersion, !version.isEmpty { parts.append("Folio \(version)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Server

    private func load() async {
        guard let client = session.client else { return }
        do {
            state = try await client.get("integrations/folio", as: FolioIntegration.self)
            failed = false
        } catch {
            failed = state == nil
        }
    }

    private func update(_ change: FolioIntegrationUpdate) async {
        guard let client = session.client else { return }
        if let next = try? await client.post("integrations/folio", body: change, as: FolioIntegration.self) {
            state = next
        }
    }

    private func match(_ request: FolioWaitingRequest) async {
        guard let client = session.client,
              let next = try? await client.post("integrations/folio/waiting/match", body: request,
                                                as: FolioIntegration.self) else { return }
        let count = next.imported ?? 0
        notice = "\(count) sitting\(count == 1 ? "" : "s") added to \(next.title ?? "your shelf")"
        state = next
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func ignore(_ item: FolioWaiting) async {
        guard let client = session.client,
              let next = try? await client.post("integrations/folio/waiting/ignore",
                                                body: FolioWaitingRequest(key: item.key),
                                                as: FolioIntegration.self) else { return }
        notice = "Ignoring \(item.title)"
        state = next
    }

    private func lookAgain(_ item: FolioWaiting) async {
        guard let client = session.client else { return }
        lookingAgain = item.key
        defer { lookingAgain = nil }
        guard let next = try? await client.post("integrations/folio/waiting/retry",
                                                body: FolioWaitingRequest(key: item.key),
                                                as: FolioIntegration.self) else { return }
        let count = next.imported ?? 0
        notice = count > 0 ? "Found it \u{2014} \(count) sitting\(count == 1 ? "" : "s") added"
                           : "Still no match \u{2014} Marquee will keep looking"
        state = next
    }

    private func unpair(_ device: FolioDevice) async {
        guard let client = session.client else { return }
        _ = try? await client.delete("integrations/folio/devices/\(device.id)", as: Empty.self)
        await load()
    }

    private func startPairing() async {
        guard let client = session.client,
              let code = try? await client.post("pair/start", as: PairCode.self) else { return }
        pairingUntil = Date().addingTimeInterval(TimeInterval(code.expiresIn ?? 300))
        pairing = code
    }

    /// Poll while the code is live; the reader appears the moment Folio registers.
    private func watchForReader(until: Date) async {
        let known = state?.devices.count ?? 0
        while Date() < until, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3))
            guard let client = session.client,
                  let next = try? await client.get("integrations/folio", as: FolioIntegration.self)
            else { continue }
            if next.devices.count > known {
                state = next
                pairing = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
        }
        if !Task.isCancelled { pairing = nil }
    }
}

/// Which book is it? Your own shelf first — it works even while Hardcover is down —
/// then Hardcover's search, prefilled with what the file says about itself.
struct FolioMatchSheet: View {
    let waiting: FolioWaiting
    let onPick: (FolioWaitingRequest) async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var shelf: [ReadingItem] = []
    @State private var results: [BookSearchResult] = []
    @State private var hardcover: Phase = .idle
    @State private var picking = false

    enum Phase { case idle, searching, done, down }

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(fileLine)
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Color.mqInkMuted)
                            TextField("Search for the book", text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                        }
                        .padding(12)
                        .mqPanel()

                        let local = shelfMatches
                        if !local.isEmpty {
                            group("On your shelf")
                            ForEach(local) { item in
                                row(cover: item.cover, title: item.displayTitle,
                                    detail: [item.author, item.year?.text, item.pages.map { "\($0)p" }]) {
                                    await pick(FolioWaitingRequest(key: waiting.key, bookID: item.id))
                                }
                            }
                        }
                        group("From Hardcover")
                        switch hardcover {
                        case .searching:
                            ProgressView().tint(Color.mqBrass).padding(.vertical, 8)
                        case .down:
                            hint("Hardcover isn\u{2019}t answering. Pick from your shelf, or try again later. The sittings stay safe either way.")
                        case .done where results.isEmpty:
                            hint("Nothing found. Try fewer words.")
                        default:
                            ForEach(results) { result in
                                row(cover: result.cover, title: result.displayTitle,
                                    detail: [result.author, result.year?.text, result.pages.map { "\($0)p" }]) {
                                    await pick(FolioWaitingRequest(key: waiting.key, result: result))
                                }
                            }
                        }
                    }
                    .padding(MQ.gutter)
                }
                .disabled(picking)
            }
            .navigationTitle("Which book is this?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationBackground(Color.mqGround)
        .onAppear {
            if query.isEmpty { query = [waiting.title, waiting.authors.first].compactMap { $0 }.joined(separator: " ") }
        }
        .task {
            guard let client = session.client,
                  let shelves = try? await client.get("reading", as: ReadingShelves.self) else { return }
            shelf = shelves.books.all
        }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    private var fileLine: String {
        var line = "Folio\u{2019}s file: \(waiting.title)"
        if !waiting.authors.isEmpty { line += " by \(waiting.authors.joined(separator: ", "))" }
        if let isbn = waiting.isbn { line += " · ISBN \(isbn)" }
        return line + " · \(waiting.sittings) sitting\(waiting.sittings == 1 ? "" : "s") waiting"
    }

    private static let stop: Set<String> = ["the", "and", "for", "with", "from", "into", "book", "novel"]

    private var shelfMatches: [ReadingItem] {
        let words = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init).filter { $0.count > 2 && !Self.stop.contains($0) }
        guard !words.isEmpty else { return [] }
        let need = max(1, Int((Double(words.count) / 2).rounded(.up)))
        return shelf.filter { item in
            let hay = "\(item.displayTitle) \(item.author ?? "")".lowercased()
            return words.filter { hay.contains($0) }.count >= need
        }.prefix(6).map { $0 }
    }

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard let client = session.client, !trimmed.isEmpty else { hardcover = .idle; return }
        hardcover = .searching
        do {
            let response = try await client.get("books/search", query: ["q": trimmed], as: BookSearchResponse.self)
            results = response.results
            hardcover = response.unavailable == true ? .down : .done
        } catch {
            results = []
            hardcover = .down
        }
    }

    private func pick(_ request: FolioWaitingRequest) async {
        picking = true
        await onPick(request)
        dismiss()
    }

    private func group(_ title: String) -> some View {
        Text(title).mqEyebrowStyle().padding(.top, 8)
    }

    private func hint(_ text: String) -> some View {
        Text(text).font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(cover: String?, title: String, detail: [String?],
                     action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            HStack(spacing: 11) {
                CoverArt(url: cover, radius: 6).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MarqueeFont.body(14, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                        .multilineTextAlignment(.leading)
                    Text(detail.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }
                Spacer(minLength: 4)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .mqPanel()
        }
        .buttonStyle(.plain)
    }
}
