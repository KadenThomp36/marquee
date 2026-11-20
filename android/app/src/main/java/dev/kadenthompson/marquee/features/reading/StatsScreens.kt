package dev.kadenthompson.marquee.features.reading

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.height
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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.ExpandableText
import dev.kadenthompson.marquee.design.FoldSpread
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.LoadingList
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.RemoteImage
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.SectionHeader
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.grouped
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.OnArtBadge
import dev.kadenthompson.marquee.model.BookSearchResult
import dev.kadenthompson.marquee.model.BookStats
import dev.kadenthompson.marquee.model.BrowseResponse
import dev.kadenthompson.marquee.model.ReadingState
import dev.kadenthompson.marquee.model.ReadingStats
import dev.kadenthompson.marquee.model.ReadingStatsResponse
import dev.kadenthompson.marquee.model.SeriesPosition
import dev.kadenthompson.marquee.nav.BookRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.roundToInt

private fun shortDate(stamp: String?): String? = MQTime.date(stamp)?.let { "${it.month.getDisplayName(TextStyle.SHORT, Locale.getDefault())} ${it.dayOfMonth}" }

private fun sourceColor(c: dev.kadenthompson.marquee.design.MqColors, s: String) = when (s) { "folio" -> c.chartAqua; "ios", "iphone", "android" -> c.chartViolet; "web" -> c.chartBlue; else -> c.brass }

/** One book's reading in depth: the finish date on a marquee, pace, the whole book as one strip, a calendar, chapters, every sitting. */
@Composable
fun BookStatsScreen(bookId: Int) {
    val nav = LocalNav.current
    val data = rememberRemote<BookStats>("bookstats-$bookId") { it.get("book/$bookId/stats") }
    var editing by remember { mutableStateOf<BookStats.Sitting?>(null) }
    val s = data.value
    ScreenScaffold(s?.book?.displayTitle ?: "Reading stats", { nav.popBackStack() }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        when {
            s != null -> FoldSpread(contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp), spacing = 20.dp, leading = {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Poster(s.book.cover, Modifier.width(48.dp), radius = 6.dp)
                    Column { Text(s.book.displayTitle, style = T.headline, color = C.ink); s.book.author?.let { Text(it, style = T.caption, color = C.inkSoft) } }
                }
                MarqueeSign(s)
                if (s.live != null) Text("Reading now", style = T.sub, color = C.brass)
                s.recentFolio?.let { FolioSyncedLine(it) }
                // numbers
                val pace = s.pace.pagesPerHour?.let { "${it.roundToInt()}" to "pages an hour" }
                    ?: s.pace.pctPerHour?.let { "${LibraryFormat.one(it)}%" to "of the book an hour" } ?: ("—" to "pace, after timed sittings")
                val cells = listOf(statDuration(s.totals.minutes) to "reading time", "${s.totals.sessions}" to if (s.totals.sessions == 1) "sitting" else "sittings",
                    pace, (s.totals.avgMinutes?.let { statDuration(it) } ?: "—") to "typical sitting")
                Column(Modifier.fillMaxWidth().mqPanel(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    cells.chunked(2).forEach { row -> Row { row.forEach { (v, l) -> Column(Modifier.weight(1f)) { Text(v, style = T.body(22f, 800).copy(fontFeatureSettings = "tnum"), color = C.ink); Text(l, style = T.caption, color = C.inkMuted) } } } }
                    if (s.sources.isNotEmpty()) FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        s.sources.forEach { src -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                            Box(Modifier.size(8.dp).clip(CircleShape).background(sourceColor(C, src.source))); Text(src.label, style = T.caption, color = C.inkSoft)
                            Text("${src.sessions} · ${statDuration(src.minutes)}", style = T.caption, color = C.inkMuted) } }
                    }
                }
                if (s.sessions.isNotEmpty()) { Eyebrow("The whole book"); BookRibbon(s) }
                if (s.days.isNotEmpty()) { Eyebrow("Days you read it"); ReadingCalendar(s.days) }
                if (s.chapters.isNotEmpty()) ChapterPace(s.chapters)
            }, trailing = {
                SectionHeader("Sittings", count = "${s.sessions.size}")
                if (s.sessions.isEmpty()) Text("No sittings yet. Start a session on the book’s page, or read it in Folio — every sitting lands here with its time, pages and chapters.", style = T.sub, color = C.inkMuted)
                else {
                    Text("Tap one to fix its date, length or pages.", style = T.caption, color = C.inkMuted)
                    s.sessions.groupBy { it.startedAt.take(7) }.forEach { (key, items) ->
                        Eyebrow(MQTime.monthKeyLabel(key))
                        Column(Modifier.fillMaxWidth().mqPanel()) {
                            items.forEachIndexed { i, it ->
                                SittingRow(it, s.book.pages) { editing = it }
                                if (i < items.lastIndex) HorizontalDivider(color = C.hairline)
                            }
                        }
                    }
                }
            })
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(3) }
        }
    }
    editing?.let { e -> SessionEditorSheet(e.logEntry, s?.book?.pages, onDismiss = { editing = null }) { data.refresh() } }
}

