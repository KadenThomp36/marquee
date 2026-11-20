package dev.kadenthompson.marquee.nav

import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

enum class Tab { NEXT, UPCOMING, LIBRARY, SEARCH, YOU }

/**
 * Where a tap from outside the current screen should land: a celebration's "see the
 * show", a notification, a deep link. The shell watches [pending] and pushes it onto
 * the right tab, so nothing else has to know how navigation is wired.
 */
object Navigator {
    var pending by mutableStateOf<Any?>(null)
        private set

    fun open(route: Any) { pending = route }
    fun consume(): Any? = pending.also { pending = null }

    fun tabFor(route: Any): Tab = when (route) {
        is ShowRoute, is EpisodeRoute -> Tab.NEXT
        is MovieRoute, is BookRoute, is BookStatsRoute, is BookBrowseRoute, is MangaRoute, is ReadingShelfRoute -> Tab.LIBRARY
        is SearchHome, is PersonRoute -> Tab.SEARCH
        else -> Tab.YOU
    }

    /** `marquee://show/1396`, or the web client's hash routes (`#/show/1396/e/5/14`). */
    fun route(uri: Uri): Any? {
        val path = if (uri.scheme == "marquee") listOfNotNull(uri.host) + uri.pathSegments
        else (uri.fragment ?: uri.path ?: "").trim('#', '/').split('/')
        return route(path.joinToString("/"))
    }

    fun route(link: String): Any? {
        val parts = link.trim('#', '/', ' ').split('/').filter { it.isNotEmpty() }
        val first = parts.firstOrNull() ?: return null
        fun int(i: Int) = parts.getOrNull(i)?.toIntOrNull()
        return when (first) {
            "show" -> if (parts.size >= 5 && parts[2] == "e") {
                val id = int(1); val s = int(3); val n = int(4)
                if (id != null && s != null && n != null) EpisodeRoute(id, s, n) else null
            } else int(1)?.let { ShowRoute(it) }
            "movie" -> int(1)?.let { MovieRoute(it) }
            "person" -> int(1)?.let { PersonRoute(it) }
            "list" -> int(1)?.let { ListRoute(it) }
            "lists" -> ListsRoute
            "book" -> if (parts.size >= 3 && parts[2] == "stats") int(1)?.let { BookStatsRoute(it) } else int(1)?.let { BookRoute(it) }
            "books" -> if (parts.size >= 3 && (parts[1] == "author" || parts[1] == "series"))
                BookBrowseRoute(parts[1], Uri.decode(parts.drop(2).joinToString("/"))) else null
            "requests" -> if (parts.getOrNull(1) == "books") BookRequestsRoute() else null
            "book-requests" -> BookRequestsRoute()
            "manga" -> int(1)?.let { MangaRoute(it) }
            "u" -> parts.getOrNull(1)?.let { ProfileRoute(it) }
            "history" -> HistoryRoute
            "inbox" -> NotificationsRoute
            "settings" -> SettingsRoute
            "recap" -> int(1)?.let { RecapRoute(it) }
            "search" -> SearchHome(parts.drop(1).joinToString("/").let(Uri::decode).ifEmpty { null })
            "debug" -> if (parts.getOrNull(1) == "requests") RequestStatesRoute else null
            else -> null
        }
    }
}
