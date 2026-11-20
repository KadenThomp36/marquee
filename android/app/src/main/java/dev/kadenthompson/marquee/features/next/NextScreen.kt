package dev.kadenthompson.marquee.features.next

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.snapping.SnapPosition
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Icon
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.RailHeader
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.StaleFooter
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.features.common.CalendarCard
import dev.kadenthompson.marquee.features.common.ContinueReadingCard
import dev.kadenthompson.marquee.features.common.DayDivider
import dev.kadenthompson.marquee.features.common.EmptyLine
import dev.kadenthompson.marquee.features.common.EmptyQueuePrompt
import dev.kadenthompson.marquee.features.common.PlainRailTitle
import dev.kadenthompson.marquee.features.common.PosterTile
import dev.kadenthompson.marquee.features.common.PunchCard
import dev.kadenthompson.marquee.features.common.Rail
import dev.kadenthompson.marquee.features.common.ReviewTeaserRow
import dev.kadenthompson.marquee.features.common.WatchedMiniCard
import dev.kadenthompson.marquee.features.common.WatchlistRailCard
import dev.kadenthompson.marquee.features.reading.ProgressOutcome
import dev.kadenthompson.marquee.features.reading.ProgressTarget
import dev.kadenthompson.marquee.features.reading.ReadingProgressSheet
import dev.kadenthompson.marquee.model.ActiveSession
import dev.kadenthompson.marquee.model.ActiveSessionsResponse
import dev.kadenthompson.marquee.model.Dashboard
import dev.kadenthompson.marquee.model.DiscoverResponse
import dev.kadenthompson.marquee.model.MarkResponse
import dev.kadenthompson.marquee.model.NotificationsResponse
import dev.kadenthompson.marquee.model.ReadingItem
import dev.kadenthompson.marquee.model.ShowCard
import dev.kadenthompson.marquee.model.WatchEntry
import dev.kadenthompson.marquee.nav.EpisodeRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.NotificationsRoute
import dev.kadenthompson.marquee.nav.ShowsWatchlistRoute
import dev.kadenthompson.marquee.nav.UpcomingHome
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.launch
import java.time.LocalTime

private sealed interface RailEntry {
    data class Past(val w: WatchEntry) : RailEntry
    data class Divider(val label: String, val i: Int) : RailEntry
    data class Next(val s: ShowCard) : RailEntry
}

