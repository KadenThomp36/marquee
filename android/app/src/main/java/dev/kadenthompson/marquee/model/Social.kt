package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

@Serializable data class ReviewsResponse(val reviews: List<Review> = emptyList())

@Serializable
data class Review(
    val id: Int = 0,
    val rating: FlexInt = null,
    val body: String? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val mine: Boolean = false,
    val author: Person = Person(),
    val replies: List<ReviewReply>? = null,
)

@Serializable
data class ReviewReply(
    val id: Int = 0,
    val body: String = "",
    val createdAt: String? = null,
    val mine: Boolean = false,
    val author: Person = Person(),
)

@Serializable data class ExternalReviewsResponse(val reviews: List<ExternalReview> = emptyList())

@Serializable
data class ExternalReview(
    val source: String = "",
    val author: String? = null,
    val rating: FlexInt = null,
    val likes: FlexInt = null,
    val body: String = "",
    val date: String? = null,
)

@Serializable
data class NotificationsResponse(val unread: Int = 0, val items: List<AppNotification> = emptyList())

@Serializable
data class AppNotification(
    val id: Int = 0,
    val type: String = "",
    val title: String = "",
    val body: String? = null,
    val link: String? = null,
    val createdAt: String? = null,
    val read: FlexBool = null,
)

@Serializable data class NotificationPrefsResponse(val prefs: List<NotificationPref> = emptyList())

@Serializable
data class NotificationPref(
    val type: String = "",
    val label: String = "",
    val help: String = "",
    val hasDays: FlexBool = null,
    val enabled: FlexBool = null,
    val value: String? = null,
) {
    val leadDays: Set<String> get() = (value ?: "").split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
}

@Serializable
data class Celebration(
    val id: Int = 0,
    val kind: String = "season",
    val season: Int = 0,
    val seasonName: String? = null,
    val episodes: Int = 0,
    val minutes: Int = 0,
    val days: FlexInt = null,
    val seasons: Int = 0,
    val firstWatched: String? = null,
    val lastWatched: String? = null,
    val nthThisYear: Int = 0,
    val year: Int = 0,
    val show: CelebrationShow = CelebrationShow(),
) {
    val isSeries get() = kind == "show"
}

@Serializable
data class CelebrationShow(
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val backdrop: String? = null,
    val year: FlexInt = null,
    val status: String? = null,
) {
    val displayTitle get() = title ?: "Untitled"
}

@Serializable data class CelebrationsResponse(val celebrations: List<Celebration> = emptyList())
