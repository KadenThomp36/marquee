package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.intOrNull

/** `GET /api/dashboard` — one call backs the whole Watch Next screen. */
@Serializable
data class Dashboard(
    val upNext: List<ShowCard> = emptyList(),
    val stale: List<ShowCard> = emptyList(),
    val calendar: List<UpcomingEpisode> = emptyList(),
    val recent: List<WatchEntry> = emptyList(),
    val social: List<WatchEntry> = emptyList(),
    val reviews: List<ReviewTeaser> = emptyList(),
    val counts: DashboardCounts? = null,
    val watchlist: List<ShowCard>? = null,
    val reading: List<ReadingItem>? = null,
)

@Serializable data class DashboardCounts(val upToDate: Int? = null, val notStarted: Int? = null)

@Serializable
data class WatchEntry(
    val showId: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val season: Int? = null,
    val number: Int? = null,
    val epTitle: String? = null,
    val watchedAt: String = "",
    val count: Int = 1,
    val by: Person? = null,
) {
    val key get() = "$showId:$watchedAt:${season ?: -1}:${number ?: -1}"
    val displayTitle get() = title ?: "Untitled"
    val code: String? get() = if (season != null && number != null) "S$season · E$number" else null
}

@Serializable
data class ReviewTeaser(
    val type: String = "show",
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val rating: FlexInt = null,
    val body: String? = null,
    val updatedAt: String? = null,
    val by: Person = Person(),
)

@Serializable
data class UpcomingResponse(
    val episodes: List<UpcomingEpisode> = emptyList(),
    val movies: List<UpcomingMovie> = emptyList(),
    val chapters: List<NewChapters>? = null,
)

@Serializable
data class NewChapters(
    val id: Int = 0,
    val title: String? = null,
    val cover: String? = null,
    val latestCh: FlexInt = null,
    val latestAt: String? = null,
    val progress: FlexInt = null,
) {
    val displayTitle get() = title ?: "Untitled"
    val behind get() = maxOf(0, (latestCh ?: 0) - (progress ?: 0))
}

@Serializable
data class UpcomingEpisode(
    val showId: Int = 0,
    val showTitle: String? = null,
    val poster: String? = null,
    val season: Int = 0,
    val number: Int = 0,
    val title: String? = null,
    val airDate: String = "",
) {
    val key get() = "$showId:$season:$number"
    val code get() = "S$season · E$number"
}

@Serializable
data class UpcomingMovie(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val releaseDate: String = "",
)

@Serializable
data class TVHistoryPage(val items: List<TVHistoryGroup> = emptyList(), val cursor: String? = null)

data class HistoryEp(val season: Int, val number: Int, val title: String?)

@Serializable
data class TVHistoryGroup(
    val day: String = "",
    val showId: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    /** `[[season, number, title?], …]` */
    val eps: List<JsonArray> = emptyList(),
    val minutes: Int = 0,
    val lastAt: String? = null,
) {
    val key get() = "$day:$showId"
    val episodes: List<HistoryEp>
        get() = eps.mapNotNull { row ->
            val s = (row.getOrNull(0) as? JsonPrimitive)?.intOrNull ?: return@mapNotNull null
            val n = (row.getOrNull(1) as? JsonPrimitive)?.intOrNull ?: return@mapNotNull null
            val t = (row.getOrNull(2) as? JsonPrimitive)?.takeIf { it.isString }?.content
            HistoryEp(s, n, t)
        }
}

@Serializable
data class MovieHistoryPage(val items: List<MovieHistoryItem> = emptyList(), val cursor: String? = null)

@Serializable
data class MovieHistoryItem(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val rating: FlexInt = null,
    val watchedAt: String = "",
    val runtime: FlexInt = null,
)
