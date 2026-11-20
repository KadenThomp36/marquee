package dev.kadenthompson.marquee.features.reading

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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ShowChart
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.CancelPresentation
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ChipRow
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.ExpandableText
import dev.kadenthompson.marquee.design.FoldSpread
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.LoadingList
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.MetaChip
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.StarRating
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.ProgressBar
import dev.kadenthompson.marquee.features.detail.BackdropWash
import dev.kadenthompson.marquee.features.detail.LinkChip
import dev.kadenthompson.marquee.features.detail.ReviewsSection
import dev.kadenthompson.marquee.features.detail.mqFieldColors
import dev.kadenthompson.marquee.features.requests.SheetTitle
import dev.kadenthompson.marquee.model.ActiveSession
import dev.kadenthompson.marquee.model.ActiveSessionsResponse
import dev.kadenthompson.marquee.model.BookMatchesResponse
import dev.kadenthompson.marquee.model.BookSearchResult
import dev.kadenthompson.marquee.model.ProgressMode
import dev.kadenthompson.marquee.model.ReadingDetail
import dev.kadenthompson.marquee.model.ReadingKind
import dev.kadenthompson.marquee.model.ReadingSession
import dev.kadenthompson.marquee.model.ReadingState
import dev.kadenthompson.marquee.model.RecentFolio
import dev.kadenthompson.marquee.model.SeriesPosition
import dev.kadenthompson.marquee.nav.BookBrowseRoute
import dev.kadenthompson.marquee.nav.BookStatsRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.JsonNullValue
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import java.time.Instant
import java.time.ZoneOffset
import kotlin.math.roundToInt

