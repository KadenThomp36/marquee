import SwiftUI

/// Your lists, and the collaborative ones other people have shared with the house.
struct ListsScreen: View {
    @Environment(Session.self) private var session
    @State private var data = RemoteData<ListsResponse>(cacheKey: "lists")
    @State private var creating = false

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 158, spacing: 12)

    }

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    if let value = data.value {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(value.lists) { ListCardView(list: $0) }
                        }
                        .padding(.horizontal, MQ.gutter)

                        if let shared = value.shared, !shared.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader("Shared with the house")
                                    .padding(.horizontal, MQ.gutter)
                                LazyVGrid(columns: columns, spacing: 12) {
                                    ForEach(shared) { ListCardView(list: $0) }
                                }
                                .padding(.horizontal, MQ.gutter)
                            }
                        }
                    } else if data.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in SkeletonBlock(height: 150) }
                        }
                        .padding(.horizontal, MQ.gutter)
                    }
                    if data.isStale { StaleFooter(cachedAt: data.cachedAt) }
                }
                .padding(.vertical, 8)
            }
            .refreshable { await load(force: true) }
        }
        .navigationTitle("Lists")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("New list")
            }
        }
        .sheet(isPresented: $creating) {
            NewListSheet { await load(force: true) }
        }
        .task { await load() }
    }

    private func load(force: Bool = false) async {
        guard let client = session.client else { return }
        await data.load(force: force) { try await client.get("lists", as: ListsResponse.self) }
    }
}

/// A list, shown as the four most recent covers behind its name.
struct ListCardView: View {
    let list: ListCard

