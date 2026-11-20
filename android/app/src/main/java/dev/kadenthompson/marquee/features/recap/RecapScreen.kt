package dev.kadenthompson.marquee.features.recap

import android.content.Intent
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.TwoPane
import dev.kadenthompson.marquee.design.grouped
import dev.kadenthompson.marquee.model.Recap
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private object Gel {
    val amber = Color(0xFFF0B544); val velvet = Color(0xFFC2414F); val teal = Color(0xFF17A377); val violet = Color(0xFF8F7FE8)
    val blue = Color(0xFF3987E5); val light = Color(0xFFFFD98A); val ground = Color(0xFF0C0A07); val ink = Color(0xFFF2ECDF)
    val inkSoft = Color(0xFFB3A88F); val muted = Color(0xFF7C7360)
}

private enum class Slide(val gel: Color) {
    INTRO(Gel.amber), QUIZ(Gel.velvet), COUNT(Gel.amber), SHOW(Gel.teal), PERSONA(Gel.violet), PRIME(Gel.blue), MONTH(Gel.amber),
    GENRES(Gel.teal), FILMS(Gel.velvet), READING(Gel.teal), READREC(Gel.velvet), HOUSE(Gel.violet), RECORD(Gel.blue), OUTRO(Gel.amber);

    companion object {
        fun build(r: Recap): List<Slide> {
            val watched = (r.episodes ?: 0) + (r.movies ?: 0) > 0
            return buildList {
                add(INTRO)
                if (watched && Quiz.of(r) != null) add(QUIZ)
                if (watched) add(COUNT)
                if (!r.topShows.isNullOrEmpty()) add(SHOW)
                if (r.persona != null) add(PERSONA)
                if (r.peakHour != null && r.hours?.any { it > 0 } == true) add(PRIME)
                if (r.months?.any { it > 0 } == true) add(MONTH)
                if ((r.genres?.size ?: 0) >= 2) add(GENRES)
                if (!r.topMovies.isNullOrEmpty()) add(FILMS)
                r.reading?.let { rd -> add(READING); if (rd.favourite != null || rd.topAuthor != null || rd.longest != null || rd.fastest != null) add(READREC) }
                if ((r.household?.of ?: 0) > 1) add(HOUSE)
                if (r.binge != null || r.firstWatch != null || r.lastWatch != null) add(RECORD)
                add(OUTRO)
            }
        }
    }
}

private data class Quiz(val truth: Int, val options: List<Int>, val isHours: Boolean) {
    companion object {
        fun of(r: Recap): Quiz? {
            val hrs = ((r.minutes ?: 0) / 60.0).roundToInt()
            val isHours = hrs >= 4
            val truth = if (isHours) hrs else (r.episodes ?: 0) + (r.movies ?: 0)
            if (truth < 2) return null
            fun nice(v: Double) = if (v < 20) maxOf(1, v.roundToInt()) else if (v < 200) (v / 5).roundToInt() * 5 else (v / 10).roundToInt() * 10
            var lo = nice(truth * 0.55); var hi = nice(truth * 1.75)
            if (lo == truth) lo = maxOf(1, truth - 1); if (hi == truth) hi = truth + 2
            val opts = listOf(lo, truth, hi)
            val order = listOf(listOf(1, 0, 2), listOf(0, 2, 1), listOf(2, 1, 0))[r.year % 3]
            return Quiz(truth, order.map { opts[it] }, isHours)
        }
    }
}

private val glyphs = mapOf("owl" to "🦉", "lark" to "🌅", "weekender" to "🛋️", "cinephile" to "🎬", "bookworm" to "📚", "binger" to "🍿", "devotee" to "📺", "explorer" to "🧭", "regular" to "☕")
private fun hoursLabel(m: Int?): String { val t = m ?: 0; if (t < 60) return "$t min"; val h = t / 60.0; return if (h < 10) "%.1f hrs".format(h) else "${h.roundToInt()} hrs" }
private fun hourWord(h: Int?) = when (h) { null -> ""; 0 -> "midnight"; 12 -> "noon"; else -> "${if (h % 12 == 0) 12 else h % 12} ${if (h < 12) "am" else "pm"}" }
private fun compare(m: Int?): String {
    val h = (m ?: 0) / 60.0
    if (h < 1) return ""
    if (h < 8) { val f = maxOf(1, (h / 2).roundToInt()); return "About $f feature film${if (f == 1) "" else "s"}' worth." }
    if (h < 24) return "That's a whole waking day, start to finish."
    val d = h / 24; val fl = (h / 22).roundToInt()
    return "That's ${if (d < 10) "%.1f".format(d) else "${d.roundToInt()}"} days back to back" + if (fl >= 2) " — or $fl flights from London to Sydney." else "."
}
private val months = listOf("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")

