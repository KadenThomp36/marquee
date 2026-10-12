import SwiftUI

/// One title, as the progress sheet needs to see it.
///
/// The server stores a book's position in pages and a manga's in chapters, whatever
/// the reader thinks in. Everything here converts for display only, and hands the
/// stored value straight back when the reader didn't move it — a round trip through
/// percent or chapters drifts the number otherwise.
struct ReadingProgressTarget: Identifiable, Equatable {
    let kind: ReadingKind
    let itemID: Int
    let title: String
    /// The stored position: pages for a book, chapters for manga.
    let progress: Int
    let pages: Int?
    /// A manga's chapter count, or a book's table-of-contents length.
    let chapters: Int?
    let rawMode: String?
    /// Set when this sheet is ending a live session.
    let live: ActiveSession?
    /// Chapter number → title, when the book has a TOC or the series a chapter list.
    var chapterTitles: [Int: String] = [:]

    var id: String { "\(kind.rawValue):\(itemID):\(live?.id ?? 0)" }

    init(kind: ReadingKind, itemID: Int, title: String, progress: Int, pages: Int?,
         chapters: Int?, rawMode: String?, live: ActiveSession?) {
        self.kind = kind
        self.itemID = itemID
        self.title = title
        self.progress = progress
        self.pages = pages
        self.chapters = chapters
        self.rawMode = rawMode
        self.live = live
    }

    /// From a shelf card or a Home rail card.
    init(item: ReadingItem, kind: ReadingKind, live: ActiveSession? = nil) {
        self.init(kind: kind, itemID: item.id, title: item.displayTitle,
                  progress: item.progress ?? 0, pages: item.pages, chapters: item.chapters,
                  rawMode: item.mode, live: live)
    }

    /// From a running session, when the shelf copy of the title isn't to hand.
    init(session: ActiveSession, progress: Int?) {
        self.init(kind: session.readingKind, itemID: session.itemID,
                  title: session.title ?? "Reading",
                  progress: progress ?? session.startPos ?? 0,
                  pages: session.pages,
                  chapters: session.readingKind == .book ? session.bookChapters : session.chapters,
                  rawMode: session.mode, live: session)
    }

    // MARK: - Units

    /// The stored total — pages for a book, chapters for manga. Nil when unknown
    /// (an ongoing series with no count yet).
    var canonicalTotal: Int? {
        let total = kind == .book ? pages : chapters
        guard let total, total > 0 else { return nil }
        return total
    }

    /// The unit the reader chose for this title, falling back to one that works with
    /// what's actually known about it.
    var mode: ProgressMode {
        let natural: ProgressMode = kind == .manga ? .chapters : .pages
        let preferred = ProgressMode(rawValue: rawMode ?? "") ?? natural
        switch preferred {
        case .pct:
            return canonicalTotal == nil ? natural : .pct
        case .chapters:
            if kind == .manga { return .chapters }
            return (pages ?? 0) > 0 && (chapters ?? 0) > 0 ? .chapters : .pages
        case .pages:
            return natural
        }
    }

    /// The top of the track in display units.
    var displayTotal: Int? {
        switch mode {
        case .pct: return 100
        case .chapters: return kind == .book ? chapters : canonicalTotal
        case .pages: return canonicalTotal
        }
    }

    func display(_ stored: Int) -> Int {
        switch mode {
        case .pct:
            guard let total = canonicalTotal else { return stored }
            return min(100, Int((Double(stored) / Double(total) * 100).rounded()))
        case .chapters where kind == .book:
            guard let pages, pages > 0, let chapters else { return stored }
            return min(chapters, Int((Double(stored) / Double(pages) * Double(chapters)).rounded()))
        default:
            return stored
        }
    }

    func stored(_ shown: Int) -> Int {
        switch mode {
        case .pct:
            guard let total = canonicalTotal else { return shown }
            return min(total, Int((Double(shown) / 100 * Double(total)).rounded()))
        case .chapters where kind == .book:
            guard let pages, let chapters, chapters > 0 else { return shown }
            return min(pages, Int((Double(shown) / Double(chapters) * Double(pages)).rounded()))
        default:
            return shown
        }
    }

