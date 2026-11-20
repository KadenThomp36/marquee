package dev.kadenthompson.marquee.features.show

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.EditNote
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.StopCircle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
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
import dev.kadenthompson.marquee.design.ExpandableText
import dev.kadenthompson.marquee.design.FoldSpread
import dev.kadenthompson.marquee.design.LoadingList
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.MetaChip
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.RatingChip
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.StaleFooter
import dev.kadenthompson.marquee.design.StarRating
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.ProgressBar
import dev.kadenthompson.marquee.features.detail.AddToListChip
import dev.kadenthompson.marquee.features.detail.ArtworkGallery
import dev.kadenthompson.marquee.features.detail.BackdropWash
import dev.kadenthompson.marquee.features.detail.FavoriteChip
import dev.kadenthompson.marquee.features.detail.LinkChip
import dev.kadenthompson.marquee.features.detail.RatingsPanel
import dev.kadenthompson.marquee.features.detail.ReviewsSection
import dev.kadenthompson.marquee.features.detail.ShareChip
import dev.kadenthompson.marquee.features.detail.WhereToWatch
import dev.kadenthompson.marquee.features.detail.mqFieldColors
import dev.kadenthompson.marquee.features.requests.RequestButton
import dev.kadenthompson.marquee.features.requests.RequestStatusPill
import dev.kadenthompson.marquee.features.requests.SeasonRequestSheet
import dev.kadenthompson.marquee.features.requests.icon
import dev.kadenthompson.marquee.features.requests.pillLabel
import dev.kadenthompson.marquee.features.requests.tone
import dev.kadenthompson.marquee.model.EpisodeRow
import dev.kadenthompson.marquee.model.MarkResponse
import dev.kadenthompson.marquee.model.RequestState
import dev.kadenthompson.marquee.model.RequestStatus
import dev.kadenthompson.marquee.model.SeasonBlock
import dev.kadenthompson.marquee.model.SeasonRequestState
import dev.kadenthompson.marquee.model.ShowDetail
import dev.kadenthompson.marquee.model.ShowRatings
import dev.kadenthompson.marquee.model.WatchProviders
import dev.kadenthompson.marquee.nav.EpisodeRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.PersonRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.JsonNullValue
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset

