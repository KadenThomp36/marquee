import SwiftUI

// MARK: - Book requests
//
// Ask for an ebook and the server finds a copy through Shelfmark, downloads it and
// files it into the household's Calibre library, where the Palma's Calibre tab can
// fetch it. It speaks the same request language as films and shows — the pill, the
// track, the confirmation in RequestControls.swift — so it reads as one feature.

extension BookRequestPhase {
    var tone: RequestTone {
        switch self {
        case .finding: .waiting
        case .downloading, .importing: .working
        case .done: .ready
        case .pick: .attention
        case .failed: .failed
        case .cancelled, .unknown: .muted
        }
    }

    var symbol: String {
        switch self {
        case .finding: "magnifyingglass"
        case .downloading: "arrow.down.circle.fill"
        case .importing: "tray.and.arrow.down.fill"
        case .done: "checkmark.circle.fill"
        case .pick: "hand.point.up.left.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var label: String {
        switch self {
        case .finding: "Finding copies"
        case .downloading: "Downloading"
        case .importing: "Adding to Calibre"
        case .done: "In Calibre"
        case .pick: "Waiting on you"
        case .failed: "Didn\u{2019}t work"
        case .cancelled: "Cancelled"
        case .unknown: "Unknown"
        }
    }

    var pill: RequestStatusPill { RequestStatusPill(label: label, symbol: symbol, tone: tone) }
}

// MARK: - Card

/// One request: what it is, who asked, where it stands, and what you can do about it.
///
/// `compact` drops the cover and the title, for the book's own page where both are
/// already the hero.
struct BookRequestCard: View {
    let request: BookRequest
    var compact = false
    /// Replace the card's request with what the server sent back.
    let onUpdate: (BookRequest) -> Void

    @Environment(Session.self) private var session
    @State private var choosing = false
    @State private var confirmingCancel = false
    @State private var busy = false
    @State private var failure: String?

    private var phase: BookRequestPhase { request.phase }
    /// The server lets the requester or an admin change a request.
    private var canManage: Bool { request.isMine || session.me?.isAdmin == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 13) {
                if !compact {
                    CoverArt(url: request.cover, radius: 8)
                        .frame(width: 58)
                        .saturation(phase == .cancelled ? 0 : 1)
                }
                VStack(alignment: .leading, spacing: 5) {
                    if compact {
                        Text(request.isMine ? "You asked for a copy" : "\(request.requestedBy ?? "Someone") asked for a copy")
                            .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                            .foregroundStyle(Color.mqInk)
                    } else {
                        Text(request.displayTitle)
                            .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if let byline {
                            Text(byline)
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkSoft)
                                .lineLimit(1)
                        }
                    }
                    phase.pill
                        .padding(.top, 2)
                    Text(askedLine)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .mqSecondaryLine()
                }
                Spacer(minLength: 0)
            }

            detail

