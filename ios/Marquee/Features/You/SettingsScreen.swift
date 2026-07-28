import SwiftUI

/// Everything about how this install behaves: which devices are paired, what gets
/// tracked, what you're told about, and how Plex and Overseerr are wired up.
struct SettingsScreen: View {
    @Environment(Session.self) private var session

    @State private var plex: PlexStatus?
    @State private var overseerr: OverseerrAccount?
    @State private var imdb: IMDbStatus?
    @State private var prefs: [NotificationPref] = []
    @State private var devices: [DeviceSession] = []
    @State private var hiddenDevices = 0
    @State private var pendingWrites = 0
    @State private var plexPin: PlexPin?
    @State private var plexWaiting = false
    @State private var confirmingUnpair = false
    @State private var revoking: DeviceSession?

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    devicesPanel
                    offlinePanel
                    plexPanel
                    if let imdb { imdbPanel(imdb) }
                    notificationsPanel
                    trackingPanel
                    aboutPanel
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadAll() }
        .confirmationDialog("Unpair this device?", isPresented: $confirmingUnpair,
                            titleVisibility: .visible) {
            Button("Unpair", role: .destructive) {
                Task { WidgetBridge.clear(); await session.unpair() }
            }
        } message: {
            Text("Marquee forgets your server address and signs this device out.")
        }
        .confirmationDialog("Sign out \(revoking?.deviceName ?? "")?",
                            isPresented: .init(get: { revoking != nil },
                                               set: { if !$0 { revoking = nil } }),
                            titleVisibility: .visible) {
            Button("Sign it out", role: .destructive) {
                if let device = revoking { Task { await revoke(device) } }
                revoking = nil
            }
        }
    }

    // MARK: - Panels

    private var devicesPanel: some View {
        Panel(title: "Devices", symbol: "lock.shield",
              note: "Every device signed in as you. Unpairing one revokes its session on the server, so it can't reach your data again without pairing afresh.") {
            VStack(spacing: 0) {
                ForEach(devices) { device in
                    HStack(spacing: 11) {
                        Image(systemName: device.current ? "checkmark.seal.fill" : "iphone")
                            .foregroundStyle(device.current ? Color.mqBrass : Color.mqInkMuted)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.deviceName + (device.current ? " · this device" : ""))
                                .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                                .foregroundStyle(Color.mqInk)
                            Text(detail(for: device))
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                        }
                        Spacer(minLength: 6)
                        Button {
                            if device.current { confirmingUnpair = true } else { revoking = device }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.mqInkMuted)
                                .frame(width: 30, height: 30)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sign out \(device.deviceName)")
                    }
                    .padding(.vertical, 10)
                    if device.id != devices.last?.id {
                        Divider().overlay(Color.mqHairline)
                    }
                }
                if devices.isEmpty {
                    Text("Loading…").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                }
                if hiddenDevices > 0 {
                    Divider().overlay(Color.mqHairline)
                    // Years of browser logins pile up behind these. Naming the number
                    // is more use than listing them, and there's one button for it.
                    Text("^[\(hiddenDevices) older session](inflect: true) not shown. "
                         + "Signing out every other device clears them.")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                }
            }
        }
    }

    @ViewBuilder
    private var offlinePanel: some View {
        if pendingWrites > 0 {
            Panel(title: "Waiting to sync", symbol: "arrow.triangle.2.circlepath",
                  note: "Changes you made while your server was out of reach. They're replayed automatically the next time it answers.") {
                HStack {
                    Text("\(pendingWrites) change\(pendingWrites == 1 ? "" : "s") queued")
                        .font(.mqSub)
                        .foregroundStyle(Color.mqInk)
                    Spacer()
                    Button("Try now") {
                        Task {
                            await SyncCoordinator.shared.replayPending(session: session)
                            pendingWrites = SyncCoordinator.shared.pendingCount
                        }
                    }
                    .buttonStyle(.mqChip)
                }
            }
        }
    }

    private var plexPanel: some View {
        Panel(title: "Plex sync", symbol: "play.tv",
              note: "Anything you watch in Plex gets crossed off here automatically.") {
            VStack(alignment: .leading, spacing: 12) {
                if let plex, plex.isLinked {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.mqPlex)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Linked to \(plex.plexUsername ?? "")")
                                .font(MarqueeFont.body(13.5, .bold, relativeTo: .caption))
                                .foregroundStyle(Color.mqInk)
                            Text(plex.directSync == true
                                 ? "Direct connection active — history checked every minute."
                                 : "Linked by name only. Re-link once to enable the direct connection.")
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                            if let last = plex.lastEvent, !last.isEmpty {
                                Text("Last sync \(MQTime.medium(last))"
                                     + (plex.lastEventUser.map { " · \($0)" } ?? ""))
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        if plex.hasOwnToken != true {
                            Button("Re-link") { Task { await startPlexLink() } }
                                .buttonStyle(.mqChip)
                        }
                        Button("Unlink") { Task { await unlinkPlex() } }
                            .buttonStyle(.mqChip(on: false, destructive: true))
                    }
                } else {
                    Button { Task { await startPlexLink() } } label: {
                        Label("Link with Plex", systemImage: "link")
                            .font(.mqSub)
                    }
                    .buttonStyle(.mqChip)
                }

                if plexWaiting {
                    Text("Waiting for you to approve it in Plex…")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqBrass)
                }

                if let overseerr, overseerr.enabled {
                    Divider().overlay(Color.mqHairline)
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(Color.mqOverseerr)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Requests" + (overseerr.account.map { " · \($0)" } ?? ""))
                                .font(MarqueeFont.body(13.5, .bold, relativeTo: .caption))
                                .foregroundStyle(Color.mqInk)
                            Text(overseerr.linked == true
                                 ? "Your requests are sent to Overseerr as you."
                                 : (overseerr.reason ?? "Link your Plex account to request media."))
                                .font(.mqCaption)
                                .foregroundStyle(Color.mqInkMuted)
                        }
                        Spacer(minLength: 4)
                        if overseerr.linked == true {
                            Image(systemName: "checkmark").foregroundStyle(Color.mqBrass)
                        }
                    }
                }
            }
        }
    }

    private func imdbPanel(_ imdb: IMDbStatus) -> some View {
        Panel(title: "IMDb ratings", symbol: "star.circle",
              note: "Episode, season, show and film ratings come from IMDb's daily dataset — no account, no API key. TMDB fills the gaps.") {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 1) {
                    Text((imdb.episodesRated ?? 0).mqGrouped)
                        .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
                        .foregroundStyle(Color.mqBrassBright)
                    Text("of \((imdb.episodes ?? 0).mqGrouped) episodes rated")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(imdb.last.map { MQTime.medium($0) } ?? "never")
                        .font(MarqueeFont.body(17, .bold, relativeTo: .title3))
                        .foregroundStyle(Color.mqBrassBright)
                    Text("last sync")
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkMuted)
                }
                Spacer(minLength: 4)
                if session.me?.isAdmin == true {
                    Button(imdb.running ? "Syncing…" : "Sync now") {
                        Task { await syncIMDb() }
                    }
                    .buttonStyle(.mqChip)
                    .disabled(imdb.running)
                }
            }
        }
    }

    private var notificationsPanel: some View {
        Panel(title: "Notifications", symbol: "bell",
              note: "Off by default — switch on only what you want. Alerts land in your inbox, and on this device once you allow them.") {
            VStack(spacing: 0) {
                ForEach(prefs) { pref in
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { pref.enabled },
                            set: { value in Task { await setPref(pref, enabled: value) } })) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pref.label)
                                    .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                                    .foregroundStyle(Color.mqInk)
                                Text(pref.help)
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqInkMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .tint(Color.mqBrassFill)

                        if pref.hasDays, pref.enabled {
                            FlowLayout(spacing: 7, lineSpacing: 7) {
                                ForEach(leadOptions, id: \.0) { value, label in
                                    let on = pref.leadDays.contains(value)
                                    Button {
                                        Task { await toggleLead(pref, value: value) }
                                    } label: {
                                        Text(label)
                                            .font(.mqCaption)
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .foregroundStyle(on ? Color.mqBrass : Color.mqInkSoft)
                                            .background(on ? Color.mqBrassSoft : Color.mqPanelRaised,
                                                        in: .capsule)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .padding(.vertical, 11)
                    if pref.id != prefs.last?.id { Divider().overlay(Color.mqHairline) }
                }
                if prefs.isEmpty {
                    Text("Loading…").font(.mqCaption).foregroundStyle(Color.mqInkMuted)
                }
            }
        }
    }

    private var leadOptions: [(String, String)] {
        [("0", "When it airs"), ("1", "1 day before"),
         ("3", "3 days before"), ("7", "1 week before")]
    }

    private var trackingPanel: some View {
        Panel(title: "Tracking extras", symbol: "books.vertical",
              note: "Off by default. Switching one on adds it to your Library — nobody else's changes.") {
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { session.me?.features?.tracksBooks == true },
                    set: { value in Task { await setFeature(books: value) } })) {
                    featureLabel("Books",
                                 "Reads, to-reads, page progress and ratings, via Hardcover.")
                }
                .tint(Color.mqBrassFill)
                Divider().overlay(Color.mqHairline).padding(.vertical, 8)
                Toggle(isOn: Binding(
                    get: { session.me?.features?.tracksManga == true },
                    set: { value in Task { await setFeature(manga: value) } })) {
                    featureLabel("Manga · manhwa · manhua",
                                 "Chapter-by-chapter progress via AniList and MangaDex.")
                }
                .tint(Color.mqBrassFill)
            }
        }
    }

    private func featureLabel(_ title: String, _ detail: String) -> some View {
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

    private var aboutPanel: some View {
        Panel(title: "About", symbol: "info.circle", note: nil) {
            VStack(alignment: .leading, spacing: 8) {
                row("Signed in as", session.me?.name ?? "—")
                row("This device", session.server?.deviceName ?? "—")
                row("App version",
                    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0")
                Text("Marquee talks to your server and to the image CDNs your server points at — nothing else. No analytics, no crash reporting.")
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .padding(.top, 4)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.mqCaption).foregroundStyle(Color.mqInkMuted)
            Spacer()
            Text(value).font(.mqCaption).foregroundStyle(Color.mqInkSoft)
        }
    }

    private func detail(for device: DeviceSession) -> String {
        var parts: [String] = []
        if let created = device.createdAt, !created.isEmpty {
            parts.append("paired \(MQTime.medium(created))")
        }
        if let seen = device.lastSeen, !seen.isEmpty {
            parts.append("last used \(MQTime.relative(seen))")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Loading

    private func loadAll() async {
        pendingWrites = SyncCoordinator.shared.pendingCount
        guard let client = session.client else { return }
        async let plexTask: PlexStatus? = try? await client.get("plex/status")
        async let overseerrTask: OverseerrAccount? = try? await client.get("overseerr/me")
        async let imdbTask: IMDbStatus? = try? await client.get("imdb/status")
        async let prefsTask: NotificationPrefsResponse? = try? await client.get("notifications/prefs")
        async let devicesTask: DeviceSessions? = try? await client.get("sessions")

        plex = await plexTask
        overseerr = await overseerrTask
        imdb = await imdbTask
        prefs = await prefsTask?.prefs ?? []
        let deviceResponse = await devicesTask
        devices = deviceResponse?.sessions ?? []
        hiddenDevices = deviceResponse?.hidden ?? 0
    }

    // MARK: - Actions

    private func setPref(_ pref: NotificationPref, enabled: Bool) async {
        guard let client = session.client else { return }
        if let index = prefs.firstIndex(where: { $0.id == pref.id }) { prefs[index].enabled = enabled }
        _ = try? await client.post("notifications/prefs",
                                   body: SetNotificationPref(type: pref.type, enabled: enabled,
                                                             value: pref.value),
                                   as: Empty.self)
    }

    private func toggleLead(_ pref: NotificationPref, value: String) async {
        guard let client = session.client,
              let index = prefs.firstIndex(where: { $0.id == pref.id }) else { return }
        var days = pref.leadDays
        if days.contains(value) { days.remove(value) } else { days.insert(value) }
        // At least one lead time, or "airing" would be on but never fire.
        if days.isEmpty { days = [value] }
        let joined = days.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }.joined(separator: ",")
        prefs[index].value = joined
        _ = try? await client.post("notifications/prefs",
                                   body: SetNotificationPref(type: pref.type, enabled: true,
                                                             value: joined),
                                   as: Empty.self)
    }

    private func setFeature(books: Bool? = nil, manga: Bool? = nil) async {
        guard let client = session.client else { return }
        let request = FeaturesRequest(books: books.map { $0 ? 1 : 0 },
                                      manga: manga.map { $0 ? 1 : 0 })
        _ = try? await client.post("profile/features", body: request, as: FeaturesResponse.self)
        await session.refreshMe()
    }

    private func startPlexLink() async {
        guard let client = session.client else { return }
        guard let pin: PlexPin = try? await client.post("plex/pin") else { return }
        plexPin = pin
        plexWaiting = true
        if let url = URL(string: pin.url) {
            await UIApplication.shared.open(url)
        }
        // Poll until Plex says the PIN was approved, or two and a half minutes pass.
        for _ in 0..<50 {
            try? await Task.sleep(for: .seconds(3))
            guard let poll: PlexPinPoll = try? await client.get("plex/pin/\(pin.id)") else { break }
            if poll.linked {
                plexWaiting = false
                await loadAll()
                return
            }
        }
        plexWaiting = false
    }

    private func unlinkPlex() async {
        guard let client = session.client else { return }
        _ = try? await client.post("plex/unlink", as: Empty.self)
        await loadAll()
    }

    private func syncIMDb() async {
        guard let client = session.client else { return }
        _ = try? await client.post("imdb/sync", as: Empty.self)
        imdb?.running = true
        try? await Task.sleep(for: .seconds(12))
        await loadAll()
    }

    private func revoke(_ device: DeviceSession) async {
        guard let client = session.client else { return }
        devices.removeAll { $0.id == device.id }
        _ = try? await client.delete("sessions/\(device.id)", as: Empty.self)
        await loadAll()
    }
}

/// A titled block with a short explanation — the shape every settings group uses.
struct Panel<Content: View>: View {
    let title: String
    let symbol: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(MarqueeFont.body(15, .bold, relativeTo: .headline))
                .foregroundStyle(Color.mqInk)
            if let note {
                Text(note)
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .mqPanel(radius: MQ.radius)
        .padding(.horizontal, MQ.gutter)
    }
}

/// The bell inbox.
struct NotificationsScreen: View {
    @Environment(Session.self) private var session
    @State private var response: NotificationsResponse?

    var body: some View {
        MarqueeScreen {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(response?.items ?? []) { item in
                        row(item)
                    }
                    if response?.items.isEmpty == true {
                        VStack(spacing: 10) {
                            Text("Nothing yet.")
                                .font(.mqSub)
                                .foregroundStyle(Color.mqInkMuted)
                            NavigationLink(value: Navigator.Route.settings) {
                                Text("Choose what you're notified about")
                                    .font(.mqCaption)
                                    .foregroundStyle(Color.mqBrass)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(MQ.gutter)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func row(_ item: AppNotification) -> some View {
        let destination = item.link.flatMap { Navigator.route(fromLink: $0) }
        Group {
            if let destination {
                NavigationLink(value: destination) { content(item) }
            } else {
                content(item)
            }
        }
        .buttonStyle(.plain)
    }

    private func content(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol(for: item.type))
                .foregroundStyle(item.read ? Color.mqInkMuted : Color.mqBrass)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MarqueeFont.body(13.5, .semibold, relativeTo: .caption))
                    .foregroundStyle(Color.mqInk)
                    .multilineTextAlignment(.leading)
                if let body = item.body, !body.isEmpty {
                    Text(body)
                        .font(.mqCaption)
                        .foregroundStyle(Color.mqInkSoft)
                }
                Text(MQTime.medium(item.createdAt))
                    .font(.mqCaption)
                    .foregroundStyle(Color.mqInkMuted)
            }
            Spacer(minLength: 4)
            if !item.read {
                Circle().fill(Color.mqBrass).frame(width: 7, height: 7).padding(.top, 5)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.read ? Color.mqPanel : Color.mqBrassSoft,
                    in: .rect(cornerRadius: MQ.radiusSmall))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.read ? "" : "Unread. ")\(item.title)")
    }

    private func symbol(for type: String) -> String {
        switch type {
        case "reply": "arrowshape.turn.up.left"
        case "comment": "text.bubble"
        case "airing": "bell"
        case "new_season": "star"
        case "available": "checkmark.circle"
        case "plex": "play.tv"
        default: "bell"
        }
    }

    private func load() async {
        guard let client = session.client else { return }
        response = try? await client.get("notifications", as: NotificationsResponse.self)
        if (response?.unread ?? 0) > 0 {
            _ = try? await client.post("notifications/read",
                                       body: MarkNotificationsRead(), as: Empty.self)
        }
    }
}
