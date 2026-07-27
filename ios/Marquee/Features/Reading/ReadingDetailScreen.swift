import SwiftUI

/// A book or a manga, tracked or not.
///
/// The subtle part is progress: a title remembers whether its owner thinks in pages,
/// percent or chapters, but the server always stores pages for a book. Converting on
/// every write drifts the number, so a field the user didn't touch is passed straight
/// back through untouched.
struct ReadingDetailScreen: View {
    let kind: ReadingKind
    let itemID: Int
    /// Set when arriving from search — the item isn't on the shelf yet.
    var isHardcoverPreview = false

    @Environment(Session.self) private var session
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss

    @State private var detail: ReadingDetail?
    @State private var error: String?
    @State private var editingSession: ReadingSession?
    @State private var showingMatches = false
    @State private var busy = false

    private var item: ReadingDetailItem? { detail?.item }
    private var state: ReadingStateRow? { detail?.state }
    private var total: Int? { kind == .book ? item?.pages : item?.chapters }
    private var mode: ProgressMode {
        ProgressMode(rawValue: state?.mode ?? "") ?? (kind == .manga ? .chapters : .pages)
    }

    var body: some View {
        MarqueeScreen {
            if let detail, let item {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        hero(item)
                        if detail.tracked { tracked(detail) } else { untracked() }
                        extras(detail, item)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 30)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                SkeletonBlock(height: 260).padding(MQ.gutter)
            }
        }
        .navigationTitle(item?.displayTitle ?? (kind == .book ? "Book" : "Manga"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .sheet(item: $editingSession) { entry in
            SessionEditorSheet(entry: entry, kind: kind, mode: mode, total: total,
                               chapters: item?.chapters, pages: item?.pages) {
                await load()
            }
        }
        .sheet(isPresented: $showingMatches) {
            RematchSheet(bookID: itemID) { await load() }
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private func hero(_ item: ReadingDetailItem) -> some View {
        ZStack(alignment: .top) {
            FilledArt(url: item.cover, height: 220)
                .opacity(0.22)
                .blur(radius: 20)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)

            HStack(alignment: .top, spacing: 16) {
                CoverArt(url: item.cover, radius: 12).frame(width: MQ.heroPoster(typeSize) - 2)

                VStack(alignment: .leading, spacing: 7) {
                    if kind == .book, let author = item.author, !author.isEmpty {
                        Text(author)
                            .font(.mqSub)
                            .foregroundStyle(Color.mqBrass)
                    } else if let origin = item.origin {
                        Text([origin, item.status].compactMap { $0 }.joined(separator: " · "))
                            .font(.mqSub)
                            .foregroundStyle(Color.mqBrass)
                    }
                    if let series = item.series, !series.isEmpty {
                        Label(series + (item.seriesPos.map { " #\($0)" } ?? ""),
                              systemImage: "books.vertical")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkSoft)
                    }
                    ChipRow {
                        if let total { MetaChip(text: "\(total) \(kind.unit)") }
                        if let volumes = item.volumes { MetaChip(text: "\(volumes) vols") }
                        if let rating = item.communityRating ?? item.score {
                            MetaChip(text: String(format: "%.1f", rating),
                                     symbol: "star.fill", tinted: true)
                        }
                        ForEach(item.genreList.prefix(3), id: \.self) { MetaChip(text: $0) }
                    }
                    if let year = item.year?.value {
                        Text(String(year))
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
            .padding(.top, 12)
        }
    }

    // MARK: - Tracked

    @ViewBuilder
    private func tracked(_ detail: ReadingDetail) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Shelf", selection: Binding(
                get: { state?.readingState ?? .want },
                set: { newValue in Task { await setState(newValue) } })) {
                ForEach(ReadingState.allCases, id: \.self) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            if state?.readingState != .want { progressControls }

            sessionButton(detail)

            HStack {
                Text("My rating").mqEyebrowStyle()
                Spacer()
                StarRating(rating: Binding(
                    get: { state?.rating },
                    set: { value in Task { await save(ReadingStateRequest(rating: value)) } })) { _ in }
            }

            dates
        }
        .padding(.horizontal, MQ.gutter)
    }

    @ViewBuilder
    private var progressControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressBar(fraction: fraction, height: 8)

            if availableModes.count > 1 {
                Picker("Progress mode", selection: Binding(
                    get: { mode },
                    set: { value in Task { await save(ReadingStateRequest(mode: value)) } })) {
                    ForEach(availableModes, id: \.self) { Text(label(for: $0)).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: 10) {
                Text("Progress").mqEyebrowStyle()
                Spacer()
                Button { Task { await step(-1) } } label: {
                    Image(systemName: "minus").frame(width: 34, height: 34)
                }
                .buttonStyle(.mqChip)

                Text(displayedProgress)
                    .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
                    .foregroundStyle(Color.mqInk)
                    .monospacedDigit()
                    .frame(minWidth: 62)

                Button { Task { await step(1) } } label: {
                    Image(systemName: "plus").frame(width: 34, height: 34)
                }
                .buttonStyle(.mqChip)
            }
            Text(progressHint)
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
        }
    }

    private var availableModes: [ProgressMode] {
        if kind == .book {
            var modes: [ProgressMode] = [.pages]
            if item?.pages != nil { modes.append(.pct) }
            if item?.chapters != nil, item?.pages != nil { modes.append(.chapters) }
            return modes
        }
        return total != nil ? [.chapters, .pct] : [.chapters]
    }

    private func label(for mode: ProgressMode) -> String {
        switch mode {
        case .pages: "Pages"
        case .pct: "%"
        case .chapters: "Chapters"
        }
    }

    private var fraction: Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(state?.progress ?? 0) / Double(total))
    }

    private var displayedProgress: String {
        let progress = state?.progress ?? 0
        switch mode {
        case .pct:
            guard let total, total > 0 else { return "\(progress)" }
            return "\(Int((Double(progress) / Double(total) * 100).rounded()))%"
        case .chapters where kind == .book:
            guard let pages = item?.pages, pages > 0, let chapters = item?.chapters
            else { return "\(progress)" }
            return "ch \(min(chapters, Int((Double(progress) / Double(pages) * Double(chapters)).rounded())))"
        default:
            return "\(progress)"
        }
    }

    private var progressHint: String {
        guard let total else { return kind.unit }
        switch mode {
        case .pct: return "\(state?.progress ?? 0)/\(total) \(kind.unit)"
        case .chapters where kind == .book:
            return "of \(item?.chapters ?? 0) chapters · \(Int(fraction * 100))%"
        default: return "of \(total) \(kind.unit) · \(Int(fraction * 100))%"
        }
    }

    @ViewBuilder
    private func sessionButton(_ detail: ReadingDetail) -> some View {
        Button {
            Task { await startSession() }
        } label: {
            Label("Start a reading session", systemImage: "play.fill")
                .font(.mqSub)
        }
        .buttonStyle(.mqChip)
        .disabled(busy)
    }

    private var dates: some View {
        HStack(spacing: 14) {
            dateField("Started", value: state?.startedAt) { stamp in
                await save(ReadingStateRequest(startedAt: stamp))
            }
            dateField("Finished", value: state?.finishedAt) { stamp in
                await save(ReadingStateRequest(finishedAt: stamp))
            }
        }
    }

    private func dateField(_ label: String, value: String?,
                           save: @escaping (String) async -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).mqEyebrowStyle()
            DatePicker(label, selection: Binding(
                get: { MQTime.date(from: value) ?? Date() },
                set: { date in Task { await save(MQTime.today(date)) } }),
                       in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(Color.mqBrass)
        }
    }

    // MARK: - Untracked

    private func untracked() -> some View {
        VStack(spacing: 10) {
            Button("Start reading") { Task { await add(.reading) } }
                .buttonStyle(.mqPrimary)
            HStack(spacing: 10) {
                Button("Want to read") { Task { await add(.want) } }
                    .buttonStyle(.mqChip)
                Button("I've read this") { Task { await add(.finished) } }
                    .buttonStyle(.mqChip)
            }
        }
        .padding(.horizontal, MQ.gutter)
    }

    // MARK: - Extras

    @ViewBuilder
    private func extras(_ detail: ReadingDetail, _ item: ReadingDetailItem) -> some View {
        if kind == .manga, detail.tracked, let chapters = item.chapters, chapters > 0 {
            ChapterList(chapters: chapters,
                        titles: Dictionary(uniqueKeysWithValues:
                            (item.chlist ?? []).map { ($0.number, $0.displayTitle) }),
                        current: state?.progress ?? 0) { chapter in
                await save(ReadingStateRequest(progress: chapter))
            }
        }

        if let desc = item.desc, !desc.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("About").mqEyebrowStyle()
                ExpandableText(text: desc, lineLimit: 5)
            }
            .padding(.horizontal, MQ.gutter)
        }

        if !detail.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reading log").mqEyebrowStyle()
                VStack(spacing: 0) {
                    ForEach(detail.sessions) { entry in
                        Button { editingSession = entry } label: {
                            HStack(spacing: 10) {
                                Text(MQTime.medium(entry.date))
                                    .font(MarqueeFont.body(13, .semibold, relativeTo: .caption))
                                    .foregroundStyle(Color.mqInk)
                                Spacer(minLength: 6)
                                Text(logLine(entry))
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkSoft)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 11)
                        }
                        .buttonStyle(.plain)
                        if entry.id != detail.sessions.last?.id {
                            Divider().overlay(Color.mqHairline)
                        }
                    }
                }
                .mqPanel()
            }
            .padding(.horizontal, MQ.gutter)
        }

        if !detail.household.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Around the house").mqEyebrowStyle()
                FlowLayout(spacing: 10, lineSpacing: 8) {
                    ForEach(detail.household) { member in
                        HStack(spacing: 6) {
                            AvatarView(person: member.person, size: 20,
                                       baseURL: session.server?.baseURL)
                            Text(member.person.name)
                                .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
                                .foregroundStyle(Color.mqInk)
                            Text(member.state ?? "")
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                            if let rating = member.rating {
                                Text("★\(rating)")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqBrass)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.mqPanel, in: .capsule)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .padding(.horizontal, MQ.gutter)
        }

        ChipRow {
            if kind == .book, detail.tracked {
                ChipButton(title: "Wrong book?", symbol: "arrow.triangle.2.circlepath") {
                    showingMatches = true
                }
            }
            if kind == .book, let slug = item.slug ?? item.hcID.map(String.init),
               let url = URL(string: "https://hardcover.app/books/\(slug)") {
                Link(destination: url) {
                    Label("Hardcover", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.mqChip)
            }
            if kind == .manga, let id = item.id,
               let url = URL(string: "https://anilist.co/manga/\(id)") {
                Link(destination: url) {
                    Label("AniList", systemImage: "arrow.up.right.square")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.mqChip)
            }
            if detail.tracked {
                ChipButton(title: "Remove", symbol: "trash", isDestructive: true) {
                    Task { await removeFromShelf() }
                }
            }
        }
        .padding(.horizontal, MQ.gutter)

        if detail.tracked, let id = item.id {
            ReviewsSection(itemType: kind.rawValue, itemID: id, hasEarnedSpoilers: true)
        }
    }

    private func logLine(_ entry: ReadingSession) -> String {
        var parts: [String] = []
        if entry.isTimed { parts.append("\(entry.minutes) min") }
        parts.append(entry.from == entry.to
                     ? "at \(entry.to)"
                     : "\(entry.from) → \(entry.to)")
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func load() async {
        guard let client = session.client else { return }
        let path = isHardcoverPreview ? "book/hc/\(itemID)" : "\(kind.path)/\(itemID)"
        do {
            detail = try await client.get(path, as: ReadingDetail.self)
            error = nil
        } catch let failure as APIError {
            if detail == nil { error = failure.errorDescription }
        } catch {
            if detail == nil { self.error = error.localizedDescription }
        }
    }

    private func save(_ request: ReadingStateRequest) async {
        guard let client = session.client, let id = item?.id else { return }
        _ = try? await client.post("\(kind.path)/\(id)/state", body: request, as: Empty.self)
        await load()
    }

    private func setState(_ newValue: ReadingState) async {
        var request = ReadingStateRequest(state: newValue)
        if newValue == .finished, let total { request.progress = total }
        await save(request)
    }

    private func step(_ delta: Int) async {
        let current = state?.progress ?? 0
        let step: Int
        switch mode {
        case .pct:
            step = max(1, (total ?? 100) / 100)
        case .chapters where kind == .book:
            guard let pages = item?.pages, let chapters = item?.chapters, chapters > 0 else {
                await save(ReadingStateRequest(progress: max(0, current + delta)))
                return
            }
            let nextChapter = max(0, Int((Double(current) / Double(pages) * Double(chapters)).rounded()) + delta)
            let asPages = min(pages, Int((Double(min(chapters, nextChapter)) / Double(chapters) * Double(pages)).rounded()))
            await save(ReadingStateRequest(progress: max(0, asPages)))
            return
        default:
            step = 1
        }
        let next = max(0, min(total ?? .max, current + delta * step))
        await save(ReadingStateRequest(progress: next))
    }

    private func startSession() async {
        guard let client = session.client, let id = item?.id else { return }
        busy = true
        defer { busy = false }
        _ = try? await client.post("\(kind.path)/\(id)/session/start",
                                   as: SessionStartResponse.self)
        await load()
    }

    private func add(_ state: ReadingState) async {
        guard let client = session.client, let item else { return }
        if kind == .book, let hcID = item.hcID {
            let request = AddBookRequest(
                from: BookSearchResult(hcID: hcID, title: item.title, author: item.author,
                                       year: item.year, pages: item.pages, cover: item.cover,
                                       series: item.series, seriesPos: item.seriesPos,
                                       communityRating: item.communityRating, ratingsCount: nil,
                                       genres: item.genres, desc: item.desc, slug: item.slug),
                state: state)
            _ = try? await client.post("books/add", body: request, as: AddedResponse.self)
        } else if kind == .manga, let id = item.id {
            _ = try? await client.post("manga/add",
                                       body: AddMangaRequest(id: id, state: state),
                                       as: AddedResponse.self)
        }
        await load()
    }

    private func removeFromShelf() async {
        guard let client = session.client, let id = item?.id else { return }
        _ = try? await client.post("\(kind.path)/\(id)/state",
                                   body: ReadingStateRequest.remove, as: Empty.self)
        dismiss()
    }
}

/// Tap a chapter to say you've read up to there. Tapping the one you're on undoes it.
private struct ChapterList: View {
    let chapters: Int
    let titles: [Int: String]
    let current: Int
    let markTo: (Int) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Chapters · \(chapters)").mqEyebrowStyle()
                Spacer()
                Text("tap to mark read up to there")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
            }
            .padding(.horizontal, MQ.gutter)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(1...max(1, chapters), id: \.self) { number in
                            let read = number <= current
                            Button {
                                Task { await markTo(number == current ? number - 1 : number) }
                            } label: {
                                HStack(spacing: 10) {
                                    Text("\(number)")
                                        .font(.mqNumeric)
                                        .foregroundStyle(read ? Color.mqBrass : Color.mqInkMuted)
                                        .monospacedDigit()
                                        .frame(width: 34, alignment: .trailing)
                                    Text(titles[number] ?? "Chapter \(number)")
                                        .font(.mqSub)
                                        .foregroundStyle(read ? Color.mqInkMuted : Color.mqInk)
                                        .lineLimit(1)
                                    Spacer(minLength: 6)
                                    if read {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(Color.mqBrass)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                            }
                            .buttonStyle(.plain)
                            .id(number)
                            .accessibilityLabel("Chapter \(number)\(read ? ", read" : "")")
                        }
                    }
                }
                .frame(maxHeight: 280)
                .mqPanel()
                .padding(.horizontal, MQ.gutter)
                .onAppear { proxy.scrollTo(max(1, current), anchor: .center) }
            }
        }
    }
}

