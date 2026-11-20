package dev.kadenthompson.marquee.nav

import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.core.tween
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Slideshow
import androidx.compose.material.icons.filled.ViewAgenda
import androidx.compose.material.icons.outlined.AccountCircle
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Slideshow
import androidx.compose.material.icons.outlined.ViewAgenda
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.NavigationRail
import androidx.compose.material3.NavigationRailItem
import androidx.compose.material3.NavigationRailItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.Snackbar
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.navigation.NavController
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.navigation
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.isMediumWindow
import dev.kadenthompson.marquee.features.Screens
import dev.kadenthompson.marquee.session.LocalSnackbar

val LocalNav = staticCompositionLocalOf<NavController> { error("No NavController") }

fun NavController.push(route: Any) = navigate(route) { launchSingleTop = true }
fun NavController.back() { if (!popBackStack()) Unit }

private data class TabSpec(val tab: Tab, val label: String, val on: ImageVector, val off: ImageVector, val graph: Any)

private val tabs = listOf(
    TabSpec(Tab.NEXT, "Next", Icons.Filled.Slideshow, Icons.Outlined.Slideshow, NextGraph),
    TabSpec(Tab.UPCOMING, "Upcoming", Icons.Filled.CalendarMonth, Icons.Outlined.CalendarMonth, UpcomingGraph),
    TabSpec(Tab.LIBRARY, "Library", Icons.Filled.ViewAgenda, Icons.Outlined.ViewAgenda, LibraryGraph),
    TabSpec(Tab.SEARCH, "Search", Icons.Filled.Search, Icons.Outlined.Search, SearchGraph),
    TabSpec(Tab.YOU, "You", Icons.Filled.AccountCircle, Icons.Outlined.AccountCircle, YouGraph),
)

private fun tabOf(dest: androidx.navigation.NavDestination?): Tab? {
    var d = dest
    while (d != null) {
        when {
            d.hasRoute<NextGraph>() -> return Tab.NEXT
            d.hasRoute<UpcomingGraph>() -> return Tab.UPCOMING
            d.hasRoute<LibraryGraph>() -> return Tab.LIBRARY
            d.hasRoute<SearchGraph>() -> return Tab.SEARCH
            d.hasRoute<YouGraph>() -> return Tab.YOU
        }
        d = d.parent
    }
    return null
}

/**
 * The app's five destinations. Films and Reading live in one Library; History, Lists
 * and Settings sit under You. A bottom bar on phones, a rail on tablets and unfolded
 * foldables, each tab keeping its own back stack.
 */
@Composable
fun MainShell() {
    val nav = rememberNavController()
    val stack by nav.currentBackStack.collectAsState()
    val current: Tab = stack.asReversed().firstNotNullOfOrNull { e -> tabOf(e.destination) } ?: Tab.NEXT
    val wide = isMediumWindow()
    val snackbar = remember { androidx.compose.material3.SnackbarHostState() }

    fun select(tab: Tab, reselect: Boolean = true) {
        val spec = tabs.first { it.tab == tab }
        if (tab == current && reselect) {
            // Tapping the tab you're on goes back to its top.
            val root: Any = when (tab) {
                Tab.NEXT -> NextHome; Tab.UPCOMING -> UpcomingHome; Tab.LIBRARY -> LibraryHome(); Tab.SEARCH -> SearchHome(); Tab.YOU -> YouHome
            }
            if (!nav.popBackStack(root, inclusive = false)) nav.navigate(spec.graph)
            return
        }
        nav.navigate(spec.graph) {
            popUpTo(nav.graph.findStartDestination().id) { saveState = true }
            launchSingleTop = true
            restoreState = true
        }
    }

    // Routes opened from outside — a notification, a deep link, a celebration.
    val pending = Navigator.pending
    LaunchedEffect(pending) {
        val route = Navigator.consume() ?: return@LaunchedEffect
        val tab = Navigator.tabFor(route)
        if (tab != current) select(tab, reselect = false)
        when (route) {
            is SearchHome -> nav.navigate(route) { launchSingleTop = true }
            else -> nav.push(route)
        }
    }

    CompositionLocalProvider(LocalNav provides nav, LocalSnackbar provides snackbar) {
        Scaffold(
            containerColor = C.ground,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            snackbarHost = { SnackbarHost(snackbar) { Snackbar(it, containerColor = C.panelRaised, contentColor = C.ink, actionColor = C.brass) } },
            bottomBar = {
                if (!wide) NavigationBar(containerColor = C.panel, tonalElevation = 0.dp) {
                    tabs.forEach { t ->
                        val sel = t.tab == current
                        NavigationBarItem(
                            selected = sel, onClick = { select(t.tab) },
                            icon = { Icon(if (sel) t.on else t.off, t.label) },
                            label = { Text(t.label, style = T.body(11f, 600)) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = C.brass, selectedTextColor = C.brass, indicatorColor = C.brassSoft,
                                unselectedIconColor = C.inkMuted, unselectedTextColor = C.inkMuted,
                            ),
                        )
                    }
                }
            },
        ) { pad ->
            Row(Modifier.fillMaxSize().padding(pad).consumeWindowInsets(pad)) {
                if (wide) NavigationRail(containerColor = C.panel, header = { Spacer(Modifier.statusBarsPadding().height(8.dp)) }) {
                    tabs.forEach { t ->
                        val sel = t.tab == current
                        NavigationRailItem(
                            selected = sel, onClick = { select(t.tab) },
                            icon = { Icon(if (sel) t.on else t.off, t.label) },
                            label = { Text(t.label, style = T.body(11f, 600)) },
                            colors = NavigationRailItemDefaults.colors(
                                selectedIconColor = C.brass, selectedTextColor = C.brass, indicatorColor = C.brassSoft,
                                unselectedIconColor = C.inkMuted, unselectedTextColor = C.inkMuted,
                            ),
                        )
                    }
                }
                Box(Modifier.weight(1f)) { MarqueeNavHost(nav) }
            }
        }
    }
}


