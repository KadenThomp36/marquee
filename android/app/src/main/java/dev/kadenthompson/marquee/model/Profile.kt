package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ProfilePayload(
    val id: Int? = null,
    val username: String = "",
    val displayName: String? = null,
    val avatar: String? = null,
    val banner: String? = null,
    val features: UserFeatures? = null,
    val isAdmin: FlexBool = null,
    val memberSince: String? = null,
    val isMe: Boolean = false,
    val headline: Headline? = null,
    val favorites: List<Favorite> = emptyList(),
    val recapYears: List<Int> = emptyList(),
    val recapSoon: FlexBool = null,
    val recapYear: FlexInt = null,
    val recapRelease: String? = null,
) {
    val person get() = Person(id, username, displayName, avatar, banner, features, isAdmin, isMe)
}

@Serializable
data class Headline(val episodes: Int = 0, val shows: Int = 0, val movies: Int = 0, val hours: Int = 0)

@Serializable data class BannerOptionsResponse(val options: List<BannerOption> = emptyList())
@Serializable data class BannerOption(val title: String = "", val backdrop: String = "")
@Serializable data class BannerResponse(val banner: String? = null)
@Serializable data class AvatarResponse(val avatar: String? = null)
@Serializable data class FeaturesResponse(val ok: Boolean? = null, val features: UserFeatures = UserFeatures())

@Serializable
data class WatchedPage(
    val user: Person = Person(),
    val kind: String = "shows",
    val items: List<WatchedItem> = emptyList(),
    val total: Int = 0,
    val next: FlexInt = null,
)

@Serializable
data class WatchedItem(
    val type: String = "show",
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val rating: FlexInt = null,
    val watched: FlexInt = null,
    val aired: FlexInt = null,
    val ended: FlexBool = null,
    val watchedAt: String? = null,
) {
    val uniqueId get() = "$type:$id"
    val displayTitle get() = title ?: "Untitled"
    val isFinishedSeries get() = (aired ?: 0) > 0 && watched != null && ended == true && watched >= aired!!
}

@Serializable
data class Stats(
    val episodes: Int = 0,
    val tvMinutes: Int = 0,
    val movies: Int = 0,
    val movieMinutes: Int = 0,
    val shows: Int = 0,
    val thisYear: ThisYear? = null,
    val monthly: List<MonthCount> = emptyList(),
    val yearly: List<YearCount> = emptyList(),
    val topShows: List<TopShow> = emptyList(),
    val genres: List<NamedCount> = emptyList(),
    val heatmap: List<List<Int>>? = null,
    val heatYears: Map<String, List<List<Int>>>? = null,
    val streak: Streak = Streak(),
    val bigDay: BigDay? = null,
    val firstWatch: FirstWatch? = null,
    val perDay: FlexDouble = null,
    val completion: Completion? = null,
    val movieDecades: List<DecadeCount>? = null,
    val ratingHist: Map<String, Int>? = null,
    val topRated: List<RatedTitle>? = null,
) {
    val totalMinutes get() = tvMinutes + movieMinutes
}

@Serializable data class ThisYear(val episodes: Int = 0, val movies: Int = 0, val top: List<TopShow>? = null)
@Serializable data class MonthCount(val ym: String = "", val count: Int = 0)
@Serializable data class YearCount(val y: String = "", val c: Int = 0)

@Serializable
data class TopShow(
    @SerialName("id") val showId: Int? = null,
    val title: String = "",
    val poster: String? = null,
    val eps: Int = 0,
    val mins: FlexInt = null,
)

@Serializable data class NamedCount(val name: String = "", val count: Int = 0)

@Serializable
data class DecadeCount(val dec: FlexInt = null, val c: Int = 0) {
    val label get() = dec?.let { "${it}s" } ?: "Unknown"
}

@Serializable data class RatedTitle(val title: String = "", val rating: FlexInt = null)
@Serializable data class Streak(val current: Int = 0, val longest: Int = 0, val longestEnd: String? = null)
@Serializable data class BigDay(val date: String = "", val count: Int = 0, val top: String? = null)
@Serializable data class FirstWatch(val watchedAt: String? = null, val title: String? = null)

