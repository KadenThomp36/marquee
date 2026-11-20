package dev.kadenthompson.marquee.features.detail

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.CastStrip
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ChipRow
import dev.kadenthompson.marquee.design.DetailSection
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.ExpandableText
import dev.kadenthompson.marquee.design.FoldSpread
import dev.kadenthompson.marquee.design.LoadingList
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.MetaChip
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.RatingChip
import dev.kadenthompson.marquee.design.RemoteImage
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.StarRating
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.features.common.TypeBadge
import dev.kadenthompson.marquee.features.requests.MovieRequestSheet
import dev.kadenthompson.marquee.features.requests.RequestButton
import dev.kadenthompson.marquee.model.EpisodeDetail
import dev.kadenthompson.marquee.model.MarkResponse
import dev.kadenthompson.marquee.model.MovieDetail
import dev.kadenthompson.marquee.model.PersonDetail
import dev.kadenthompson.marquee.model.RequestState
import dev.kadenthompson.marquee.model.RequestStatus
import dev.kadenthompson.marquee.model.WatchProviders
import dev.kadenthompson.marquee.nav.EpisodeRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MovieRoute
import dev.kadenthompson.marquee.nav.PersonRoute
import dev.kadenthompson.marquee.nav.ShowRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.launch

// ================= Episode

@Composable
fun EpisodeScreen(showId: Int, season: Int, number: Int) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val haptic = LocalHapticFeedback.current
    val data = rememberRemote<EpisodeDetail>("ep-$showId-$season-$number") { it.get("show/$showId/episode/$season/$number") }
    var ahead by remember { mutableStateOf(false) }
    var revealed by rememberSaveable { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }

    fun mark(watched: Boolean, previous: Boolean) = scope.launch {
        val c = session.client ?: return@launch
        busy = true
        data.mutate { it.copy(watched = watched, watchedAt = if (watched) it.watchedAt ?: MQTime.stamp() else null, earlierUnwatched = if (previous) 0 else it.earlierUnwatched) }
        try {
            val r: MarkResponse = c.post("show/$showId/watch", body("season" to season, "number" to number, "unwatch" to if (watched) null else true, "previous" to if (previous) true else null))
            session.enqueue(r.celebrate); session.noteWatched()
            if (watched) haptic.performHapticFeedback(HapticFeedbackType.Confirm)
        } catch (e: Exception) { snackbar.showSnackbar(e.friendly); data.refresh() } finally { busy = false }
    }

    val e = data.value
    ScreenScaffold(e?.code ?: "", { nav.popBackStack() }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        when {
            e != null -> Box(Modifier.fillMaxSize()) {
                BackdropWash(listOf(e.still, e.seasonPoster, e.showBackdrop, e.showPoster).firstOrNull { !it.isNullOrEmpty() }, alpha = 0.4f)
                FoldSpread(contentPadding = PaddingValues(top = pad.calculateTopPadding()), leading = {
                    Column(Modifier.padding(horizontal = MQ.gutter).padding(top = 60.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            Row(Modifier.clickable { nav.push(ShowRoute(showId)) }, verticalAlignment = Alignment.CenterVertically) {
                                Text(e.showTitle ?: "Show", style = T.body(13f, 700), color = C.brass, maxLines = 1)
                                Icon(Icons.Filled.ChevronRight, null, tint = C.brass, modifier = Modifier.size(14.dp))
                            }
                            Text(e.displayTitle, style = T.body(24f, 700), color = C.ink)
                            Text(buildString {
                                append(e.code); e.runtime?.takeIf { it > 0 }?.let { append(" · $it min") }
                                e.airDate?.takeIf { it.isNotEmpty() }?.let { append(" · ${MQTime.medium(it)}") }
                            }, style = T.sub, color = C.inkSoft)
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                RatingChip(e.imdb, e.extra?.vote ?: e.rating)
                                if (e.watched && e.watchedAt != null) Text("watched ${MQTime.medium(e.watchedAt)}", style = T.caption, color = C.inkMuted)
                            }
                        }
                        e.overview?.takeIf { it.isNotEmpty() }?.let {
                            if (!e.watched && !revealed) SpoilerCover("The summary", e.code) { revealed = true }
                            else Text(it, style = T.body, color = C.inkSoft)
                        }
                        val dirs = e.extra?.directors.orEmpty(); val writers = e.extra?.writers.orEmpty()
                        if (dirs.isNotEmpty() || writers.isNotEmpty()) FlowRow(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            if (dirs.isNotEmpty()) Column { Eyebrow("Directed by"); Text(dirs.joinToString(", "), style = T.sub, color = C.inkSoft) }
                            if (writers.isNotEmpty()) Column { Eyebrow("Written by"); Text(writers.joinToString(", "), style = T.sub, color = C.inkSoft) }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                            if (e.watched) PrimaryButton("Watched", { mark(false, false) }, fill = false, icon = Icons.Filled.Check, busy = busy)
                            else Row(Modifier.clip(CircleShape).border(1.5.dp, C.brass, CircleShape).clickable(enabled = !busy) {
                                if (season > 0 && (e.earlierUnwatched ?: 0) > 0) ahead = true else mark(true, false)
                            }.padding(horizontal = 20.dp, vertical = 13.dp), verticalAlignment = Alignment.CenterVertically) {
                                Icon(Icons.Filled.Check, null, tint = C.brass, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)); Text("Mark watched", style = T.headline, color = C.brass)
                            }
                            ShareChip("show/$showId/e/$season/$number")
                        }
                    }
                    e.extra?.guests?.takeIf { it.isNotEmpty() }?.let { DetailSection("Guest stars") { CastStrip(it) { id -> nav.push(PersonRoute(id)) } } }
                }, trailing = {
                    ReviewsSection("episode", e.reviewKey, e.code, e.watched)
                    Row(Modifier.padding(horizontal = MQ.gutter).fillMaxWidth()) {
                        e.prev?.let { p -> ChipButton("Previous", Icons.AutoMirrored.Filled.KeyboardArrowLeft) { nav.push(EpisodeRoute(showId, p.season, p.number)) } }
                        Spacer(Modifier.weight(1f))
                        e.next?.let { n -> ChipButton("Next episode", Icons.AutoMirrored.Filled.KeyboardArrowRight) { nav.push(EpisodeRoute(showId, n.season, n.number)) } }
                    }
                })
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(2) }
        }
    }
    if (ahead) {
        val behind = e?.earlierUnwatched ?: 0
        AlertDialog(onDismissRequest = { ahead = false }, containerColor = C.panelRaised,
            title = { Text("You're ahead — $behind earlier episode${if (behind == 1) " isn't" else "s aren't"} marked yet.", style = T.headline, color = C.ink) },
            confirmButton = { TextButton({ ahead = false; mark(true, true) }) { Text("Mark all ${behind + 1} up to here", color = C.brass) } },
            dismissButton = { TextButton({ ahead = false; mark(true, false) }) { Text("Just this episode", color = C.inkSoft) } })
    }
}

