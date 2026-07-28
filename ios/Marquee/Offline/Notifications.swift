import Foundation
import UserNotifications
import os

/// Everything to do with telling you something happened.
///
/// The server speaks Web Push (VAPID), which a native app cannot receive, and standing
/// up APNs would put a push service between the phone and a household server whose
/// address is the one thing this app is careful never to leak. So notifications are
/// local, and they come from two places:
///
/// * **Scheduled ahead.** An episode's air date is known days in advance, so its
///   notification is registered with the system there and then and fires whether or not
///   the app ever wakes up. This is the reliable half.
/// * **Opportunistic.** `BackgroundRefresh` catches everything with no knowable date —
///   a finished download, a new review — whenever iOS grants it a background slot.
@MainActor
final class Notifications: NSObject {
    static let shared = Notifications()

    private let logger = Logger(subsystem: "dev.kadenthompson.marquee",
                                category: "notifications")

    /// Air-date notifications are rebuilt wholesale each time, so they carry a prefix
    /// that makes them safe to clear as a group.
    private static let airPrefix = "air-"

    private override init() { super.init() }

    /// Called once at launch. Without a delegate a notification raised while the app is
    /// open is swallowed silently, and tapping one does nothing.
    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    var isAuthorized: Bool {
        get async {
            await UNUserNotificationCenter.current().notificationSettings()
                .authorizationStatus == .authorized
        }
    }

    /// Ask, but only once — after a denial iOS answers `false` without prompting, and
    /// the caller should send the user to Settings instead.
    @discardableResult
    func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let status = await centre.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined:
            let granted = (try? await centre.requestAuthorization(
                options: [.alert, .sound, .badge])) ?? false
            logger.info("notification permission granted: \(granted)")
            return granted
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    // MARK: - Scheduled ahead

    /// Register a notification for every upcoming episode we know the date of.
    ///
    /// Rebuilt from scratch on each refresh: episodes get delayed, renamed and
    /// cancelled, and reconciling that is more error-prone than simply replacing the
    /// set. Only the air-date ones are cleared, never anything already delivered.
    func scheduleAirDates(_ episodes: [UpcomingEpisode], leadHours: Int = 0) async {
        guard await isAuthorized else { return }
        let centre = UNUserNotificationCenter.current()

        let pending = await centre.pendingNotificationRequests()
        centre.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier)
                .filter { $0.hasPrefix(Self.airPrefix) })

        var scheduled = 0
        for episode in episodes {
            guard let airs = MQTime.date(from: episode.airDate) else { continue }
            // 9am on the day it lands, or a lead time before that if one is set.
            var when = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0,
                                             of: airs) ?? airs
            if leadHours > 0 {
                when = Calendar.current.date(byAdding: .hour, value: -leadHours, to: when) ?? when
            }
            guard when > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = episode.showTitle ?? "New episode"
            content.body = [episode.code, episode.title ?? ""]
                .filter { !$0.isEmpty }.joined(separator: " · ")
            content.userInfo = ["link": "show/\(episode.showID)"]
            content.sound = .default

            let parts = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: when)
            let request = UNNotificationRequest(
                identifier: Self.airPrefix + episode.id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
            try? await centre.add(request)
            scheduled += 1
            // The system caps pending requests at 64; leave room for everything else.
            if scheduled >= 48 { break }
        }
        logger.info("scheduled \(scheduled) air-date notifications")
    }

    /// Drop everything pending. Used on unpair, so a forgotten server can't keep
    /// announcing itself on the lock screen.
    func clearAll() {
        let centre = UNUserNotificationCenter.current()
        centre.removeAllPendingNotificationRequests()
        centre.removeAllDeliveredNotifications()
    }
}

extension Notifications: UNUserNotificationCenterDelegate {
    /// Show it even when the app is open — otherwise marking something watched on the
    /// telly while you're looking at the app produces nothing at all.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Tapping one opens what it was about.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let link = response.notification.request.content.userInfo["link"] as? String
        guard let link, !link.isEmpty else { return }
        await MainActor.run {
            guard let route = Navigator.route(fromLink: link) else { return }
            Navigator.shared.open(route)
        }
    }
}