/** Year in Review: a night at the pictures, one slide at a time. Tap to go on, tap the left edge to go back. */
@Composable
fun RecapScreen(year: Int, username: String?) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val ctx = LocalContext.current
    val isMe = username == null || username.equals(session.me?.username, true)
    var recap by remember { mutableStateOf<Recap?>(null) }
    var failure by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(year, username) {
        val c = session.client ?: return@LaunchedEffect
        runCatching { c.get<Recap>(if (isMe) "recap/$year" else "profile/$username/recap/$year") }.onSuccess { r ->
            if (r.locked == true) failure = "$year's Year in Review premieres ${r.release?.let { "on ${dev.kadenthompson.marquee.design.MQTime.medium(it)}" } ?: "at the end of the year"}."
            else if (!r.hasData) failure = "There's nothing to look back on for $year yet."
            else { recap = r; if (isMe) runCatching { c.send("recap/$year/seen") } }
        }.onFailure { failure = it.friendly }
    }
    Box(Modifier.fillMaxSize().background(Gel.ground)) {
        val r = recap
        if (r == null) Column(Modifier.align(Alignment.Center).padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("$year", style = T.wordmark(54f), color = Gel.amber)
            Text(failure ?: "Rolling the film…", style = T.sub, color = Gel.inkSoft, textAlign = TextAlign.Center)
        } else {
            val slides = remember(r) { Slide.build(r) }
            val share = {
                val bits = listOfNotNull((r.episodes ?: 0).takeIf { it > 0 }?.let { "${it.grouped} episodes" }, (r.movies ?: 0).takeIf { it > 0 }?.let { "$it films" }, hoursLabel(r.minutes))
                val text = "${if (isMe) "My" else "Their"} ${r.year} on Marquee${r.persona?.let { " (${it.title})" } ?: ""}: ${bits.joinToString(", ")}.${r.topShows?.firstOrNull()?.let { " Show of the year: ${it.title}." } ?: ""}"
                ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text) }, null))
            }
            // On a foldable opened out it reads like a programme: two slides a spread.
            TwoPane(
                leading = { Story(r, slides, isMe, step = 2, offset = 0, onShare = share) },
                trailing = { Story(r, slides, isMe, step = 2, offset = 1, onShare = share) },
                single = { Story(r, slides, isMe, step = 1, offset = 0, onShare = share) },
            )
        }
        IconButton({ nav.popBackStack() }, Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(6.dp)) { Icon(Icons.Filled.Close, "Close", tint = Gel.ink) }
    }
}