    func unitName(_ count: Int) -> String {
        switch mode {
        case .pct: return "%"
        case .chapters: return count == 1 ? "chapter" : "chapters"
        case .pages: return count == 1 ? "page" : "pages"
        }
    }

    /// "p. 214", "ch 12", "40%" — a position in words.
    func positionLabel(_ shown: Int) -> String {
        switch mode {
        case .pct: return "\(shown)%"
        case .chapters: return "ch \(shown)"
        case .pages: return "p. \(shown)"
        }
    }
}

/// What the sheet did, so the screen behind it can update in place.
enum ReadingProgressOutcome {
    case progress(Int)
    case finished(Int)
    case sessionEnded(Int)
    case discarded
}

/// "Where did you get to?" — one sheet for every way progress gets logged: from the
/// detail page, a shelf card, Home's Continue reading rail, or the end of a session.
///
/// A big readout in the unit you track the title in, a track to drag, chips for the
/// common jumps, and the number itself to tap for an exact position. Finishing is a
/// separate, deliberate button that only appears once you're at the end — one tap
/// never finishes a book. Ending a session shows that session's own numbers above
/// Save, and discarding one asks first.
struct ReadingProgressSheet: View {
    let target: ReadingProgressTarget
    let onSaved: (ReadingProgressOutcome) async -> Void

    @Environment(Session.self) private var appSession
    @Environment(\.dismiss) private var dismiss
    @State private var position = 0
    @State private var prepared = false
    @State private var typing = false
    @FocusState private var fieldFocused: Bool
    @State private var busy = false
    @State private var failure: String?
    @State private var confirmingDiscard = false
    @State private var summary: String?
    @State private var savedTick = 0

