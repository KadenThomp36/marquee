package dev.kadenthompson.marquee.features.browse

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.EmptyState
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.SectionHeader
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.StaleFooter
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.PlainRailTitle
import dev.kadenthompson.marquee.features.common.PosterTile
import dev.kadenthompson.marquee.features.common.Rail
import dev.kadenthompson.marquee.features.library.FilterField
import dev.kadenthompson.marquee.features.reading.AddableTile
import dev.kadenthompson.marquee.features.reading.bookAddBody
import dev.kadenthompson.marquee.model.BookSearchResponse
import dev.kadenthompson.marquee.model.BookSearchResult
import dev.kadenthompson.marquee.model.DiscoverResponse
import dev.kadenthompson.marquee.model.MangaSearchResponse
import dev.kadenthompson.marquee.model.MangaSearchResult
import dev.kadenthompson.marquee.model.SearchResponse
import dev.kadenthompson.marquee.model.SearchResult
import dev.kadenthompson.marquee.model.UpcomingResponse
import dev.kadenthompson.marquee.nav.BookRoute
import dev.kadenthompson.marquee.nav.EpisodeRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MangaRoute
import dev.kadenthompson.marquee.nav.MovieRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/** The calendar of what's airing for shows you follow, films coming out, and new chapters. */
@Composable
fun UpcomingScreen() {
    val nav = LocalNav.current
    val data = rememberRemote<UpcomingResponse>("upcoming", true) { it.get("upcoming") }
    val v = data.value
    PullToRefreshBox(data.refreshing, { data.refresh() }, Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item { Text("Upcoming", style = T.title, color = C.ink, modifier = Modifier.statusBarsPadding().padding(top = 12.dp)) }
            if (v != null) {
                v.chapters?.takeIf { it.isNotEmpty() }?.let { ch ->
                    item {
                        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            Row(verticalAlignment = Alignment.Bottom) { Text("New chapters out", style = T.rail, color = C.ink); Spacer(Modifier.width(8.dp)); Text("the last two weeks", style = T.caption, color = C.inkMuted) }
                            ch.forEach { s ->
                                UpRow(s.cover, s.displayTitle, "${s.behind} new · up to ch ${s.latestCh ?: "?"}", "+${s.behind}") { nav.push(MangaRoute(s.id)) }
                            }
                        }
                    }
                }
                val days = (v.episodes.map { it.airDate.take(10) } + v.movies.map { it.releaseDate.take(10) }).distinct().sorted()
                if (days.isEmpty() && v.chapters.isNullOrEmpty()) item { EmptyState(Icons.Filled.CalendarMonth, "Nothing on the calendar", "Follow a show that's still airing and its next episodes appear here.") }
                days.forEach { day ->
                    item(key = "d$day") {
                        val d = runCatching { LocalDate.parse(day) }.getOrNull()
                        val far = d != null && d.isAfter(LocalDate.now().plusDays(6))
                        Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(if (far && d != null) d.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault()) else MQTime.upcomingLabel(day), style = T.headline, color = C.brass)
                            Text(MQTime.medium(day), style = T.caption, color = C.inkMuted)
                        }
                    }
                    items(v.episodes.filter { it.airDate.take(10) == day }, key = { "e" + it.key }) { e ->
                        UpRow(e.poster, e.showTitle ?: "", "${e.code}${e.title?.let { " · $it" } ?: ""}", "TV") { nav.push(EpisodeRoute(e.showId, e.season, e.number)) }
                    }
                    items(v.movies.filter { it.releaseDate.take(10) == day }, key = { "m${it.id}" }) { m ->
                        UpRow(m.poster, m.title ?: "", "In release", "FILM") { nav.push(MovieRoute(m.id)) }
                    }
                }
            } else if (data.error != null) item { ErrorState(data.error!!) { data.refresh() } }
            else items(5) { Skeleton(height = 68.dp) }
            item { StaleFooter(data.stale && v != null && !data.loading) }
        }
    }
}

