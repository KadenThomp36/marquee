package dev.kadenthompson.marquee.features.reading

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MoveDown
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.outlined.MoveToInbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.StaleFooter
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.EmptyLine
import dev.kadenthompson.marquee.features.common.NavRow
import dev.kadenthompson.marquee.features.common.OnArtBadge
import dev.kadenthompson.marquee.features.common.ProgressBar
import dev.kadenthompson.marquee.features.library.FilterField
import dev.kadenthompson.marquee.model.ActiveSession
import dev.kadenthompson.marquee.model.ActiveSessionsResponse
import dev.kadenthompson.marquee.model.BookSearchResponse
import dev.kadenthompson.marquee.model.BookSearchResult
import dev.kadenthompson.marquee.model.MangaSearchResponse
import dev.kadenthompson.marquee.model.MangaSearchResult
import dev.kadenthompson.marquee.model.ReadingItem
import dev.kadenthompson.marquee.model.ReadingKind
import dev.kadenthompson.marquee.model.ReadingSections
import dev.kadenthompson.marquee.model.ReadingShelves
import dev.kadenthompson.marquee.model.ReadingState
import dev.kadenthompson.marquee.nav.BookRequestsRoute
import dev.kadenthompson.marquee.nav.BookRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MangaRoute
import dev.kadenthompson.marquee.nav.ReadingStatsRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

fun bookAddBody(r: BookSearchResult, state: ReadingState) = body(
    "hc_id" to r.hcId, "title" to r.title, "author" to r.author, "year" to r.year, "pages" to r.pages, "cover" to r.cover,
    "series" to r.series, "rating" to r.communityRating, "genres" to r.genres, "slug" to r.slug, "desc" to r.desc, "state" to state.key,
)