/** Watch Next — one `/api/dashboard` call backs the whole screen. */
@Composable
fun NextScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    val snackbar = LocalSnackbar.current
    val scope = rememberCoroutineScope()
    val data = rememberRemote<Dashboard>("dashboard", true, session.watchRevision, session.readingRevision) { it.get("dashboard") }
    val discover = rememberRemote<DiscoverResponse>("discover", true) { it.get("discover") }
    var unread by remember { mutableIntStateOf(0) }
    var active by remember { mutableStateOf<List<ActiveSession>>(emptyList()) }
    var progressTarget by remember { mutableStateOf<ProgressTarget?>(null) }

    suspend fun loadSide() {
        val c = session.client ?: return
        runCatching { c.get<NotificationsResponse>("notifications") }.onSuccess { unread = it.unread }
        active = if (session.tracksReading) runCatching { c.get<ActiveSessionsResponse>("reading/active").sessions }.getOrDefault(active) else emptyList()
    }
    LaunchedEffect(session.watchRevision, session.readingRevision) { loadSide() }
    // Keep the home-screen widgets and launcher shortcuts in step with what Home shows.
    val appContext = androidx.compose.ui.platform.LocalContext.current.applicationContext
    LaunchedEffect(data.value, data.stale) {
        val d = data.value ?: return@LaunchedEffect
        val c = session.client ?: return@LaunchedEffect
        if (!data.stale) runCatching { dev.kadenthompson.marquee.widget.WidgetData.publish(appContext, d, c) }
    }

    fun live(item: ReadingItem) = active.firstOrNull { it.kind == item.readingKind.path && it.itemId == item.id }

    fun apply(updated: ShowCard, d: Dashboard): Dashboard {
        fun fix(list: List<ShowCard>) = list.mapNotNull { if (it.id == updated.id) (if (updated.nextEp != null) updated else null) else it }
        return d.copy(upNext = fix(d.upNext), stale = fix(d.stale))
    }

    suspend fun punch(show: ShowCard) {
        val ep = show.nextEp ?: return
        val c = session.client ?: return
        data.mutate { it.copy(recent = listOf(WatchEntry(show.id, show.title, show.poster, ep.season, ep.number, ep.title, MQTime.stamp(), 1)) + it.recent) }
        try {
            val r: MarkResponse = c.post("show/${show.id}/watch", body("season" to ep.season, "number" to ep.number))
            r.show?.let { u -> data.mutate { apply(u, it) } }
            session.enqueue(r.celebrate)
            scope.launch {
                val res = snackbar.showSnackbar("Punched ${ep.code} · ${show.displayTitle}", actionLabel = "Open", duration = SnackbarDuration.Short)
                if (res == SnackbarResult.ActionPerformed) nav.push(EpisodeRoute(show.id, ep.season, ep.number))
            }
        } catch (e: Exception) {
            session.handle(e)
            data.mutate { it.copy(recent = it.recent.drop(1)) }
            scope.launch { snackbar.showSnackbar("Couldn't mark it: ${e.friendly}") }
        }
    }

    suspend fun increment(item: ReadingItem) {
        val kind = item.readingKind
        val next = item.incrementedProgress(kind)
        val total = item.total(kind)
        if (total != null && next >= total) { progressTarget = ProgressTarget(item, kind, live(item)); return }
        data.mutate { d -> d.copy(reading = d.reading?.map { if (it.railId == item.railId) it.copy(progress = next) else it }) }
        runCatching { session.client?.send("${kind.path}/${item.id}/state", body("progress" to next)) }
            .onFailure { scope.launch { snackbar.showSnackbar("Couldn't save — ${it.friendly}") } }
    }

    PullToRefreshBox(data.refreshing, { data.refresh(); scope.launch { loadSide() } }, Modifier.fillMaxSize()) {
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(26.dp)) {
            item {
                Row(Modifier.fillMaxWidth().statusBarsPadding().padding(horizontal = MQ.gutter).padding(top = 12.dp), verticalAlignment = Alignment.Top) {
                    Column(Modifier.weight(1f).semantics(mergeDescendants = true) { heading() }, verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        val h = LocalTime.now().hour
                        Text(when { h < 5 -> "Late show"; h < 12 -> "Good morning"; h < 18 -> "Good afternoon"; else -> "Tonight's feature" }, style = T.title, color = C.ink)
                        session.me?.shortName?.let { Text(it.uppercase(), style = T.wordmark(21f), color = C.brass) }
                    }
                    Box(Modifier.size(42.dp).clip(CircleShape).background(C.panel).clickable { nav.push(NotificationsRoute) }, contentAlignment = Alignment.Center) {
                        BadgedBox(badge = { if (unread > 0) Badge(containerColor = C.velvet) { Text("$unread") } }) {
                            Icon(if (unread > 0) Icons.Filled.Notifications else Icons.Outlined.Notifications,
                                if (unread > 0) "Notifications, $unread unread" else "Notifications", tint = C.ink)
                        }
                    }
                }
            }
            val d = data.value
            when {
                d != null -> dashboard(d, discover.value, ::live, { punch(it) }, { increment(it) },
                    { progressTarget = ProgressTarget(it, it.readingKind, live(it)) }, { nav.push(it) })
                data.error != null -> item { ErrorState(data.error!!) { data.refresh() } }
                else -> item {
                    Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Skeleton(Modifier.width(140.dp), 18.dp, 6.dp)
                        Row(horizontalArrangement = Arrangement.spacedBy(MQ.railGap)) { repeat(3) { Skeleton(Modifier.width(MQ.upNextWidth), 237.dp, 16.dp) } }
                    }
                }
            }
            item { StaleFooter(data.stale && data.value != null && !data.loading) }
        }
    }

    progressTarget?.let { t ->
        ReadingProgressSheet(t, onDismiss = { progressTarget = null }) { outcome ->
            val id = "${t.kind.path}:${t.itemId}"
            data.mutate { d ->
                d.copy(reading = when (outcome) {
                    is ProgressOutcome.Progress -> d.reading?.map { if (it.railId == id) it.copy(progress = outcome.value) else it }
                    is ProgressOutcome.SessionEnded -> d.reading?.map { if (it.railId == id) it.copy(progress = maxOf(outcome.value, it.progress ?: 0)) else it }
                    is ProgressOutcome.Finished -> d.reading?.filterNot { it.railId == id }
                    ProgressOutcome.Discarded -> d.reading
                })
            }
            if (t.live != null) loadSide()
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.dashboard(
    d: Dashboard,
    discover: DiscoverResponse?,
    live: (ReadingItem) -> ActiveSession?,
    punch: suspend (ShowCard) -> Unit,
    increment: suspend (ReadingItem) -> Unit,
    log: (ReadingItem) -> Unit,
    push: (Any) -> Unit,
) {
    if (d.upNext.isNotEmpty() || d.recent.isNotEmpty()) item("upnext") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PlainRailTitle("Up Next")
            UpNextRail(d.upNext, d.recent, punch)
        }
    }
    if (d.upNext.isEmpty()) item {
        val wl = d.watchlist
        if (!wl.isNullOrEmpty()) EmptyQueuePrompt(maxOf(wl.size, d.counts?.notStarted ?: 0)) { push(ShowsWatchlistRoute) }
        else EmptyLine("Nothing in the queue — everything is crossed off.")
    }
    d.reading?.takeIf { it.isNotEmpty() }?.let { reading ->
        item("reading") {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                PlainRailTitle("Continue reading")
                Rail { items(reading, key = { it.railId }) { ContinueReadingCard(it, live(it), { increment(it) }, { log(it) }) } }
            }
        }
    }
    d.watchlist?.takeIf { it.isNotEmpty() }?.let { wl ->
        item("watchlist") {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RailHeader("On your watchlist") { push(ShowsWatchlistRoute) }
                Rail { items(wl, key = { it.id }) { WatchlistRailCard(it) } }
            }
        }
    }
    if (d.stale.isNotEmpty()) item("stale") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PlainRailTitle("Haven't watched in a while")
            Rail { items(d.stale, key = { it.id }) { PunchCard(it, onPunch = punch) } }
        }
    }
    if (d.calendar.isNotEmpty()) item("calendar") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            RailHeader("On the calendar") { push(UpcomingHome) }
            Rail { items(d.calendar, key = { it.key }) { CalendarCard(it) } }
        }
    }
    val section = discover?.sections?.let { s -> s.firstOrNull { it.title.lowercase().contains("because you watched") } ?: s.firstOrNull() }
    if (section != null && section.items.isNotEmpty()) item("rec") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PlainRailTitle(section.title)
            Rail { items(section.items.take(14), key = { "${it.type}:${it.id}" }) { PosterTile(it) } }
        }
    }
    if (d.social.isNotEmpty()) item("social") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PlainRailTitle("Around the house")
            Rail { items(d.social, key = { it.key + (it.by?.username ?: "") }) { WatchedMiniCard(it, showsWho = true) } }
        }
    }
    if (d.reviews.isNotEmpty()) item("reviews") {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            PlainRailTitle("Fresh reviews")
            Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                d.reviews.take(4).forEach { ReviewTeaserRow(it) }
            }
        }
    }
}

