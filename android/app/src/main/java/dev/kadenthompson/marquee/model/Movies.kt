package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

@Serializable
data class MovieShelves(val watched: List<MovieCard> = emptyList(), val watchlist: List<MovieCard> = emptyList())

@Serializable
data class MovieCard(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val releaseDate: String? = null,
    val runtime: FlexInt = null,
    val genres: String? = null,
    val state: String? = null,
    val watchedAt: String? = null,
    val rating: FlexInt = null,
    val addedAt: String? = null,
    val imdb: FlexDouble = null,
    val vote: FlexDouble = null,
    val cert: String? = null,
    val prov: StreamingProvider? = null,
    val provKnown: FlexBool = null,
    val household: List<HouseholdFilm>? = null,
) {
    val displayTitle get() = title ?: "Untitled"
    val isWatched get() = state == "watched"
    fun isUpcoming(today: String) = (releaseDate?.length ?: 0) >= 10 && releaseDate!!.take(10) > today
}

@Serializable
data class HouseholdFilm(
    val name: String? = null,
    val username: String? = null,
    val avatar: String? = null,
    val state: String? = null,
    val rating: FlexInt = null,
) {
    val displayName get() = name ?: username ?: "Someone"
    val person get() = Person(username = username, displayName = name, avatar = avatar, isMe = false)
}

@Serializable
data class MovieDetail(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val releaseDate: String? = null,
    val runtime: FlexInt = null,
    val genres: String? = null,
    val info: MovieInfo? = null,
    val state: String? = null,
    val myRating: FlexInt = null,
) {
    val displayTitle get() = title ?: "Untitled"
    val isWatched get() = state == "watched"
}

@Serializable
data class MovieInfo(
    val overview: String? = null,
    val tagline: String? = null,
    val vote: FlexDouble = null,
    val votes: FlexInt = null,
    val backdrop: String? = null,
    val runtime: FlexInt = null,
    val genres: List<String>? = null,
    val contentRating: String? = null,
    val imdbId: String? = null,
    val directors: List<String>? = null,
    val cast: List<CastMember>? = null,
    val imdb: IMDbRating? = null,
)