/** Books and manga on shelves, a live session strip, and an add field searching Hardcover / AniList. */
@Composable
fun ReadingShelf(query: String) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val haptic = LocalHapticFeedback.current
    val shelves = rememberRemote<ReadingShelves>("reading", true, session.readingRevision) { it.get("reading") }
    var active by remember { mutableStateOf<List<ActiveSession>>(emptyList()) }
    var kind by rememberSaveable { mutableStateOf(if (!session.tracksBooks && session.tracksManga) ReadingKind.MANGA else ReadingKind.BOOK) }
    var addQuery by rememberSaveable { mutableStateOf("") }
    var books by remember { mutableStateOf<List<BookSearchResult>>(emptyList()) }
    var manga by remember { mutableStateOf<List<MangaSearchResult>>(emptyList()) }
    var target by remember { mutableStateOf<ProgressTarget?>(null) }

    suspend fun loadActive() { active = runCatching { session.client?.get<ActiveSessionsResponse>("reading/active")?.sessions }.getOrNull() ?: active }
    LaunchedEffect(session.readingRevision) { loadActive(); session.loadBookRequestConfig() }
    LaunchedEffect(addQuery, kind) {
        val q = addQuery.trim()
        if (q.length < 3) { books = emptyList(); manga = emptyList(); return@LaunchedEffect }
        delay(450)
        val c = session.client ?: return@LaunchedEffect
        if (kind == ReadingKind.BOOK) books = runCatching { c.get<BookSearchResponse>("books/search", mapOf("q" to q)).results }.getOrDefault(emptyList())
        else manga = runCatching { c.get<MangaSearchResponse>("manga/search", mapOf("q" to q)).results }.getOrDefault(emptyList())
    }

    fun sectionsOf(v: ReadingShelves) = if (kind == ReadingKind.BOOK) v.books else v.manga
    fun withSections(v: ReadingShelves, s: ReadingSections) = if (kind == ReadingKind.BOOK) v.copy(books = s) else v.copy(manga = s)
    fun live(item: ReadingItem) = active.firstOrNull { it.kind == kind.path && it.itemId == item.id }
    fun patch(item: ReadingItem, state: ReadingState? = null, progress: Int? = null) = shelves.mutate { v ->
        val s = sectionsOf(v); val t = s.take(item.id) ?: return@mutate v
        val moved = t.second.copy(state = state?.key ?: t.second.state, progress = progress ?: t.second.progress)
        withSections(v, t.first.put(moved, state ?: t.third.first, if (state == null) t.third.second else 0))
    }

    fun increment(item: ReadingItem) = scope.launch {
        val next = item.incrementedProgress(kind); val total = item.total(kind)
        if (total != null && next >= total) { target = ProgressTarget(item, kind, live(item)); return@launch }
        haptic.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick)
        patch(item, progress = next)
        runCatching { session.client?.send("${kind.path}/${item.id}/state", body("progress" to next)) }.onFailure { snackbar.showSnackbar(it.friendly) }
    }

    fun move(item: ReadingItem, state: ReadingState) = scope.launch {
        patch(item, state)
        runCatching { session.client?.send("${kind.path}/${item.id}/state", body("state" to state.key)) }.onFailure { snackbar.showSnackbar(it.friendly) }
        session.noteReading()
    }

    fun remove(item: ReadingItem) = scope.launch {
        val k = kind
        var spot: Pair<ReadingState, Int>? = null
        shelves.mutate { v -> val t = sectionsOf(v).take(item.id); spot = t?.third; if (t == null) v else withSections(v, t.first) }
        runCatching { session.client?.send("${k.path}/${item.id}/state", body("state" to "none")) }
        if (snackbar.showSnackbar("Removed ${item.displayTitle}", "Undo", duration = SnackbarDuration.Short) == SnackbarResult.ActionPerformed) {
            shelves.mutate { v -> withSections(v, sectionsOf(v).put(item, spot?.first ?: item.readingState ?: ReadingState.WANT, spot?.second ?: 0)) }
            val restore = body("state" to (item.readingState?.key ?: spot?.first?.key ?: "want"), "progress" to item.progress, "rating" to item.ratingValue,
                "mode" to item.mode, "started_at" to item.startedAt, "finished_at" to item.finishedAt)
            runCatching { session.client?.send("${k.path}/${item.id}/restore", restore) }
                .onFailure { runCatching { session.client?.send("${k.path}/${item.id}/state", body("state" to (item.readingState?.key ?: "want"))) } }
        }
    }

    fun addBook(r: BookSearchResult, s: ReadingState) = scope.launch {
        runCatching { session.client?.send("books/add", bookAddBody(r, s)) }.onFailure { snackbar.showSnackbar(it.friendly) }
        addQuery = ""; shelves.refresh()
    }
    fun addManga(r: MangaSearchResult, s: ReadingState) = scope.launch {
        runCatching { session.client?.send("manga/add", body("id" to r.id, "state" to s.key)) }.onFailure { snackbar.showSnackbar(it.friendly) }
        addQuery = ""; shelves.refresh()
    }

    PullToRefreshBox(shelves.refreshing, { shelves.refresh(); scope.launch { loadActive() } }, Modifier.fillMaxSize()) {
        LazyVerticalGrid(GridCells.Adaptive(104.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, bottom = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (session.tracksBooks && session.tracksManga) Segmented(listOf("Books", "Manga"), if (kind == ReadingKind.BOOK) 0 else 1, Modifier.weight(1f)) { kind = if (it == 0) ReadingKind.BOOK else ReadingKind.MANGA }
                        else Box(Modifier.weight(1f))
                        ChipButton("Stats", Icons.AutoMirrored.Filled.ShowChart) { nav.push(ReadingStatsRoute) }
                    }
                    active.forEach { s -> LiveStrip(s) { target = sectionsOf(shelves.value ?: ReadingShelves()).all.firstOrNull { it.id == s.itemId }?.let { ProgressTarget(it, s.readingKind, s) } ?: ProgressTarget(s, null) } }
                    FilterField(addQuery, { addQuery = it }, if (kind == ReadingKind.BOOK) "Add a book — search Hardcover" else "Add manga · manhwa · manhua", icon = Icons.Filled.Search)
                    if (kind == ReadingKind.BOOK && addQuery.isEmpty() && session.bookRequestConfig?.isEnabled == true)
                        NavRow(Icons.Outlined.MoveToInbox, "Request a book for Calibre") { nav.push(BookRequestsRoute()) }
                }
            }
            if (addQuery.isNotEmpty()) {
                item(span = { GridItemSpan(maxLineSpan) }) { Eyebrow("Results") }
                if (kind == ReadingKind.BOOK) items(books, key = { "b${it.hcId}" }) { r ->
                    AddableTile(r.cover, r.displayTitle, listOfNotNull(r.author, r.year?.toString()).joinToString(" · "), r.communityRating, { nav.push(BookRoute(r.hcId, preview = true)) }) { addBook(r, it) }
                } else items(manga, key = { "m${it.id}" }) { r ->
                    AddableTile(r.cover, r.displayTitle, listOfNotNull(r.origin, r.year?.toString()).joinToString(" · "), r.score, { nav.push(MangaRoute(r.id)) }) { addManga(r, it) }
                }
            }
            val v = shelves.value
            if (v != null) {
                val s = sectionsOf(v)
                ReadingState.shelfOrder.forEach { st ->
                    val items = s.items(st).filter { query.isEmpty() || it.displayTitle.contains(query, true) || (it.author?.contains(query, true) ?: false) }
                    if (items.isNotEmpty()) {
                        item(span = { GridItemSpan(maxLineSpan) }, key = "h-${st.key}") {
                            Eyebrow("${when (st) { ReadingState.READING -> "Reading now"; ReadingState.WANT -> "Want to read"; ReadingState.PAUSED -> "Paused"; ReadingState.FINISHED -> "Finished"; ReadingState.DNF -> "Didn’t finish" }} · ${items.size}")
                        }
                        items(items, key = { "${kind.path}-${it.id}" }) { item ->
                            ReadingTile(item, kind, st, live(item) != null, onIncrement = { increment(item) }, onLog = { target = ProgressTarget(item, kind, live(item)) },
                                onMove = { move(item, it) }, onRemove = { remove(item) })
                        }
                    }
                }
                if (s.all.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyLine("Nothing on the shelf yet — search above to add your first ${if (kind == ReadingKind.BOOK) "book" else "series"}.") }
            } else items(6) { Skeleton(height = 160.dp) }
            item(span = { GridItemSpan(maxLineSpan) }) { StaleFooter(shelves.stale && v != null && !shelves.loading) }
        }
    }
    target?.let { t ->
        ReadingProgressSheet(t, onDismiss = { target = null }) { o ->
            val item = sectionsOf(shelves.value ?: ReadingShelves()).all.firstOrNull { it.id == t.itemId }
            if (item != null) when (o) {
                is ProgressOutcome.Progress -> patch(item, progress = o.value)
                is ProgressOutcome.SessionEnded -> patch(item, progress = maxOf(o.value, item.progress ?: 0))
                is ProgressOutcome.Finished -> patch(item, ReadingState.FINISHED, o.value)
                ProgressOutcome.Discarded -> Unit
            }
            loadActive()
        }
    }
}