/// Correct a bad automatic match — the picker behind "Wrong book?".
private struct RematchSheet: View {
    let bookID: Int
    let onDone: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var matches: BookMatchesResponse?

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(spacing: 10) {
                        Text("Your progress, dates and reviews stay put.")
                            .font(.mqCaption)
                            .foregroundStyle(Color.mqInkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(matches?.results ?? []) { candidate in
                            Button { Task { await pick(candidate) } } label: {
                                HStack(spacing: 11) {
                                    CoverArt(url: candidate.cover, radius: 6).frame(width: 44)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(candidate.displayTitle)
                                            .font(MarqueeFont.body(14, .semibold, relativeTo: .subheadline))
                                            .foregroundStyle(Color.mqInk)
                                            .multilineTextAlignment(.leading)
                                        Text([candidate.author, candidate.year?.text,
                                              candidate.pages.map { "\($0)p" }]
                                                .compactMap { $0 }.filter { !$0.isEmpty }
                                                .joined(separator: " · "))
                                            .font(.mqCaption)
                                            .foregroundStyle(Color.mqInkMuted)
                                    }
                                    Spacer(minLength: 4)
                                    if candidate.hcID == matches?.current {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.mqBrass)
                                    }
                                }
                                .padding(11)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .mqPanel()
                            }
                            .buttonStyle(.plain)
                        }