// ================= Film

@Composable
fun MovieScreen(movieId: Int) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val data = rememberRemote<MovieDetail>("movie-$movieId", true) { it.get("movie/$movieId") }
    var providers by remember { mutableStateOf<WatchProviders?>(null) }
    var request by remember { mutableStateOf<RequestStatus?>(null) }
    var gallery by remember { mutableStateOf(false) }
    var requestSheet by remember { mutableStateOf(false) }

    suspend fun refreshRequest() {
        if (session.requestConfig?.enabled != true) return
        request = runCatching { session.client?.get<RequestStatus>("request/status/movie/$movieId") }.getOrNull() ?: request
    }
    LaunchedEffect(movieId) {
        val c = session.client ?: return@LaunchedEffect
        providers = runCatching { c.get<WatchProviders>("watch_providers/movie/$movieId") }.getOrNull()
        session.loadRequestConfig(); refreshRequest()
        while (request?.isBusy == true) { kotlinx.coroutines.delay(8000); refreshRequest() }
    }

    fun setState(state: String, rating: Int? = null) = scope.launch {
        data.mutate { it.copy(state = if (state == "none") null else state, myRating = rating ?: it.myRating) }
        try { session.client?.send("movie/$movieId/state", body("state" to state, "rating" to rating)) } catch (e: Exception) { snackbar.showSnackbar(e.friendly); data.refresh() }
    }

    val m = data.value
    ScreenScaffold(m?.displayTitle ?: "Film", { nav.popBackStack() }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        when {
            m != null -> Box(Modifier.fillMaxSize()) {
                BackdropWash(m.info?.backdrop)
                FoldSpread(contentPadding = PaddingValues(top = pad.calculateTopPadding()), leading = {
                    Column(Modifier.padding(horizontal = MQ.gutter).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            Poster(m.poster, Modifier.width(118.dp).clip(RoundedCornerShape(14.dp)).clickable { gallery = true }, radius = 14.dp)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                                Text(m.displayTitle, style = T.title, color = C.ink)
                                m.info?.tagline?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption.copy(fontStyle = FontStyle.Italic), color = C.inkMuted, maxLines = 2) }
                                ChipRow {
                                    m.info?.contentRating?.takeIf { it.isNotEmpty() }?.let { MetaChip(it) }
                                    RatingChip(m.info?.imdb, m.info?.vote)
                                    (m.info?.runtime ?: m.runtime)?.takeIf { it > 0 }?.let { MetaChip("${it / 60}h ${it % 60}m") }
                                    m.info?.genres?.takeIf { it.isNotEmpty() }?.let { MetaChip(it.take(2).joinToString(" · ")) }
                                }
                                Text(listOfNotNull(m.year?.toString(), m.info?.directors?.takeIf { it.isNotEmpty() }?.let { "dir. ${it.joinToString(", ")}" }).joinToString(" · "), style = T.caption, color = C.inkSoft)
                                if (m.isWatched) StarRating(m.myRating) { v -> if (v != null) setState("watched", v) }
                            }
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                            if (m.isWatched) ChipButton("Watched", Icons.Filled.Check, on = true) { setState("none") }
                            else PrimaryButton("Mark watched", { setState("watched") }, fill = false, icon = Icons.Filled.Check)
                            if (m.state == null) ChipButton("Watchlist", Icons.Filled.Bookmark) { setState("watchlist") }
                            if (session.requestConfig?.enabled == true) request?.let { RequestButton(it) { requestSheet = true } }
                        }
                        ChipRow {
                            FavoriteChip("movie", movieId)
                            AddToListChip("movie", movieId, m.displayTitle)
                            ShareChip("movie/$movieId")
                            m.info?.imdbId?.takeIf { it.isNotEmpty() }?.let { LinkChip("IMDb", "https://www.imdb.com/title/$it/") }
                            if (m.state != null) ChipButton("Remove", Icons.Filled.Delete, destructive = true) { setState("none") }
                        }
                    }
                    m.info?.overview?.takeIf { it.isNotEmpty() }?.let { Box(Modifier.padding(horizontal = MQ.gutter)) { ExpandableText(it) } }
                    WhereToWatch(providers, request?.state == RequestState.AVAILABLE)
                    m.info?.cast?.takeIf { it.isNotEmpty() }?.let { DetailSection("Cast") { CastStrip(it) { id -> nav.push(PersonRoute(id)) } } }
                }, trailing = {
                    ReviewsSection("movie", movieId, "this film", m.isWatched)
                })
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(2) }
        }
    }
    if (gallery) ArtworkGallery("movie", movieId, m?.displayTitle ?: "", onDismiss = { gallery = false })
    if (requestSheet) request?.let { MovieRequestSheet(movieId, it, onDismiss = { requestSheet = false }) { refreshRequest() } }
}