    var body: some View {
        NavigationLink(value: Navigator.Route.list(list.id)) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    if list.posters.isEmpty {
                        Color.mqPanelRaised
                        Image(systemName: "bookmark")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.mqInkMuted.opacity(0.6))
                    } else {
                        HStack(spacing: 0) {
                            ForEach(Array(list.posters.prefix(4).enumerated()), id: \.offset) { _, poster in
                                RemoteImage(url: poster, contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .frame(height: 96)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if let visibility = list.visibility, visibility != .private {
                        Label(visibility.label, systemImage: visibility.symbol)
                            .font(MarqueeFont.body(9.5, .bold, relativeTo: .caption2))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.ultraThinMaterial, in: .capsule)
                            .padding(6)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        if list.isDefault {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.mqBrass)
                        }
                        Text(list.name)
                            .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                            .foregroundStyle(Color.mqInk)
                            .lineLimit(1)
                    }
                    Text("\(list.count) \(list.count == 1 ? "title" : "titles")"
                         + (list.owner.map { " · \($0)'s" } ?? ""))
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .lineLimit(1)
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.mqPanel)
            .clipShape(.rect(cornerRadius: MQ.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: MQ.radiusSmall)
                .strokeBorder(Color.mqHairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(list.name), \(list.count) titles")
    }
}

/// One list. Items use the Watch-Next card look, so progress reads the same here as
/// it does on the home screen.
struct ListScreen: View {
    let listID: Int

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var list: ListDetail?
    @State private var error: String?
    @State private var sort: ListSort = .added
    @State private var adding = false
    @State private var confirmingDelete = false
    @State private var members: [Person] = []

    enum ListSort: String, CaseIterable, Identifiable {
        case added = "Recently added"
        case watched = "Recently watched"
        case first = "First watched"
        case released = "Newest release"
        case title = "Title A–Z"
        var id: String { rawValue }
    }

    @Environment(\.dynamicTypeSize) private var gridTypeSize

    private var columns: [GridItem] {

        MQ.adaptiveColumns(gridTypeSize, minimum: 150, spacing: 12)

    }

    private var items: [ListItem] {
        guard let items = list?.items else { return [] }
        switch sort {
        case .added: return items.sorted { ($0.addedAt ?? "") > ($1.addedAt ?? "") }
        case .watched: return items.sorted { ($0.lastWatched ?? "") > ($1.lastWatched ?? "") }
        case .first: return items.sorted { ($0.firstWatched ?? "~") < ($1.firstWatched ?? "~") }
        case .released: return items.sorted { ($0.year?.value ?? 0) > ($1.year?.value ?? 0) }
        case .title: return items.sorted { $0.displayTitle < $1.displayTitle }
        }
    }

    var body: some View {
        MarqueeScreen {
            if let list {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ownership(list)
                        if list.items.isEmpty {
                            EmptyLine(list.editable
                                      ? "This list is empty. Tap + to add titles."
                                      : "This list is empty.")
                        } else {
                            if list.items.count > 1 { sortControl }
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items, id: \.uniqueID) { item in
                                    ListItemCard(item: item, canEdit: list.editable) {
                                        await remove(item)
                                    }
                                }
                            }
                            .padding(.horizontal, MQ.gutter)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                }
            } else if let error {
                LoadFailure(message: error) { await load() }
            } else {
                SkeletonBlock(height: 200).padding(MQ.gutter)
            }
        }
        .navigationTitle(list?.name ?? "List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if list?.editable == true {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add titles")
                }
                if let list, let url = shareURL {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share \(list.name)")
                }
                if list?.isOwner == true, list?.isDefault == false {
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Delete list")
                }
            }
        }
        .sheet(isPresented: $adding) {
            AddTitlesSheet(listID: listID) { await load() }
        }
        .confirmationDialog("Delete “\(list?.name ?? "")”?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete list", role: .destructive) { Task { await deleteList() } }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func ownership(_ list: ListDetail) -> some View {
        if list.isOwner {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Visibility", selection: Binding(
                    get: { list.visibility ?? .private },
                    set: { value in Task { await setVisibility(value) } })) {
                    ForEach(ListVisibility.allCases, id: \.self) { visibility in
                        Label(visibility.label, systemImage: visibility.symbol).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)

                Text((list.visibility ?? .private).explanation)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)

                if (list.visibility ?? .private) != .private {
                    audience(list)
                }
            }
            .padding(.horizontal, MQ.gutter)
        } else {
            HStack(spacing: 9) {
                AvatarView(person: list.owner, size: 28, baseURL: session.server?.baseURL)
                Text("Shared by \(list.owner.name)")
                    .font(.mqSub)
                    .foregroundStyle(Color.mqInkSoft)
                Spacer(minLength: 6)
                if let visibility = list.visibility {
                    Label(visibility.label, systemImage: visibility.symbol)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqBrass)
                }
            }
            .padding(.horizontal, MQ.gutter)
        }
    }

    /// A shared list with nobody picked is shared with everyone; picking people
    /// narrows it. That rule is the server's, so the copy says it plainly.
    private func audience(_ list: ListDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shared with").mqEyebrowStyle()
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(members.filter { $0.isMe != true }) { member in
                    let picked = list.sharedWith?.contains(member.id ?? -1) == true
                    Button {
                        Task { await toggleAudience(member, currently: picked, list: list) }
                    } label: {
                        HStack(spacing: 6) {
                            AvatarView(person: member, size: 20, baseURL: session.server?.baseURL)
                            Text(member.name)
                                .font(MarqueeFont.body(12.5, .semibold, relativeTo: .caption))
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .foregroundStyle(picked ? Color.mqBrass : Color.mqInkSoft)
                        .background(picked ? Color.mqBrassSoft : Color.mqPanel, in: .capsule)
                        .overlay(Capsule().strokeBorder(picked ? Color.mqBrassDim : Color.mqHairline,
                                                        lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(picked ? .isSelected : [])
                }
            }
            Text("No one picked means everyone in the household.")
                .font(.mqCaption)
                .foregroundStyle(Color.mqInkMuted)
        }
        .task {
            guard members.isEmpty, let client = session.client else { return }
            members = (try? await client.get("members", as: MembersResponse.self))?.members ?? []
        }
    }

    private var sortControl: some View {
        Menu {
            Picker("Sort", selection: $sort) {
                ForEach(ListSort.allCases) { Text($0.rawValue).tag($0) }
            }
        } label: {
            Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
                .font(.mqCaption)
        }
        .buttonStyle(.mqChip)
        .padding(.horizontal, MQ.gutter)
    }

    private var shareURL: URL? {
        session.server.map { $0.baseURL.appendingPathComponent("#/list/\(listID)") }
    }

    // MARK: - Actions

    private func load() async {
        guard let client = session.client else { return }
        do {
            list = try await client.get("list/\(listID)", as: ListDetail.self)
            error = nil
        } catch let failure as APIError {
            if list == nil { error = failure.errorDescription }
        } catch {
            if list == nil { self.error = error.localizedDescription }
        }
    }

    private func remove(_ item: ListItem) async {
        guard let client = session.client else { return }
        list?.items.removeAll { $0.uniqueID == item.uniqueID }
        do {
            try await client.post("list/\(listID)/item",
                                  body: ListItemToggle(itemType: item.type, itemID: item.id,
                                                       remove: true), as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .listToggle(listID: listID, itemType: item.type, itemID: item.id, remove: true)))
        }
        await session.refreshListMembership()
    }

    private func setVisibility(_ visibility: ListVisibility) async {
        guard let client = session.client else { return }
        list?.visibility = visibility
        _ = try? await client.post("list/\(listID)/visibility",
                                   body: VisibilityRequest(visibility: visibility), as: Empty.self)
        await load()
    }

    private func toggleAudience(_ member: Person, currently picked: Bool,
                                list: ListDetail) async {
        guard let client = session.client, let id = member.id else { return }
        var shared = list.sharedWith ?? []
        if picked { shared.removeAll { $0 == id } } else { shared.append(id) }
        self.list?.sharedWith = shared
        _ = try? await client.post("list/\(listID)/visibility",
                                   body: VisibilityRequest(visibility: list.visibility ?? .public,
                                                           sharedWith: shared),
                                   as: Empty.self)
    }

    private func deleteList() async {
        guard let client = session.client else { return }
        _ = try? await client.delete("list/\(listID)", as: Empty.self)
        dismiss()
    }
}

