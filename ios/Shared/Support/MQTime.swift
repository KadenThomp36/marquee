import Foundation

/// Timestamps in Marquee are **naive household-local**, not UTC — the database was
/// migrated to that deliberately in build 20260718a. So every string sent up looks
/// like `2026-07-27T21:04:00` with no zone and no `Z`, and every string read back is
/// interpreted in the device's own zone.
///
/// Everything here works on the strings rather than converting eagerly, because
/// lexicographic order on this format *is* chronological order — which is how the
/// server compares them too.
public enum MQTime {

    /// `YYYY-MM-DDTHH:MM:SS` for right now, in local time. The format the API expects.
    public static func stamp(_ date: Date = Date()) -> String {
        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d-%02d-%02dT%02d:%02d:%02d",
                      parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1,
                      parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0)
    }

    /// `YYYY-MM-DD` for today, local.
    public static func today(_ date: Date = Date()) -> String {
        String(stamp(date).prefix(10))
    }

    /// Parse a naive stamp (or a bare date) back into a `Date` in the local zone.
    public static func date(from stamp: String?) -> Date? {
        guard let stamp, stamp.count >= 10 else { return nil }
        var components = DateComponents()
        components.year = Int(stamp.prefix(4))
        components.month = Int(stamp.dropFirst(5).prefix(2))
        components.day = Int(stamp.dropFirst(8).prefix(2))
        if stamp.count >= 19 {
            components.hour = Int(stamp.dropFirst(11).prefix(2))
            components.minute = Int(stamp.dropFirst(14).prefix(2))
            components.second = Int(stamp.dropFirst(17).prefix(2))
        }
        return Calendar.current.date(from: components)
    }

    /// "14 Mar 2026" — the app's standard date, localised.
    public static func medium(_ stamp: String?) -> String {
        guard let date = date(from: stamp) else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    /// "14 Mar" — for anywhere the year is obvious from context.
    public static func short(_ stamp: String?) -> String {
        guard let date = date(from: stamp) else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// "Today", "Yesterday", "Tue 14 Mar" — the history timeline's day heading.
    public static func dayLabel(_ dayStamp: String) -> String {
        guard let date = date(from: dayStamp) else { return dayStamp }
        let days = daysAgo(date)
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    /// "March 2026" — the month rule in the history timeline.
    public static func monthLabel(_ dayStamp: String) -> String {
        guard let date = date(from: dayStamp) else { return dayStamp }
        return date.formatted(.dateTime.month(.wide).year())
    }

    /// The buckets the Up Next rail scrolls back through.
    public static func bucketLabel(_ stamp: String) -> String {
        guard let date = date(from: stamp) else { return "Earlier" }
        switch daysAgo(date) {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        case 2..<7: return "This week"
        case 7..<14: return "Last week"
        case 14..<31: return "Last month"
        default: return "Earlier"
        }
    }

    public static func daysAgo(_ date: Date, from reference: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: reference)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// "3 days", "5 months" — how long ago something happened, in words.
    public static func relative(_ stamp: String?) -> String {
        guard let date = date(from: stamp) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }

    /// "Tonight", "Tomorrow", "Thursday", "14 Mar" — the Upcoming day heading.
    public static func upcomingLabel(_ dayStamp: String) -> String {
        guard let date = date(from: dayStamp) else { return dayStamp }
        let days = -daysAgo(date)
        if days <= 0 { return "Tonight" }
        if days == 1 { return "Tomorrow" }
        if days < 7 { return date.formatted(.dateTime.weekday(.wide)) }
        return medium(dayStamp)
    }

    /// "4h 20m" from minutes — the shape used on cards and stat tiles.
    public static func duration(minutes: Int) -> String {
        if minutes >= 6000 {
            return String(format: "%.1f days", Double(minutes) / 1440)
        }
        return "\(Int((Double(minutes) / 60).rounded())) hrs"
    }

    /// "1h 42m" — for a single sitting rather than a lifetime total.
    public static func clock(minutes: Int) -> String {
        minutes >= 60
            ? "\(minutes / 60)h\(minutes % 60 > 0 ? " \(minutes % 60)m" : "")"
            : "\(minutes)m"
    }

    /// "2026-03" as "March 2026", for a chart readout.
    static func monthKeyLabel(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let month = Int(parts[1]), (1...12).contains(month) else {
            return key
        }
        return "\(monthName(month - 1)) \(parts[0])"
    }

    /// "January" for 0. Used where a one-letter axis label needs spelling out.
    static func monthName(_ index: Int) -> String {
        let names = ["January", "February", "March", "April", "May", "June", "July",
                     "August", "September", "October", "November", "December"]
        return names[((index % 12) + 12) % 12]
    }
}

public extension Int {
    /// 1,482 — counts read better with separators everywhere they appear.
    var mqGrouped: String { formatted(.number.grouping(.automatic)) }

}