/** A book or manga: shelf state, progress, sessions, the log, household, reviews. */
@Composable
fun ReadingDetailScreen(kindKey: String, itemId: Int, preview: Boolean) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    val kind = ReadingKind.of(kindKey)
    val path = if (preview) "book/hc/$itemId" else "${kind.path}/$itemId"
    val data = rememberRemote<ReadingDetail>("rd-$path") { it.get(path) }
    var live by remember { mutableStateOf<ActiveSession?>(null) }
    var target by remember { mutableStateOf<ProgressTarget?>(null) }
    var editing by remember { mutableStateOf<ReadingSession?>(null) }
    var matches by remember { mutableStateOf(false) }
    var confirmFinish by remember { mutableStateOf(false) }
    var confirmRemove by remember { mutableStateOf(false) }
    var datePick by remember { mutableStateOf<String?>(null) }
    var busy by remember { mutableStateOf(false) }

    val d = data.value
    val item = d?.item
    val st = d?.state
    val total = if (kind == ReadingKind.BOOK) item?.pages else item?.chapters
    val mode = st?.mode ?: if (kind == ReadingKind.MANGA) ProgressMode.CHAPTERS else ProgressMode.PAGES
    val id = item?.id

    suspend fun loadLive() {
        if (d?.tracked != true || id == null) { live = null; return }
        runCatching { session.client?.get<ActiveSessionsResponse>("reading/active") }.getOrNull()?.let { r -> live = r.sessions.firstOrNull { it.kind == kind.path && it.itemId == id } }
    }
    LaunchedEffect(d?.tracked, id) { loadLive() }

    fun reload() = scope.launch { data.load(force = true); loadLive(); session.noteReading() }
    fun save(b: JsonObject) = scope.launch {
        val i = id ?: return@launch
        try { session.client?.send("${kind.path}/$i/state", b) } catch (e: Exception) { snackbar.showSnackbar(e.friendly) }
        reload()
    }
    fun setState(s: ReadingState) = save(if (s == ReadingState.FINISHED && total != null) body("state" to s.key, "progress" to total) else body("state" to s.key))
    fun requestState(s: ReadingState) {
        if (s == st?.readingState) return
        if (s == ReadingState.FINISHED && total != null && (st?.progress ?: 0) < total) { confirmFinish = true; return }
        setState(s)
    }
    fun openProgress() {
        val it = item ?: return; val i = it.id ?: return
        val titles = if (kind == ReadingKind.BOOK && !it.toc.isNullOrEmpty()) it.toc.mapIndexed { n, t -> n + 1 to t }.toMap()
        else it.chlist?.associate { c -> c.number to c.displayTitle } ?: emptyMap()
        target = ProgressTarget(kind, i, it.displayTitle, st?.progress ?: 0, it.pages, it.chapters, st?.mode, live, titles)
    }
    fun step(delta: Int) {
        val cur = st?.progress ?: 0
        val next = when {
            mode == ProgressMode.PCT -> (cur + delta * maxOf(1, (total ?: 100) / 100))
            mode == ProgressMode.CHAPTERS && kind == ReadingKind.BOOK && item?.pages != null && (item.chapters ?: 0) > 0 -> {
                val pages = item.pages; val ch = item.chapters!!
                val nc = maxOf(0, (cur.toDouble() / pages * ch).roundToInt() + delta)
                minOf(pages, (minOf(ch, nc).toDouble() / ch * pages).roundToInt())
            }
            else -> cur + delta
        }.coerceIn(0, total ?: Int.MAX_VALUE)
        save(body("progress" to next))
    }
    fun add(s: ReadingState) = scope.launch {
        val it = item ?: return@launch
        val c = session.client ?: return@launch
        runCatching {
            if (kind == ReadingKind.BOOK && it.hcId != null) c.send("books/add", bookAddBody(BookSearchResult(it.hcId, it.title, it.author, it.year, it.pages, it.cover, it.series, it.seriesPos, it.communityRating, null, it.genres, it.desc, it.slug), s))
            else if (it.id != null) c.send("manga/add", body("id" to it.id, "state" to s.key))
        }.onFailure { snackbar.showSnackbar(it.friendly) }
        reload()
    }

    ScreenScaffold(item?.displayTitle ?: if (kind == ReadingKind.BOOK) "Book" else "Manga", { nav.popBackStack() }, refreshing = data.refreshing, onRefresh = { reload() }) { pad ->
        when {
            d != null && item != null -> Box(Modifier.fillMaxSize()) {
                BackdropWash(item.cover, alpha = 0.22f)
                FoldSpread(contentPadding = PaddingValues(top = pad.calculateTopPadding()), spacing = 20.dp, leading = {
                    Column(Modifier.padding(horizontal = MQ.gutter).padding(top = 12.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                        // hero
                        Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                            Poster(item.cover, Modifier.width(116.dp), radius = 12.dp)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(7.dp)) {
                                Text(item.displayTitle, style = T.title, color = C.ink)
                                if (kind == ReadingKind.BOOK && !item.author.isNullOrEmpty()) FlowRow {
                                    val names = item.author.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                                    names.forEachIndexed { i, n ->
                                        Text(n + if (i < names.lastIndex) ", " else "", style = T.body(14f, 600).copy(textDecoration = TextDecoration.Underline), color = C.brass,
                                            modifier = Modifier.clickable { nav.push(BookBrowseRoute("author", n)) })
                                    }
                                } else item.origin?.let { Text(listOfNotNull(it, item.status).joinToString(" · "), style = T.sub, color = C.inkSoft) }
                                if (kind == ReadingKind.BOOK && !item.series.isNullOrEmpty()) Row(
                                    Modifier.clip(RoundedCornerShape(8.dp)).background(C.brassSoft).border(1.dp, C.brassDim, RoundedCornerShape(8.dp)).clickable { nav.push(BookBrowseRoute("series", item.series)) }.padding(horizontal = 9.dp, vertical = 5.dp),
                                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                    Icon(Icons.Filled.AutoStories, null, tint = C.brass, modifier = Modifier.size(13.dp))
                                    Text(item.series, style = T.body(12f, 700), color = C.brass, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                    SeriesPosition.label(item.seriesPos)?.let { Text(it, style = T.body(12f, 800), color = C.brassBright) }
                                }
                                ChipRow {
                                    total?.let { MetaChip("$it ${kind.unit}") }
                                    item.volumes?.let { MetaChip("$it vols") }
                                    (item.communityRating ?: item.score)?.let { MetaChip(LibraryFormat.one(it), Icons.Filled.Star, tinted = true) }
                                    item.genreList.take(3).forEach { MetaChip(it) }
                                }
                                item.year?.let { Text("$it", style = T.caption, color = C.inkSoft) }
                                if (kind == ReadingKind.BOOK && id != null && !preview) BookRequestControl(id, item.displayTitle, item.cover)
                            }
                        }
                        if (d.tracked) {
                            // shelf
                            val current = st?.readingState
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                                val opts = ReadingState.primary + listOfNotNull(current?.takeIf { it in ReadingState.secondary })
                                Segmented(opts.map { it.label }, opts.indexOf(current ?: ReadingState.WANT).coerceAtLeast(0), Modifier.weight(1f)) { requestState(opts[it]) }
                                Box {
                                    var menu by remember { mutableStateOf(false) }
                                    Box(Modifier.size(40.dp).mqPanel(9.dp).clickable { menu = true }, contentAlignment = Alignment.Center) { Icon(Icons.Filled.MoreHoriz, "More shelves", tint = C.inkSoft) }
                                    DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) {
                                        ReadingState.secondary.forEach { o -> DropdownMenuItem({ Text(o.label) }, { menu = false; requestState(o) }, trailingIcon = { if (o == current) Icon(Icons.Filled.Check, null, tint = C.brass) }) }
                                    }
                                }
                            }
                            if (current == ReadingState.PAUSED || current == ReadingState.DNF) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Icon(if (current == ReadingState.PAUSED) Icons.Filled.PauseCircle else Icons.Filled.CancelPresentation, null, tint = C.inkMuted, modifier = Modifier.size(18.dp))
                                Text(current.label, style = T.sub, color = C.inkSoft, modifier = Modifier.weight(1f))
                                if (current == ReadingState.PAUSED) ChipButton("Pick it back up", on = true) { requestState(ReadingState.READING) }
                            }
                            // progress
                            if (current != ReadingState.WANT) Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                val frac = if ((total ?: 0) > 0) minOf(1f, (st?.progress ?: 0).toFloat() / total!!) else 0f
                                ProgressBar(frac, Modifier.clickable { openProgress() }, height = 8.dp)
                                val modes = if (kind == ReadingKind.BOOK) listOfNotNull(ProgressMode.PAGES, ProgressMode.PCT.takeIf { item.pages != null }, ProgressMode.CHAPTERS.takeIf { item.chapters != null && item.pages != null })
                                    else if (total != null) listOf(ProgressMode.CHAPTERS, ProgressMode.PCT) else listOf(ProgressMode.CHAPTERS)
                                if (modes.size > 1) Segmented(modes.map { when (it) { ProgressMode.PCT -> "%"; ProgressMode.CHAPTERS -> "Chapters"; else -> "Pages" } }, modes.indexOf(mode).coerceAtLeast(0)) { save(body("mode" to modes[it])) }
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                    Eyebrow("Progress", Modifier.weight(1f))
                                    Box(Modifier.size(34.dp).clip(CircleShape).background(C.panelRaised).clickable { step(-1) }, contentAlignment = Alignment.Center) { Icon(Icons.Filled.Remove, "Back one", tint = C.inkSoft) }
                                    val p = st?.progress ?: 0
                                    val shown = when {
                                        mode == ProgressMode.PCT && (total ?: 0) > 0 -> "${(p.toDouble() / total!! * 100).roundToInt()}%"
                                        mode == ProgressMode.CHAPTERS && kind == ReadingKind.BOOK && (item.pages ?: 0) > 0 && item.chapters != null -> "ch ${minOf(item.chapters, (p.toDouble() / item.pages!! * item.chapters).roundToInt())}"
                                        else -> "$p"
                                    }
                                    Text(shown, style = T.body(20f, 700).copy(textDecoration = TextDecoration.Underline, fontFeatureSettings = "tnum"), color = C.ink, modifier = Modifier.clickable { openProgress() })
                                    Box(Modifier.size(34.dp).clip(CircleShape).background(C.brassFill).clickable { step(1) }, contentAlignment = Alignment.Center) { Icon(Icons.Filled.Add, "Forward one", tint = C.brassOnFill) }
                                }
                                Text(when {
                                    total == null -> kind.unit
                                    mode == ProgressMode.PCT -> "${st?.progress ?: 0}/$total ${kind.unit}"
                                    mode == ProgressMode.CHAPTERS && kind == ReadingKind.BOOK -> "of ${item.chapters ?: 0} chapters · ${(frac * 100).toInt()}%"
                                    else -> "of $total ${kind.unit} · ${(frac * 100).toInt()}%"
                                }, style = T.caption, color = C.inkMuted)
                            }
                            // session
                            val l = live
                            if (l != null) LiveStrip(l) { openProgress() }
                            else PrimaryButton("Start a reading session", {
                                scope.launch { busy = true; runCatching { session.client?.send("${kind.path}/$id/session/start") }; busy = false; reload() }
                            }, icon = Icons.Filled.PlayArrow, busy = busy)
                            if (l == null) d.recentFolio?.let { FolioSyncedLine(it) }
                            if (kind == ReadingKind.BOOK && id != null) d.reading?.takeIf { it.minutes > 0 || d.sessions.isNotEmpty() }?.let { r ->
                                Row(Modifier.fillMaxWidth().mqPanel().clickable { nav.push(BookStatsRoute(id)) }.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                    Icon(Icons.AutoMirrored.Filled.ShowChart, null, tint = C.brass)
                                    Column(Modifier.weight(1f)) {
                                        Text("Reading stats", style = T.body(15f, 700), color = C.ink)
                                        Text((if (r.minutes > 0) "${statDuration(r.minutes)} over ${r.sessions} sitting${if (r.sessions == 1) "" else "s"}" else "Pace, calendar and every sitting") +
                                            (r.folio?.takeIf { it > 0 }?.let { " · $it from Folio" } ?: ""), style = T.caption, color = C.inkSoft)
                                    }
                                    Icon(Icons.Filled.ChevronRight, null, tint = C.inkMuted)
                                }
                            }
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Eyebrow("My rating", Modifier.weight(1f))
                                StarRating(st?.rating) { v -> save(body("rating" to (v ?: JsonNullValue))) }
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                DateField("Started", st?.startedAt) { datePick = "started_at" }
                                if (current == ReadingState.FINISHED) DateField("Finished", st?.finishedAt) { datePick = "finished_at" }
                            }
                        } else Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                            PrimaryButton("Start reading", { add(ReadingState.READING) })
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                ChipButton("Want to read", modifier = Modifier.weight(1f)) { add(ReadingState.WANT) }
                                ChipButton("I've read this", modifier = Modifier.weight(1f)) { add(ReadingState.FINISHED) }
                            }
                        }
                    }
                }, trailing = {
                    Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(20.dp)) {
                        if (kind == ReadingKind.MANGA && d.tracked && (item.chapters ?: 0) > 0) ChapterList(item.chapters!!, item.chlist?.associate { it.number to it.displayTitle } ?: emptyMap(), st?.progress ?: 0) { save(body("progress" to it)) }
                        item.desc?.takeIf { it.isNotEmpty() }?.let { Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { Eyebrow("About"); ExpandableText(it, 5) } }
                        if (d.sessions.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Eyebrow("Reading log")
                            Column(Modifier.fillMaxWidth().mqPanel()) {
                                d.sessions.forEachIndexed { i, e ->
                                    Row(Modifier.fillMaxWidth().clickable { editing = e }.padding(horizontal = 12.dp, vertical = 11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                        Text(MQTime.medium(e.date), style = T.sub, color = C.ink, modifier = Modifier.weight(1f))
                                        Text(logLine(e, total), style = T.caption.copy(fontFeatureSettings = "tnum"), color = C.inkSoft)
                                        if (e.isTimed && e.source != null && e.source != "marquee") e.sourceLabel?.let {
                                            Text(it, style = T.body(10f, 700), color = if (e.isFolio) C.chartAqua else C.inkMuted, modifier = Modifier.border(1.dp, C.hairlineBold, RoundedCornerShape(5.dp)).padding(horizontal = 5.dp, vertical = 2.dp))
                                        }
                                    }
                                    if (i < d.sessions.lastIndex) HorizontalDivider(color = C.hairline)
                                }
                            }
                        }
                        if (d.household.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Eyebrow("Around the house")
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                d.household.forEach { m ->
                                    Row(Modifier.mqPanel().padding(horizontal = 9.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Avatar(m.person, 20.dp); Text(m.person.name, style = T.body(12.5f, 700), color = C.ink)
                                        Text(m.stateLabel, style = T.caption, color = C.inkMuted); m.rating?.let { Text("★$it", style = T.body(12f, 700), color = C.brass) }
                                    }
                                }
                            }
                        }
                        ChipRow {
                            if (kind == ReadingKind.BOOK && d.tracked) ChipButton("Wrong book?", Icons.Filled.SwapHoriz) { matches = true }
                            if (kind == ReadingKind.BOOK) (item.slug ?: item.hcId?.toString())?.let { LinkChip("Hardcover", "https://hardcover.app/books/$it") }
                            if (kind == ReadingKind.MANGA && item.id != null) LinkChip("AniList", "https://anilist.co/manga/${item.id}")
                            if (d.tracked) ChipButton("Remove", Icons.Filled.Delete, destructive = true) { confirmRemove = true }
                        }
                    }
                    if (d.tracked && id != null) ReviewsSection(kind.path, id, "this", st?.readingState == ReadingState.FINISHED)
                })
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(3) }
        }
    }

    target?.let { t -> ReadingProgressSheet(t, onDismiss = { target = null }) { reload() } }
    editing?.let { e -> SessionEditorSheet(e, total, onDismiss = { editing = null }) { reload() } }
    if (matches && id != null) RematchSheet(id, onDismiss = { matches = false }) { reload() }
    if (confirmFinish) AlertDialog(onDismissRequest = { confirmFinish = false }, containerColor = C.panelRaised,
        title = { Text("Mark ${item?.displayTitle ?: "this"} finished?", style = T.headline, color = C.ink) },
        text = { Text("This moves your progress to the end and dates the finish today.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmFinish = false; setState(ReadingState.FINISHED) }) { Text("Mark finished", color = C.brass) } },
        dismissButton = { TextButton({ confirmFinish = false; openProgress() }) { Text("Update progress instead", color = C.inkSoft) } })
    if (confirmRemove) AlertDialog(onDismissRequest = { confirmRemove = false }, containerColor = C.panelRaised,
        title = { Text("Remove ${item?.displayTitle ?: "this"} from your shelf?", style = T.headline, color = C.ink) },
        text = { Text("Your progress, dates and rating go with it${if (live != null) ", and the running session is dropped" else ""}.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmRemove = false; scope.launch { runCatching { session.client?.send("${kind.path}/$id/state", body("state" to "none")) }; session.noteReading(); nav.popBackStack() } }) { Text("Remove", color = C.velvet) } },
        dismissButton = { TextButton({ confirmRemove = false }) { Text("Cancel", color = C.brass) } })
    datePick?.let { key ->
        val initial = MQTime.date(if (key == "started_at") st?.startedAt else st?.finishedAt)?.atStartOfDay()?.toInstant(ZoneOffset.UTC)?.toEpochMilli() ?: System.currentTimeMillis()
        val ps = rememberDatePickerState(initialSelectedDateMillis = initial)
        DatePickerDialog(onDismissRequest = { datePick = null }, confirmButton = {
            TextButton({ datePick = null; ps.selectedDateMillis?.let { save(body(key to Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString())) } }) { Text("Save", color = C.brass) }
        }, dismissButton = { TextButton({ datePick = null }) { Text("Cancel", color = C.inkSoft) } }) { DatePicker(ps) }
    }
}

fun statDuration(minutes: Int): String = if (minutes < 60) "$minutes min" else "${minutes / 60} h${if (minutes % 60 > 0) " ${minutes % 60} min" else ""}"

private fun logLine(e: ReadingSession, total: Int?): String {
    val parts = mutableListOf<String>()
    if (e.isTimed) parts += "${e.minutes} min"
    if (total == null && e.endFraction != null) { parts += "${((e.startFraction ?: 0.0) * 100).roundToInt()}% → ${(e.endFraction * 100).roundToInt()}%"; return parts.joinToString(" · ") }
    parts += if (e.from == e.to) "at ${e.to}" else "${e.from} → ${e.to}"
    return parts.joinToString(" · ")
}

@Composable
private fun DateField(label: String, value: String?, onPick: () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Eyebrow(label)
        Row(Modifier.mqPanel(9.dp).clickable(onClick = onPick).padding(horizontal = 10.dp, vertical = 7.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Icon(Icons.Filled.CalendarMonth, null, tint = C.brass, modifier = Modifier.size(15.dp))
            Text(value?.let { MQTime.medium(it) } ?: "Add date", style = T.sub, color = if (value != null) C.ink else C.brass)
        }
    }
}

/** "Read on Boox Palma 2 hours ago — 40 min, 14 pages, up to Chapter 19". */
@Composable
fun FolioSyncedLine(r: RecentFolio, verb: String = "Read on") {
    val details = listOfNotNull(statDuration(r.minutes), r.pages?.takeIf { it > 0 }?.let { "$it page${if (it == 1) "" else "s"}" }, r.chapter?.let { "up to $it" })
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(C.chartAqua.copy(alpha = 0.08f)).border(1.dp, C.chartAqua.copy(alpha = 0.3f), RoundedCornerShape(11.dp)).padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(Icons.Filled.AutoStories, null, tint = C.chartAqua, modifier = Modifier.size(16.dp))
        Text("$verb ${r.device} ${MQTime.relative(r.endedAt)} — ${details.joinToString(", ")}", style = T.sub, color = C.inkSoft)
    }
}

@Composable
private fun ChapterList(count: Int, titles: Map<Int, String>, current: Int, onSet: (Int) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val shown = (1..count).toList().let { all -> if (expanded) all.reversed() else all.filter { it in (current - 2)..(current + 5) }.ifEmpty { all.takeLast(8) } }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row { Eyebrow("Chapters", Modifier.weight(1f)); Text(if (expanded) "Fewer" else "All $count", style = T.body(12f, 700), color = C.brass, modifier = Modifier.clickable { expanded = !expanded }) }
        Column(Modifier.fillMaxWidth().mqPanel().heightIn(max = if (expanded) 420.dp else 600.dp).verticalScroll(rememberScrollState())) {
            shown.forEachIndexed { i, n ->
                val read = n <= current
                Row(Modifier.fillMaxWidth().clickable { onSet(n) }.padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("$n", style = T.numeric, color = if (read) C.brass else C.inkMuted, modifier = Modifier.width(34.dp))
                    Text(titles[n] ?: "Chapter $n", style = T.body(14f), color = if (read) C.inkMuted else C.ink, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    if (read) Icon(Icons.Filled.Check, null, tint = C.brass, modifier = Modifier.size(16.dp))
                }
                if (i < shown.lastIndex) HorizontalDivider(color = C.hairline)
            }
        }
    }
}

/** Fix a sitting: date, minutes, where it started and ended, or delete it. */
@Composable
fun SessionEditorSheet(e: ReadingSession, total: Int?, onDismiss: () -> Unit, onSaved: () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var date by remember { mutableStateOf(e.date.take(10)) }
    var minutes by remember { mutableStateOf(e.minutes.toString()) }
    var from by remember { mutableStateOf(e.from.toString()) }
    var to by remember { mutableStateOf(e.to.toString()) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }
    fun send(b: JsonObject) = scope.launch {
        try { session.client?.send("reading/session/${e.id}", b); onSaved(); onDismiss() } catch (ex: Exception) { error = ex.friendly }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Edit sitting", style = T.headline, color = C.ink)
            if (e.isFolio) Text("From ${e.sourceLabel ?: "Folio"}${e.idleMinutes?.takeIf { it > 0 }?.let { " · $it min idle left out" } ?: ""}", style = T.caption, color = C.chartAqua)
            OutlinedTextField(date, { date = it }, Modifier.fillMaxWidth(), label = { Text("Date (YYYY-MM-DD)") }, singleLine = true, colors = mqFieldColors())
            OutlinedTextField(minutes, { minutes = it.filter(Char::isDigit) }, Modifier.fillMaxWidth(), label = { Text("Minutes") }, singleLine = true, colors = mqFieldColors())
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(from, { from = it.filter(Char::isDigit) }, Modifier.weight(1f), label = { Text("From") }, singleLine = true, colors = mqFieldColors())
                OutlinedTextField(to, { to = it.filter(Char::isDigit) }, Modifier.weight(1f), label = { Text("To${total?.let { " (of $it)" } ?: ""}") }, singleLine = true, colors = mqFieldColors())
            }
            error?.let { Text(it, style = T.caption, color = C.velvet) }
            PrimaryButton("Save", { send(body("date" to date, "minutes" to minutes.toIntOrNull(), "from" to from.toIntOrNull(), "to" to to.toIntOrNull())) })
            ChipButton("Delete sitting", Icons.Filled.Delete, modifier = Modifier.align(Alignment.CenterHorizontally), destructive = true) { confirmDelete = true }
        }
    }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, containerColor = C.panelRaised,
        title = { Text("Delete this sitting?", style = T.headline, color = C.ink) },
        confirmButton = { TextButton({ confirmDelete = false; send(body("delete" to true)) }) { Text("Delete", color = C.velvet) } },
        dismissButton = { TextButton({ confirmDelete = false }) { Text("Cancel", color = C.brass) } })
}