                        if matches == nil {
                            ProgressView().tint(Color.mqBrass).padding(.top, 30)
                        } else if matches?.results.isEmpty == true {
                            EmptyLine("No other editions found.")
                        }
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle("Which book is it?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .presentationBackground(Color.mqGround)
        .task {
            guard let client = session.client else { return }
            matches = try? await client.get("book/\(bookID)/matches", as: BookMatchesResponse.self)
        }
    }

    private func pick(_ candidate: BookSearchResult) async {
        guard let client = session.client else { return }
        _ = try? await client.post("book/\(bookID)/rematch",
                                   body: RematchRequest(hcID: candidate.hcID), as: Empty.self)
        await onDone()
        dismiss()
    }
}

/// Edit or delete one row of the reading log.
private struct SessionEditorSheet: View {
    let entry: ReadingSession
    let kind: ReadingKind
    let mode: ProgressMode
    let total: Int?
    let chapters: Int?
    let pages: Int?
    let onDone: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var minutes = 0
    @State private var from = 0
    @State private var to = 0

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                Stepper("Minutes: \(minutes)", value: $minutes, in: 0...600, step: 5)
                HStack {
                    Text("From")
                    Spacer()
                    TextField("0", value: $from, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("To")
                    Spacer()
                    TextField("0", value: $to, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                Section {
                    Button("Delete this entry", role: .destructive) {
                        Task { await save(delete: true) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.mqGround)
            .navigationTitle("Edit log entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save(delete: false) } }.fontWeight(.bold)
                }
            }
        }
        .presentationBackground(Color.mqGround)
        .onAppear {
            date = MQTime.date(from: entry.date) ?? Date()
            minutes = entry.minutes
            from = entry.from
            to = entry.to
        }
    }

    private func save(delete: Bool) async {
        guard let client = session.client else { return }
        let request = delete
            ? EditSessionRequest(delete: true)
            : EditSessionRequest(date: MQTime.today(date), minutes: minutes,
                                 // Only send a field the user actually changed, so
                                 // display rounding can't shift a stored value.
                                 from: from == entry.from ? entry.from : from,
                                 to: to == entry.to ? entry.to : to)
        _ = try? await client.post("reading/session/\(entry.id)", body: request, as: Empty.self)
        await onDone()
        dismiss()
    }
}