@Composable
private fun MarqueeSign(s: BookStats) {
    val st = s.state
    val (kicker, date, line) = when {
        st?.readingState == ReadingState.FINISHED && st.finishedAt != null -> Triple("Finished", shortDate(st.finishedAt), "${s.totals.days} day${if (s.totals.days == 1) "" else "s"} of reading, ${statDuration(s.totals.minutes)} in all")
        s.forecast != null -> {
            val f = s.forecast
            val rate = if (f.unit == "pct") "${LibraryFormat.one(f.perDay ?: 0.0)}% a day" else "${LibraryFormat.one(f.perDay ?: 0.0)} pages a day"
            Triple("Finishing around", shortDate(f.date), "${f.days} day${if (f.days == 1) "" else "s"} at your recent $rate" + (f.hoursLeft?.let { " — about ${statDuration((it * 60).roundToInt())} of reading left" } ?: ""))
        }
        st?.readingState == ReadingState.READING -> Triple("No finish date yet", null, "A forecast appears after a few sittings in the last three weeks.")
        else -> return
    }
    val bulbs = C.brassBright
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(C.panel).border(1.dp, if (date != null) C.brassDim else C.hairline, RoundedCornerShape(16.dp))) {
        if (date != null) Canvas(Modifier.matchParentSize().padding(horizontal = 12.dp, vertical = 7.dp)) {
            val n = (size.width / 22.dp.toPx()).toInt()
            for (i in 0..n) { val x = i * size.width / n; drawCircle(bulbs.copy(alpha = if (i % 2 == 0) 0.9f else 0.35f), 2.2.dp.toPx(), Offset(x, 0f)); drawCircle(bulbs.copy(alpha = if (i % 2 == 1) 0.9f else 0.35f), 2.2.dp.toPx(), Offset(x, size.height)) }
        }
        Column(Modifier.padding(horizontal = 18.dp, vertical = 24.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(kicker, style = T.body(13f, 600), color = C.inkSoft)
            date?.let { Text(it.uppercase(), style = T.wordmark(46f), color = C.brass, maxLines = 1) }
            Text(line, style = T.sub, color = C.inkSoft)
        }
    }
}