@Composable
private fun Story(r: Recap, slides: List<Slide>, isMe: Boolean, step: Int, offset: Int, onShare: () -> Unit) {
    val mine = slides.filterIndexed { i, _ -> i % step == offset }
    if (mine.isEmpty()) return
    val pager = rememberPagerState { mine.size }
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    var quizAnswer by remember { mutableStateOf<Int?>(null) }
    Box(Modifier.fillMaxSize()) {
        HorizontalPager(pager, Modifier.fillMaxSize()) { i ->
            val s = mine[i]
            Box(Modifier.fillMaxSize().pointerInput(i) {
                detectTapGestures { pos -> scope.launch { if (pos.x < size.width * 0.28f) pager.animateScrollToPage(maxOf(0, i - 1)) else if (i < mine.lastIndex) pager.animateScrollToPage(i + 1) } }
            }) {
                Stage(s.gel)
                Canvas360 { SlideContent(s, r, isMe, pager.currentPage == i, quizAnswer, { quizAnswer = it; haptic.performHapticFeedback(HapticFeedbackType.Confirm) }, onShare) }
            }
        }
        // progress segments
        Row(Modifier.fillMaxWidth().statusBarsPadding().padding(start = 14.dp, end = 56.dp, top = 10.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            mine.indices.forEach { i -> Box(Modifier.weight(1f).height(3.dp).clip(CircleShape).background(if (i <= pager.currentPage) Gel.light else Gel.ink.copy(alpha = 0.18f))) }
        }
    }
}

@Composable
private fun Stage(gel: Color) {
    Canvas(Modifier.fillMaxSize()) {
        drawRect(Gel.ground)
        drawRect(Brush.radialGradient(listOf(gel.copy(alpha = 0.46f), Color.Transparent), center = Offset(size.width / 2, -size.height * 0.06f), radius = size.width * 1.1f))
        drawRect(Brush.radialGradient(listOf(gel.copy(alpha = 0.14f), Color.Transparent), center = Offset(size.width / 2, size.height * 1.1f), radius = size.width * 0.75f))
    }
}

/** Drawn on one 360×640 canvas fitted to the screen, so it looks the same on every phone. */
@Composable
private fun Canvas360(content: @Composable () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(top = 24.dp), contentAlignment = Alignment.Center) {
        val scale = minOf(maxWidth.value / 360f, maxHeight.value / 640f)
        Box(Modifier.requiredSize(360.dp, 640.dp).graphicsLayer { scaleX = scale; scaleY = scale }, contentAlignment = Alignment.Center) { content() }
    }
}

@Composable private fun Say(t: String, size: Float = 18f) = Text(t, style = T.body(size, 600), color = Gel.ink, textAlign = TextAlign.Center)
@Composable private fun Kicker(t: String, gel: Color) = Text(t.uppercase(), style = T.body(12f, 800).copy(letterSpacing = 2.4.sp), color = gel, textAlign = TextAlign.Center)
@Composable private fun Big(t: String, gel: Color, size: Float = 96f) = Text(t, style = T.wordmark(size), color = gel, textAlign = TextAlign.Center, maxLines = 1)
@Composable private fun Soft(t: String) = Text(t, style = T.body(14.5f, 500), color = Gel.inkSoft, textAlign = TextAlign.Center)