// ================= Person

@Composable
fun PersonScreen(personId: Int) {
    val nav = LocalNav.current
    val data = rememberRemote<PersonDetail>("person-$personId") { it.get("person/$personId") }
    var filter by rememberSaveable { mutableIntStateOf(0) }
    val p = data.value
    ScreenScaffold(p?.name ?: "", { nav.popBackStack() }) { pad ->
        when {
            p != null -> {
                val credits = p.credits.filter { when (filter) { 1 -> it.isShow; 2 -> !it.isShow; else -> true } }
                LazyVerticalGrid(GridCells.Adaptive(108.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                            Row(horizontalArrangement = Arrangement.spacedBy(16.dp), verticalAlignment = Alignment.CenterVertically) {
                                RemoteImage(p.img, Modifier.size(104.dp).clip(CircleShape).border(1.dp, C.hairlineBold, CircleShape), placeholder = Icons.Filled.Person)
                                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                                    Text(p.name ?: "", style = T.title, color = C.ink)
                                    Text(listOfNotNull(p.knownFor, p.birthday?.let { b -> "born ${MQTime.medium(b)}" + (p.deathday?.let { " – ${MQTime.medium(it)}" } ?: "") }, p.place).joinToString(" · "), style = T.caption, color = C.inkSoft)
                                    p.imdbId?.let { LinkChip("IMDb", "https://www.imdb.com/name/$it/") }
                                }
                            }
                            p.bio?.takeIf { it.isNotEmpty() }?.let { ExpandableText(it, 4) }
                            Segmented(listOf("All", "TV", "Films"), filter) { filter = it }
                        }
                    }
                    items(credits, key = { it.uniqueId }) { c ->
                        Column(Modifier.clip(RoundedCornerShape(8.dp)).clickable { nav.push(if (c.isShow) ShowRoute(c.id) else MovieRoute(c.id)) }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Box { Poster(c.poster, Modifier.fillMaxWidth()); TypeBadge(c.isShow, Modifier.align(Alignment.TopStart).padding(6.dp)) }
                            Text(c.title ?: "", style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(c.character?.takeIf { it.isNotEmpty() } ?: c.year?.toString() ?: "", style = T.caption, color = C.inkMuted, maxLines = 1)
                        }
                    }
                }
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(2) }
        }
    }
}