@Composable
private fun BookRibbon(s: BookStats) {
    val colors = C
    val here = s.state?.fraction ?: s.book.pages?.let { p -> s.state?.progress?.let { it.toDouble() / maxOf(1, p) } }
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Canvas(Modifier.fillMaxWidth().height(34.dp)) {
            drawRoundRect(colors.panelRaised, cornerRadius = CornerRadius(8f))
            s.sessions.reversed().forEach { sit ->
                val span = sit.span(s.book.pages) ?: return@forEach
                drawRect(sourceColor(colors, sit.source).copy(alpha = 0.85f), Offset((span.first * size.width).toFloat(), 4f), Size(((span.second - span.first) * size.width).toFloat().coerceAtLeast(2f), size.height - 8f))
            }
            listOf(0.25f, 0.5f, 0.75f).forEach { drawLine(colors.ground.copy(alpha = 0.6f), Offset(it * size.width, 0f), Offset(it * size.width, size.height), 1f) }
            here?.let { h -> val x = (h * size.width).toFloat(); drawLine(colors.ink, Offset(x, -2f), Offset(x, size.height + 2f), 3f) }
        }
        Row { Text("start", style = T.caption, color = C.inkMuted); Spacer(Modifier.weight(1f)); if (here != null) Text("you’re here · ${(here * 100).roundToInt()}%", style = T.caption, color = C.ink); Spacer(Modifier.weight(1f)); Text("end", style = T.caption, color = C.inkMuted) }
    }
}

@Composable
private fun ReadingCalendar(days: List<BookStats.Day>) {
    val byDate = days.associateBy { it.date.take(10) }
    val first = days.minOfOrNull { it.date.take(10) }?.let { LocalDate.parse(it) } ?: return
    val last = maxOf(days.maxOf { LocalDate.parse(it.date.take(10)) }, first)
    val start = first.minusDays((first.dayOfWeek.value % 7).toLong())
    val weeks = ((java.time.temporal.ChronoUnit.DAYS.between(start, last) / 7) + 1).toInt().coerceAtMost(53)
    val max = days.maxOf { it.minutes }.coerceAtLeast(1.0)
    val brass = C.brass; val empty = C.panelRaised
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Canvas(Modifier.fillMaxWidth().height((7 * 16).dp)) {
            val cell = minOf(size.width / weeks, size.height / 7)
            for (w in 0 until weeks) for (d in 0 until 7) {
                val day = start.plusDays((w * 7 + d).toLong())
                if (day.isAfter(last)) continue
                val v = byDate[day.toString()]?.minutes ?: 0.0
                drawRoundRect(if (v > 0) brass.copy(alpha = (0.2 + 0.8 * v / max).toFloat()) else empty, Offset(w * cell + 1, d * cell + 1), Size(cell - 2, cell - 2), CornerRadius(3f))
            }
        }
        Text("${days.size} day${if (days.size == 1) "" else "s"} · ${shortDate(first.toString())} – ${shortDate(last.toString())}", style = T.caption, color = C.inkMuted)
    }
}

@Composable
private fun ChapterPace(chapters: List<BookStats.Chapter>) {
    var all by remember { mutableStateOf(false) }
    val shown = if (all) chapters else chapters.take(12)
    val typical = chapters.mapNotNull { it.perHour }.sorted().let { if (it.isEmpty()) null else it[it.size / 2] }
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Eyebrow("Chapter by chapter")
        Column(Modifier.fillMaxWidth().mqPanel()) {
            shown.forEachIndexed { i, c ->
                Row(Modifier.padding(horizontal = 12.dp, vertical = 9.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(c.title, style = T.body(13.5f), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    Text(statDuration(c.minutes.roundToInt()), style = T.caption.copy(fontFeatureSettings = "tnum"), color = C.inkSoft, modifier = Modifier.width(76.dp))
                    val ph = c.perHour
                    val tint = if (ph != null && typical != null) (if (ph > typical * 1.15) C.chartGreen else if (ph < typical * 0.85) C.chartOrange else C.inkSoft) else C.inkMuted
                    Text(ph?.let { "${it.roundToInt()}${if (c.paceUnit == "pct") "%" else " p"}/h" } ?: "—", style = T.caption.copy(fontFeatureSettings = "tnum"), color = tint, modifier = Modifier.width(64.dp))
                }
                if (i < shown.lastIndex) HorizontalDivider(color = C.hairline)
            }
        }
        if (chapters.size > 12) Text(if (all) "Show fewer" else "Show all ${chapters.size}", style = T.body(12f, 700), color = C.brass, modifier = Modifier.clickable { all = !all })
    }
}

@Composable
private fun SittingRow(s: BookStats.Sitting, pages: Int?, onClick: () -> Unit) {
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Box(Modifier.size(7.dp).clip(CircleShape).background(sourceColor(C, s.source)))
            Text(MQTime.dayLabel(s.startedAt), style = T.body(14f, 700), color = C.ink, modifier = Modifier.weight(1f))
            Text(listOfNotNull(if (s.checkpoint) null else statDuration(s.minutes), s.pages?.takeIf { it > 0 }?.let { "$it p" }).joinToString(" · "), style = T.caption.copy(fontFeatureSettings = "tnum"), color = C.inkSoft)
            Text(s.sourceLabel, style = T.body(10f, 700), color = sourceColor(C, s.source))
        }
        val ch = listOfNotNull(s.startChapter, s.endChapter?.takeIf { it != s.startChapter }).joinToString(" → ")
        if (ch.isNotEmpty()) Text(ch, style = T.caption, color = C.inkMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
        s.span(pages)?.let { (a, b) ->
            val col = sourceColor(C, s.source); val track = C.panelRaised
            Canvas(Modifier.fillMaxWidth().height(4.dp)) { drawRect(track); drawRect(col, Offset((a * size.width).toFloat(), 0f), Size(((b - a) * size.width).toFloat().coerceAtLeast(2f), size.height)) }
        }
    }
}