@Composable
private fun SlideContent(s: Slide, r: Recap, isMe: Boolean, active: Boolean, quizAnswer: Int?, onAnswer: (Int) -> Unit, onShare: () -> Unit) {
    val your = if (isMe) "Your" else "Their"
    val you = if (isMe) "you" else "they"
    Column(Modifier.fillMaxSize().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
        when (s) {
            Slide.INTRO -> Leader(r.year, "$your year in lights", active)
            Slide.QUIZ -> {
                val q = Quiz.of(r)!!
                Kicker("A little quiz", s.gel)
                Say(if (q.isHours) "How many hours do $you think $you spent watching in ${r.year}?" else "How many episodes and films do $you think $you watched in ${r.year}?", 20f)
                q.options.forEach { o ->
                    val picked = quizAnswer == o; val right = o == q.truth
                    val bg = when { quizAnswer == null -> Gel.ink.copy(alpha = 0.08f); right -> Gel.teal.copy(alpha = 0.5f); picked -> Gel.velvet.copy(alpha = 0.5f); else -> Gel.ink.copy(alpha = 0.04f) }
                    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(bg).border(1.dp, Gel.ink.copy(alpha = 0.2f), RoundedCornerShape(14.dp))
                        .clickable(enabled = quizAnswer == null) { onAnswer(o) }.padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
                        Text(o.grouped, style = T.body(26f, 800), color = Gel.ink)
                    }
                }
                if (quizAnswer != null) Soft(if (quizAnswer == q.truth) "Spot on." else "It was ${q.truth.grouped}. Tap on.")
            }
            Slide.COUNT -> {
                Kicker("${r.year} on screen", s.gel)
                CountUp(((r.minutes ?: 0) / 60.0).roundToInt(), active, s.gel)
                Say("hours of telly and film")
                Soft(listOfNotNull((r.episodes ?: 0).takeIf { it > 0 }?.let { "${it.grouped} episodes" }, (r.movies ?: 0).takeIf { it > 0 }?.let { "$it films" }, r.newShows?.takeIf { it > 0 }?.let { "$it new shows" }).joinToString(" · "))
                Soft(compare(r.minutes))
            }
            Slide.SHOW -> {
                val t = r.topShows!!.first()
                Kicker("Show of the year", s.gel)
                Poster(t.poster, Modifier.width(170.dp).rotate(-2f), radius = 12.dp)
                Text(t.title, style = T.body(26f, 800), color = Gel.ink, textAlign = TextAlign.Center)
                Soft("${t.eps} episodes${t.mins?.let { " · ${hoursLabel(it)}" } ?: ""}")
                r.topShows.drop(1).take(3).forEachIndexed { i, o -> Soft("${i + 2}. ${o.title} — ${o.eps} eps") }
            }
            Slide.PERSONA -> {
                val p = r.persona!!
                Kicker("$your ${r.year} persona", s.gel)
                Stamp(glyphs[p.key] ?: "🎟️", r.year, s.gel, active)
                Text(p.title.uppercase(), style = T.wordmark(34f), color = s.gel, textAlign = TextAlign.Center)
                Say(p.line, 16f)
            }
            Slide.PRIME -> {
                Kicker("Prime time", s.gel)
                Big(hourWord(r.peakHour), s.gel, 60f)
                Say("was when the lights went down most${r.peakWeekday?.let { ", especially on ${it}s" } ?: ""}.", 16f)
                r.hours?.let { h -> Bars(h, s.gel, Modifier.fillMaxWidth().height(120.dp)); Row(Modifier.fillMaxWidth()) { listOf("12a", "6a", "12p", "6p").forEach { Text(it, style = T.caption, color = Gel.muted, modifier = Modifier.weight(1f)) } } }
                r.daysWatched?.let { Soft("$it days with something on") }
            }
            Slide.MONTH -> {
                val m = r.months!!; val top = m.indexOf(m.max())
                Kicker("The big month", s.gel)
                Big(months[top].uppercase(), s.gel, 52f)
                Say("${(r.busiestMonthCount ?: m[top]).grouped} watched in ${months[top]}", 16f)
                Bars(m, s.gel, Modifier.fillMaxWidth().height(130.dp), highlight = top)
                Row(Modifier.fillMaxWidth()) { months.forEach { Text(it.take(1), style = T.caption, color = Gel.muted, modifier = Modifier.weight(1f), textAlign = TextAlign.Center) } }
            }
            Slide.GENRES -> {
                Kicker("$your genres", s.gel)
                val g = r.genres!!.take(5); val max = g.maxOf { it.count }.coerceAtLeast(1)
                g.forEachIndexed { i, x ->
                    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Row { Text(x.name, style = T.body(if (i == 0) 22f else 16f, 800), color = Gel.ink, modifier = Modifier.weight(1f)); Text("${x.count}", style = T.body(14f, 700), color = Gel.inkSoft) }
                        Box(Modifier.fillMaxWidth(x.count.toFloat() / max).height(if (i == 0) 10.dp else 6.dp).clip(CircleShape).background(if (i == 0) s.gel else s.gel.copy(alpha = 0.5f)))
                    }
                }
            }
            Slide.FILMS -> {
                Kicker("At the pictures", s.gel)
                Big("${r.movies ?: 0}", s.gel, 80f); Say("films${r.movieMinutes?.let { " · ${hoursLabel(it)}" } ?: ""}")
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { r.topMovies!!.take(3).forEachIndexed { i, m -> Poster(m.poster, Modifier.width(92.dp).rotate((i - 1) * 4f), radius = 8.dp) } }
                r.topMovies?.firstOrNull { it.rating != null }?.let { Soft("Top-rated: ${it.title} ★${it.rating}") }
            }
            Slide.READING -> {
                val rd = r.reading!!
                Kicker("$your reading year", s.gel)
                Row(horizontalArrangement = Arrangement.spacedBy((-24).dp)) { rd.covers?.take(4)?.forEachIndexed { i, c -> Poster(c.cover, Modifier.width(88.dp).rotate((i - 1.5f) * 5f), radius = 6.dp) } }
                Big("${(rd.books ?: 0) + (rd.manga ?: 0)}", s.gel, 72f)
                Say(listOfNotNull((rd.books ?: 0).takeIf { it > 0 }?.let { "$it book${if (it == 1) "" else "s"}" }, (rd.manga ?: 0).takeIf { it > 0 }?.let { "$it manga" }).joinToString(" and ").ifEmpty { "finished" })
                Soft(listOfNotNull((rd.pages ?: 0).takeIf { it > 0 }?.let { "${it.grouped} pages" }, (rd.chapters ?: 0).takeIf { it > 0 }?.let { "${it.grouped} chapters" }, (rd.minutes ?: 0).takeIf { it > 0 }?.let { hoursLabel(it) + " reading" }).joinToString(" · "))
                rd.goal?.target?.let { t -> Soft("Goal: ${rd.goal.done ?: 0} of $t") }
            }
            Slide.READREC -> {
                val rd = r.reading!!
                Kicker("On the shelf", s.gel)
                rd.favourite?.let { f -> Poster(f.cover, Modifier.width(130.dp), radius = 8.dp); Say("Favourite: ${f.title}${f.rating?.let { " ★$it" } ?: ""}", 16f) }
                rd.topAuthor?.let { Soft("Most-read author: ${it.name} — ${it.count} books, ${it.pages.grouped} pages") }
                rd.longest?.let { Soft("Longest: ${it.title}${it.pages?.let { p -> " (${p.grouped} pages)" } ?: ""}") }
                rd.fastest?.let { Soft("Fastest: ${it.title} in ${if (it.days == 0) "a day" else "${it.days} days"}") }
            }
            Slide.HOUSE -> {
                val h = r.household!!
                Kicker("Around the house", s.gel)
                Big("#${h.rank}", s.gel, 110f)
                Say("of ${h.of} in the household for time watched", 17f)
            }
            Slide.RECORD -> {
                Kicker("The records", s.gel)
                r.binge?.let { b -> Big("${b.count}", s.gel, 80f); Say("episodes in one day — ${dev.kadenthompson.marquee.design.MQTime.medium(b.date)}${b.top?.let { ", mostly $it" } ?: ""}", 16f) }
                r.streak?.let { st -> Soft("Longest streak: ${st.days} days in a row") }
                r.firstWatch?.title?.let { Soft("First of the year: $it") }
                r.lastWatch?.title?.let { Soft("Latest: $it") }
            }
            Slide.OUTRO -> Ticket(r, isMe, onShare)
        }
    }
}