@Composable
private fun MarqueeNavHost(nav: NavHostController) {
    NavHost(
        nav, startDestination = NextGraph, modifier = Modifier.fillMaxSize(),
        enterTransition = { fadeIn(tween(220)) + slideInHorizontally(tween(260)) { it / 12 } },
        exitTransition = { fadeOut(tween(180)) },
        popEnterTransition = { fadeIn(tween(220)) },
        popExitTransition = { fadeOut(tween(180)) + slideOutHorizontally(tween(240)) { it / 12 } },
    ) {
        navigation<NextGraph>(startDestination = NextHome) { composable<NextHome> { Screens.Next() } }
        navigation<UpcomingGraph>(startDestination = UpcomingHome) { composable<UpcomingHome> { Screens.Upcoming() } }
        navigation<LibraryGraph>(startDestination = LibraryHome()) { composable<LibraryHome> { Screens.Library(it.toRoute()) } }
        navigation<SearchGraph>(startDestination = SearchHome()) { composable<SearchHome> { Screens.Search(it.toRoute<SearchHome>().query) } }
        navigation<YouGraph>(startDestination = YouHome) { composable<YouHome> { Screens.You() } }

        composable<ShowRoute> { Screens.Show(it.toRoute<ShowRoute>().id) }
        composable<EpisodeRoute> { val r = it.toRoute<EpisodeRoute>(); Screens.Episode(r.showId, r.season, r.number) }
        composable<MovieRoute> { Screens.Movie(it.toRoute<MovieRoute>().id) }
        composable<PersonRoute> { Screens.Person(it.toRoute<PersonRoute>().id) }
        composable<ListRoute> { Screens.ListDetail(it.toRoute<ListRoute>().id) }
        composable<ListsRoute> { Screens.Lists() }
        composable<BookRoute> { val r = it.toRoute<BookRoute>(); Screens.Reading("book", r.id, r.preview) }
        composable<MangaRoute> { Screens.Reading("manga", it.toRoute<MangaRoute>().id, false) }
        composable<BookStatsRoute> { Screens.BookStats(it.toRoute<BookStatsRoute>().id) }
        composable<BookBrowseRoute> { val r = it.toRoute<BookBrowseRoute>(); Screens.BookBrowse(r.by, r.name) }
        composable<BookRequestsRoute> { Screens.BookRequests(it.toRoute<BookRequestsRoute>().query) }
        composable<ReadingShelfRoute> { val r = it.toRoute<ReadingShelfRoute>(); Screens.ReadingShelf(r.kind, r.state) }
        composable<ReadingStatsRoute> { Screens.ReadingStats() }
        composable<ProfileRoute> { Screens.Profile(it.toRoute<ProfileRoute>().username) }
        composable<RecapRoute> { val r = it.toRoute<RecapRoute>(); Screens.Recap(r.year, r.username) }
        composable<WatchedRoute> { val r = it.toRoute<WatchedRoute>(); Screens.Watched(r.username, r.kind) }
        composable<HistoryRoute> { Screens.History() }
        composable<NotificationsRoute> { Screens.Notifications() }
        composable<SettingsRoute> { Screens.Settings() }
        composable<FolioRoute> { Screens.Folio() }
        composable<DevicesRoute> { Screens.Devices() }
        composable<ShowsWatchlistRoute> { Screens.ShowsWatchlist() }
        composable<RequestStatesRoute> { Screens.RequestStates() }
    }
}
