package dev.kadenthompson.marquee.features.library

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyGridScope
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.StopCircle
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.BookmarkAdd
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.FilterPill
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.SectionHeader
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.StaleFooter
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.EmptyLine
import dev.kadenthompson.marquee.features.common.HouseholdSummary
import dev.kadenthompson.marquee.features.common.OnArtBadge
import dev.kadenthompson.marquee.features.common.ProgressBar
import dev.kadenthompson.marquee.features.reading.ReadingShelf
import dev.kadenthompson.marquee.features.requests.SheetTitle
import dev.kadenthompson.marquee.model.MarkResponse
import dev.kadenthompson.marquee.model.MovieCard
import dev.kadenthompson.marquee.model.MovieShelves
import dev.kadenthompson.marquee.model.ShowCard
import dev.kadenthompson.marquee.model.ShowShelves
import dev.kadenthompson.marquee.nav.LibraryHome
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MovieRoute
import dev.kadenthompson.marquee.nav.ShowRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.launch

/** Shows, Films and (when switched on) Reading, under one Library with a shared filter. */
@Composable
fun LibraryScreen(r: LibraryHome) {
    val session = LocalSession.current
    val sections = if (session.tracksReading) listOf("Shows", "Films", "Reading") else listOf("Shows", "Films")
    var section by rememberSaveable { mutableStateOf(when (r.section) { "films" -> 1; "reading" -> 2; else -> 0 }) }
    if (section >= sections.size) section = 0
    var query by rememberSaveable { mutableStateOf("") }
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Text("Library", style = T.title, color = C.ink, modifier = Modifier.padding(horizontal = MQ.gutter).padding(top = 12.dp, bottom = 10.dp))
        FilterField(query, { query = it }, "Filter your library", Modifier.padding(horizontal = MQ.gutter))
        Spacer(Modifier.height(10.dp))
        if (sections.size > 1) Segmented(sections, section, Modifier.padding(horizontal = MQ.gutter)) { section = it }
        Spacer(Modifier.height(10.dp))
        when (section) {
            1 -> FilmsShelf(query.trim())
            2 -> ReadingShelf(query.trim())
            else -> ShowsShelf(query.trim(), r.shelf)
        }
    }
}