/**
 * Up Next scrolls left into history: past watches oldest-first with a day divider
 * closing each bucket, then the queue. It parks on the first queue card so history
 * starts off-screen, and snaps card by card.
 */
@Composable
private fun UpNextRail(upNext: List<ShowCard>, recent: List<WatchEntry>, punch: suspend (ShowCard) -> Unit) {
    val entries = remember(upNext, recent) {
        val out = mutableListOf<RailEntry>()
        val buckets = mutableListOf<Pair<String, MutableList<WatchEntry>>>()
        for (w in recent) {
            val label = MQTime.bucketLabel(w.watchedAt)
            if (buckets.lastOrNull()?.first == label) buckets.last().second.add(w) else buckets.add(label to mutableListOf(w))
        }
        buckets.reversed().forEachIndexed { i, (label, items) ->
            out += items.reversed().map { RailEntry.Past(it) }
            out += RailEntry.Divider(label, i)
        }
        out += upNext.map { RailEntry.Next(it) }
        out.toList()
    }
    val firstNext = entries.indexOfFirst { it is RailEntry.Next }.let { if (it < 0) maxOf(0, entries.lastIndex) else it }
    val state = rememberLazyListState(initialFirstVisibleItemIndex = firstNext)
    LaunchedEffect(upNext.firstOrNull()?.id) { if (firstNext >= 0) state.scrollToItem(firstNext) }
    val fling = rememberSnapFlingBehavior(state, SnapPosition.Start)
    val ground = C.ground
    LazyRow(
        Modifier.fillMaxWidth().graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen).drawWithContent {
            drawContent()
            // History scrolling into the gutter fades rather than slicing off square.
            drawRect(Brush.horizontalGradient(0f to Color.Transparent, 0.05f to Color.Black, endX = size.width), blendMode = BlendMode.DstIn)
        },
        state = state, flingBehavior = fling, contentPadding = PaddingValues(horizontal = MQ.gutter),
        horizontalArrangement = Arrangement.spacedBy(MQ.railGap), verticalAlignment = Alignment.CenterVertically,
    ) {
        items(entries, key = {
            when (it) { is RailEntry.Past -> "p:" + it.w.key; is RailEntry.Divider -> "d:${it.i}"; is RailEntry.Next -> "n:${it.s.id}" }
        }) { e ->
            when (e) {
                is RailEntry.Past -> WatchedMiniCard(e.w, isPast = true)
                is RailEntry.Divider -> DayDivider(e.label)
                is RailEntry.Next -> PunchCard(e.s, onPunch = punch)
            }
        }
    }
    @Suppress("UNUSED_EXPRESSION") ground
}