    private var upper: Int? { target.displayTotal }
    private var isLive: Bool { target.live != nil }
    private var reachedEnd: Bool {
        guard let upper, target.canonicalTotal != nil else { return false }
        return position >= upper
    }

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let summary {
                            summaryView(summary)
                        } else {
                            if isLive { sessionStrip }
                            readout
                            track
                            chips
                            if let failure {
                                Label(failure, systemImage: "exclamationmark.triangle")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqVelvet)
                            }
                            actions
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle(isLive ? "End session" : "Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                // Number pads have no return key; this is the way out of typing.
                ToolbarItem(placement: .keyboard) {
                    Button("Done") {
                        typing = false
                        fieldFocused = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.mqGround)
        .sensoryFeedback(.selection, trigger: tickKey)
        .sensoryFeedback(.success, trigger: savedTick)
        .confirmationDialog("Discard this session?", isPresented: $confirmingDiscard,
                            titleVisibility: .visible) {
            Button("Discard session", role: .destructive) { Task { await discard() } }
            Button("Keep it running", role: .cancel) {}
        } message: {
            Text("Nothing from it will be logged, and your progress stays where it was.")
        }
        .onAppear {
            guard !prepared else { return }
            position = target.display(target.progress)
            prepared = true
        }
        .onChange(of: position) { _, new in
            let clamped = clamp(new)
            if clamped != new { position = clamped }
        }
    }

    // MARK: - Pieces

    private var readout: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(target.title)
                .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                .foregroundStyle(Color.mqInkSoft)
                .lineLimit(2)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if typing {
                    TextField("0", value: $position, format: .number)
                        .keyboardType(.numberPad)
                        .focused($fieldFocused)
                        .font(MarqueeFont.body(44, .bold, relativeTo: .largeTitle))
                        .foregroundStyle(Color.mqInk)
                        .frame(maxWidth: 170)
                        .onSubmit { typing = false }
                } else {
                    Button {
                        typing = true
                        fieldFocused = true
                    } label: {
                        Text(verbatim: target.mode == .pct ? "\(position)%" : "\(position)")
                            .font(MarqueeFont.body(44, .bold, relativeTo: .largeTitle))
                            .foregroundStyle(Color.mqInk)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(position)))
                            .animation(.snappy(duration: 0.2), value: position)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Position, \(target.positionLabel(position))")
                    .accessibilityHint("Type an exact position")
                }
                Text(caption)
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkMuted)
                    .lineLimit(2)
            }

            if let chapterTitle {
                Text(chapterTitle)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqBrass)
                    .lineLimit(1)
            }
        }
    }

    private var caption: String {
        switch target.mode {
        case .pct:
            return target.canonicalTotal.map { "p. \(target.stored(position)) of \($0)" } ?? ""
        case .chapters:
            guard let upper else { return target.unitName(position) }
            if target.kind == .book { return "of \(upper) chapters · p. \(target.stored(position))" }
            return "of \(upper) chapters"
        case .pages:
            return upper.map { "of \($0) pages" } ?? "pages"
        }
    }

    private var chapterTitle: String? {
        guard target.mode == .chapters, position > 0 else { return nil }
        guard let title = target.chapterTitles[position], !title.isEmpty else { return nil }
        return title
    }

    @ViewBuilder
    private var track: some View {
        if let upper, upper > 0 {
            VStack(alignment: .leading, spacing: 6) {
                Slider(value: Binding(get: { Double(position) },
                                      set: { position = Int($0.rounded()) }),
                       in: 0...Double(upper), step: 1)
                    .tint(Color.mqBrass)
                    .accessibilityLabel("Progress")
                    .accessibilityValue("\(target.positionLabel(position)) of \(upper)")
                HStack {
                    Text("0")
                    Spacer()
                    if let mark = sessionStartDisplay, isLive {
                        Text("session began at \(target.positionLabel(mark))")
                        Spacer()
                    }
                    Text(verbatim: target.mode == .pct ? "100%" : "\(upper)")
                }
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .monospacedDigit()
            }
        }
    }

    private var increments: [Int] {
        switch target.mode {
        case .pages: [1, 10, 25, 50]
        case .chapters: [1, 3, 5]
        case .pct: [1, 5, 10]
        }
    }

    private var chips: some View {
        ChipRow {
            Button { nudge(-1) } label: {
                Image(systemName: "minus").frame(minWidth: 18)
            }
            .buttonStyle(.mqChip)
            .accessibilityLabel("Back one \(target.unitName(1))")

            ForEach(increments, id: \.self) { step in
                Button { nudge(step) } label: {
                    Text("+\(step)").monospacedDigit()
                }
                .buttonStyle(.mqChip)
                .accessibilityLabel("Forward \(step) \(target.unitName(step))")
            }
        }
    }

    @ViewBuilder
    private var sessionStrip: some View {
        if let live = target.live, let started = MQTime.date(from: live.startedAt) {
            HStack(alignment: .top, spacing: 18) {
                stat("Reading for") {
                    Text(started, style: .timer)
                }
                stat("This session") {
                    Text(gainedText)
                }
                if let pace = paceText(since: started) {
                    stat("Pace") { Text(pace) }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.mqBrassSoft, in: .rect(cornerRadius: MQ.radiusSmall))
        }
    }

    private func stat<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).mqEyebrowStyle()
            value()
                .font(MarqueeFont.body(17, .bold, relativeTo: .headline))
                .foregroundStyle(Color.mqInk)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await save() }
            } label: {
                Text(isLive ? "Save session" : "Save")
            }
            .buttonStyle(.mqPrimary)
            .disabled(busy)

            if reachedEnd {
                Button {
                    Task { await finish() }
                } label: {
                    Label("Finished it", systemImage: "checkmark.seal")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.mqChip(on: true))
                .disabled(busy)
                .frame(maxWidth: .infinity)
            }

            if isLive {
                Button("Discard session") { confirmingDiscard = true }
                    .buttonStyle(.mqQuiet)
                    .disabled(busy)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func summaryView(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(Color.mqBrass)
                .symbolEffect(.bounce, value: savedTick)
            Text(text)
                .font(MarqueeFont.body(17, .bold, relativeTo: .headline))
                .foregroundStyle(Color.mqInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Session numbers

    private var sessionStartDisplay: Int? {
        guard let live = target.live else { return nil }
        return target.display(live.startPos ?? target.progress)
    }

    private var gained: Int {
        max(0, position - (sessionStartDisplay ?? position))
    }

    private var gainedText: String {
        target.mode == .pct ? "+\(gained)%" : "+\(gained) \(target.unitName(gained))"
    }

    private func paceText(since started: Date) -> String? {
        let minutes = Date().timeIntervalSince(started) / 60
        guard minutes >= 3, gained > 0 else { return nil }
        let perHour = Double(gained) / minutes * 60
        let unit: String
        switch target.mode {
        case .pct: unit = "%/hr"
        case .chapters: unit = "ch/hr"
        case .pages: unit = "p/hr"
        }
        return "~\(Int(perHour.rounded())) \(unit)"
    }

    /// Haptic ticks that scale with the unit: one per chapter, but one per few pages
    /// rather than a buzz for every page of a 600-page book.
    private var tickKey: Int {
        switch target.mode {
        case .chapters: return position
        case .pct: return position / 5
        case .pages: return position / max(1, (upper ?? 400) / 40)
        }
    }

    // MARK: - Actions

    private func clamp(_ value: Int) -> Int {
        max(0, min(upper ?? Int.max, value))
    }

    private func nudge(_ delta: Int) {
        position = clamp(position + delta)
    }

    /// Untouched means untouched: hand the stored value back so display rounding
    /// can't move it.
    private var storedPosition: Int {
        position == target.display(target.progress) ? target.progress : target.stored(position)
    }

    private func save() async {
        guard let client = appSession.client else { return }
        busy = true
        defer { busy = false }
        failure = nil
        let pos = storedPosition
        let path = "\(target.kind.path)/\(target.itemID)"

        if isLive {
            do {
                try await client.post("\(path)/session/end",
                                      body: EndSessionRequest(pos: pos), as: Empty.self)
            } catch {
                // Never "nice session" for one that didn't save.
                failure = "Couldn't save the session — it's still running. Try again in a moment."
                return
            }
            savedTick += 1
            withAnimation(.snappy) { summary = sessionSummary }
            await onSaved(.sessionEnded(pos))
            try? await Task.sleep(for: .seconds(1.6))
            dismiss()
            return
        }

        guard pos != target.progress else {
            dismiss()
            return
        }
        do {
            try await client.post("\(path)/state",
                                  body: ReadingStateRequest(progress: pos), as: Empty.self)
        } catch {
            // Tiny and idempotent: queue it and let the sheet go.
            OfflineStore.shared.enqueue(PendingWrite(
                .readingProgress(kind: target.kind.path, itemID: target.itemID, progress: pos)))
        }
        savedTick += 1
        await onSaved(.progress(pos))
        dismiss()
    }

    private func finish() async {
        guard let client = appSession.client, let total = target.canonicalTotal else { return }
        busy = true
        defer { busy = false }
        failure = nil
        let path = "\(target.kind.path)/\(target.itemID)"

        if isLive {
            do {
                try await client.post("\(path)/session/end",
                                      body: EndSessionRequest(pos: total), as: Empty.self)
            } catch {
                failure = "Couldn't save the session — it's still running. Try again in a moment."
                return
            }
        }
        do {
            try await client.post("\(path)/state",
                                  body: ReadingStateRequest(state: .finished, progress: total),
                                  as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .readingProgress(kind: target.kind.path, itemID: target.itemID, progress: total)))
            OfflineStore.shared.enqueue(PendingWrite(
                .readingState(kind: target.kind.path, itemID: target.itemID, state: "finished")))
        }
        savedTick += 1
        withAnimation(.snappy) { summary = "Finished \(target.title)." }
        await onSaved(.finished(total))
        try? await Task.sleep(for: .seconds(1.4))
        dismiss()
    }

    private func discard() async {
        guard let client = appSession.client else { return }
        busy = true
        defer { busy = false }
        failure = nil
        do {
            try await client.post("\(target.kind.path)/\(target.itemID)/session/end",
                                  body: EndSessionRequest(discard: true), as: Empty.self)
        } catch {
            failure = "Couldn't discard the session. Try again in a moment."
            return
        }
        await onSaved(.discarded)
        dismiss()
    }

    private var sessionSummary: String {
        var parts: [String] = []
        if gained > 0 { parts.append(gainedText) }
        if let live = target.live, let started = MQTime.date(from: live.startedAt) {
            let minutes = max(1, Int(Date().timeIntervalSince(started) / 60))
            parts.append("in \(MQTime.clock(minutes: minutes))")
        }
        let detail = parts.joined(separator: " ")
        return detail.isEmpty ? "Session saved." : "Nice session — \(detail)."
    }
}
