package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

// Folio is the household's own e-reader app. It uploads reading sessions to the
// server; these shapes describe the integration, a recently synced session, and one
// book's reading in depth.

@Serializable
data class FolioIntegration(
    val enabled: Boolean = false,
    val autoCapture: Boolean = false,
    val devices: List<FolioDevice> = emptyList(),
    val waiting: List<FolioWaiting>? = null,
    val imported: FlexInt = null,
    val title: String? = null,
)

@Serializable
data class FolioWaiting(
    val key: String = "",
    val title: String = "",
    val authors: List<String> = emptyList(),
    val isbn: String? = null,
    val sittings: Int = 0,
    val minutes: Int = 0,
    val firstAt: String? = null,
    val nextAttemptAt: String? = null,
    val reason: String? = null,
) {
    val byline get() = if (authors.isEmpty()) isbn?.let { "ISBN $it" } ?: "No author in the file" else authors.joinToString(", ")
}

@Serializable
data class FolioDevice(
    val id: Int = 0,
    val name: String? = null,
    val platform: String? = null,
    val appVersion: String? = null,
    val pairedAt: String? = null,
    val lastSyncAt: String? = null,
    val sessionsSynced: Int = 0,
    val signedIn: FlexBool = null,
) {
    val displayName get() = name?.takeIf { it.isNotEmpty() } ?: "Folio"
}

@Serializable
data class RecentFolio(
    val bookId: Int = 0,
    val title: String? = null,
    val cover: String? = null,
    val device: String = "",
    val endedAt: String = "",
    val minutes: Int = 0,
    val pages: FlexInt = null,
    val endFraction: FlexDouble = null,
    val chapter: String? = null,
)

@Serializable data class ReadingSummary(val minutes: Int = 0, val sessions: Int = 0, val folio: FlexInt = null)

/** `GET /api/book/{id}/stats` */
@Serializable
data class BookStats(
    val book: Book = Book(),
    val tracked: Boolean = false,
    val state: State? = null,
    val totals: Totals = Totals(),
    val pace: Pace = Pace(),
    val forecast: Forecast? = null,
    val sessions: List<Sitting> = emptyList(),
    val days: List<Day> = emptyList(),
    val clock: List<Int>? = null,
    val chapters: List<Chapter> = emptyList(),
    val sources: List<Source> = emptyList(),
    val live: Live? = null,
    val recentFolio: RecentFolio? = null,
) {
    @Serializable
    data class Book(
        val id: Int = 0, val title: String? = null, val author: String? = null, val cover: String? = null,
        val pages: FlexInt = null, val chapters: FlexInt = null,
    ) {
        val displayTitle get() = title ?: "Untitled"
    }

    @Serializable
    data class State(
        val state: String? = null, val progress: FlexInt = null, val mode: String? = null,
        val startedAt: String? = null, val finishedAt: String? = null, val fraction: FlexDouble = null,
    ) {
        val readingState get() = ReadingState.of(state)
    }

    @Serializable
    data class Totals(
        val minutes: Int = 0, val sessions: Int = 0, val checkpoints: Int = 0, val days: Int = 0, val pages: Int = 0,
        val avgMinutes: FlexInt = null, val longestMinutes: FlexInt = null,
    )

    @Serializable
    data class Pace(val pagesPerHour: FlexDouble = null, val pctPerHour: FlexDouble = null, val perDay: FlexDouble = null)

    @Serializable
    data class Forecast(
        val days: Int = 0, val perDay: FlexDouble = null, val unit: String = "pages", val date: String = "",
        val hoursLeft: FlexDouble = null,
    )

    @Serializable
    data class Sitting(
        val id: Int = 0,
        val startedAt: String = "",
        val endedAt: String? = null,
        val minutes: Int = 0,
        val wallMinutes: FlexInt = null,
        val from: Int = 0,
        val to: Int = 0,
        val pages: FlexInt = null,
        val startFraction: FlexDouble = null,
        val endFraction: FlexDouble = null,
        val pagesTurned: FlexInt = null,
        val source: String = "",
        val sourceLabel: String = "",
        val checkpoint: Boolean = false,
        val startChapter: String? = null,
        val endChapter: String? = null,
    ) {
        fun span(pages: Int?): Pair<Double, Double>? {
            val s = startFraction ?: pages?.let { from.toDouble() / maxOf(1, it) }
            val e = endFraction ?: pages?.let { to.toDouble() / maxOf(1, it) }
            return if (s != null && e != null && e > s) s to e else null
        }

        val logEntry get() = ReadingSession(id = id, date = startedAt, minutes = minutes, from = from, to = to, source = source)
    }

    @Serializable data class Day(val date: String = "", val minutes: Double = 0.0, val pages: Int = 0)

    @Serializable
    data class Chapter(
        val title: String = "", val minutes: Double = 0.0, val pagesTurned: Int = 0,
        val perHour: FlexDouble = null, val paceUnit: String? = null,
    )

    @Serializable data class Source(val source: String = "", val label: String = "", val sessions: Int = 0, val minutes: Int = 0)
    @Serializable data class Live(val sessionId: Int = 0, val startedAt: String = "")
}