@Composable
fun LiveStrip(s: ActiveSession, onEnd: () -> Unit) {
    var now by remember { mutableLongStateOf(0L) }
    LaunchedEffect(Unit) { while (true) { delay(1000); now++ } }
    val secs = MQTime.dateTime(s.startedAt)?.let { java.time.Duration.between(it, java.time.LocalDateTime.now()).seconds } ?: 0
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(C.brassSoft).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(C.brassFill))
        Text(s.title ?: "Reading", style = T.body(14f, 700), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
        Text(formatTimer(maxOf(0, secs) + 0 * now), style = T.numeric, color = C.brass)
        ChipButton("End", on = true, onClick = onEnd)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ReadingTile(item: ReadingItem, kind: ReadingKind, section: ReadingState, isLive: Boolean, onIncrement: () -> Unit, onLog: () -> Unit, onMove: (ReadingState) -> Unit, onRemove: () -> Unit) {
    val nav = LocalNav.current
    var menu by remember { mutableStateOf(false) }
    Box {
        Column(Modifier.clip(RoundedCornerShape(8.dp)).combinedClickable(onClick = { nav.push(if (kind == ReadingKind.BOOK) BookRoute(item.id) else MangaRoute(item.id)) }, onLongClick = { menu = true }),
            verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Box {
                Poster(item.cover, Modifier.fillMaxWidth())
                if (isLive) OnArtBadge("Live", Modifier.align(Alignment.TopStart).padding(6.dp), dot = true)
                if (item.newChapters > 0) OnArtBadge("+${item.newChapters}", Modifier.align(Alignment.TopEnd).padding(6.dp))
                item.rating?.takeIf { section == ReadingState.FINISHED }?.let { OnArtBadge("★ $it", Modifier.align(Alignment.TopEnd).padding(6.dp)) }
                if (section == ReadingState.READING) Box(Modifier.align(Alignment.BottomEnd).padding(6.dp).size(34.dp).clip(CircleShape).background(C.brassFill)
                    .clickable { if (item.supportsIncrement(kind) && !isLive) onIncrement() else onLog() }, contentAlignment = Alignment.Center) {
                    Icon(if (item.supportsIncrement(kind) && !isLive) Icons.Filled.Add else Icons.Filled.Tune, if (item.supportsIncrement(kind)) "One more chapter" else "Log progress", tint = C.brassOnFill, modifier = Modifier.size(18.dp))
                }
            }
            Text(item.displayTitle, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (section == ReadingState.READING) {
                Text(item.progressLabel(kind), style = T.caption, color = C.brassBright, maxLines = 1)
                if (item.total(kind) != null) ProgressBar(item.fraction(kind), height = 4.dp)
            } else Text(listOfNotNull(if (kind == ReadingKind.BOOK) item.author else item.origin, item.year?.toString()).joinToString(" · "), style = T.caption, color = C.inkMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) {
            DropdownMenuItem({ Text("Log progress…") }, { menu = false; onLog() }, leadingIcon = { Icon(Icons.Filled.Tune, null) })
            ReadingState.entries.filter { it != section && it != ReadingState.FINISHED }.forEach { st ->
                DropdownMenuItem({ Text("Move to ${st.label}") }, { menu = false; onMove(st) }, leadingIcon = { Icon(Icons.Filled.MoveDown, null) })
            }
            DropdownMenuItem({ Text("Remove", color = C.velvet) }, { menu = false; onRemove() }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = C.velvet) })
        }
    }
}

/** A search result that adds straight to Want to read (or Reading). */
@Composable
fun AddableTile(cover: String?, title: String, subtitle: String, score: Double?, onOpen: () -> Unit, onAdd: (ReadingState) -> Unit) {
    var menu by remember { mutableStateOf(false) }
    var added by remember { mutableStateOf(false) }
    Column(Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onOpen), verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Box {
            Poster(cover, Modifier.fillMaxWidth())
            score?.takeIf { it > 0 }?.let { OnArtBadge(LibraryFormat.one(it), Modifier.align(Alignment.TopEnd).padding(6.dp), icon = Icons.Filled.Star) }
            Box(Modifier.align(Alignment.BottomEnd).padding(6.dp)) {
                Box(Modifier.size(34.dp).clip(CircleShape).background(if (added) C.panelRaised else C.brassFill).clickable(enabled = !added) { menu = true }, contentAlignment = Alignment.Center) {
                    Icon(if (added) Icons.Filled.ChevronRight else Icons.Filled.Add, "Add $title", tint = if (added) C.brass else C.brassOnFill, modifier = Modifier.size(18.dp))
                }
                DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) {
                    listOf(ReadingState.WANT, ReadingState.READING, ReadingState.FINISHED).forEach { st ->
                        DropdownMenuItem({ Text(st.label) }, { menu = false; added = true; onAdd(st) })
                    }
                }
            }
        }
        Text(title, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(subtitle, style = T.caption, color = C.inkMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}