/** "Wrong book?" — other Hardcover editions, the current one marked. */
@Composable
private fun RematchSheet(bookId: Int, onDismiss: () -> Unit, onDone: () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var m by remember { mutableStateOf<BookMatchesResponse?>(null) }
    LaunchedEffect(Unit) { m = runCatching { session.client?.get<BookMatchesResponse>("book/$bookId/matches") }.getOrNull() ?: BookMatchesResponse() }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding()) {
            SheetTitle("Wrong book?", onClose = onDismiss)
            Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Pick the right edition from Hardcover. Your progress and sittings stay.", style = T.caption, color = C.inkMuted)
                val r = m
                if (r == null) LoadingList(2) else if (r.results.isEmpty()) Text("No other matches found.", style = T.sub, color = C.inkMuted)
                else r.results.forEach { b ->
                    val cur = b.hcId == r.current
                    Row(Modifier.fillMaxWidth().mqPanel().clickable(enabled = !cur) {
                        scope.launch { runCatching { session.client?.send("book/$bookId/rematch", body("hc_id" to b.hcId)) }; onDone(); onDismiss() }
                    }.padding(10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                        Poster(b.cover, Modifier.width(42.dp), radius = 6.dp)
                        Column(Modifier.weight(1f)) {
                            Text(b.displayTitle, style = T.body(14f, 700), color = C.ink, maxLines = 2)
                            Text(listOfNotNull(b.author, b.year?.toString(), b.pages?.let { "$it p" }).joinToString(" · "), style = T.caption, color = C.inkMuted)
                        }
                        if (cur) Text("CURRENT", style = T.eyebrow, color = C.brass)
                    }
                }
            }
        }
    }
}
