package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

@Serializable data class SearchResponse(val results: List<SearchResult> = emptyList())

@Serializable
data class SearchResult(
    val type: String = "show",
    val id: Int = 0,
    val title: String? = null,
    val year: FlexInt = null,
    val poster: String? = null,
    val followed: FlexBool = null,
    val state: String? = null,
    val vote: FlexDouble = null,
) {
    val isShow get() = type == "show"
    val displayTitle get() = title ?: "Untitled"
    val alreadyHave get() = followed == true || state != null
    val stateLabel: String? get() = if (followed == true) "on watchlist" else state
}

@Serializable data class DiscoverResponse(val sections: List<DiscoverSection> = emptyList())
@Serializable data class DiscoverSection(val title: String = "", val items: List<SearchResult> = emptyList())

@Serializable
data class ArtworkResponse(
    val posters: List<Artwork> = emptyList(),
    val backdrops: List<Artwork> = emptyList(),
    val count: Int = 0,
) {
    val all get() = posters + backdrops
}

@Serializable
data class Artwork(
    val kind: String = "poster",
    val thumb: String? = null,
    val full: String? = null,
    val w: FlexInt = null,
    val h: FlexInt = null,
    val lang: String? = null,
) {
    val isWide get() = kind == "backdrop"
    val aspect: Float
        get() = if ((w ?: 0) > 0 && (h ?: 0) > 0) w!!.toFloat() / h!! else if (isWide) 16f / 9f else 2f / 3f
}

@Serializable
data class WatchProviders(
    val region: String? = null,
    val link: String? = null,
    val flatrate: List<Provider> = emptyList(),
    val rent: List<Provider> = emptyList(),
    val buy: List<Provider> = emptyList(),
    val hasAny: Boolean = false,
    val plex: PlexAvailability? = null,
)

/** Newer servers say when the title is on the household's own Plex. */
@Serializable data class PlexAvailability(val available: FlexBool = null, val url: String? = null)

@Serializable data class Provider(val id: Int? = null, val name: String? = null, val logo: String? = null)

@Serializable
data class PersonDetail(
    val id: Int = 0,
    val name: String? = null,
    val bio: String? = null,
    val birthday: String? = null,
    val deathday: String? = null,
    val place: String? = null,
    val knownFor: String? = null,
    val img: String? = null,
    val imdbId: String? = null,
    val credits: List<PersonCredit> = emptyList(),
)

@Serializable
data class PersonCredit(
    val type: String = "movie",
    val id: Int = 0,
    val title: String? = null,
    val year: FlexInt = null,
    val poster: String? = null,
    val character: String? = null,
    val vote: FlexDouble = null,
) {
    val isShow get() = type == "show"
    val uniqueId get() = "$type:$id"
}
