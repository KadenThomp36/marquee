@preconcurrency import BackgroundTasks
import Foundation
import UserNotifications
import os

/// Phase one of notifications, per the brief: rather than standing up APNs, the app
/// wakes periodically, asks the server what it missed, and raises local notifications.
///
/// That keeps the promise the rest of the app makes — nothing leaves the household —
/// because there's no push service in the middle holding your server's address.
enum BackgroundRefresh {

    private static let logger = Logger(subsystem: "dev.kadenthompson.marquee",
                                       category: "background")

    static func register(id: String) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { return }
            handle(refresh, id: id)
        }
    }

    static func schedule(id: String) {
        let request = BGAppRefreshTaskRequest(identifier: id)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask, id: String) {
        schedule(id: id)

        // BGTask predates Sendable; the whole handler stays on the main actor so the
        // capture is safe in practice, and the pre-concurrency import says so.
        let work = Task { @MainActor in
            await run()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }

    /// Ask for what's new, and say it out loud only if the user asked to be told.
    private static func run() async {
        guard let server = Vault.load() else { return }
        let client = MarqueeClient(server: server)

        if let celebrations: CelebrationsResponse = try? await client.get("celebrations"),
           let first = celebrations.celebrations.first {
            await notify(title: first.isSeries
                            ? "You finished \(first.show.displayTitle)"
                            : "\(first.show.displayTitle) — season complete",
                         body: "\(first.episodes) episodes · \(MQTime.clock(minutes: first.minutes))",
                         link: "show/\(first.show.id)",
                         id: "celebration-\(first.id)")
        }

        if let inbox: NotificationsResponse = try? await client.get("notifications") {
            for item in inbox.items.prefix(5) where !item.read {
                await notify(title: item.title, body: item.body ?? "",
                             link: item.link ?? "", id: "notification-\(item.id)")
            }
        }

        // Keep the widgets honest while the app is asleep.
        if let dashboard: Dashboard = try? await client.get("dashboard") {
            let upNext = dashboard.upNext.prefix(6).map { show in
                WidgetShow(id: show.id, title: show.displayTitle, poster: show.poster,
                           episodeCode: show.nextEp?.code, episodeTitle: show.nextEp?.title,
                           season: show.nextEp?.season, number: show.nextEp?.number,
                           watched: show.watched, aired: show.aired)
            }
            let existing = OfflineStore.shared.readWidgetSnapshot()
            OfflineStore.shared.writeWidgetSnapshot(
                WidgetSnapshot(updatedAt: Date(), upNext: Array(upNext),
                               reading: existing?.reading ?? [],
                               episodesWaiting: dashboard.upNext.reduce(0) { $0 + $1.remaining },
                               isPaired: true))
            await ArtCache.shared.warm(upNext.map(\.poster))
            MarqueeWidgetRefresh.request()
        }

        logger.info("background refresh finished")
    }

    private static func notify(title: String, body: String, link: String, id: String) async {
        let centre = UNUserNotificationCenter.current()
        let settings = await centre.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        content.userInfo = ["link": link]
        content.sound = .default
        try? await centre.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Asked for once, the first time someone turns a notification preference on.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
}