@Composable
fun FilterField(value: String, onChange: (String) -> Unit, placeholder: String, modifier: Modifier = Modifier, icon: androidx.compose.ui.graphics.vector.ImageVector = Icons.Filled.FilterList) {
    Row(modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(C.panel).border(1.dp, C.hairline, RoundedCornerShape(11.dp)).padding(horizontal = 12.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(icon, null, tint = C.inkMuted, modifier = Modifier.size(18.dp))
        Box(Modifier.weight(1f)) {
            if (value.isEmpty()) Text(placeholder, style = T.body, color = C.inkMuted)
            BasicTextField(value, onChange, singleLine = true, textStyle = T.body.copy(color = C.ink), cursorBrush = SolidColor(C.brass), modifier = Modifier.fillMaxWidth())
        }
        if (value.isNotEmpty()) Icon(Icons.Filled.Cancel, "Clear", tint = C.inkMuted, modifier = Modifier.size(18.dp).clickable { onChange("") })
    }
}

// ================= Shows

enum class ShowShelf(val key: String, val title: String, val empty: String) {
    WATCHLIST("watchlist", "Watchlist", "Your watchlist is empty — add shows from Search and they wait here until you start one."),
    WATCHING("watching", "Watching", "Nothing in progress. Start something from your watchlist."),
    CAUGHT_UP("caught_up", "Caught up", "No show is waiting on new episodes."),
    FINISHED("finished", "Finished", "No finished series yet."),
    STOPPED("stopped", "Stopped", "You haven't stopped watching anything.");
}

fun ShowShelves.cards(s: ShowShelf) = when (s) { ShowShelf.WATCHLIST -> watchlist; ShowShelf.WATCHING -> watching; ShowShelf.CAUGHT_UP -> caughtUp; ShowShelf.FINISHED -> finished; ShowShelf.STOPPED -> stopped }
fun ShowShelves.with(s: ShowShelf, l: List<ShowCard>) = when (s) {
    ShowShelf.WATCHLIST -> copy(watchlist = l); ShowShelf.WATCHING -> copy(watching = l); ShowShelf.CAUGHT_UP -> copy(caughtUp = l)
    ShowShelf.FINISHED -> copy(finished = l); ShowShelf.STOPPED -> copy(stopped = l)
}
fun ShowShelves.take(id: Int): Triple<ShowShelves, ShowCard, Pair<ShowShelf, Int>>? {
    for (s in ShowShelf.entries) { val l = cards(s); val i = l.indexOfFirst { it.id == id }; if (i >= 0) return Triple(with(s, l.filterIndexed { j, _ -> j != i }), l[i], s to i) }
    return null
}
fun ShowShelves.put(c: ShowCard, s: ShowShelf, i: Int = 0) = with(s, cards(s).toMutableList().apply { add(i.coerceIn(0, size), c) })

private fun home(c: ShowCard) = when {
    c.watched == 0 -> ShowShelf.WATCHLIST
    c.remaining > 0 -> ShowShelf.WATCHING
    c.isEnded -> ShowShelf.FINISHED
    else -> ShowShelf.CAUGHT_UP
}

@Composable
fun ShowsShelf(query: String, initial: String? = null) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val haptic = LocalHapticFeedback.current
    val data = rememberRemote<ShowShelves>("shows-library", true, session.watchRevision) { it.get("shows") }
    var shelf by remember { mutableStateOf(ShowShelf.entries.firstOrNull { it.key == (initial ?: session.prefs.string("library.showShelf", "watchlist")) } ?: ShowShelf.WATCHLIST) }
    var dealing by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf<ShowCard?>(null) }

    fun choose(s: ShowShelf) { shelf = s; session.prefs.putString("library.showShelf", s.key); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }

    fun start(c: ShowCard) = scope.launch {
        val ep = c.nextEp ?: return@launch
        val cl = session.client ?: return@launch
        try {
            val r: MarkResponse = cl.post("show/${c.id}/watch", body("season" to ep.season, "number" to ep.number))
            haptic.performHapticFeedback(HapticFeedbackType.Confirm)
            r.show?.let { s -> data.mutate { v -> val t = v.take(c.id); if (t == null) v else t.first.put(c.merged(s), home(c.merged(s)), 0) } }
            session.enqueue(r.celebrate); session.noteWatched()
            snackbar.showSnackbar("Punched ${ep.code} · ${c.displayTitle}", duration = SnackbarDuration.Short)
        } catch (e: Exception) { snackbar.showSnackbar(e.friendly) }
    }

    fun setArchived(c: ShowCard, archived: Boolean) = scope.launch {
        data.mutate { v -> v.take(c.id)?.first?.put(c, if (archived) ShowShelf.STOPPED else home(c)) ?: v }
        runCatching { session.client?.send("show/${c.id}/follow", body("archived" to archived)) }
        if (archived && snackbar.showSnackbar("Stopped watching ${c.displayTitle}", "Undo", duration = SnackbarDuration.Short) == SnackbarResult.ActionPerformed) {
            data.mutate { v -> v.take(c.id)?.first?.put(c, home(c)) ?: v }
            runCatching { session.client?.send("show/${c.id}/follow", body("archived" to false)) }
        }
    }

    fun remove(c: ShowCard) = scope.launch {
        var spot: Pair<ShowShelf, Int>? = null
        data.mutate { v -> v.take(c.id)?.let { spot = it.third; it.first } ?: v }
        runCatching { session.client?.send("show/${c.id}/follow", body("unfollow" to true)) }
        session.noteWatched()
        // Removing a show you never started happens at once, with Undo.
        if (c.watched == 0 && snackbar.showSnackbar("Removed ${c.displayTitle}", "Undo", duration = SnackbarDuration.Short) == SnackbarResult.ActionPerformed) {
            data.mutate { v -> v.put(c, spot?.first ?: ShowShelf.WATCHLIST, spot?.second ?: 0) }
            runCatching { session.client?.send("show/${c.id}/follow", body("added_at" to c.addedAt)) }
        }
    }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = MQ.gutter), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            ShowShelf.entries.forEach { s -> FilterPill(s.title, shelf == s, data.value?.cards(s)?.size) { choose(s) } }
        }
        Spacer(Modifier.height(8.dp))
        PullToRefreshBox(data.refreshing, { data.refresh() }, Modifier.fillMaxSize()) {
            val v = data.value
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                if (v != null) {
                    val cards = v.cards(shelf).filter { query.isEmpty() || it.displayTitle.contains(query, true) }
                    if (shelf == ShowShelf.WATCHLIST) {
                        val pool = v.watchlist.filter { it.watchlistGroup == ShowCard.WatchlistGroup.BINGE }
                        if (query.isEmpty() && pool.isNotEmpty()) item("deal") {
                            Row(Modifier.fillMaxWidth().mqPanel().clickable { dealing = true }.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(Icons.Filled.Casino, null, tint = C.brass, modifier = Modifier.size(24.dp))
                                Column(Modifier.weight(1f)) { Text("Can’t decide?", style = T.body(15f, 700), color = C.ink); Text("Deal three from what you could start tonight", style = T.caption, color = C.inkSoft) }
                                Icon(Icons.Filled.ChevronRight, null, tint = C.inkMuted)
                            }
                        }
                        ShowCard.WatchlistGroup.entries.forEach { g ->
                            val members = cards.filter { it.watchlistGroup == g }
                            if (members.isNotEmpty()) {
                                item("h-${g.name}") {
                                    SectionHeader(g.title, count = listOfNotNull("${members.size}", LibraryFormat.hours(members.sumOf { it.totalMin ?: 0.0 })).joinToString(" · "))
                                }
                                items(members, key = { "s-${it.id}" }) { c -> ShowShelfRow(c, shelf, { nav.push(ShowRoute(c.id)) }, { start(c) }, { setArchived(c, it) }, { if (c.watched == 0) remove(c) else confirmRemove = c }) }
                            }
                        }
                    } else items(cards, key = { "s-${it.id}" }) { c -> ShowShelfRow(c, shelf, { nav.push(ShowRoute(c.id)) }, { start(c) }, { setArchived(c, it) }, { if (c.watched == 0) remove(c) else confirmRemove = c }) }
                    if (cards.isEmpty()) item { EmptyLine(if (query.isEmpty()) shelf.empty else "No show on this shelf matches “$query”.") }
                } else if (data.error != null) item { ErrorState(data.error!!) { data.refresh() } }
                else items(6) { Skeleton(height = 92.dp) }
                item { StaleFooter(data.stale && v != null && !data.loading) }
            }
        }
    }
    if (dealing) DealSheet(data.value?.watchlist?.filter { it.watchlistGroup == ShowCard.WatchlistGroup.BINGE } ?: emptyList(), onDismiss = { dealing = false }) { id -> dealing = false; nav.push(ShowRoute(id)) }
    confirmRemove?.let { c ->
        AlertDialog(onDismissRequest = { confirmRemove = null }, containerColor = C.panelRaised,
            title = { Text("Remove ${c.displayTitle}?", style = T.headline, color = C.ink) },
            text = { Text("This removes the show and every episode you've marked watched. It can't be undone.", style = T.body, color = C.inkSoft) },
            confirmButton = { TextButton({ confirmRemove = null; remove(c) }) { Text("Remove and delete watch history", color = C.velvet) } },
            dismissButton = { TextButton({ confirmRemove = null }) { Text("Cancel", color = C.brass) } })
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ShowShelfRow(c: ShowCard, shelf: ShowShelf, onOpen: () -> Unit, onStart: () -> Unit, onArchive: (Boolean) -> Unit, onRemove: () -> Unit) {
    var menu by remember { mutableStateOf(false) }
    val meta = when {
        shelf == ShowShelf.WATCHING -> c.nextEp?.let { listOfNotNull("${it.code} next", "${c.remaining} left", LibraryFormat.hours(c.leftMin)).joinToString(" · ") } ?: "${c.watched} / ${c.aired} watched"
        c.aired == 0 -> c.nEpisodes?.takeIf { it > 0 }?.let { "$it episodes announced" } ?: c.network ?: "Not out yet"
        else -> listOfNotNull(c.seasons?.takeIf { it > 0 }?.let { "$it season${if (it == 1) "" else "s"}" }, "${c.aired} ep${if (c.aired == 1) "" else "s"}",
            if (shelf != ShowShelf.WATCHLIST && c.watched in 1 until c.aired) "${c.watched} watched" else null, LibraryFormat.hours(c.totalMin)).joinToString(" · ")
    }
    val whenLine = c.nextAir?.takeIf { it.isNotEmpty() }?.let { n ->
        if (c.aired == 0) "Premieres ${MQTime.upcomingLabel(n)}" else if (shelf == ShowShelf.STOPPED || shelf == ShowShelf.FINISHED) null else "New episode ${MQTime.upcomingLabel(n)}"
    }
    Box {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).combinedClickable(onClick = onOpen, onLongClick = { menu = true }), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Poster(c.poster, Modifier.width(62.dp).alpha(if (shelf == ShowShelf.STOPPED) 0.7f else 1f), radius = 8.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(c.displayTitle, style = T.body(15.5f, 700), color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (c.stale == true && shelf == ShowShelf.WATCHING) Text("PAUSED", style = T.body(9f, 700), color = C.inkMuted, modifier = Modifier.border(1.dp, C.hairlineBold, RoundedCornerShape(4.dp)).padding(horizontal = 5.dp, vertical = 2.dp))
                }
                Text(meta, style = T.caption, color = C.inkSoft, maxLines = 2)
                if (shelf == ShowShelf.WATCHING && c.aired > 0) ProgressBar(c.progress, Modifier.widthIn(max = 200.dp), height = 4.dp)
                whenLine?.let { Text(it, style = T.caption, color = C.brass) }
                val prov = listOfNotNull(c.prov?.name ?: c.network, (c.imdb ?: c.vote)?.takeIf { it > 0 }?.let { "${if (c.imdb != null) "IMDb" else "★"} ${LibraryFormat.one(it)}" }).joinToString(" · ")
                if (prov.isNotEmpty()) Text(prov, style = T.caption, color = C.inkMuted, maxLines = 1)
                HouseholdSummary.show(c)?.let { (text, people) ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy((-6).dp)) { people.take(3).forEach { Avatar(it, 18.dp) } }
                        Text(text, style = T.caption, color = C.inkSoft, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
            val ep = c.nextEp
            if (ep != null && (shelf == ShowShelf.WATCHLIST || shelf == ShowShelf.WATCHING)) {
                Column(Modifier.size(64.dp, 60.dp).clip(RoundedCornerShape(14.dp)).background(C.brassFill).clickable(onClick = onStart), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    Icon(if (c.watched == 0) Icons.Filled.PlayArrow else Icons.Filled.Check, if (c.watched == 0) "Start ${c.displayTitle}" else "Mark ${ep.code} watched", tint = C.brassOnFill)
                    Text(if (c.watched == 0) "Start" else "S${ep.season} E${ep.number}", style = T.body(11.5f, 700), color = C.brassOnFill, maxLines = 1)
                }
            } else if (c.aired == 0 && !c.nextAir.isNullOrEmpty()) {
                Column(Modifier.size(64.dp, 60.dp).border(1.dp, C.hairline, RoundedCornerShape(14.dp)), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    Icon(Icons.Filled.NotificationsNone, null, tint = C.inkSoft); Text(MQTime.short(c.nextAir), style = T.body(11f, 700), color = C.inkSoft)
                }
            }
        }
        DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) {
            c.nextEp?.takeIf { shelf != ShowShelf.STOPPED }?.let { ep -> DropdownMenuItem({ Text(if (c.watched == 0) "Start — mark ${ep.code} watched" else "Mark ${ep.code} watched") }, { menu = false; onStart() }, leadingIcon = { Icon(Icons.Filled.Check, null) }) }
            if (shelf == ShowShelf.WATCHING || shelf == ShowShelf.CAUGHT_UP) DropdownMenuItem({ Text("Stop watching") }, { menu = false; onArchive(true) }, leadingIcon = { Icon(Icons.Filled.StopCircle, null) })
            if (shelf == ShowShelf.STOPPED) DropdownMenuItem({ Text("Resume watching") }, { menu = false; onArchive(false) }, leadingIcon = { Icon(Icons.Filled.PlayCircle, null) })
            DropdownMenuItem({ Text(if (c.watched == 0) "Remove from watchlist" else "Remove and delete watch history", color = C.velvet) }, { menu = false; onRemove() }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = C.velvet) })
        }
    }
}