/** A film-leader countdown — 3, 2, 1 — then the title rolls in. */
@Composable
private fun Leader(year: Int, title: String, active: Boolean) {
    val sweep = remember { Animatable(0f) }
    var n by remember { mutableStateOf(3) }
    var done by remember { mutableStateOf(false) }
    LaunchedEffect(active) {
        if (!active || done) return@LaunchedEffect
        for (i in 3 downTo 1) { n = i; sweep.snapTo(0f); sweep.animateTo(360f, tween(700, easing = LinearEasing)) }
        done = true
    }
    val titleA by animateFloatAsState(if (done) 1f else 0f, tween(600), label = "t")
    Box(Modifier.size(240.dp), contentAlignment = Alignment.Center) {
        if (!done) {
            Canvas(Modifier.fillMaxSize()) {
                drawCircle(Gel.ink.copy(alpha = 0.25f), size.minDimension / 2, style = Stroke(3f))
                drawCircle(Gel.ink.copy(alpha = 0.15f), size.minDimension / 2.6f, style = Stroke(2f))
                drawArc(Gel.amber.copy(alpha = 0.35f), -90f, sweep.value, true)
                drawLine(Gel.ink.copy(alpha = 0.2f), Offset(0f, size.height / 2), Offset(size.width, size.height / 2), 2f)
                drawLine(Gel.ink.copy(alpha = 0.2f), Offset(size.width / 2, 0f), Offset(size.width / 2, size.height), 2f)
            }
            Text("$n", style = T.wordmark(110f), color = Gel.ink)
        } else Column(Modifier.alpha(titleA), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("MARQUEE PRESENTS", style = T.body(12f, 800).copy(letterSpacing = 3.sp), color = Gel.inkSoft)
            Text("$year", style = T.wordmark(84f), color = Gel.amber)
            Text(title, style = T.body(22f, 700), color = Gel.ink, textAlign = TextAlign.Center)
            Text("tap to begin", style = T.caption, color = Gel.muted)
        }
    }
}