// ================= Series and author pages

/** Your copies first, then the rest of the series or bibliography from Hardcover to add from. */
@Composable
fun BookBrowseScreen(by: String, name: String) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val data = rememberRemote<BrowseResponse>("browse-$by-$name") { it.get("books/browse", mapOf("by" to by, "name" to name)) }
    var added by remember { mutableStateOf(setOf<Int>()) }
    val b = data.value
    ScreenScaffold(name, { nav.popBackStack() }) { pad ->
        when {
            b != null -> LazyVerticalGrid(GridCells.Adaptive(104.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
                            if (b.isAuthor) RemoteImage(b.header?.image, Modifier.size(72.dp).clip(CircleShape), placeholder = Icons.Filled.AutoStories)
                            else Box(Modifier.size(56.dp).clip(RoundedCornerShape(12.dp)).background(C.brassSoft), contentAlignment = Alignment.Center) { Icon(Icons.Filled.AutoStories, null, tint = C.brass) }
                            Column {
                                Text(if (b.isAuthor) "AUTHOR" else "SERIES", style = T.eyebrow, color = C.brass)
                                Text(b.header?.name ?: name, style = T.title, color = C.ink)
                                b.header?.booksCount?.let { Text("$it books on Hardcover", style = T.caption, color = C.inkMuted) }
                            }
                        }
                        b.header?.bio?.takeIf { it.isNotEmpty() }?.let { ExpandableText(it, 4) }
                    }
                }
                if (b.shelf.isNotEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }) { SectionHeader("On your shelf", count = "${b.shelf.size}") }
                    items(b.shelf, key = { "s${it.id}" }) { it ->
                        Column(Modifier.clip(RoundedCornerShape(8.dp)).clickable { nav.push(BookRoute(it.id)) }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Box { Poster(it.cover, Modifier.fillMaxWidth()); if (!b.isAuthor) SeriesPosition.label(it.seriesPos)?.let { p -> OnArtBadge(p, Modifier.align(Alignment.TopStart).padding(6.dp)) }
                                it.readingState?.let { st -> OnArtBadge(st.label, Modifier.align(Alignment.BottomStart).padding(6.dp)) } }
                            Text(it.displayTitle, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
                if (b.more.isNotEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }) { SectionHeader(if (b.isAuthor) "More by ${b.header?.name ?: name}" else "The rest of the series", count = "${b.more.size}") }
                    items(b.more, key = { "m${it.hcId}" }) { r -> MoreTile(r, !b.isAuthor, r.hcId in added, { nav.push(BookRoute(r.hcId, preview = true)) }) { st ->
                        added = added + r.hcId; scope.launch { runCatching { session.client?.send("books/add", bookAddBody(r, st)) }; session.noteReading() } } }
                }
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(3) }
        }
    }
}