/** Three random Ready-to-binge shows; deal again with a haptic, tap one to open it. */
@Composable
private fun DealSheet(pool: List<ShowCard>, onDismiss: () -> Unit, onPick: (Int) -> Unit) {
    val haptic = LocalHapticFeedback.current
    var hand by remember { mutableStateOf(pool.shuffled().take(3)) }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Text("TONIGHT, MAYBE…", style = T.wordmark(24f), color = C.brass)
            Row(Modifier.widthIn(max = 460.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                hand.forEach { c ->
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(8.dp)).clickable { onPick(c.id) }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Poster(c.poster, Modifier.fillMaxWidth())
                        Text(c.displayTitle, style = T.tile, color = C.ink, maxLines = 2)
                        Text(LibraryFormat.hours(c.totalMin) ?: "${c.aired} eps", style = T.caption, color = C.inkMuted)
                        c.prov?.name?.let { Text(it, style = T.caption, color = C.brass) }
                    }
                }
            }
            ChipButton("Deal again", Icons.Filled.Casino, enabled = pool.size > hand.size) { hand = pool.shuffled().take(3); haptic.performHapticFeedback(HapticFeedbackType.ContextClick) }
        }
    }
}

/** "All" from Home's watchlist rail: the Shows shelf on its own page. */
@Composable
fun ShowsWatchlistScreen() {
    val nav = LocalNav.current
    ScreenScaffold("Your shows", { nav.popBackStack() }) { pad -> Box(Modifier.padding(top = pad.calculateTopPadding())) { ShowsShelf("", "watchlist") } }
}