private struct ListItemCard: View {
    let item: ListItem
    let canEdit: Bool
    let remove: () async -> Void

    var body: some View {
        // Poster first, everything else overlaid: as stack siblings the title would
        // set the tile's height and leave the art letterboxed inside it.
        NavigationLink(value: item.isShow ? Navigator.Route.show(item.id)
                                          : Navigator.Route.movie(item.id)) {
            PosterArt(url: item.poster, radius: MQ.radius)
        }
        .buttonStyle(.plain)
        .overlay {
            LinearGradient(stops: [.init(color: .clear, location: 0.4),
                                   .init(color: Color.mqScrim.opacity(0.95), location: 0.92)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                    .foregroundStyle(Color.mqInkOnArt)
                    .lineLimit(2)
                if !line.isEmpty {
                    Text(line)
                        .font(MarqueeFont.body(11.5, .semibold, relativeTo: .caption))
                        .foregroundStyle(Color.mqBrassOnArt)
                        .lineLimit(1)
                }
                if item.isShow, (item.total ?? 0) > 0 {
                    ProgressBar(fraction: item.progress, percentLabel: true, tint: tint)
                }
            }
            .padding(.horizontal, 11)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
        }
        .clipShape(.rect(cornerRadius: MQ.radius))

        .overlay(alignment: .topLeading) {
            if item.ended == true { EndedTag().padding(8) }
            else { TypeBadge(isShow: item.isShow).padding(8) }
        }
        .overlay(alignment: .topTrailing) {
            if canEdit {
                Button { Task { await remove() } } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Remove \(item.displayTitle) from this list")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.displayTitle). \(line)")
    }

    private var tint: ProgressBar.ProgressTint {
        if item.archived == true { return .stopped }
        if item.isComplete, item.ended == true { return .complete }
        return .brass
    }

    private var line: String {
        guard item.isShow else {
            if (item.watched ?? 0) > 0 { return "Watched" }
            return item.year?.text ?? ""
        }
        if item.archived == true { return "Stopped watching" }
        guard let total = item.total, total > 0 else { return item.year?.text ?? "" }
        if item.isComplete { return item.ended == true ? "Series complete" : "All caught up" }
        return "\(item.watched ?? 0) / \(total) watched"
    }
}

/// Create a list, with its visibility chosen up front.
struct NewListSheet: View {
    let onCreated: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var visibility: ListVisibility = .private

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("e.g. Weekend binges", text: $name)
                        .font(.mqBody)
                        .padding(13)
                        .mqPanel()

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ListVisibility.allCases, id: \.self) { option in
                            Button { visibility = option } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: option.symbol)
                                        .frame(width: 22)
                                        .foregroundStyle(visibility == option
                                                         ? Color.mqBrass : Color.mqInkMuted)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(option.label)
                                            .font(MarqueeFont.body(14, .bold, relativeTo: .subheadline))
                                            .foregroundStyle(Color.mqInk)
                                        Text(option.explanation)
                                            .font(.mqCaption)
                                            .foregroundStyle(Color.mqInkMuted)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 4)
                                    if visibility == option {
                                        Image(systemName: "checkmark").foregroundStyle(Color.mqBrass)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(visibility == option ? Color.mqBrassSoft : Color.mqPanel,
                                            in: .rect(cornerRadius: MQ.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(visibility == option ? .isSelected : [])
                        }
                    }
                    Spacer()
                }
                .padding(MQ.gutter)
            }
            .navigationTitle("New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationBackground(Color.mqGround)
    }

    private func create() async {
        guard let client = session.client else { return }
        _ = try? await client.post("lists",
                                   body: CreateListRequest(name: name.trimmingCharacters(in: .whitespaces),
                                                           visibility: visibility),
                                   as: CreatedList.self)
        await onCreated()
        dismiss()
    }
}