@Composable
private fun MoreTile(r: BookSearchResult, series: Boolean, added: Boolean, onOpen: () -> Unit, onAdd: (ReadingState) -> Unit) {
    var menu by remember { mutableStateOf(false) }
    Column(Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onOpen), verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Box {
            Poster(r.cover, Modifier.fillMaxWidth())
            if (series) SeriesPosition.label(r.seriesPos)?.let { OnArtBadge(it, Modifier.align(Alignment.TopStart).padding(6.dp)) }
            Box(Modifier.align(Alignment.BottomEnd).padding(6.dp)) {
                Box(Modifier.size(32.dp).clip(CircleShape).background(if (added) C.panelRaised else C.brassFill).clickable(enabled = !added) { menu = true }, contentAlignment = Alignment.Center) {
                    Icon(if (added) Icons.Filled.Check else Icons.Filled.Add, "Add ${r.displayTitle}", tint = if (added) C.brass else C.brassOnFill, modifier = Modifier.size(17.dp))
                }
                DropdownMenu(menu, { menu = false }, containerColor = C.panelRaised) { listOf(ReadingState.WANT, ReadingState.READING, ReadingState.FINISHED).forEach { st -> DropdownMenuItem({ Text(st.label) }, { menu = false; onAdd(st) }) } }
            }
        }
        Text(r.displayTitle, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(listOfNotNull(r.year?.toString(), r.communityRating?.let { "★ ${LibraryFormat.one(it)}" }).joinToString(" · "), style = T.caption, color = C.inkMuted, maxLines = 1)
    }
}

// ================= Reading stats (all books / all manga)

@Composable
fun ReadingStatsScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    val data = rememberRemote<ReadingStatsResponse>("reading-stats") { it.get("reading/stats") }
    var tab by rememberSaveable { mutableIntStateOf(if (!session.tracksBooks && session.tracksManga) 1 else 0) }
    ScreenScaffold("Reading stats", { nav.popBackStack() }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        val v = data.value
        when {
            v != null -> FoldSpread(contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp), spacing = 18.dp, leading = {
                if (v.books != null && v.manga != null) Segmented(listOf("Books", "Manga"), tab) { tab = it }
                val s = (if (tab == 0) v.books else v.manga) ?: v.books ?: v.manga
                if (s == null || s.isEmpty) Text("Nothing logged yet. Progress and sessions land here as you read.", style = T.sub, color = C.inkMuted)
                else ReadingStatsTop(s, if (tab == 0) "pages" else "chapters")
            }, trailing = {
                val s = (if (tab == 0) v.books else v.manga) ?: v.books ?: v.manga
                if (s != null && !s.isEmpty) ReadingStatsCharts(s, if (tab == 0) "pages" else "chapters")
            })
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(3) }
        }
    }
}

@Composable
fun StatTile(value: String, label: String, modifier: Modifier = Modifier, accent: Boolean = false) {
    Column(modifier.mqPanel().padding(13.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, style = T.body(22f, 800).copy(fontFeatureSettings = "tnum"), color = if (accent) C.brass else C.ink, maxLines = 1)
        Text(label, style = T.caption, color = C.inkMuted, maxLines = 2)
    }
}