// ================= Films

@Composable
fun FilmsShelf(query: String) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val data = rememberRemote<MovieShelves>("movies", true) { it.get("movies") }
    var tab by rememberSaveable { mutableStateOf(0) }
    val today = remember { MQTime.today() }

    fun update(f: MovieCard, action: String) = scope.launch {
        val wasWatched = data.value?.watched?.any { it.id == f.id } == true
        val idx = (if (wasWatched) data.value?.watched else data.value?.watchlist)?.indexOfFirst { it.id == f.id } ?: 0
        data.mutate { s ->
            val w = s.watched.filterNot { it.id == f.id }; val l = s.watchlist.filterNot { it.id == f.id }
            when (action) {
                "watched" -> s.copy(watched = listOf(f.copy(state = "watched", watchedAt = f.watchedAt ?: MQTime.stamp())) + w, watchlist = l)
                "watchlist" -> s.copy(watched = w, watchlist = listOf(f.copy(state = "watchlist")) + l)
                else -> s.copy(watched = w, watchlist = l)
            }
        }
        runCatching { session.client?.send("movie/${f.id}/state", body("state" to action)) }.onFailure { snackbar.showSnackbar(it.friendly) }
        if (action == "none" && snackbar.showSnackbar("Removed ${f.displayTitle}", "Undo", duration = SnackbarDuration.Short) == SnackbarResult.ActionPerformed) {
            data.mutate { s -> if (wasWatched) s.copy(watched = s.watched.toMutableList().apply { add(idx.coerceIn(0, size), f) }) else s.copy(watchlist = s.watchlist.toMutableList().apply { add(idx.coerceIn(0, size), f) }) }
            runCatching { session.client?.send("movie/${f.id}/state", body("state" to (f.state ?: if (wasWatched) "watched" else "watchlist"), "rating" to f.rating, "watched_at" to f.watchedAt, "added_at" to f.addedAt)) }
        }
    }

    val v = data.value
    val shelf = (if (tab == 1) v?.watched else v?.watchlist)?.filter { query.isEmpty() || it.displayTitle.contains(query, true) } ?: emptyList()
    PullToRefreshBox(data.refreshing, { data.refresh() }, Modifier.fillMaxSize()) {
        LazyVerticalGrid(GridCells.Adaptive(104.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, bottom = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item(span = { GridItemSpan(maxLineSpan) }) {
                Segmented(listOf("Watchlist · ${v?.watchlist?.size ?: 0}", "Watched · ${v?.watched?.size ?: 0}"), tab) { tab = it }
            }
            if (v == null) items(12) { Skeleton(height = 160.dp) }
            else if (shelf.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyLine(if (query.isEmpty()) "Nothing here yet — find something in Search." else "No film on this shelf matches “$query”.") }
            else if (tab == 0) {
                val out = shelf.filter { !it.isUpcoming(today) }
                val soon = shelf.filter { it.isUpcoming(today) }.sortedBy { it.releaseDate ?: "" }
                filmGroup("Out now", out, tab, ::update)
                filmGroup("Coming soon", soon, tab, ::update)
            } else items(shelf, key = { it.id }) { FilmTile(it, tab) { a -> update(it, a) } }
        }
    }
}