            if let failure {
                Label(failure, systemImage: "exclamationmark.triangle")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqVelvet)
            }

            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel(radius: MQ.radius)
        .opacity(phase == .cancelled ? 0.72 : 1)
        .animation(.snappy, value: request.state)
        .sensoryFeedback(.success, trigger: phase == .done) { old, new in !old && new }
        .sheet(isPresented: $choosing) {
            CopyPickerSheet(request: request) { onUpdate($0) }
        }
        .confirmationDialog("Cancel the request for \(request.displayTitle)?",
                            isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Cancel request", role: .destructive) { Task { await act("cancel") } }
            Button("Keep it", role: .cancel) {}
        } message: {
            Text(phase == .downloading ? "The download stops and nothing goes into Calibre." : "Nothing goes into Calibre.")
        }
    }

    private var byline: String? {
        let parts = [request.author, request.year?.text].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private var askedLine: String {
        let when = MQTime.relative(request.createdAt)
        if compact { return when.isEmpty ? "" : "Asked \(when)" }
        let who = request.isMine ? "You asked" : "\(request.requestedBy ?? "Someone") asked"
        return when.isEmpty ? who : "\(who) \(when)"
    }

    @ViewBuilder
    private var detail: some View {
        switch phase {
        case .finding:
            RequestProgressTrack(note: "Looking for copies\u{2026} this takes a minute or two",
                                 tone: .working, indeterminate: true)
        case .downloading:
            VStack(alignment: .leading, spacing: 6) {
                RequestProgressTrack(fraction: request.fraction, percent: request.percent,
                                     note: request.message)
                if let copy = request.copy, !copy.summary.isEmpty {
                    Text(copy.summary)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .monospacedDigit()
                }
            }
        case .importing:
            RequestProgressTrack(fraction: max(request.fraction, 0.99), percent: nil,
                                 note: "Adding to Calibre")
        case .done:
            Label {
                Text("In Calibre")
            } icon: {
                Image(systemName: "books.vertical.fill").foregroundStyle(RequestTone.ready.color)
            }
            .font(.mqSub)
            .foregroundStyle(Color.mqInkSoft)
        case .pick, .failed:
            if let message = request.message, !message.isEmpty {
                Text(message)
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .cancelled, .unknown:
            EmptyView()
        }
    }

    @ViewBuilder
    private var actions: some View {
        let showChoose = phase == .pick && canManage
        let showRetry = (phase == .failed || phase == .pick) && canManage
        let showCancel = phase.isCancellable && request.isMine
        let showOpen = !compact && request.bookID != nil
        if showChoose || showRetry || showCancel || showOpen {
            ChipRow {
                if showChoose {
                    Button { choosing = true } label: {
                        Label("Choose a copy", systemImage: "list.bullet.rectangle")
                    }
                    .buttonStyle(.mqChip(on: true))
                }
                if showRetry {
                    Button { Task { await act("retry") } } label: {
                        Label(phase == .pick ? "Search again" : "Retry", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.mqChip(on: phase == .failed))
                }
                if showOpen, let bookID = request.bookID {
                    NavigationLink(value: Navigator.Route.book(bookID)) {
                        Label("Open book", systemImage: "book")
                    }
                    .buttonStyle(.mqChip)
                }
                if showCancel {
                    Button { confirmingCancel = true } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.mqChip(on: false, destructive: true))
                }
            }
            .disabled(busy)
        }
    }

    private func act(_ verb: String) async {
        guard let client = session.client else { return }
        busy = true
        failure = nil
        defer { busy = false }
        do {
            let updated = try await client.post("book-requests/\(request.id)/\(verb)", as: BookRequest.self)
            onUpdate(updated)
        } catch {
            failure = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - On a book's page

/// The Request control on a book's page. Its state comes from the server's own
/// lookup for this book, and it polls every four seconds while the request moves.
struct BookRequestControl: View {
    let bookID: Int
    let title: String
    /// The book's own cover, for the details sheet when the request has none.
    var cover: String?

    @Environment(Session.self) private var session
    @State private var request: BookRequest?
    @State private var loaded = false
    @State private var confirming = false
    @State private var busy = false
    @State private var failure: String?
    @State private var notFound = false
    @State private var notice: String?

    /// The sheet behind the pill: the copy, who asked, Calibre, and the actions.
    @State private var showingDetails = false
    /// Calibre already has it (it came in some other way); "Request another copy" overrides.
    @State private var inCalibre: CalibreCopy?
    @State private var anyway = false

    private var enabled: Bool { session.bookRequestConfig?.isEnabled == true }
    private var isActive: Bool { request?.phase.isActive == true }

    /// Sits in the book's hero, right where a film or show keeps its Request button:
    /// a button until it's asked for, then a status pill with the live track under it.
    var body: some View {
        Group {
            if enabled, loaded {
                VStack(alignment: .leading, spacing: 7) {
                    if let request, request.phase != .cancelled, !(request.phase == .failed && inCalibre != nil && !anyway) {
                        status(request)
                    } else if inCalibre != nil, !anyway {
                        Button { showingDetails = true } label: {
                            HStack(spacing: 5) {
                                RequestStatusPill(label: "In Calibre", symbol: "checkmark.circle.fill", tone: .ready)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("In Calibre. Opens the details.")
                    } else {
                        Button { confirming = true } label: {
                            if busy {
                                ProgressView().controlSize(.small).tint(Color.mqBrass)
                            } else {
                                Label("Request ebook", systemImage: "arrow.down.to.line.circle")
                                    .font(.mqSub)
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.mqBrass)
                        .disabled(busy)
                        .accessibilityHint("Finds an ebook copy and adds it to Calibre")
                    }
                    if let failure {
                        HStack(spacing: 10) {
                            Text(failure)
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                            if notFound {
                                NavigationLink(value: Navigator.Route.bookRequests(query: title)) {
                                    Text("Search for it").font(MarqueeFont.body(12, .bold, relativeTo: .caption))
                                }
                                .foregroundStyle(Color.mqBrass)
                            }
                        }
                    }
                    if let notice {
                        Text(notice).font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.82), value: request?.state)
            } else {
                // An empty Group is no view at all, and its tasks would never run.
                Color.clear.frame(height: 0)
            }
        }
        .task {
            await session.loadBookRequestConfig()
            await load()
        }
        .task(id: isActive) {
            guard isActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await load()
                if !isActive { return }
            }
        }
        .confirmationDialog("Request \(title)?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Request ebook") { Task { await create() } }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Marquee finds an ebook copy and adds it to Calibre. Everyone in the house can see the request.")
        }
        .sheet(isPresented: $showingDetails) {
            BookRequestDetailSheet(
                title: title,
                cover: cover,
                request: request.flatMap { $0.phase == .cancelled ? nil : $0 },
                inCalibre: inCalibre,
                onUpdate: { request = $0 },
                onDeleted: {
                    request = nil
                    await load()
                },
                onRequestAnother: {
                    anyway = true
                    if let request, request.phase == .done { await act("retry") } else { await create() }
                })
        }
    }

    @ViewBuilder
    private func status(_ request: BookRequest) -> some View {
        let (label, symbol, tone): (String, String, RequestTone) = switch request.phase {
        case .finding: ("Finding a copy", "magnifyingglass", .working)
        case .downloading: ("Downloading", "arrow.down.circle", .working)
        case .importing: ("Adding to Calibre", "books.vertical", .working)
        case .done: ("In Calibre", "checkmark.circle.fill", .ready)
        case .pick: ("Choose a copy", "hand.point.up.left", .attention)
        case .failed: ("No copy yet", "exclamationmark.circle", .failed)
        default: ("Requested", "clock", .waiting)
        }
        Button {
            showingDetails = true
        } label: {
            HStack(spacing: 5) {
                RequestStatusPill(label: label, symbol: symbol, tone: tone)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label). Opens the request.")
        if request.phase.isActive {
            RequestProgressTrack(fraction: request.phase == .importing ? 1 : request.fraction,
                                 percent: request.phase == .downloading ? request.percent : nil,
                                 note: request.phase == .finding ? "Searching every indexer, about a minute"
                                     : request.message,
                                 tone: .working, indeterminate: request.phase == .finding)
                .frame(maxWidth: 260)
        } else if let message = request.message, !message.isEmpty {
            Text(message).font(.mqCaption).foregroundStyle(Color.mqInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func act(_ verb: String) async {
        guard let client = session.client, let id = request?.id else { return }
        if let updated = try? await client.post("book-requests/\(id)/\(verb)", as: BookRequest.self) {
            request = updated
        }
    }

    private func load() async {
        guard enabled, let client = session.client else { loaded = true; return }
        if let list = try? await client.get("book-requests", query: ["book_id": String(bookID)],
                                            as: BookRequestList.self) {
            request = list.requests?.first
            inCalibre = list.inCalibre
        }
        loaded = true
    }

    private func create() async {
        guard let client = session.client else { return }
        busy = true
        failure = nil
        notFound = false
        defer { busy = false }
        do {
            let created = try await client.post("book-requests", body: CreateBookRequest(bookID: bookID),
                                                as: BookRequest.self)
            request = created
            if created.already == true {
                notice = created.isMine ? "You'd already asked for this one."
                    : "\(created.requestedBy ?? "Someone") had already asked for this one."
            }
        } catch let error as APIError {
            if case .http(404, let detail) = error {
                failure = detail
                notFound = true
            } else {
                failure = error.errorDescription
            }
        } catch {
            failure = error.localizedDescription
        }
    }
}

// MARK: - The screen

/// Search the downloader, ask for a book, and follow every request in the house.
/// On the open Duo the search is the left page and the requests the right.
struct BookRequestsScreen: View {
    var initialQuery: String?

    @Environment(Session.self) private var session
    @State private var query = ""
    @State private var results: [ShelfmarkBook] = []
    @State private var searching = false
    @State private var unavailable = false
    @State private var searched = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var requests: [BookRequest]?
    @State private var loadError: String?
    @State private var pending: ShelfmarkBook?
    @State private var creating: String?
    @State private var notice: String?
    @State private var createdTick = 0
    @FocusState private var searchFocused: Bool

    private var enabled: Bool? { session.bookRequestConfig?.enabled }
    private var anyActive: Bool { (requests ?? []).contains { $0.phase.isActive } }

    var body: some View {
        MarqueeScreen {
            if enabled == false {
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.mqInkMuted)
                    Text("Book requests aren\u{2019}t set up on this server. An admin can add the book downloader in the web app\u{2019}s settings.")
                        .font(.mqSub)
                        .foregroundStyle(Color.mqInkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(MQ.gutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                FoldSpread(spacing: 18, refresh: { await loadRequests() }) {
                    searchPage
                } trailing: {
                    requestsPage
                }
            }
        }
        .navigationTitle("Book requests")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: createdTick)
        .task {
            await session.loadBookRequestConfig(force: true)
            if let initialQuery, query.isEmpty { query = initialQuery }
            await loadRequests()
        }
        .task(id: anyActive) {
            guard anyActive else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await loadRequests()
                if !anyActive { return }
            }
        }
        .onChange(of: query) { _, new in scheduleSearch(new) }
        .confirmationDialog("Request \(pending?.displayTitle ?? "this book")?",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible, presenting: pending) { book in
            Button("Request a copy") { Task { await create(book) } }
            Button("Not now", role: .cancel) {}
        } message: { book in
            Text("\(book.authorLine.isEmpty ? "" : "By \(book.authorLine). ")Marquee finds an ebook copy and adds it to Calibre. Everyone in the house can see the request.")
        }
    }

    // MARK: Search

    @ViewBuilder
    private var searchPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.mqInkMuted)
                TextField("Find a book to request", text: $query)
                    .font(.mqBody)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { scheduleSearch(query, immediately: true) }
                if searching {
                    ProgressView().controlSize(.small).tint(Color.mqBrass)
                } else if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color.mqInkMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .mqPanel()

            if let notice {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkSoft)
                    .symbolRenderingMode(.hierarchical)
                    .transition(.opacity)
            }

            searchBody
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 10)
        .animation(.easeOut(duration: 0.2), value: notice)
    }

    @ViewBuilder
    private var searchBody: some View {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            Text("Search by title or author. A request finds an ebook and files it into Calibre, usually within a few minutes.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
                .fixedSize(horizontal: false, vertical: true)
        } else if unavailable {
            Label("The book downloader isn\u{2019}t answering. Try again in a bit.", systemImage: "wifi.exclamationmark")
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
        } else if results.isEmpty, !searching, searched == trimmed {
            Text("Nothing found for \u{201C}\(trimmed)\u{201D}. Try the author\u{2019}s surname, or fewer words.")
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
        } else if !results.isEmpty {
            VStack(spacing: 0) {
                ForEach(results) { book in
                    resultRow(book)
                    if book.id != results.last?.id {
                        Divider().overlay(Color.mqHairline).padding(.leading, 66)
                    }
                }
            }
            .mqPanel(radius: MQ.radius)
        }
    }

    private func resultRow(_ book: ShelfmarkBook) -> some View {
        let existing = book.request
        return Button {
            if existing == nil { pending = book }
        } label: {
            HStack(spacing: 12) {
                CoverArt(url: book.cover, radius: 6).frame(width: 42)
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.displayTitle)
                        .font(MarqueeFont.body(14, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(Color.mqInk)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text([book.authorLine, book.year?.text ?? ""].filter { !$0.isEmpty }.joined(separator: ", "))
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if let existing {
                    RequestStatusPill(label: existing.phase.label, symbol: existing.phase.symbol,
                                      tone: existing.phase.tone, compact: true)
                } else if book.inCalibre != nil {
                    RequestStatusPill(label: "In Calibre", symbol: "checkmark.circle.fill", tone: .ready, compact: true)
                } else if creating == book.id {
                    ProgressView().controlSize(.small).tint(Color.mqBrass)
                } else {
                    Text("Request")
                        .font(MarqueeFont.body(12.5, .bold, relativeTo: .caption))
                        .foregroundStyle(Color.mqBrass)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Color.mqBrassSoft, in: .capsule)
                        .overlay(Capsule().strokeBorder(Color.mqBrassDim, lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(creating != nil)
        .accessibilityLabel("\(book.displayTitle)\(book.authorLine.isEmpty ? "" : ", \(book.authorLine)")")
        .accessibilityValue(existing.map { $0.phase.label } ?? "")
        .accessibilityHint(existing == nil ? "Requests a copy" : "")
    }

    // MARK: Requests

    @ViewBuilder
    private var requestsPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Requests in the house", count: requests.map { "\($0.count)" })
            if let requests {
                if requests.isEmpty {
                    Text("Nobody has asked for a book yet. Search to request one.")
                        .font(.mqSub)
                        .foregroundStyle(Color.mqInkMuted)
                        .padding(.vertical, 18)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(requests) { request in
                            BookRequestCard(request: request) { replace($0) }
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            } else if let loadError {
                LoadFailure(message: loadError) { await loadRequests() }
            } else {
                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 120, radius: MQ.radius) }
            }
        }
        .padding(.horizontal, MQ.gutter)
        .padding(.top, 10)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: requests)
    }

    // MARK: Data

    private func loadRequests() async {
        guard let client = session.client else { return }
        do {
            let list = try await client.get("book-requests", as: BookRequestList.self)
            requests = list.requests ?? []
            loadError = nil
        } catch {
            if requests == nil { loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription }
        }
    }

    private func replace(_ updated: BookRequest) {
        guard var list = requests else { return }
        if let index = list.firstIndex(where: { $0.id == updated.id }) {
            list[index] = updated
        } else {
            list.insert(updated, at: 0)
        }
        requests = list
        // keep the search result's pill in step
        if let at = results.firstIndex(where: { $0.providerID == updated.providerID }) {
            results[at].request = updated.phase == .cancelled || updated.phase == .failed
                ? nil : BookRequestRef(id: updated.id, state: updated.state)
        }
    }

    private func scheduleSearch(_ text: String, immediately: Bool = false) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            results = []
            unavailable = false
            searching = false
            return
        }
        searchTask = Task {
            if !immediately { try? await Task.sleep(for: .milliseconds(500)) }
            guard !Task.isCancelled, let client = session.client else { return }
            searching = true
            let response = try? await client.get("book-requests/search", query: ["q": trimmed],
                                                 as: ShelfmarkSearchResponse.self)
            guard !Task.isCancelled else { return }
            searching = false
            searched = trimmed
            results = response?.results ?? []
            unavailable = response == nil || response?.unavailable == true
        }
    }

    private func create(_ book: ShelfmarkBook) async {
        guard let client = session.client else { return }
        creating = book.id
        defer { creating = nil }
        do {
            let created = try await client.post("book-requests", body: CreateBookRequest(book),
                                                as: BookRequest.self)
            replace(created)
            if created.already == true {
                notice = created.isMine ? "You'd already asked for \(created.displayTitle)."
                    : "\(created.requestedBy ?? "Someone") had already asked for \(created.displayTitle)."
            } else {
                notice = "Requested \(created.displayTitle). Finding a copy takes a minute or two."
                createdTick += 1
            }
        } catch {
            notice = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Choose a copy

/// Every copy the indexers found, best matches first, the ones already tried marked —
/// for when no copy matched well enough, or the good ones failed.
struct CopyPickerSheet: View {
    let request: BookRequest
    let onPicked: (BookRequest) -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var detail: BookRequest?
    @State private var error: String?
    @State private var confirming: BookRequestChoice?
    @State private var busy = false

    /// Recommended copies first; the server's order otherwise.
    private var choices: [BookRequestChoice] {
        let all = detail?.choices ?? []
        return all.filter(\.isRecommended) + all.filter { !$0.isRecommended }
    }

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let message = (detail ?? request).message, !message.isEmpty {
                            Text(message)
                                .font(.mqSub)
                                .foregroundStyle(Color.mqInkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if detail == nil, error == nil {
                            ProgressView().tint(Color.mqBrass)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 30)
                        } else if let error {
                            LoadFailure(message: error) { await load() }
                        } else if choices.isEmpty {
                            EmptyLine("No copies to choose from. Search again from the request.")
                        } else {
                            VStack(spacing: 0) {
                                ForEach(choices) { choice in
                                    row(choice)
                                    if choice.id != choices.last?.id {
                                        Divider().overlay(Color.mqHairline)
                                    }
                                }
                            }
                            .mqPanel(radius: MQ.radius)
                        }
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle("Choose a copy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .confirmationDialog("Download this copy?", isPresented: Binding(
                get: { confirming != nil }, set: { if !$0 { confirming = nil } }),
                                titleVisibility: .visible, presenting: confirming) { choice in
                Button("Download it") { Task { await pick(choice) } }
                Button("Cancel", role: .cancel) {}
            } message: { choice in
                Text(choice.title ?? "")
            }
        }
        .presentationBackground(Color.mqGround)
        .task { await load() }
    }

    private func row(_ choice: BookRequestChoice) -> some View {
        Button {
            confirming = choice
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                if choice.isRecommended || choice.wasTried {
                    HStack(spacing: 6) {
                        if choice.isRecommended {
                            RequestStatusPill(label: "Good match", symbol: "star.fill", tone: .working, compact: true)
                        }
                        if choice.wasTried {
                            RequestStatusPill(label: "Tried, didn\u{2019}t work", symbol: "arrow.uturn.backward",
                                              tone: .muted, compact: true)
                        }
                    }
                }
                Text(choice.title ?? "Untitled copy")
                    .font(MarqueeFont.body(13.5, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Text([choice.summary, choice.indexer ?? ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(.rect)
            .opacity(choice.wasTried ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy)
    }

    private func load() async {
        guard let client = session.client else { return }
        do {
            detail = try await client.get("book-requests/\(request.id)", as: BookRequest.self)
            error = nil
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func pick(_ choice: BookRequestChoice) async {
        guard let client = session.client else { return }
        busy = true
        defer { busy = false }
        do {
            let updated = try await client.post("book-requests/\(request.id)/pick",
                                                body: PickBookCopy(sourceID: choice.sourceID.value),
                                                as: BookRequest.self)
            onPicked(updated)
            dismiss()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - What's behind a book's pill

/// Everything behind a book's request pill, in the same shape as a film's or show's:
/// the book and where it stands, who asked and when, the copy (title, size, format,
/// seeders), what Calibre holds, and what you can do about it. That's choose another
/// copy, cancel, delete the request, or ask for another copy of a book already in
/// Calibre.
///
/// `sample` (debug gallery only) shows the request as given, fetches nothing and
/// changes nothing.
struct BookRequestDetailSheet: View {
    let title: String
    /// The book's cover, when the request doesn't carry one.
    var cover: String?
    var request: BookRequest?
    var inCalibre: CalibreCopy?
    var sample = false
    /// The server sent back a changed request.
    var onUpdate: (BookRequest) -> Void = { _ in }
    /// The request is gone.
    var onDeleted: () async -> Void = {}
    /// "Request another copy", already confirmed.
    var onRequestAnother: () async -> Void = {}

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var current: BookRequest?
    @State private var detail: BookRequest?
    @State private var picking = false
    @State private var confirmingDelete = false
    @State private var confirmingCancel = false
    @State private var confirmingAnother = false
    @State private var busy = false
    @State private var failure: String?

    private var shown: BookRequest? { current ?? request }
    private var phase: BookRequestPhase? { shown?.phase }
    private var canManage: Bool { shown?.isMine == true || session.me?.isAdmin == true }
    private var copy: BookRequestCopy? { detail?.copy ?? shown?.copy }
    private var choices: [BookRequestChoice] { detail?.choices ?? [] }
    /// The book sits in Calibre, either because this request put it there or because
    /// it came in some other way.
    private var isInCalibre: Bool { inCalibre != nil || phase == .done }

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        progress
                        if isInCalibre { calibreSection }
                        if let shown { copySection(shown) }
                        if let shown { askedSection(shown) }
                        if let failure {
                            Label(failure, systemImage: "exclamationmark.triangle")
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqVelvet)
                        }
                        actions
                    }
                    .padding(MQ.gutter)
                    .padding(.top, 4)
                }
            }
            .navigationTitle(shown == nil ? "In Calibre" : "Book request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .sheet(isPresented: $picking) {
                if let shown {
                    CopyPickerSheet(request: shown) { picked in
                        current = picked
                        onUpdate(picked)
                    }
                }
            }
            .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete request", role: .destructive) { Task { await delete() } }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
            .confirmationDialog("Cancel the request for \(shown?.displayTitle ?? title)?",
                                isPresented: $confirmingCancel, titleVisibility: .visible) {
                Button("Cancel request", role: .destructive) { Task { await act("cancel") } }
                Button("Keep it", role: .cancel) {}
            } message: {
                Text(phase == .downloading ? "The download stops and nothing goes into Calibre." : "Nothing goes into Calibre.")
            }
            .confirmationDialog("Request another copy?", isPresented: $confirmingAnother,
                                titleVisibility: .visible) {
                Button("Request another copy") {
                    Task {
                        await onRequestAnother()
                        dismiss()
                    }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Marquee finds a fresh ebook copy and adds it to Calibre. The copy that\u{2019}s there now stays.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.mqGround)
        .task { await load() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .top, spacing: 13) {
            CoverArt(url: shown?.cover ?? cover, radius: 8)
                .frame(width: 58)
            VStack(alignment: .leading, spacing: 5) {
                // The book's own title; Calibre's (often with a subtitle) is in its row.
                Text(shown?.displayTitle ?? title)
                    .font(MarqueeFont.body(17, .bold, relativeTo: .headline))
                    .foregroundStyle(Color.mqInk)
                    .lineLimit(3)
                if let byline {
                    Text(byline)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                        .lineLimit(1)
                }
                pill.padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
    }

    /// The same words as the pill that opened the sheet.
    private var pill: RequestStatusPill {
        guard let phase, !(phase == .failed && inCalibre != nil) else {
            return RequestStatusPill(label: "In Calibre", symbol: "checkmark.circle.fill", tone: .ready)
        }
        let (label, symbol, tone): (String, String, RequestTone) = switch phase {
        case .finding: ("Finding a copy", "magnifyingglass", .working)
        case .downloading: ("Downloading", "arrow.down.circle", .working)
        case .importing: ("Adding to Calibre", "books.vertical", .working)
        case .done: ("In Calibre", "checkmark.circle.fill", .ready)
        case .pick: ("Choose a copy", "hand.point.up.left", .attention)
        case .failed: ("No copy yet", "exclamationmark.circle", .failed)
        case .cancelled: ("Cancelled", "xmark.circle", .muted)
        case .unknown: ("Requested", "clock", .waiting)
        }
        return RequestStatusPill(label: label, symbol: symbol, tone: tone)
    }

    private var byline: String? {
        let author = shown?.author ?? inCalibre?.authors?.joined(separator: ", ")
        let parts = [author, shown?.year?.text].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var progress: some View {
        if let shown, shown.phase.isActive {
            RequestProgressTrack(fraction: shown.phase == .importing ? 1 : shown.fraction,
                                 percent: shown.phase == .downloading ? shown.percent : nil,
                                 note: shown.phase == .finding ? "Searching every indexer, about a minute"
                                     : shown.message,
                                 tone: .working, indeterminate: shown.phase == .finding)
        } else if let shown, shown.phase == .pick || shown.phase == .failed,
                  let message = shown.message, !message.isEmpty {
            Text(message)
                .font(.mqSub)
                .foregroundStyle(Color.mqInkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var calibreSection: some View {
        RequestDetailSection("In Calibre") {
            if let inCalibre {
                RequestFactRow(symbol: "books.vertical.fill", tone: .ready,
                               headline: inCalibre.title ?? shown?.displayTitle ?? title,
                               detail: [inCalibre.authors?.joined(separator: ", ") ?? "", inCalibre.summary]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
            } else {
                RequestFactRow(symbol: "books.vertical.fill", tone: .ready,
                               headline: "Filed into the library",
                               detail: [copy?.format?.uppercased() ?? "",
                                        RequestWhen.relative(shown?.finishedAt ?? shown?.updatedAt)]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
            }
        }
    }

    @ViewBuilder
    private func copySection(_ request: BookRequest) -> some View {
        let others = choices.filter { $0.title != copy?.title }.count
        RequestDetailSection("The copy") {
            if let copy {
                RequestFactRow(symbol: "doc.richtext.fill",
                               tone: request.phase == .done ? .ready : (request.phase.isActive ? .working : .muted),
                               headline: copy.title ?? "Untitled copy",
                               detail: copy.summary, dense: true)
            } else {
                RequestFactRow(symbol: "doc.badge.ellipsis", tone: .muted,
                               headline: request.phase == .finding ? "Still looking" : "No copy chosen yet",
                               detail: request.phase == .finding
                                ? "The indexers are being searched."
                                : (choices.isEmpty ? nil : "\(choices.count) cop\(choices.count == 1 ? "y" : "ies") found to choose from"))
            }
            if copy != nil, others > 0 {
                RequestDetailDivider()
                RequestFactRow(symbol: "square.stack.3d.up", tone: .muted,
                               headline: "\(others) other cop\(others == 1 ? "y" : "ies") found",
                               detail: (request.attempts ?? 0) > 1 ? "\(request.attempts ?? 0) tried so far" : nil)
            }
        }
    }

    private func askedSection(_ request: BookRequest) -> some View {
        RequestDetailSection("Request") {
            RequesterRow(name: request.requestedBy, isMine: request.isMine, when: request.createdAt,
                         canDelete: canManage, deleting: busy) {
                confirmingDelete = true
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        let showChoose = canManage && phase.map { $0 == .pick || (($0 == .downloading || $0 == .failed) && !choices.isEmpty) } == true
        let showRetry = canManage && phase == .failed && inCalibre == nil
        let showCancel = canManage && phase?.isActive == true
        let showAnother = isInCalibre && !(phase?.isActive ?? false)
        if showChoose || showRetry || showCancel || showAnother {
            ChipRow {
                if showChoose {
                    Button { picking = true } label: {
                        Label(phase == .pick ? "Choose a copy" : "Choose another copy",
                              systemImage: "list.bullet.rectangle")
                    }
                    .buttonStyle(.mqChip(on: phase == .pick))
                }
                if showRetry {
                    Button { Task { await act("retry") } } label: {
                        Label("Try again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.mqChip(on: true))
                }
                if showAnother {
                    Button { confirmingAnother = true } label: {
                        Label("Request another copy", systemImage: "arrow.down.to.line.circle")
                    }
                    .buttonStyle(.mqChip)
                }
                if showCancel {
                    Button { confirmingCancel = true } label: {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.mqChip(on: false, destructive: true))
                }
            }
            .disabled(busy || sample)
        }
    }

    private var deleteTitle: String {
        guard let shown else { return "Delete this request?" }
        return shown.isMine ? "Delete your request?" : "Delete \(shown.requestedBy ?? "their")\u{2019}s request?"
    }

    private var deleteMessage: String {
        var lines = ["The request comes off the list for everyone"]
        if phase?.isActive == true { lines[0] += " and its download stops" }
        lines[0] += "."
        lines.append(isInCalibre ? "The copy in Calibre stays." : "Nothing in Calibre changes.")
        return lines.joined(separator: " ")
    }

    // MARK: Data

    private func load() async {
        guard !sample, let id = shown?.id, let client = session.client else { return }
        if let fetched = try? await client.get("book-requests/\(id)", as: BookRequest.self) {
            detail = fetched
        }
    }

    private func act(_ verb: String) async {
        guard !sample, let id = shown?.id, let client = session.client else { return }
        busy = true
        failure = nil
        defer { busy = false }
        do {
            let updated = try await client.post("book-requests/\(id)/\(verb)", as: BookRequest.self)
            current = updated
            onUpdate(updated)
        } catch {
            failure = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func delete() async {
        if sample { dismiss(); return }
        guard let id = shown?.id, let client = session.client else { return }
        busy = true
        failure = nil
        defer { busy = false }
        do {
            _ = try await client.post("book-requests/\(id)/delete", as: RequestResult.self)
            await onDeleted()
            dismiss()
        } catch {
            failure = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