@Composable
private fun CountUp(target: Int, active: Boolean, gel: Color) {
    val v = remember { Animatable(0f) }
    LaunchedEffect(active) { if (active) v.animateTo(target.toFloat(), tween(1400)) }
    Big(v.value.roundToInt().grouped, gel, 104f)
}

/** The persona as a rubber stamp, slammed down. */
@Composable
private fun Stamp(glyph: String, year: Int, gel: Color, active: Boolean) {
    val s by animateFloatAsState(if (active) 1f else 1.6f, spring(0.45f, 400f), label = "s")
    Box(Modifier.size(200.dp).scale(s).rotate(-8f), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(gel, size.minDimension / 2, style = Stroke(6f))
            drawCircle(gel.copy(alpha = 0.6f), size.minDimension / 2 - 14f, style = Stroke(2f))
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(glyph, fontSize = 64.sp)
            Text("CLASS OF $year", style = T.body(11f, 800).copy(letterSpacing = 2.sp), color = gel)
        }
    }
}

@Composable
private fun Bars(values: List<Int>, gel: Color, modifier: Modifier, highlight: Int? = null) {
    Canvas(modifier) {
        val max = values.maxOrNull()?.coerceAtLeast(1) ?: 1
        val w = size.width / values.size
        val top = highlight ?: values.indexOf(max)
        values.forEachIndexed { i, v ->
            val h = v.toFloat() / max * size.height
            drawRoundRect(if (i == top) gel else gel.copy(alpha = 0.4f), Offset(i * w + w * 0.15f, size.height - h), Size(w * 0.7f, h), CornerRadius(3f))
        }
    }
}

/** A ticket stub to keep: admit one, the year in numbers, and Share. */
@Composable
private fun Ticket(r: Recap, isMe: Boolean, onShare: () -> Unit) {
    Kicker("That's a wrap", Gel.amber)
    Box(Modifier.width(280.dp).clip(RoundedCornerShape(14.dp)).background(Gel.light).padding(18.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("ADMIT ONE", style = T.body(11f, 800).copy(letterSpacing = 3.sp), color = Color(0xFF6B4A0E))
            Text("${r.year}", style = T.wordmark(56f), color = Color(0xFF2A1A04))
            r.persona?.let { Text(it.title, style = T.body(18f, 800), color = Color(0xFF2A1A04)) }
            Canvas(Modifier.fillMaxWidth().height(2.dp)) { var x = 0f; while (x < size.width) { drawLine(Color(0xFF6B4A0E), Offset(x, 0f), Offset(x + 8f, 0f), 2f); x += 16f } }
            Row { Column(Modifier.weight(1f)) { Text(hoursLabel(r.minutes), style = T.body(20f, 800), color = Color(0xFF2A1A04)); Text("watched", style = T.caption, color = Color(0xFF6B4A0E)) }
                Column(Modifier.weight(1f)) { Text("${(r.episodes ?: 0).grouped}", style = T.body(20f, 800), color = Color(0xFF2A1A04)); Text("episodes", style = T.caption, color = Color(0xFF6B4A0E)) } }
            r.topShows?.firstOrNull()?.let { Text("Show of the year: ${it.title}", style = T.body(13f, 700), color = Color(0xFF2A1A04), maxLines = 2, overflow = TextOverflow.Ellipsis) }
        }
    }
    Row(Modifier.clip(CircleShape).background(Gel.amber).clickable(onClick = onShare).padding(horizontal = 22.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Icon(Icons.Filled.Share, null, tint = Color(0xFF221703)); Text("Share ${if (isMe) "my" else "their"} year", style = T.headline, color = Color(0xFF221703))
    }
    Soft("Text only — nothing names your server.")
}
