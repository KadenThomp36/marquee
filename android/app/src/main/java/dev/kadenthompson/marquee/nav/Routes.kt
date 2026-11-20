package dev.kadenthompson.marquee.nav

import kotlinx.serialization.Serializable

// Tab graphs and their roots.
@Serializable object NextGraph
@Serializable object UpcomingGraph
@Serializable object LibraryGraph
@Serializable object SearchGraph
@Serializable object YouGraph

@Serializable object NextHome
@Serializable object UpcomingHome
@Serializable data class LibraryHome(val section: String? = null, val shelf: String? = null)
@Serializable data class SearchHome(val query: String? = null)
@Serializable object YouHome

// Destinations reachable from anywhere — the same screen with the same back behaviour
// whether it was pushed from Next, Search, a list or a notification.
@Serializable data class ShowRoute(val id: Int)
@Serializable data class EpisodeRoute(val showId: Int, val season: Int, val number: Int)
@Serializable data class MovieRoute(val id: Int)
@Serializable data class PersonRoute(val id: Int)
@Serializable data class ListRoute(val id: Int)
@Serializable object ListsRoute
@Serializable data class BookRoute(val id: Int, val preview: Boolean = false)
@Serializable data class MangaRoute(val id: Int)
@Serializable data class BookStatsRoute(val id: Int)
@Serializable data class BookBrowseRoute(val by: String, val name: String)
@Serializable data class BookRequestsRoute(val query: String? = null)
@Serializable data class ReadingShelfRoute(val kind: String, val state: String? = null)
@Serializable object ReadingStatsRoute
@Serializable data class ProfileRoute(val username: String)
@Serializable data class RecapRoute(val year: Int, val username: String? = null)
@Serializable data class WatchedRoute(val username: String? = null, val kind: String)
@Serializable object HistoryRoute
@Serializable object NotificationsRoute
@Serializable object SettingsRoute
@Serializable object FolioRoute
@Serializable object DevicesRoute
@Serializable object ShowsWatchlistRoute
@Serializable object RequestStatesRoute