private fun LazyGridScope.filmGroup(title: String, films: List<MovieCard>, tab: Int, update: (MovieCard, String) -> Unit) {
    if (films.isEmpty()) return
    item(span = { GridItemSpan(maxLineSpan) }, key = "h-$title") { SectionHeader(title, count = "${films.size}") }
    items(films, key = { it.id }) { FilmTile(it, tab) { a -> update(it, a) } }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun FilmTile(f: MovieCard, tab: Int, perform: (String) -> Unit) {
    val nav = LocalNav.current
    var menu by remember { mutableStateOf(false) }
    Box {
        Column(Modifier.clip(RoundedCornerShape(8.dp)).combinedClickable(onClick = { nav.push(MovieRoute(f.id)) }, onLongClick = { menu = true }), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Box {
                Poster(f.poster, Modifier.fillMaxWidth())
                f.rating?.takeIf { tab == 1 }?.let { OnArtBadge("★ $it", Modifier.align(Alignment.TopEnd).padding(6.dp)) }
                HouseholdSummary.film(f)?.let { (_, people) ->
                    Row(Modifier.align(Alignment.BottomStart).padding(5.dp), horizontalArrangement = Arrangement.spacedBy((-6).dp)) { people.take(3).forEach { Avatar(it, 20.dp, Modifier.border(1.5.dp, C.ground, CircleShape)) } }
                }
            }
            Text(f.displayTitle, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
            val sub = if (tab == 1) listOfNotNull(f.year?.toString(), f.watchedAt?.let { MQTime.short(it) }).joinToString(" · ")
            else if (f.isUpcoming(MQTime.today())) "Out ${MQTime.medium(f.releaseDate)}"
            else listOfNotNull(LibraryFormat.runtime(f.runtime), f.cert, f.prov?.name).joinToString(" · ")
            Text(sub, style = T.caption, color = C.inkMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) {
            HouseholdSummary.film(f)?.let { (text, _) -> DropdownMenuItem({ Text(text, color = C.inkMuted) }, {}, enabled = false) }
            if (tab == 0) DropdownMenuItem({ Text("Mark watched") }, { menu = false; perform("watched") }, leadingIcon = { Icon(Icons.Filled.Visibility, null) })
            else DropdownMenuItem({ Text("Move to watchlist") }, { menu = false; perform("watchlist") }, leadingIcon = { Icon(Icons.Filled.BookmarkAdd, null) })
            DropdownMenuItem({ Text("Remove", color = C.velvet) }, { menu = false; perform("none") }, leadingIcon = { Icon(Icons.Filled.Delete, null, tint = C.velvet) })
        }
    }
}