@Composable
fun ShowScreen(showId: Int) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val today = remember { MQTime.today() }
    val data = rememberRemote<ShowDetail>("show-$showId", true) { it.get("show/$showId") }
    var ratings by remember { mutableStateOf<ShowRatings?>(null) }
    var providers by remember { mutableStateOf<WatchProviders?>(null) }
    var request by remember { mutableStateOf<RequestStatus?>(null) }
    var openSeason by remember { mutableStateOf<Int?>(null) }
    var gallery by remember { mutableStateOf(false) }
    var requestSheet by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf(false) }
    var episodeEditor by remember { mutableStateOf(false) }
    var ahead by remember { mutableStateOf<Pair<EpisodeRow, Int>?>(null) }
    var dateFor by remember { mutableStateOf<EpisodeRow?>(null) }

    LaunchedEffect(showId) {
        val c = session.client ?: return@LaunchedEffect
        launch { ratings = runCatching { c.get<ShowRatings>("show/$showId/ratings") }.getOrNull() }
        launch { providers = runCatching { c.get<WatchProviders>("watch_providers/show/$showId") }.getOrNull() }
        launch {
            session.loadRequestConfig()
            if (session.requestConfig?.enabled != true) return@launch
            request = runCatching { c.get<RequestStatus>("request/status/show/$showId") }.getOrNull()
            // Live progress while something is in flight.
            while (request?.isBusy == true) { delay(8000); request = runCatching { c.get<RequestStatus>("request/status/show/$showId") }.getOrNull() ?: request }
        }
    }

    val d = data.value?.let { it.copy(seasons = it.seasons.filter { s -> s.episodes.isNotEmpty() }) }
    val watchable = d?.seasons?.flatMap { it.episodes }?.filter { it.season > 0 && it.hasAired(today) }?.sortedWith(compareBy({ it.season }, { it.number })) ?: emptyList()
    val watchedCount = watchable.count { it.watched }
    val total = watchable.size
    val complete = total > 0 && watchedCount == total
    val nextEp = watchable.firstOrNull { !it.watched }
    LaunchedEffect(d != null) { if (d != null && openSeason == null) openSeason = nextEp?.season ?: d.seasons.lastOrNull()?.season }

    fun patch(transform: (ShowDetail) -> ShowDetail) = data.mutate(transform)
    fun markLocally(season: Int, number: Int, watched: Boolean, through: Boolean) = patch { sd ->
        sd.copy(seasons = sd.seasons.map { b -> b.copy(episodes = b.episodes.map { e ->
            val target = e.season == season && e.number == number
            val earlier = through && watched && e.season > 0 && e.hasAired(today) && (e.season < season || (e.season == season && e.number < number))
            if (target || earlier) e.copy(watched = watched, watchedAt = if (watched) e.watchedAt ?: MQTime.stamp() else null) else e
        }) })
    }

    fun mark(e: EpisodeRow, watched: Boolean, through: Boolean = false) = scope.launch {
        markLocally(e.season, e.number, watched, through)
        val c = session.client ?: return@launch
        try {
            val r: MarkResponse = c.post("show/$showId/watch", body("season" to e.season, "number" to e.number,
                "unwatch" to if (watched) null else true, "previous" to if (through) true else null))
            session.enqueue(r.celebrate); session.noteWatched()
        } catch (ex: Exception) { session.handle(ex); snackbar.showSnackbar("Couldn't save: ${ex.friendly}"); data.refresh() }
    }

    fun tick(e: EpisodeRow, watched: Boolean) {
        if (watched && e.season > 0) {
            val behind = watchable.count { !it.watched && (it.season < e.season || (it.season == e.season && it.number < e.number)) }
            if (behind > 0) { ahead = e to behind; return }
        }
        mark(e, watched)
    }

    fun markSeason(season: Int, watched: Boolean) = scope.launch {
        patch { sd -> sd.copy(seasons = sd.seasons.map { b -> if (b.season != season) b else b.copy(episodes = b.episodes.map { e ->
            if (watched && !e.hasAired(today)) e else e.copy(watched = watched, watchedAt = if (watched) e.watchedAt ?: MQTime.stamp() else null) }) }) }
        val c = session.client ?: return@launch
        try {
            val r: MarkResponse = c.post("show/$showId/season/$season/watch", body("unwatch" to if (watched) null else true))
            session.enqueue(r.celebrate); session.noteWatched()
        } catch (ex: Exception) { snackbar.showSnackbar("Couldn't save: ${ex.friendly}"); data.refresh() }
    }

    fun follow(vararg pairs: Pair<String, Any?>, after: suspend () -> Unit = {}) = scope.launch {
        val c = session.client ?: return@launch
        try { c.send("show/$showId/follow", body(*pairs)); session.noteWatched(); after() } catch (ex: Exception) { snackbar.showSnackbar(ex.friendly); data.refresh() }
    }

    ScreenScaffold(d?.displayTitle ?: "", { nav.popBackStack() }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        when {
            d != null -> Box(Modifier.fillMaxSize()) {
                BackdropWash(d.backdrop)
                FoldSpread(contentPadding = PaddingValues(top = pad.calculateTopPadding()), leading = {
                    // ---- hero
                    Column(Modifier.padding(horizontal = MQ.gutter).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            Box(Modifier.width(118.dp).clip(RoundedCornerShape(14.dp)).clickable { gallery = true }) {
                                Poster(d.poster, Modifier.fillMaxWidth(), radius = 14.dp, contentDescription = "${d.displayTitle} poster. Opens the artwork gallery.")
                                Row(Modifier.align(Alignment.BottomCenter).fillMaxWidth().background(Color.Black.copy(alpha = 0.55f)).padding(vertical = 5.dp),
                                    horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Filled.PhotoLibrary, null, tint = Color.White, modifier = Modifier.size(11.dp))
                                    Text(" ARTWORK", style = T.body(9.5f, 700), color = Color.White)
                                }
                            }
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                                Text(d.displayTitle, style = T.title, color = C.ink)
                                d.info?.tagline?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption.copy(fontStyle = FontStyle.Italic), color = C.inkMuted, maxLines = 2) }
                                ChipRow {
                                    if (d.isEnded) MetaChip("Ended" + (d.info?.lastAir?.take(4)?.let { " · $it" } ?: ""), Icons.Filled.Flag)
                                    d.info?.contentRating?.takeIf { it.isNotEmpty() }?.let { MetaChip(it) }
                                    RatingChip(d.info?.imdb, d.info?.vote)
                                    d.info?.networks?.takeIf { it.isNotEmpty() }?.let { MetaChip(it.joinToString(" · ")) }
                                    val sc = d.info?.seasonCount; val ec = d.info?.episodeCount
                                    if (sc != null && ec != null) MetaChip("$sc season${if (sc == 1) "" else "s"} · $ec eps")
                                    d.info?.origin?.takeIf { it.isNotEmpty() }?.let { MetaChip(it) }
                                }
                                Text(facts(d), style = T.caption, color = C.inkSoft)
                                if (d.isFollowed) StarRating(d.rating) { v ->
                                    patch { it.copy(rating = v) }
                                    follow("rating" to (v ?: JsonNullValue))
                                }
                            }
                        }
                        // progress
                        Column(Modifier.widthIn(max = 360.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            ProgressBar(if (total > 0) watchedCount.toFloat() / total else 0f, height = 9.dp,
                                tint = if (d.isArchived) "stopped" else if (complete && d.isEnded) "complete" else "brass")
                            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                Text("$watchedCount", style = T.body(12.5f, 600), color = C.brass)
                                Text("/ $total watched", style = T.body(12.5f, 600), color = C.inkSoft)
                                if (total - watchedCount > 0) Text("· ${total - watchedCount} to go", style = T.body(12.5f, 600), color = C.inkMuted)
                                else if (total > 0) Text("· complete ✓", style = T.body(12.5f, 600), color = C.brass)
                            }
                        }
                        // actions
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                            WatchlistControl(d, watchedCount,
                                onFollow = { patch { it.copy(followed = true) }; follow(after = { data.refresh() }) },
                                onResume = { patch { it.copy(archived = false) }; follow("archived" to false) },
                                onUnlist = { patch { it.copy(followed = false, archived = false) }; follow("unfollow" to true) },
                                onStop = { patch { it.copy(archived = true) }; follow("archived" to true) })
                            if (session.requestConfig?.enabled == true) request?.let { RequestButton(it) { requestSheet = true } }
                        }
                        ChipRow {
                            FavoriteChip("show", showId)
                            AddToListChip("show", showId, d.displayTitle)
                            ShareChip("show/$showId")
                            if (session.me?.isAdmin == true) ChipButton("Episodes", Icons.Filled.EditNote) { episodeEditor = true }
                            d.info?.imdbId?.takeIf { it.isNotEmpty() }?.let { LinkChip("IMDb", "https://www.imdb.com/title/$it/") }
                            if (d.isFollowed) ChipButton("Remove", Icons.Filled.Delete, destructive = true) { confirmRemove = true }
                        }
                    }
                    d.info?.overview?.takeIf { it.isNotEmpty() }?.let { Box(Modifier.padding(horizontal = MQ.gutter)) { ExpandableText(it) } }
                    if (watchedCount > 0 && nextEp != null) NextUpCard(nextEp, d.info?.seasonPosters?.get(nextEp.season.toString()) ?: d.poster,
                        onOpen = { nav.push(EpisodeRoute(showId, nextEp.season, nextEp.number)) }) { tick(nextEp, true) }
                    WhereToWatch(providers, request?.state == RequestState.AVAILABLE)
                    d.info?.cast?.takeIf { it.isNotEmpty() }?.let { DetailSection("Cast") { CastStrip(it) { id -> nav.push(PersonRoute(id)) } } }
                }, trailing = {
                    ratings?.takeIf { it.episodes.size >= 4 }?.let { RatingsPanel(it) }
                    Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        d.seasons.forEach { b ->
                            SeasonBlockView(b, d.info?.seasonName(b.season) ?: "Season ${b.season}", openSeason == b.season,
                                request?.seasons?.firstOrNull { it.number == b.season }, today,
                                onToggle = { openSeason = if (openSeason == b.season) null else b.season },
                                onMarkAll = { markSeason(b.season, it) },
                                onTick = { e -> tick(e, !e.watched) },
                                onOpen = { e -> nav.push(EpisodeRoute(showId, e.season, e.number)) },
                                onLongPress = { e -> if (e.watched) dateFor = e })
                        }
                    }
                    ReviewsSection("show", showId, d.displayTitle, complete)
                    StaleFooter(data.stale && !data.loading)
                })
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList() }
        }
    }

    if (gallery) ArtworkGallery("show", showId, d?.displayTitle ?: "", onDismiss = { gallery = false })
    if (requestSheet) request?.let { st ->
        SeasonRequestSheet(showId, st, onDismiss = { requestSheet = false }) {
            request = runCatching { session.client?.get<RequestStatus>("request/status/show/$showId") }.getOrNull() ?: request
        }
    }
    if (confirmRemove) AlertDialog(onDismissRequest = { confirmRemove = false }, containerColor = C.panelRaised,
        title = { Text("Remove ${d?.displayTitle}?", style = T.headline, color = C.ink) },
        text = { Text("This removes the show from your shows and deletes every episode you've marked watched.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmRemove = false; follow("unfollow" to true, after = { nav.popBackStack() }) }) { Text("Remove and delete watch history", color = C.velvet) } },
        dismissButton = { TextButton({ confirmRemove = false }) { Text("Cancel", color = C.brass) } })
    ahead?.let { (e, behind) ->
        AlertDialog(onDismissRequest = { ahead = null }, containerColor = C.panelRaised,
            title = { Text("You're ahead — $behind earlier episode${if (behind == 1) " isn't" else "s aren't"} marked yet.", style = T.headline, color = C.ink) },
            confirmButton = { TextButton({ ahead = null; mark(e, true, through = true) }) { Text("Mark all ${behind + 1} up to here", color = C.brass) } },
            dismissButton = { TextButton({ ahead = null; mark(e, true) }) { Text("Just this episode", color = C.inkSoft) } })
    }
    dateFor?.let { e ->
        val initial = MQTime.date(e.watchedAt)?.atStartOfDay()?.toInstant(ZoneOffset.UTC)?.toEpochMilli()
        val state = rememberDatePickerState(initialSelectedDateMillis = initial)
        DatePickerDialog(onDismissRequest = { dateFor = null }, confirmButton = {
            TextButton({
                val ms = state.selectedDateMillis
                dateFor = null
                if (ms != null) {
                    val day = Instant.ofEpochMilli(ms).atZone(ZoneOffset.UTC).toLocalDate()
                    val time = e.watchedAt?.takeIf { it.length >= 19 }?.substring(10, 19) ?: "T20:00:00"
                    val stamp = "$day$time"
                    patch { sd -> sd.copy(seasons = sd.seasons.map { b -> b.copy(episodes = b.episodes.map { x -> if (x.key == e.key) x.copy(watchedAt = stamp) else x }) }) }
                    scope.launch { runCatching { session.client?.send("show/$showId/watch", body("season" to e.season, "number" to e.number, "set_date" to stamp)) } }
                }
            }) { Text("Save", color = C.brass) }
        }, dismissButton = { TextButton({ dateFor = null }) { Text("Cancel", color = C.inkSoft) } }) { DatePicker(state, title = { Text("  ${e.code} watched on", style = T.headline, color = C.ink) }) }
    }
    if (episodeEditor) CustomEpisodesSheet(showId, d?.seasons?.lastOrNull()?.season ?: 1, onDismiss = { episodeEditor = false }) { data.refresh() }
}

private fun facts(d: ShowDetail): String {
    val info = d.info
    val first = info?.firstAir?.take(4)
    val last = info?.lastAir?.take(4)
    val span = when {
        first.isNullOrEmpty() -> d.year?.toString() ?: ""
        last == null || last == first -> first
        d.status == "Returning Series" -> "$first–"
        else -> "$first–$last"
    }
    return listOfNotNull(d.status?.takeIf { it.isNotEmpty() }, span.takeIf { it.isNotEmpty() }, d.genreList.takeIf { it.isNotEmpty() }?.joinToString(", "),
        info?.createdBy?.takeIf { it.isNotEmpty() }?.let { "by ${it.joinToString(", ")}" }).joinToString(" · ")
}

/** Add to watchlist → On your watchlist → Watching ▾ (Stop lives in the menu) → Resume watching. */
@Composable
private fun WatchlistControl(d: ShowDetail, watched: Int, onFollow: () -> Unit, onResume: () -> Unit, onUnlist: () -> Unit, onStop: () -> Unit) {
    when {
        !d.isFollowed -> PrimaryButton("Add to watchlist", onFollow, icon = Icons.Filled.Add, fill = false)
        d.isArchived -> PrimaryButton("Resume watching", onResume, icon = Icons.Filled.PlayArrow, fill = false)
        watched == 0 -> ChipButton("On your watchlist", Icons.Filled.Check, on = true, onClick = onUnlist)
        else -> Box {
            var menu by remember { mutableStateOf(false) }
            Row(Modifier.clip(CircleShape).background(C.brassFill).clickable { menu = true }.padding(start = 18.dp, end = 12.dp, top = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
                Text("Watching", style = T.headline, color = C.brassOnFill); Icon(Icons.Filled.ArrowDropDown, "Opens a menu to stop watching", tint = C.brassOnFill)
            }
            DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) {
                DropdownMenuItem({ Text("Stop watching", color = C.velvet) }, { menu = false; onStop() }, leadingIcon = { Icon(Icons.Filled.StopCircle, null, tint = C.velvet) })
            }
        }
    }
}

@Composable
private fun NextUpCard(e: EpisodeRow, art: String?, onOpen: () -> Unit, onMark: () -> Unit) {
    val haptic = LocalHapticFeedback.current
    DetailSection("Continue watching") {
        Row(Modifier.padding(horizontal = MQ.gutter).fillMaxWidth().mqPanel(16.dp).clickable(onClick = onOpen).padding(12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            if (e.still != null) dev.kadenthompson.marquee.design.Still(e.still, Modifier.width(110.dp)) else Poster(art, Modifier.width(48.dp), radius = 7.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("UP NEXT · ${e.code}", style = T.eyebrow, color = C.brass)
                Text(e.displayTitle, style = T.body(14.5f, 700), color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                listOfNotNull(e.runtime?.let { "$it min" }, e.airDate?.let { MQTime.medium(it) }).joinToString(" · ").takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkMuted) }
            }
            Box(Modifier.size(42.dp).clip(CircleShape).background(C.brassFill).clickable { haptic.performHapticFeedback(HapticFeedbackType.Confirm); onMark() }, contentAlignment = Alignment.Center) {
                Icon(Icons.Filled.Check, "Mark ${e.code} watched", tint = C.brassOnFill)
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SeasonBlockView(
    b: SeasonBlock, name: String, open: Boolean, req: SeasonRequestState?, today: String,
    onToggle: () -> Unit, onMarkAll: (Boolean) -> Unit, onTick: (EpisodeRow) -> Unit, onOpen: (EpisodeRow) -> Unit, onLongPress: (EpisodeRow) -> Unit,
) {
    val rot by animateFloatAsState(if (open) 90f else 0f, label = "r")
    Column(Modifier.fillMaxWidth().mqPanel().animateContentSize()) {
        Column(Modifier.fillMaxWidth().clickable(onClick = onToggle).padding(horizontal = 14.dp, vertical = 13.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp)) {
                Icon(Icons.Filled.ChevronRight, null, tint = C.inkMuted, modifier = Modifier.size(16.dp).rotate(rot))
                Text(name, style = T.body(14.5f, 700), color = C.ink, maxLines = 1, modifier = Modifier.weight(1f, fill = false))
                if (b.isComplete) Icon(Icons.Filled.Check, null, tint = C.brass, modifier = Modifier.size(14.dp))
                Spacer(Modifier.weight(1f))
                Text("${b.watchedCount}/${b.episodes.size}", style = T.caption.copy(fontFeatureSettings = "tnum"), color = C.inkMuted)
                Text(if (b.isComplete) "unmark all" else "mark all", style = T.body(12f, 600), color = C.brass,
                    modifier = Modifier.clip(CircleShape).background(C.brassSoft).clickable { onMarkAll(!b.isComplete) }.padding(horizontal = 12.dp, vertical = 6.dp))
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ProgressBar(if (b.episodes.isNotEmpty()) b.watchedCount.toFloat() / b.episodes.size else 0f, Modifier.weight(1f))
                if (req != null && req.state != RequestState.NONE) {
                    if (req.state == RequestState.DOWNLOADING && req.progress != null) RequestStatusPill("${req.progress}%", req.state.icon, req.state.tone, true)
                    else RequestStatusPill(req.state.pillLabel, req.state.icon, req.state.tone, true)
                }
            }
        }
        if (open) {
            HorizontalDivider(color = C.hairline)
            b.episodes.forEachIndexed { i, e ->
                val future = !e.hasAired(today)
                Row(
                    Modifier.fillMaxWidth().alpha(if (future) 0.45f else 1f)
                        .background(if (e.watched) Brush.horizontalGradient(listOf(C.brassSoft.copy(alpha = 0.07f), Color.Transparent)) else Brush.horizontalGradient(listOf(Color.Transparent, Color.Transparent)))
                        .combinedClickable(onClick = { onOpen(e) }, onLongClick = { onLongPress(e) })
                        .padding(horizontal = 12.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text("${e.number}", style = T.numeric, color = if (e.watched) C.brass else C.inkMuted, modifier = Modifier.width(28.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
                    Column(Modifier.weight(1f)) {
                        Text(e.displayTitle, style = T.body(14f), color = if (e.watched) C.inkMuted else C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        if (e.watched && e.watchedAt != null) Text("Watched ${MQTime.medium(e.watchedAt)}", style = T.body(11f, 600), color = C.brass.copy(alpha = 0.8f))
                    }
                    e.airDate?.takeIf { it.isNotEmpty() }?.let { Text(MQTime.short(it), style = T.body(11.5f), color = C.inkMuted, maxLines = 1) }
                    TickButton(e.watched, "Mark ${e.code} ${if (e.watched) "unwatched" else "watched"}") { onTick(e) }
                }
                if (i < b.episodes.lastIndex) HorizontalDivider(Modifier.padding(start = 46.dp), color = C.hairline.copy(alpha = 0.6f))
            }
        }
    }
}

@Composable
fun TickButton(on: Boolean, label: String, onClick: () -> Unit) {
    val haptic = LocalHapticFeedback.current
    Box(
        Modifier.size(32.dp).clip(CircleShape).background(if (on) C.brassFill else Color.Transparent)
            .then(if (on) Modifier else Modifier.background(C.panelRaised))
            .clickable { haptic.performHapticFeedback(if (on) HapticFeedbackType.ToggleOff else HapticFeedbackType.ToggleOn); onClick() },
        contentAlignment = Alignment.Center,
    ) { Icon(Icons.Filled.Check, label, tint = if (on) C.brassOnFill else C.hairlineBold, modifier = Modifier.size(18.dp)) }
}

/** Admin: add placeholder episodes TMDB doesn't have. */
@Composable
private fun CustomEpisodesSheet(showId: Int, defaultSeason: Int, onDismiss: () -> Unit, onDone: () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var season by remember { mutableStateOf(defaultSeason.toString()) }
    var count by remember { mutableStateOf("1") }
    var titles by remember { mutableStateOf("") }
    var air by remember { mutableStateOf(LocalDate.now().toString()) }
    var error by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Add episodes", style = T.headline, color = C.ink)
            Text("For episodes TMDB doesn't list — a fan edit, a gap in the catalogue.", style = T.caption, color = C.inkMuted)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(season, { season = it.filter(Char::isDigit) }, Modifier.weight(1f), label = { Text("Season") }, singleLine = true, colors = mqFieldColors())
                OutlinedTextField(count, { count = it.filter(Char::isDigit) }, Modifier.weight(1f), label = { Text("How many") }, singleLine = true, colors = mqFieldColors())
            }
            OutlinedTextField(titles, { titles = it }, Modifier.fillMaxWidth(), label = { Text("Titles, one per line (optional)") }, colors = mqFieldColors())
            OutlinedTextField(air, { air = it }, Modifier.fillMaxWidth(), label = { Text("Air date (YYYY-MM-DD)") }, singleLine = true, colors = mqFieldColors())
            error?.let { Text(it, style = T.caption, color = C.velvet) }
            PrimaryButton("Add", {
                scope.launch {
                    busy = true
                    try {
                        session.client?.send("show/$showId/episodes/custom", body("season" to (season.toIntOrNull() ?: 1), "count" to (count.toIntOrNull() ?: 1), "titles" to titles, "air_date" to air))
                        onDone(); onDismiss()
                    } catch (e: Exception) { error = e.friendly } finally { busy = false }
                }
            }, busy = busy)
            Spacer(Modifier.height(8.dp))
        }
    }
}
