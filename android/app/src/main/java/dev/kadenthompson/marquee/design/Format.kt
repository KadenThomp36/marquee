package dev.kadenthompson.marquee.design

import java.text.NumberFormat
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.util.Locale
import kotlin.math.roundToInt

/**
 * Timestamps from the server are naive local household time ("2026-10-11T21:04:00").
 * Never parsed as UTC: the household and the server share a clock.
 */
object MQTime {
    private val stampFmt = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss")

    fun stamp(at: LocalDateTime = LocalDateTime.now()): String = at.format(stampFmt)
    fun today(): String = LocalDate.now().toString()

    fun dateTime(stamp: String?): LocalDateTime? {
        if (stamp == null || stamp.length < 10) return null
        return runCatching {
            val d = LocalDate.parse(stamp.take(10))
            if (stamp.length >= 16) {
                val h = stamp.substring(11, 13).toInt(); val m = stamp.substring(14, 16).toInt()
                val s = if (stamp.length >= 19) stamp.substring(17, 19).toIntOrNull() ?: 0 else 0
                d.atTime(h, m, s)
            } else d.atStartOfDay()
        }.getOrNull()
    }

    fun date(stamp: String?): LocalDate? = dateTime(stamp)?.toLocalDate()

    private fun month(d: LocalDate) = d.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())

    /** "Oct 31, 2026" */
    fun medium(stamp: String?): String = date(stamp)?.let { "${month(it)} ${it.dayOfMonth}, ${it.year}" } ?: ""
    /** "Oct 31" */
    fun short(stamp: String?): String = date(stamp)?.let { "${month(it)} ${it.dayOfMonth}" } ?: ""

    fun daysAgo(d: LocalDate, from: LocalDate = LocalDate.now()) = ChronoUnit.DAYS.between(d, from).toInt()

    fun dayLabel(stamp: String): String {
        val d = date(stamp) ?: return stamp
        return when (daysAgo(d)) {
            0 -> "Today"; 1 -> "Yesterday"
            else -> "${d.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault())}, ${month(d)} ${d.dayOfMonth}"
        }
    }

    fun monthLabel(stamp: String): String = date(stamp)?.let {
        "${it.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${it.year}"
    } ?: stamp

    fun bucketLabel(stamp: String): String {
        val d = date(stamp) ?: return "Earlier"
        val n = daysAgo(d)
        return when {
            n < 1 -> "Today"; n == 1 -> "Yesterday"; n < 7 -> "This week"; n < 14 -> "Last week"
            n < 31 -> "Last month"; else -> "Earlier"
        }
    }

    /** "5 minutes ago", "yesterday", "3 weeks ago". */
    fun relative(stamp: String?): String {
        val t = dateTime(stamp) ?: return ""
        val mins = ChronoUnit.MINUTES.between(t, LocalDateTime.now())
        return when {
            mins < 0 -> when (val d = -ChronoUnit.DAYS.between(LocalDate.now(), t.toLocalDate()).toInt()) {
                0 -> "today"; -1 -> "tomorrow"; else -> "in ${-d} days"
            }
            mins < 1 -> "just now"
            mins < 60 -> "$mins min ago"
            mins < 60 * 24 -> "${mins / 60} hr ago"
            mins < 60 * 48 -> "yesterday"
            mins < 60 * 24 * 7 -> "${mins / 1440} days ago"
            mins < 60 * 24 * 30 -> "${mins / 10080} wk ago".let { if (mins / 10080 == 1L) "1 week ago" else "${mins / 10080} weeks ago" }
            mins < 60 * 24 * 365 -> (mins / 43200).let { if (it == 1L) "1 month ago" else "$it months ago" }
            else -> (mins / 525600).let { if (it == 1L) "1 year ago" else "$it years ago" }
        }
    }

    fun upcomingLabel(stamp: String): String {
        val d = date(stamp) ?: return stamp
        val days = -daysAgo(d)
        return when {
            days <= 0 -> "Tonight"; days == 1 -> "Tomorrow"
            days < 7 -> d.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
            else -> medium(stamp)
        }
    }

    fun duration(minutes: Int): String =
        if (minutes >= 6000) String.format(Locale.getDefault(), "%.1f days", minutes / 1440.0) else "${(minutes / 60.0).roundToInt()} hrs"

    /** "1h 52m" */
    fun clock(minutes: Int): String =
        if (minutes >= 60) "${minutes / 60}h${if (minutes % 60 > 0) " ${minutes % 60}m" else ""}" else "${minutes}m"

    fun monthName(i: Int): String = listOf("January", "February", "March", "April", "May", "June", "July",
        "August", "September", "October", "November", "December")[((i % 12) + 12) % 12]

    fun monthKeyLabel(key: String): String {
        val p = key.split("-")
        val m = p.getOrNull(1)?.toIntOrNull() ?: return key
        return if (m in 1..12) "${monthName(m - 1)} ${p[0]}" else key
    }
}

val Int.grouped: String get() = NumberFormat.getIntegerInstance().format(this)

object LibraryFormat {
    /** "45 min", "~3.5 hrs", "~16 hrs" — the size of the commitment. */
    fun hours(minutes: Double?): String? {
        if (minutes == null || minutes <= 0) return null
        if (minutes < 60) return "${minutes.roundToInt()} min"
        val h = minutes / 60
        if (minutes < 180) {
            val tenths = (h * 10).roundToInt() / 10.0
            return if (tenths == Math.rint(tenths)) "~${tenths.toInt()} hrs" else "~${String.format(Locale.getDefault(), "%.1f", tenths)} hrs"
        }
        return "~${h.roundToInt()} hrs"
    }

    fun runtime(minutes: Int?): String? = if (minutes == null || minutes <= 0) null else MQTime.clock(minutes)

    /** "1.2M", "48k" */
    fun compact(votes: Int): String = when {
        votes >= 1_000_000 -> String.format(Locale.US, if (votes < 10_000_000) "%.1fM" else "%.0fM", votes / 1_000_000.0)
        votes >= 1_000 -> "${(votes / 1000.0).roundToInt()}k"
        else -> "$votes"
    }

    fun one(d: Double) = String.format(Locale.getDefault(), "%.1f", d)

    /** "1 h 22 min left" from an ETA like "01:22:05" or an ISO timestamp. */
    fun eta(raw: String?): String? {
        if (raw.isNullOrBlank()) return null
        val parts = raw.split(":")
        if (parts.size == 3 && parts.all { p -> p.trim().toIntOrNull() != null }) {
            val h = parts[0].trim().toInt(); val m = parts[1].trim().toInt()
            return when {
                h > 0 -> "$h h${if (m > 0) " $m min" else ""} left"
                m > 0 -> "$m min left"
                else -> "Almost done"
            }
        }
        MQTime.dateTime(raw)?.let {
            val mins = ChronoUnit.MINUTES.between(LocalDateTime.now(), it)
            return if (mins <= 0) "Almost done" else if (mins < 60) "$mins min left" else "${mins / 60} h ${mins % 60} min left"
        }
        return raw
    }
}

fun plural(n: Int, one: String, many: String = one + "s") = "$n ${if (n == 1) one else many}"
