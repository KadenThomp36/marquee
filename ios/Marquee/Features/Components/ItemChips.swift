import SwiftUI

/// The favourite toggle on a detail page. Favourites are ordered and shown on your
/// profile, so this is a considered pick rather than a like button.
struct FavoriteChip: View {
    let itemType: String
    let itemID: Int

    @Environment(Session.self) private var session
    @State private var isOn = false
    @State private var loaded = false

    var body: some View {
        ChipButton(title: isOn ? "Favorited" : "Favorite",
                   symbol: isOn ? "star.fill" : "star",
                   isOn: isOn) {
            Task { await toggle() }
        }
        .task { await load() }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func load() async {
        guard !loaded, let client = session.client else { return }
        loaded = true
        if let response: FavoritesResponse = try? await client.get("favorites") {
            isOn = response.favorites.contains { $0.type == itemType && $0.id == itemID }
        }
    }

    private func toggle() async {
        guard let client = session.client else { return }
        let next = !isOn
        isOn = next
        do {
            if next {
                _ = try await client.post("favorites",
                                          body: FavoriteRequest(itemType: itemType, itemID: itemID),
                                          as: FavoritesResponse.self)
            } else {
                _ = try await client.delete("favorites/\(itemType)/\(itemID)",
                                            as: FavoritesResponse.self)
            }
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .favorite(itemType: itemType, itemID: itemID, remove: !next)))
        }
    }
}

/// "List" — and once a title is on one, the chip says which.
struct AddToListChip: View {
    let itemType: String
    let itemID: Int
    let title: String

    @Environment(Session.self) private var session
    @State private var showingSheet = false

    private var count: Int { session.listCount(itemType, itemID) }

    var body: some View {
        ChipButton(title: label,
                   symbol: count > 0 ? "bookmark.fill" : "text.badge.plus",
                   isOn: count > 0) {
            showingSheet = true
        }
        .sheet(isPresented: $showingSheet) {
            AddToListSheet(itemType: itemType, itemID: itemID, title: title)
        }
    }

    private var label: String {
        switch count {
        case 0: "List"
        case 1: "In a list"
        default: "In \(count) lists"
        }
    }
}

/// Pick which lists a title belongs to, and make a new one without leaving.
struct AddToListSheet: View {
    let itemType: String
    let itemID: Int
    let title: String

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [ItemListRow] = []
    @State private var newListName = ""
    @State private var busy: Set<Int> = []

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(rows) { row in
                            Button { Task { await toggle(row) } } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: row.collab ? "person.2.fill"
                                          : (row.has ? "bookmark.fill" : "bookmark"))
                                        .font(.system(size: 15))
                                        .foregroundStyle(row.has ? Color.mqBrass : Color.mqInkMuted)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(row.name)
                                            .font(MarqueeFont.body(14.5, .semibold, relativeTo: .subheadline))
                                            .foregroundStyle(Color.mqInk)
                                        if let owner = row.owner {
                                            Text("shared by \(owner)")
                                                .font(.mqCaption)
                                                .foregroundStyle(Color.mqInkMuted)
                                        }
                                    }
                                    Spacer(minLength: 6)
                                    if busy.contains(row.id) {
                                        ProgressView().controlSize(.small)
                                    } else if row.has {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.mqBrass)
                                    }
                                }
                                .padding(13)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(row.has ? Color.mqBrassSoft : Color.mqPanel,
                                            in: .rect(cornerRadius: MQ.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(row.has ? .isSelected : [])
                        }

                        HStack(spacing: 8) {
                            TextField("New list name…", text: $newListName)
                                .font(.mqBody)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 12)
                                .background(Color.mqPanel, in: .rect(cornerRadius: MQ.radiusSmall))
                                .submitLabel(.done)
                                .onSubmit { Task { await createList() } }
                            Button {
                                Task { await createList() }
                            } label: {
                                Image(systemName: "plus")
                                    .frame(width: 42, height: 42)
                            }
                            .buttonStyle(.mqChip)
                            .disabled(newListName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.top, 6)
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle("Add to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.mqGround)
        .task { await load() }
    }

    private func load() async {
        guard let client = session.client else { return }
        if let response: ItemListsResponse =
            try? await client.get("item/\(itemType)/\(itemID)/lists") {
            rows = response.lists
        }
    }

    private func toggle(_ row: ItemListRow) async {
        guard let client = session.client else { return }
        busy.insert(row.id)
        defer { busy.remove(row.id) }
        do {
            try await client.post("list/\(row.id)/item",
                                  body: ListItemToggle(itemType: itemType, itemID: itemID,
                                                       remove: row.has ? true : nil),
                                  as: Empty.self)
        } catch {
            OfflineStore.shared.enqueue(PendingWrite(
                .listToggle(listID: row.id, itemType: itemType, itemID: itemID, remove: row.has)))
        }
        await load()
        await session.refreshListMembership()
    }

    private func createList() async {
        let name = newListName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let client = session.client else { return }
        newListName = ""
        guard let created: CreatedList = try? await client.post(
            "lists", body: CreateListRequest(name: name, visibility: .private)) else { return }
        _ = try? await client.post("list/\(created.id)/item",
                                   body: ListItemToggle(itemType: itemType, itemID: itemID),
                                   as: Empty.self)
        await load()
        await session.refreshListMembership()
    }
}

/// Admin-only: add placeholder episodes TMDB doesn't have — a fan edit, a gap in the
/// catalogue. If TMDB later publishes the same numbers, its data takes over and the
/// watch marks stay put.
struct CustomEpisodesSheet: View {
    let showID: Int
    let defaultSeason: Int
    let onAdded: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var season: Int
    @State private var count = ""
    @State private var titles = ""
    @State private var airDate = Date()
    @State private var busy = false
    @State private var message: String?

    init(showID: Int, defaultSeason: Int, onAdded: @escaping () async -> Void) {
        self.showID = showID
        self.defaultSeason = defaultSeason
        self.onAdded = onAdded
        _season = State(initialValue: defaultSeason)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Season \(season)", value: $season, in: 0...99)
                    TextField("How many episodes", text: $count)
                        .keyboardType(.numberPad)
                    DatePicker("Air date", selection: $airDate, displayedComponents: .date)
                } footer: {
                    Text("Numbering continues after the last existing episode. The air date defaults to today so they count as aired.")
                }

                Section("…or paste titles, one per line") {
                    TextEditor(text: $titles)
                        .frame(minHeight: 100)
                        .font(.mqBody)
                }

                if let message {
                    Section { Text(message).foregroundStyle(Color.mqBrass) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.mqGround)
            .navigationTitle("Add missing episodes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await add() } }
                        .fontWeight(.bold)
                        .disabled(busy || (Int(count) ?? 0) <= 0 && titles.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationBackground(Color.mqGround)
    }

    private func add() async {
        guard let client = session.client else { return }
        busy = true
        defer { busy = false }
        let request = CustomEpisodesRequest(season: season,
                                            count: Int(count) ?? 0,
                                            titles: titles,
                                            airDate: MQTime.today(airDate))
        guard let response: CustomEpisodesResponse =
                try? await client.post("show/\(showID)/episodes/custom", body: request) else {
            message = "Couldn't add those."
            return
        }
        message = "Added \(response.added) episode\(response.added == 1 ? "" : "s") to season \(response.season)."
        await onAdded()
        dismiss()
    }
}