@Serializable
data class Completion(
    val finished: Int = 0,
    val inProgress: Int = 0,
    val upToDate: Int = 0,
    val dropped: Int = 0,
    val notStarted: Int = 0,
) {
    val total get() = finished + inProgress + upToDate + dropped + notStarted
}

@Serializable
data class AdvancedStats(
    val networks: List<NamedCount> = emptyList(),
    val studios: List<NamedCount> = emptyList(),
    val countries: List<CountryCount> = emptyList(),
    val actors: List<ActorCount> = emptyList(),
    val directors: List<NamedCount> = emptyList(),
    val moviesEnriched: FlexInt = null,
    val moviesTotal: FlexInt = null,
) {
    val isEmpty get() = networks.isEmpty() && studios.isEmpty() && countries.isEmpty() && actors.isEmpty() && directors.isEmpty()
}

@Serializable data class CountryCount(val code: String = "", val name: String = "", val count: Int = 0)

@Serializable
data class ActorCount(val name: String = "", val img: String? = null, val shows: Int = 0, val movies: Int = 0) {
    val total get() = shows + movies
}

@Serializable
data class Recap(
    val year: Int = 0,
    val locked: FlexBool = null,
    val hasData: Boolean = false,
    val episodes: FlexInt = null,
    val movies: FlexInt = null,
    val minutes: FlexInt = null,
    val tvMinutes: FlexInt = null,
    val movieMinutes: FlexInt = null,
    val topShows: List<TopShow>? = null,
    val topMovies: List<RecapMovie>? = null,
    val genres: List<NamedCount>? = null,
    val months: List<Int>? = null,
    val busiestMonth: String? = null,
    val busiestMonthCount: FlexInt = null,
    val binge: BigDay? = null,
    val firstWatch: FirstWatch? = null,
    val lastWatch: FirstWatch? = null,
    val newShows: FlexInt = null,
    val years: List<Int>? = null,
    val final: FlexBool = null,
    val preview: FlexBool = null,
    val reading: RecapReading? = null,
    val persona: RecapPersona? = null,
    val hours: List<Int>? = null,
    val weekdays: List<Int>? = null,
    val peakHour: FlexInt = null,
    val peakWeekday: String? = null,
    val daysWatched: FlexInt = null,
    val streak: RecapStreak? = null,
    val household: RecapHousehold? = null,
    val release: String? = null,
)

@Serializable data class RecapMovie(val title: String = "", val poster: String? = null, val rating: FlexInt = null)
@Serializable data class RecapIndex(val years: List<Int> = emptyList(), val autoshow: FlexInt = null, val release: String? = null)
@Serializable data class RecapPersona(val key: String = "", val title: String = "", val line: String = "")
@Serializable data class RecapStreak(val days: Int = 0, val start: String = "", val end: String = "")
@Serializable data class RecapHousehold(val rank: Int = 0, val of: Int = 0)

@Serializable
data class RecapReading(
    val books: FlexInt = null,
    val manga: FlexInt = null,
    val pages: FlexInt = null,
    val chapters: FlexInt = null,
    val minutes: FlexInt = null,
    val covers: List<Cover>? = null,
    val topAuthor: Author? = null,
    val longest: Book? = null,
    val fastest: Fastest? = null,
    val favourite: Book? = null,
    val busiestMonth: String? = null,
    val busiestMonthUnits: FlexInt = null,
    val goal: Goal? = null,
) {
    @Serializable data class Cover(val title: String? = null, val cover: String? = null)
    @Serializable data class Author(val name: String = "", val count: Int = 0, val pages: Int = 0)
    @Serializable data class Book(val title: String = "", val cover: String? = null, val author: String? = null, val pages: FlexInt = null, val rating: FlexInt = null)
    @Serializable data class Fastest(val title: String = "", val days: Int = 0)
    @Serializable data class Goal(val target: FlexInt = null, val done: FlexInt = null)
}
