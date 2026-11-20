package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

enum class ListVisibility(val key: String, val label: String, val explanation: String) {
    PRIVATE("private", "Private", "Only you can see this list."),
    PUBLIC("public", "Public", "Household members can see this on your profile."),
    COLLAB("collab", "Collab", "Household members can see it and add or remove titles.");

    companion object {
        fun of(key: String?) = entries.firstOrNull { it.key == key } ?: PRIVATE
    }
}

@Serializable
data class ListsResponse(val lists: List<ListCard> = emptyList(), val shared: List<ListCard>? = null)

@Serializable
data class ListCard(
    val id: Int = 0,
    val name: String = "",
    val isDefault: FlexBool = null,
    val count: Int = 0,
    val posters: List<String> = emptyList(),
    val visibility: String? = null,
    val owner: String? = null,
)

@Serializable
data class ListDetail(
    val id: Int = 0,
    val name: String = "",
    val isDefault: FlexBool = null,
    val visibility: String? = null,
    val isOwner: Boolean = false,
    val canEdit: FlexBool = null,
    val sharedWith: List<Int>? = null,
    val owner: Person = Person(),
    val items: List<ListItem> = emptyList(),
) {
    val editable get() = canEdit ?: isOwner
}

@Serializable
data class ListItem(
    val type: String = "show",
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val addedAt: String? = null,
    val ended: FlexBool = null,
    val total: FlexInt = null,
    val watched: FlexInt = null,
    val firstWatched: String? = null,
    val lastWatched: String? = null,
    val archived: FlexBool = null,
) {
    val uniqueId get() = "$type:$id"
    val isShow get() = type == "show"
    val displayTitle get() = title ?: "Untitled"
    val isComplete get() = (total ?: 0) > 0 && (watched ?: 0) >= (total ?: 0)
    val progress: Float get() = if ((total ?: 0) > 0) minOf(1f, (watched ?: 0).toFloat() / total!!) else 0f
}

@Serializable data class ItemListsResponse(val lists: List<ItemListRow> = emptyList())

@Serializable
data class ItemListRow(
    val id: Int = 0,
    val name: String = "",
    val isDefault: FlexBool = null,
    val has: Boolean = false,
    val collab: FlexBool = null,
    val owner: String? = null,
)

@Serializable data class ListMembership(val members: Map<String, Int> = emptyMap())

@Serializable data class CreatedList(val id: Int = 0, val name: String = "", val visibility: String? = null)

@Serializable data class FavoritesResponse(val favorites: List<Favorite> = emptyList())

@Serializable
data class Favorite(
    val type: String = "show",
    val id: Int = 0,
    val title: String? = null,
    val poster: String? = null,
    val year: FlexInt = null,
    val position: FlexInt = null,
) {
    val uniqueId get() = "$type:$id"
    val displayTitle get() = title ?: "Untitled"
}
