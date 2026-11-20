package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/** `show_summary()` server-side — what every mark endpoint hands back. */
@Serializable
data class ShowCard(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val status: String? = null,
    val rating: FlexInt = null,
    val avgRuntime: FlexInt = null,
    val aired: Int = 0,
    val watched: Int = 0,
    val remaining: Int = 0,
    val lastWatched: String? = null,
    val nextAir: String? = null,
    val nextEp: NextEpisode? = null,
    val addedAt: String? = null,
    val seasons: FlexInt = null,
    val stale: FlexBool = null,
    val totalMin: FlexDouble = null,
    val leftMin: FlexDouble = null,
    val imdb: FlexDouble = null,
    val vote: FlexDouble = null,
    val network: String? = null,
    val nEpisodes: FlexInt = null,
    val prov: StreamingProvider? = null,
    val provKnown: FlexBool = null,
    val household: List<HouseholdShow>? = null,
) {
    val displayTitle get() = title ?: "Untitled"
    val isEnded get() = ShowStatus.isEnded(status)
    val progress: Float get() = if (aired > 0) watched.toFloat() / aired else 0f
    val percent get() = Math.round(progress * 100)
    val hoursRemaining: Double?
        get() = if (remaining > 0 && (avgRuntime ?: 0) > 0) remaining * (avgRuntime ?: 0) / 60.0 else null

    enum class WatchlistGroup(val title: String) { BINGE("Ready to binge"), AIRING("Airing now"), SOON("Coming soon") }

    val watchlistGroup: WatchlistGroup
        get() = when {
            aired == 0 -> WatchlistGroup.SOON
            nextAir == null -> WatchlistGroup.BINGE
            else -> WatchlistGroup.AIRING
        }

    /** Take a freshly marked summary without losing library extras it doesn't carry. */
    fun merged(summary: ShowCard): ShowCard {
        var left = leftMin
        if (left != null && summary.watched > watched) {
            val per = (avgRuntime ?: summary.avgRuntime ?: 0).toDouble()
            left = maxOf(0.0, left - per * (summary.watched - watched))
        }
        return copy(
            title = summary.title ?: title, poster = summary.poster ?: poster,
            status = summary.status ?: status, rating = summary.rating ?: rating,
            aired = summary.aired, watched = summary.watched, remaining = summary.remaining,
            lastWatched = summary.lastWatched ?: lastWatched, nextAir = summary.nextAir,
            nextEp = summary.nextEp, stale = false, leftMin = left,
        )
    }
}

@Serializable data class StreamingProvider(val name: String? = null, val logo: String? = null)

@Serializable
data class HouseholdShow(
    val name: String? = null,
    val username: String? = null,
    val avatar: String? = null,
    val watched: FlexInt = null,
    val lastEp: String? = null,
    val rating: FlexInt = null,
    val stopped: FlexBool = null,
) {
    val displayName get() = name ?: username ?: "Someone"
    val person get() = Person(username = username, displayName = name, avatar = avatar, isMe = false)
    val lastEpCode: String?
        get() = lastEp?.split(":")?.takeIf { it.size == 2 }?.let { "S${it[0]} E${it[1]}" }
}

@Serializable
data class ShowShelves(
    val watching: List<ShowCard> = emptyList(),
    val watchlist: List<ShowCard> = emptyList(),
    val caughtUp: List<ShowCard> = emptyList(),
    val finished: List<ShowCard> = emptyList(),
    val stopped: List<ShowCard> = emptyList(),
)

@Serializable
data class NextEpisode(
    val season: Int = 0,
    val number: Int = 0,
    val title: String? = null,
    val airDate: String? = null,
) {
    val code get() = "S$season · E$number"
}

object ShowStatus {
    fun isEnded(status: String?): Boolean =
        status?.lowercase() in setOf("ended", "canceled", "cancelled")
}

@Serializable
data class ShowDetail(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val backdrop: String? = null,
    val year: FlexInt = null,
    val status: String? = null,
    val genres: String? = null,
    val avgRuntime: FlexInt = null,
    val info: ShowInfo? = null,
    val followed: FlexBool = null,
    val archived: FlexBool = null,
    val rating: FlexInt = null,
    val seasons: List<SeasonBlock> = emptyList(),
) {
    val displayTitle get() = title ?: "Untitled"
    val isEnded get() = ShowStatus.isEnded(status)
    val genreList get() = (genres ?: "").split(",").map { it.trim() }.filter { it.isNotEmpty() }
    val isFollowed get() = followed == true
    val isArchived get() = archived == true
}