@Composable
private fun UpRow(poster: String?, title: String, sub: String, tag: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().mqPanel().clickable(onClick = onClick).padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Poster(poster, Modifier.width(40.dp), radius = 6.dp)
        Column(Modifier.weight(1f)) {
            Text(title, style = T.body(14.5f, 700), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(sub, style = T.caption, color = C.inkSoft, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        Text(tag, style = T.eyebrow, color = C.brass, modifier = Modifier.clip(RoundedCornerShape(6.dp)).background(C.brassSoft).padding(horizontal = 7.dp, vertical = 3.dp))
    }
}

// ================= Search & Discover

@Composable
fun SearchScreen(initial: String?) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    var query by rememberSaveable { mutableStateOf(initial ?: "") }
    val scopes = buildList { add("All"); add("Shows & films"); if (session.tracksBooks) add("Books"); if (session.tracksManga) add("Manga") }
    var scopeIdx by rememberSaveable { mutableIntStateOf(0) }
    var screen by remember { mutableStateOf<List<SearchResult>?>(null) }
    var books by remember { mutableStateOf<List<BookSearchResult>>(emptyList()) }
    var manga by remember { mutableStateOf<List<MangaSearchResult>>(emptyList()) }
    val discover = rememberRemote<DiscoverResponse>("discover", true) { it.get("discover") }
    LaunchedEffect(initial) { if (initial != null) query = initial }
    LaunchedEffect(query) {
        val q = query.trim()
        if (q.length < 2) { screen = null; books = emptyList(); manga = emptyList(); return@LaunchedEffect }
        delay(350)
        val c = session.client ?: return@LaunchedEffect
        coroutineScope {
            val a = async { runCatching { c.get<SearchResponse>("search", mapOf("q" to q)).results }.getOrDefault(emptyList()) }
            val b = async { if (session.tracksBooks && q.length >= 3) runCatching { c.get<BookSearchResponse>("books/search", mapOf("q" to q)).results }.getOrDefault(emptyList()) else emptyList() }
            val m = async { if (session.tracksManga && q.length >= 3) runCatching { c.get<MangaSearchResponse>("manga/search", mapOf("q" to q)).results }.getOrDefault(emptyList()) else emptyList() }
            screen = a.await(); books = b.await(); manga = m.await()
        }
    }
    val sel = scopes.getOrElse(scopeIdx) { "All" }
    LazyVerticalGrid(GridCells.Adaptive(108.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, bottom = 32.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item(span = { GridItemSpan(maxLineSpan) }) {
            Column(Modifier.statusBarsPadding().padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Search", style = T.title, color = C.ink)
                FilterField(query, { query = it }, if (session.tracksReading) "Shows, films, books" else "Shows and films", icon = Icons.Filled.Search)
                if (scopes.size > 2) Segmented(scopes, scopeIdx) { scopeIdx = it }
            }
        }
        val s = screen
        if (s == null) {
            // Discover
            discover.value?.sections?.forEach { sec ->
                item(span = { GridItemSpan(maxLineSpan) }, key = "sec-${sec.title}") {
                    Column(Modifier.padding(horizontal = 0.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Text(sec.title, style = T.rail, color = C.ink)
                        Rail(Modifier.padding(horizontal = 0.dp)) { items(sec.items, key = { "${it.type}:${it.id}" }) { r -> AddingPosterTile(r) } }
                    }
                }
            }
            if (discover.value == null) items(6) { Skeleton(height = 180.dp) }
        } else {
            if (sel == "All" || sel == "Shows & films") {
                if (sel == "All" && s.isNotEmpty() && (books.isNotEmpty() || manga.isNotEmpty())) item(span = { GridItemSpan(maxLineSpan) }) { SectionHeader("Shows & films", count = "${s.size}") }
                items(s, key = { "s-${it.type}:${it.id}" }) { r -> AddingPosterTile(r, null) }
            }
            if ((sel == "All" || sel == "Books") && books.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) { SectionHeader("Books", count = "${books.size}") }
                items(books, key = { "b${it.hcId}" }) { r -> AddableTile(r.cover, r.displayTitle, listOfNotNull(r.author, r.year?.toString()).joinToString(" · "), r.communityRating, { nav.push(BookRoute(r.hcId, true)) }) { st ->
                    scope.launch { runCatching { session.client?.send("books/add", bookAddBody(r, st)) }; session.noteReading() } } }
            }
            if ((sel == "All" || sel == "Manga") && manga.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) { SectionHeader("Manga", count = "${manga.size}") }
                items(manga, key = { "m${it.id}" }) { r -> AddableTile(r.cover, r.displayTitle, listOfNotNull(r.origin, r.year?.toString()).joinToString(" · "), r.score, { nav.push(MangaRoute(r.id)) }) { st ->
                    scope.launch { runCatching { session.client?.send("manga/add", body("id" to r.id, "state" to st.key)) }; session.noteReading() } } }
            }
            if (s.isEmpty() && books.isEmpty() && manga.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState(Icons.Filled.Search, "Nothing found", "Try fewer words, or the original title.") }
        }
    }
}

/** A result tile with a quick-add: "Add to watchlist" for shows, Watchlist for films. */
@Composable
private fun AddingPosterTile(r: SearchResult, width: androidx.compose.ui.unit.Dp? = dev.kadenthompson.marquee.design.MQ.tileWidth) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var added by remember(r.type, r.id) { mutableStateOf(r.alreadyHave) }
    PosterTile(r.copy(followed = if (added && r.isShow) true else r.followed, state = if (added && !r.isShow) r.state ?: "watchlist" else r.state), width) {
        Box(Modifier.align(Alignment.BottomStart).padding(6.dp).size(30.dp).clip(CircleShape).background(if (added) C.panelRaised else C.brassFill)
            .clickable(enabled = !added) {
                added = true
                scope.launch { runCatching { session.client?.send("add", body("type" to r.type, "id" to r.id, "state" to if (r.isShow) null else "watchlist")) }; session.noteWatched(); session.refreshListMembership() }
            }, contentAlignment = Alignment.Center) {
            Icon(if (added) Icons.Filled.Check else Icons.Filled.Add, if (r.isShow) "Add to watchlist" else "Add to film watchlist", tint = if (added) C.brass else C.brassOnFill, modifier = Modifier.size(17.dp))
        }
    }
}