/// Search TMDB and drop results straight onto a list.
struct AddTitlesSheet: View {
    let listID: Int
    let onChanged: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var added: Set<String> = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { result in
                            Button { Task { await add(result) } } label: {
                                HStack(spacing: 11) {
                                    PosterArt(url: result.poster, radius: 6).frame(width: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(result.displayTitle)
                                            .font(MarqueeFont.body(14, .semibold, relativeTo: .subheadline))
                                            .foregroundStyle(Color.mqInk)
                                            .multilineTextAlignment(.leading)
                                        Text("\(result.isShow ? "TV" : "Film")"
                                             + (result.year?.text.isEmpty == false ? " · \(result.year!.text)" : ""))
                                            .font(.mqCaption)
                                            .foregroundStyle(Color.mqInkMuted)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: added.contains(result.uniqueKey)
                                          ? "checkmark" : "plus")
                                        .foregroundStyle(Color.mqBrass)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .mqPanel()
                            }
                            .buttonStyle(.plain)
                        }
                        if results.isEmpty {
                            Text(query.count < 2 ? "Type to search shows and films."
                                                 : "No matches.")
                                .font(.mqSub)
                                .foregroundStyle(Color.mqInkMuted)
                                .padding(.top, 30)
                        }
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle("Add titles")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Shows & films")
            .onChange(of: query) { _, new in schedule(new) }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { Task { await onChanged(); dismiss() } }.fontWeight(.bold)
                }
            }
        }
        .presentationBackground(Color.mqGround)
    }

    private func schedule(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { results = []; return }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let client = session.client else { return }
            let response: SearchResponse? = try? await client.get("search", query: ["q": trimmed])
            if !Task.isCancelled { results = response?.results ?? [] }
        }
    }

    private func add(_ result: SearchResult) async {
        guard let client = session.client else { return }
        added.insert(result.uniqueKey)
        _ = try? await client.post("list/\(listID)/item",
                                   body: ListItemToggle(itemType: result.type, itemID: result.id),
                                   as: Empty.self)
        await session.refreshListMembership()
        await onChanged()
    }
}

extension SearchResult {
    var uniqueKey: String { "\(type):\(id)" }
}
