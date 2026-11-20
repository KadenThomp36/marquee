package dev.kadenthompson.marquee.features

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.nav.LibraryHome
import dev.kadenthompson.marquee.nav.LocalNav

/** Every destination's entry point, in one place so the nav graph reads as a table of contents. */
object Screens {
    @Composable fun Next() = dev.kadenthompson.marquee.features.next.NextScreen()
    @Composable fun Upcoming() = dev.kadenthompson.marquee.features.browse.UpcomingScreen()
    @Composable fun Library(r: LibraryHome) = dev.kadenthompson.marquee.features.library.LibraryScreen(r)
    @Composable fun Search(query: String?) = dev.kadenthompson.marquee.features.browse.SearchScreen(query)
    @Composable fun You() = dev.kadenthompson.marquee.features.you.ProfileScreen(null)
    @Composable fun Show(id: Int) = dev.kadenthompson.marquee.features.show.ShowScreen(id)
    @Composable fun Episode(showId: Int, season: Int, number: Int) = dev.kadenthompson.marquee.features.detail.EpisodeScreen(showId, season, number)
    @Composable fun Movie(id: Int) = dev.kadenthompson.marquee.features.detail.MovieScreen(id)
    @Composable fun Person(id: Int) = dev.kadenthompson.marquee.features.detail.PersonScreen(id)
    @Composable fun ListDetail(id: Int) = dev.kadenthompson.marquee.features.you.ListScreen(id)
    @Composable fun Lists() = dev.kadenthompson.marquee.features.you.ListsScreen()
    @Composable fun Reading(kind: String, id: Int, preview: Boolean) = dev.kadenthompson.marquee.features.reading.ReadingDetailScreen(kind, id, preview)
    @Composable fun BookStats(id: Int) = dev.kadenthompson.marquee.features.reading.BookStatsScreen(id)
    @Composable fun BookBrowse(by: String, name: String) = dev.kadenthompson.marquee.features.reading.BookBrowseScreen(by, name)
    @Composable fun BookRequests(query: String?) = dev.kadenthompson.marquee.features.reading.BookRequestsScreen(query)
    @Composable fun ReadingShelf(kind: String, state: String?) = Todo("Shelf", true)
    @Composable fun ReadingStats() = dev.kadenthompson.marquee.features.reading.ReadingStatsScreen()
    @Composable fun Profile(username: String) = dev.kadenthompson.marquee.features.you.ProfileScreen(username)
    @Composable fun Recap(year: Int, username: String?) = Todo("Recap", true)
    @Composable fun Watched(username: String?, kind: String) = dev.kadenthompson.marquee.features.you.WatchedGridScreen(username, kind)
    @Composable fun History() = dev.kadenthompson.marquee.features.you.HistoryScreen()
    @Composable fun Notifications() = dev.kadenthompson.marquee.features.you.NotificationsScreen()
    @Composable fun Settings() = Todo("Settings", true)
    @Composable fun Folio() = Todo("Folio", true)
    @Composable fun Devices() = Todo("Devices", true)
    @Composable fun ShowsWatchlist() = dev.kadenthompson.marquee.features.library.ShowsWatchlistScreen()
    @Composable fun RequestStates() = Todo("Request states", true)

    @Composable
    private fun Todo(title: String, pushed: Boolean = false) {
        val nav = LocalNav.current
        ScreenScaffold(title, if (pushed) ({ nav.popBackStack() }) else null) { pad ->
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Text(title, style = T.headline, color = C.inkMuted) }
        }
    }
}