@Serializable
data class ShowInfo(
    val overview: String? = null,
    val tagline: String? = null,
    val vote: FlexDouble = null,
    val votes: FlexInt = null,
    val firstAir: String? = null,
    val lastAir: String? = null,
    val networks: List<String>? = null,
    val createdBy: List<String>? = null,
    val contentRating: String? = null,
    val imdbId: String? = null,
    val origin: String? = null,
    val language: String? = null,
    @SerialName("n_seasons") val seasonCount: FlexInt = null,
    @SerialName("n_episodes") val episodeCount: FlexInt = null,
    val cast: List<CastMember>? = null,
    val seasonNames: Map<String, String>? = null,
    val seasonPosters: Map<String, String>? = null,
    val imdb: IMDbRating? = null,
) {
    fun seasonName(season: Int): String =
        seasonNames?.get(season.toString())?.takeIf { it.isNotEmpty() }
            ?: if (season == 0) "Specials" else "Season $season"
}

@Serializable
data class IMDbRating(val rating: FlexDouble = null, val votes: FlexInt = null, val id: String? = null)

@Serializable
data class CastMember(
    val id: Int? = null,
    val name: String = "",
    val character: String? = null,
    val img: String? = null,
)

@Serializable
data class SeasonBlock(val season: Int = 0, val episodes: List<EpisodeRow> = emptyList()) {
    val watchedCount get() = episodes.count { it.watched }
    val isComplete get() = episodes.isNotEmpty() && watchedCount == episodes.size
}

@Serializable
data class EpisodeRow(
    val season: Int = 0,
    val number: Int = 0,
    val title: String? = null,
    val airDate: String? = null,
    val runtime: FlexInt = null,
    val still: String? = null,
    val custom: FlexBool = null,
    val watched: Boolean = false,
    val watchedAt: String? = null,
) {
    val key get() = "$season:$number"
    val code get() = "S$season · E$number"
    val displayTitle get() = title?.takeIf { it.isNotEmpty() } ?: "Episode $number"
    fun hasAired(today: String) = !airDate.isNullOrEmpty() && airDate <= today
}

/** What every mark/unmark endpoint returns: the patched card plus any celebration. */
@Serializable
data class MarkResponse(
    val ok: Boolean? = null,
    val show: ShowCard? = null,
    val celebrate: List<Celebration>? = null,
)

@Serializable
data class EpisodeDetail(
    val showId: Int = 0,
    val season: Int = 0,
    val number: Int = 0,
    val title: String? = null,
    val airDate: String? = null,
    val runtime: FlexInt = null,
    val overview: String? = null,
    val still: String? = null,
    val rating: FlexDouble = null,
    val imdbRating: FlexDouble = null,
    val imdbVotes: FlexInt = null,
    val showTitle: String? = null,
    val showPoster: String? = null,
    val showBackdrop: String? = null,
    val seasonPoster: String? = null,
    val watched: Boolean = false,
    val watchedAt: String? = null,
    val prev: EpisodeRef? = null,
    val next: EpisodeRef? = null,
    val earlierUnwatched: FlexInt = null,
    val extra: EpisodeExtra? = null,
) {
    val code get() = "S$season · E$number"
    val displayTitle get() = title?.takeIf { it.isNotEmpty() } ?: "Episode $number"
    /** Reviews on an episode key off a packed id — the same one the server uses. */
    val reviewKey get() = showId * 1_000_000 + season * 1_000 + number
    val imdb get() = imdbRating?.let { IMDbRating(it, imdbVotes) }
}

@Serializable data class EpisodeRef(val season: Int = 0, val number: Int = 0)

@Serializable
data class EpisodeExtra(
    val vote: FlexDouble = null,
    val votes: FlexInt = null,
    val directors: List<String>? = null,
    val writers: List<String>? = null,
    val guests: List<CastMember>? = null,
)

@Serializable
data class ShowRatings(
    val episodes: List<RatedEpisode> = emptyList(),
    val seasonAvg: List<SeasonAverage> = emptyList(),
    val source: String? = null,
    val imdbCount: FlexInt = null,
    val count: FlexInt = null,
) {
    val isMixed get() = (imdbCount ?: 0) > 0 && (imdbCount ?: 0) < (count ?: 0)
}

@Serializable
data class RatedEpisode(
    val season: Int = 0,
    val number: Int = 0,
    val title: String? = null,
    val rating: Double = 0.0,
    val src: String = "tmdb",
    val votes: FlexInt = null,
    val tmdbRating: FlexDouble = null,
) {
    val isImdb get() = src == "imdb"
}

@Serializable
data class SeasonAverage(val season: Int = 0, val avg: Double = 0.0, val count: Int = 0, val src: String? = null) {
    val isImdb get() = src == "imdb"
}
