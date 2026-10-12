import PhotosUI
import SwiftUI

/// Name, username, password — the three things you own about your account.
struct EditProfileSheet: View {
    let profile: ProfilePayload?
    let onSaved: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var username = ""
    @State private var password = ""
    @State private var photo: PhotosPickerItem?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        if let profile {
                            AvatarView(person: profile.person, size: 60,
                                       baseURL: session.server?.baseURL)
                        }
                        PhotosPicker(selection: $photo, matching: .images) {
                            Label("Change photo", systemImage: "camera")
                                .font(.mqSub)
                        }
                        .buttonStyle(.mqChip)
                    }
                    .padding(.vertical, 4)
                }

                Section("Display name") {
                    TextField("Display name", text: $displayName)
                }
                Section("Username") {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    SecureField("New password", text: $password)
                        .textContentType(.newPassword)
                } header: {
                    Text("Password")
                } footer: {
                    Text("Leave blank to keep the one you have.")
                }

                if let error {
                    Section { Text(error).foregroundStyle(Color.mqVelvet) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.mqGround)
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .fontWeight(.bold)
                        .disabled(busy)
                }
            }
        }
        .presentationBackground(Color.mqGround)
        .onAppear {
            displayName = profile?.displayName ?? ""
            username = profile?.username ?? ""
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private func save() async {
        guard let client = session.client else { return }
        busy = true
        defer { busy = false }
        var request = UpdateProfileRequest(displayName: displayName, username: username)
        if !password.isEmpty { request.password = password }
        do {
            try await client.post("profile", body: request, as: Empty.self)
            await session.refreshMe()
            await onSaved()
            dismiss()
        } catch let failure as APIError {
            error = failure.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        guard let client = session.client,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        // Send a reasonably-sized JPEG rather than a 12-megapixel original.
        let jpeg = UIImage(data: data)?.mqSquareJPEG(side: 480) ?? data
        _ = try? await client.upload("profile/avatar", fileData: jpeg,
                                     filename: "avatar.jpg", mimeType: "image/jpeg",
                                     as: AvatarResponse.self)
        await session.refreshMe()
        await onSaved()
    }
}

/// Pick a banner from the shows you actually watch, or upload one.
struct BannerPickerSheet: View {
    let onSet: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var options: [BannerOption] = []
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            MarqueeScreen {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            PhotosPicker(selection: $photo, matching: .images) {
                                Label("Upload your own", systemImage: "photo")
                                    .font(.mqSub)
                            }
                            .buttonStyle(.mqChip)
                            Button("Remove banner") { Task { await clear() } }
                                .buttonStyle(.mqChip(on: false, destructive: true))
                        }

                        Text("From shows you watch").mqEyebrowStyle()

                        ForEach(options) { option in
                            Button { Task { await pick(option) } } label: {
                                ZStack(alignment: .bottomLeading) {
                                    FilledArt(url: option.backdrop, height: 116)
                                    LinearGradient(colors: [.clear, Color.mqScrim.opacity(0.9)],
                                                   startPoint: .center, endPoint: .bottom)
                                    Text(option.title)
                                        .font(MarqueeFont.body(13, .bold, relativeTo: .caption))
                                        .foregroundStyle(.white)
                                        .padding(10)
                                }
                                .frame(height: 116)
                                .clipShape(.rect(cornerRadius: MQ.radiusSmall))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Use \(option.title) as your banner")
                        }

                        if options.isEmpty {
                            Text("Watch a few shows and their artwork shows up here.")
                                .font(.mqSub)
                                .foregroundStyle(Color.mqInkMuted)
                                .padding(.top, 20)
                        }
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle("Profile banner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
        .presentationBackground(Color.mqGround)
        .task {
            guard let client = session.client else { return }
            options = (try? await client.get("profile/banner/options",
                                             as: BannerOptionsResponse.self))?.options ?? []
        }
        .onChange(of: photo) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
    }

    private func pick(_ option: BannerOption) async {
        guard let client = session.client else { return }
        _ = try? await client.post("profile/banner",
                                   body: SetBannerRequest(url: option.backdrop),
                                   as: BannerResponse.self)
        await onSet()
        dismiss()
    }

    private func clear() async {
        guard let client = session.client else { return }
        _ = try? await client.post("profile/banner", body: SetBannerRequest(clear: true),
                                   as: BannerResponse.self)
        await onSet()
        dismiss()
    }

    private func upload(_ item: PhotosPickerItem) async {
        guard let client = session.client,
              let data = try? await item.loadTransferable(type: Data.self) else { return }
        _ = try? await client.upload("profile/banner/upload", fileData: data,
                                     filename: "banner.jpg", mimeType: "image/jpeg",
                                     as: BannerResponse.self)
        await onSet()
        dismiss()
    }
}

/// Favourites are an ordered, deliberate shelf — so adding one is a search, not a tap
/// on a heart you happened to be near.
struct FavoritePickerSheet: View {
    let onAdded: () async -> Void

    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SearchResult] = []
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
                                    Image(systemName: "star")
                                        .foregroundStyle(Color.mqBrass)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .mqPanel()
                            }
                            .buttonStyle(.plain)
                        }
                        if results.isEmpty {
                            Text(query.count < 2 ? "Search for something you love."
                                                 : "No matches.")
                                .font(.mqSub)
                                .foregroundStyle(Color.mqInkMuted)
                                .padding(.top, 30)
                        }
                    }
                    .padding(MQ.gutter)
                }
            }
            .navigationTitle("Add a favorite")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Shows & films")
            .onChange(of: query) { _, new in schedule(new) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
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
        _ = try? await client.post("favorites",
                                   body: FavoriteRequest(itemType: result.type, itemID: result.id),
                                   as: FavoritesResponse.self)
        await onAdded()
        dismiss()
    }
}

extension UIImage {
    /// Centre-crop to a square and compress — avatars are shown at 96pt at most.
    func mqSquareJPEG(side: CGFloat, quality: CGFloat = 0.85) -> Data? {
        let shortest = min(size.width, size.height)
        let crop = CGRect(x: (size.width - shortest) / 2, y: (size.height - shortest) / 2,
                          width: shortest, height: shortest)
        guard let cropped = cgImage?.cropping(to: crop) else { return jpegData(compressionQuality: quality) }
        let square = UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let resized = renderer.image { _ in
            square.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