@Composable
private fun ReadingStatsTop(s: ReadingStats, unit: String) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatTile(s.totals.week.grouped, "$unit this week", Modifier.weight(1f), true)
            StatTile(s.totals.month.grouped, "$unit this month", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatTile(s.totals.year.grouped, "$unit this year", Modifier.weight(1f))
            StatTile("${s.finished.year}", "finished this year · ${s.finished.all} all time", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatTile("${LibraryFormat.one(s.totals.hoursAll)} h", "reading time · ${s.totals.sessions} sessions", Modifier.weight(1f))
            StatTile(s.pace?.let { "${it.roundToInt()}" } ?: "—", "$unit an hour", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatTile("${s.streak.current}", "day streak · best ${s.streak.longest}", Modifier.weight(1f), s.streak.current > 0)
            StatTile(s.avgSessionMin?.let { "$it min" } ?: "—", "typical session", Modifier.weight(1f))
        }
        s.fastest?.let { Text("Fastest finish: ${it.title} in ${it.days} day${if (it.days == 1) "" else "s"}", style = T.caption, color = C.inkSoft) }
        s.longest?.let { Text("Longest: ${it.title} — ${it.units.grouped} $unit", style = T.caption, color = C.inkSoft) }
        s.bigDay?.let { Text("Biggest day: ${MQTime.medium(it.date)} — ${it.units} $unit", style = T.caption, color = C.inkSoft) }
    }
}

@Composable
private fun ReadingStatsCharts(s: ReadingStats, unit: String) {
    val brass = C.brass; val hair = C.hairline
    s.daily30?.takeIf { it.isNotEmpty() }?.let { daily ->
        Eyebrow("Last 30 days")
        BarChart(daily.map { it.units.toFloat() }, Modifier.fillMaxWidth().height(110.dp), brass, hair)
    }
    s.monthly?.takeIf { it.isNotEmpty() }?.let { months ->
        Eyebrow("By month")
        BarChart(months.map { it.units.toFloat() }, Modifier.fillMaxWidth().height(130.dp), brass, hair)
        Row { Text(MQTime.monthKeyLabel(months.first().key), style = T.caption, color = C.inkMuted); Spacer(Modifier.weight(1f)); Text(MQTime.monthKeyLabel(months.last().key), style = T.caption, color = C.inkMuted) }
    }
    s.clock?.takeIf { it.size == 24 && it.any { v -> v > 0 } }?.let { clock ->
        Eyebrow("When you read")
        BarChart(clock.map { it.toFloat() }, Modifier.fillMaxWidth().height(90.dp), C.chartViolet, hair)
        Row { listOf("12a", "6a", "12p", "6p", "").forEach { Text(it, style = T.caption, color = C.inkMuted, modifier = Modifier.weight(1f)) } }
    }
    s.weekday?.takeIf { it.size == 7 && it.any { v -> v > 0 } }?.let { wd ->
        Eyebrow("Days of the week")
        BarChart(wd.map { it.toFloat() }, Modifier.fillMaxWidth().height(80.dp), C.chartAqua, hair)
        Row { listOf("M", "T", "W", "T", "F", "S", "S").forEach { Text(it, style = T.caption, color = C.inkMuted, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center) } }
    }
    s.ratingHist?.takeIf { it.isNotEmpty() }?.let { h ->
        Eyebrow("Your ratings")
        BarChart((1..10).map { (h[it.toString()] ?: 0).toFloat() }, Modifier.fillMaxWidth().height(80.dp), C.brassBright, hair, colorFor = { i -> dev.kadenthompson.marquee.design.MqColors.rating(i + 1) })
    }
}

/** Bars on a baseline with a light grid and an emphasised maximum. */
@Composable
fun BarChart(values: List<Float>, modifier: Modifier, color: Color, grid: Color, colorFor: ((Int) -> Color)? = null) {
    Canvas(modifier) {
        val max = (values.maxOrNull() ?: 0f).coerceAtLeast(1f)
        listOf(0.5f, 1f).forEach { f -> drawLine(grid, Offset(0f, size.height * (1 - f)), Offset(size.width, size.height * (1 - f)), 1f) }
        drawLine(grid, Offset(0f, size.height), Offset(size.width, size.height), 1.5f)
        val w = size.width / values.size
        val top = values.indexOf(values.maxOrNull() ?: 0f)
        values.forEachIndexed { i, v ->
            val h = v / max * size.height
            val c = colorFor?.invoke(i) ?: color
            drawRoundRect(if (i == top || colorFor != null) c else c.copy(alpha = 0.6f), Offset(i * w + w * 0.15f, size.height - h), Size(w * 0.7f, h), CornerRadius(3f))
        }
    }
}
