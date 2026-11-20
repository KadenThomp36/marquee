package dev.kadenthompson.marquee.features.common

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.layout
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.ColorMatrix
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.MqColors
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.model.ActiveSession
import dev.kadenthompson.marquee.model.Person
import dev.kadenthompson.marquee.model.ReadingItem
import dev.kadenthompson.marquee.model.ReadingKind
import dev.kadenthompson.marquee.model.ReviewTeaser
import dev.kadenthompson.marquee.model.SearchResult
import dev.kadenthompson.marquee.model.ShowCard
import dev.kadenthompson.marquee.model.UpcomingEpisode
import dev.kadenthompson.marquee.model.WatchEntry
import dev.kadenthompson.marquee.nav.BookRoute
import dev.kadenthompson.marquee.nav.EpisodeRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MangaRoute
import dev.kadenthompson.marquee.nav.MovieRoute
import dev.kadenthompson.marquee.nav.ShowRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.Locale

/** A horizontal rail with the shared gutter. */
@Composable
fun Rail(
    modifier: Modifier = Modifier, state: LazyListState = rememberLazyListState(), spacing: Dp = MQ.railGap,
    content: LazyListScope.() -> Unit,
) {
    LazyRow(modifier.fillMaxWidth(), state = state, contentPadding = PaddingValues(horizontal = MQ.gutter),
        horizontalArrangement = Arrangement.spacedBy(spacing), verticalAlignment = Alignment.Top, content = content)
}

@Composable
fun PlainRailTitle(title: String) {
    Text(title, style = T.rail, color = C.ink, modifier = Modifier.padding(horizontal = MQ.gutter))
}

@Composable
fun EmptyLine(message: String) {
    Text(message, style = T.sub, color = C.inkMuted, modifier = Modifier.fillMaxWidth().padding(horizontal = MQ.gutter, vertical = 30.dp),
        textAlign = androidx.compose.ui.text.style.TextAlign.Center)
}

/** The amber fill every progress reading in the app uses. */
@Composable
fun ProgressBar(fraction: Float, modifier: Modifier = Modifier, percentLabel: Boolean = false, onArt: Boolean = false, tint: String = "brass", height: Dp = 6.dp) {
    val f by animateFloatAsState(fraction.coerceIn(0f, 1f), spring(), label = "pb")
    val grad = when (tint) {
        "complete" -> listOf(C.chartViolet.copy(alpha = 0.7f), C.chartViolet)
        "stopped" -> listOf(C.velvet.copy(alpha = 0.7f), C.velvet)
        else -> listOf(C.brassDim, C.brassFill, C.brassBright)
    }
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Box(Modifier.weight(1f).height(height).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f))) {
            Box(Modifier.fillMaxWidth(f).fillMaxHeight().clip(CircleShape).background(Brush.horizontalGradient(grad)))
        }
        if (percentLabel) Text("${Math.round(f * 100)}%", style = T.body(10.5f, 700).copy(fontFeatureSettings = "tnum"),
            color = if (onArt) MqColors.brassOnArt else C.brassBright, modifier = Modifier.widthIn(min = 30.dp))
    }
}

@Composable
fun OnArtBadge(text: String, modifier: Modifier = Modifier, dot: Boolean = false, icon: androidx.compose.ui.graphics.vector.ImageVector? = null) {
    Row(
        modifier.clip(RoundedCornerShape(7.dp)).background(Color.Black.copy(alpha = 0.55f)).padding(horizontal = 7.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        if (dot) Box(Modifier.size(6.dp).clip(CircleShape).background(MqColors.brassOnArt))
        if (icon != null) Icon(icon, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(9.dp))
        Text(text.uppercase(), style = T.body(9.5f, 700).copy(letterSpacing = 0.6.sp), color = Color.White.copy(alpha = 0.88f))
    }
}

private val artScrim = Brush.verticalGradient(
    0f to Color.Transparent, 0.36f to Color.Transparent, 0.62f to Color(0x8C0F0D0A), 0.9f to Color(0xF20F0D0A), 1f to Color(0xF20F0D0A),
)

/** The round brass button on a card's corner — punch, +1, stop. */
@Composable
fun CornerAction(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, busy: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val s by animateFloatAsState(if (busy) 0.86f else 1f, spring(0.55f), label = "s")
    Box(
        modifier.size(44.dp).scale(s).alpha(if (busy) 0.5f else 1f).shadow(6.dp, CircleShape).clip(CircleShape)
            .background(MqColors.brassOnArt.copy(alpha = 0.92f)).clickable(enabled = !busy, onClick = onClick)
            .semantics { contentDescription = label },
        contentAlignment = Alignment.Center,
    ) { Icon(icon, null, tint = C.brassOnFill, modifier = Modifier.size(20.dp)) }
}

/** An Up Next card: poster, the episode, progress, and the punch. */
@Composable
fun PunchCard(show: ShowCard, modifier: Modifier = Modifier, onPunch: suspend (ShowCard) -> Unit) {
    val nav = LocalNav.current
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    var punching by remember { mutableStateOf(false) }
    var stamped by remember { mutableStateOf(false) }
    val stampAlpha by animateFloatAsState(if (stamped) 1f else 0f, spring(0.5f, 400f), label = "stamp")
    val stampScale by animateFloatAsState(if (stamped) 1f else 1.8f, spring(0.45f, 500f), label = "stampS")
    val episodeLine = show.nextEp?.let { e -> e.code + (e.title?.let { " $it" } ?: "") }
        ?: show.nextAir?.takeIf { it.isNotEmpty() }?.let { "returns ${MQTime.medium(it)}" }
        ?: if (show.isEnded) "series complete" else "waiting for new episodes"
    val subline = if (show.remaining > 0) buildString {
        append("${show.remaining} left")
        show.hoursRemaining?.takeIf { it >= 1 }?.let { h ->
            append(if (h < 10) " · ${String.format(Locale.getDefault(), "%.1f", h)} hrs to go" else " · ${Math.round(h)} hrs to go")
        }
    } else null

    Box(modifier.width(MQ.upNextWidth).aspectRatio(MQ.posterAspect).shadow(10.dp, RoundedCornerShape(16.dp)).clip(RoundedCornerShape(16.dp))
        .clickable { nav.push(ShowRoute(show.id)) }
        .semantics(mergeDescendants = false) { contentDescription = "${show.displayTitle}. $episodeLine. ${show.watched} of ${show.aired} watched" }) {
        Poster(show.poster, Modifier.fillMaxSize(), radius = 16.dp)
        Box(Modifier.fillMaxSize().background(artScrim))
        Column(Modifier.align(Alignment.BottomStart).padding(start = 12.dp, end = 12.dp, bottom = 11.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(show.displayTitle, style = T.body(14.5f, 700), color = MqColors.inkOnArt, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(episodeLine, style = T.body(11.5f, 600), color = MqColors.brassOnArt, maxLines = 2, overflow = TextOverflow.Ellipsis)
            subline?.let { Text(it, style = T.caption, color = MqColors.inkSoftOnArt, maxLines = 1) }
            ProgressBar(show.progress, Modifier.padding(top = 5.dp), percentLabel = true, onArt = true)
        }
        if (show.isEnded) OnArtBadge("Ended", Modifier.align(Alignment.TopStart).padding(9.dp), icon = Icons.Filled.Flag)
        if (show.nextEp != null) CornerAction(Icons.Filled.Check, "Mark ${show.nextEp.code} of ${show.displayTitle} watched", punching, Modifier.align(Alignment.TopEnd).padding(7.dp)) {
            punching = true
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            stamped = true
            scope.launch {
                // The mark goes to the server straight away; the stamp is decoration.
                launch { onPunch(show) }
                delay(900); stamped = false; delay(250); punching = false
                haptic.performHapticFeedback(HapticFeedbackType.Confirm)
            }
        }
        // The punch: a foil WATCHED stamp slammed across the ticket.
        if (stampAlpha > 0.01f) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f * stampAlpha)), contentAlignment = Alignment.Center) {
            Text("WATCHED", style = T.wordmark(22f), color = MqColors.brassOnArt,
                modifier = Modifier.rotate(-14f).scale(stampScale).alpha(stampAlpha)
                    .border(2.dp, MqColors.brassOnArt, RoundedCornerShape(6.dp)).padding(horizontal = 10.dp, vertical = 4.dp))
        }
    }
}

/** A recent watch — history receding to the left of the queue. */
@Composable
fun WatchedMiniCard(entry: WatchEntry, showsWho: Boolean = false, isPast: Boolean = false) {
    val nav = LocalNav.current
    val desat = remember { ColorMatrix().apply { setToSaturation(0.55f) } }
    Column(
        Modifier.width(MQ.watchedWidth).clip(RoundedCornerShape(8.dp)).clickable {
            if (isPast && entry.season != null && entry.number != null) nav.push(EpisodeRoute(entry.showId, entry.season, entry.number))
            else nav.push(ShowRoute(entry.showId))
        },
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box(Modifier.alpha(if (isPast) 0.78f else 1f)) {
            Poster(entry.poster, Modifier.fillMaxWidth())
            if (isPast) Box(Modifier.matchParentSize().clip(RoundedCornerShape(11.dp)).background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color(0xE60F0D0A))), contentAlignment = Alignment.BottomCenter) {
                Text(MQTime.short(entry.watchedAt), style = T.body(10.5f, 700), color = MqColors.brassOnArt, modifier = Modifier.padding(bottom = 4.dp))
            }
            if (entry.count > 1) Text("${entry.count}", style = T.body(10.5f, 700), color = C.brassOnFill,
                modifier = Modifier.align(Alignment.TopEnd).padding(5.dp).clip(CircleShape).background(C.brassFill).padding(horizontal = 5.dp, vertical = 2.dp))
            if (showsWho && entry.by != null) Avatar(entry.by, 20.dp, Modifier.align(Alignment.BottomStart).padding(5.dp).border(2.dp, C.ground, CircleShape))
        }
        Text(entry.displayTitle, style = T.tile, color = if (isPast) C.inkSoft else C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        entry.code?.let { Text(it + if (entry.count > 1) " +${entry.count - 1}" else "", style = T.caption, color = C.brassBright, maxLines = 1) }
        if (showsWho && entry.by != null) Text("${entry.by.name} · ${MQTime.short(entry.watchedAt)}", style = T.body(10.5f, 500), color = C.inkMuted, maxLines = 1)
    }
}

/** The vertical "YESTERDAY" rule between days of history. */
@Composable
fun DayDivider(label: String) {
    Column(Modifier.width(22.dp).height(MQ.upNextWidth / MQ.posterAspect).padding(vertical = 6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.weight(1f).width(1.dp).background(C.hairline))
        Text(label.uppercase(), style = T.body(10f, 700).copy(letterSpacing = 1.4.sp), color = C.inkMuted, maxLines = 1, softWrap = false,
            modifier = Modifier.padding(vertical = 8.dp).layout { m, _ ->
                // Rotation doesn't change layout bounds, so reserve the rotated footprint.
                val p = m.measure(androidx.compose.ui.unit.Constraints())
                layout(p.height, p.width) { p.place((p.height - p.width) / 2, (p.width - p.height) / 2) }
            }.rotate(90f))
        Box(Modifier.weight(1f).width(1.dp).background(C.hairline))
    }
}

@Composable
fun CalendarCard(ep: UpcomingEpisode) {
    val nav = LocalNav.current
    Column(Modifier.width(MQ.watchedWidth).clip(RoundedCornerShape(8.dp)).clickable { nav.push(EpisodeRoute(ep.showId, ep.season, ep.number)) }, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box {
            Poster(ep.poster, Modifier.fillMaxWidth())
            Box(Modifier.matchParentSize().clip(RoundedCornerShape(11.dp)).background(Brush.verticalGradient(0.5f to Color.Transparent, 1f to Color(0xE60F0D0A))), contentAlignment = Alignment.BottomCenter) {
                Text(MQTime.short(ep.airDate), style = T.body(10.5f, 700), color = MqColors.brassOnArt, modifier = Modifier.padding(bottom = 4.dp))
            }
        }
        Text(ep.showTitle ?: "", style = T.tile, color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(ep.code, style = T.caption, color = C.brassBright, maxLines = 1)
    }
}

@Composable
fun ReviewTeaserRow(review: ReviewTeaser) {
    val nav = LocalNav.current
    Row(
        Modifier.fillMaxWidth().mqPanel().clickable { nav.push(if (review.type == "show") ShowRoute(review.id) else MovieRoute(review.id)) }.padding(11.dp),
        horizontalArrangement = Arrangement.spacedBy(11.dp),
    ) {
        Poster(review.poster, Modifier.width(46.dp), radius = 7.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Avatar(review.by, 20.dp)
                Text(review.by.name, style = T.body(12.5f, 600), color = C.ink, modifier = Modifier.weight(1f))
                review.rating?.let { Icon(Icons.Filled.Star, null, tint = C.brass, modifier = Modifier.size(12.dp)); Text("$it", style = T.body(12f, 700), color = C.brass) }
            }
            Text(review.title ?: "", style = T.body(13f, 700), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            review.body?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkSoft, maxLines = 2, overflow = TextOverflow.Ellipsis) }
        }
    }
}

@Composable
fun TypeBadge(isShow: Boolean, modifier: Modifier = Modifier) = OnArtBadge(if (isShow) "TV" else "Film", modifier)

@Composable
fun ListBookmark(count: Int, modifier: Modifier = Modifier) {
    if (count <= 0) return
    Row(modifier.clip(RoundedCornerShape(6.dp)).background(Color.Black.copy(alpha = 0.55f)).padding(horizontal = 5.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Bookmark, if (count > 1) "On $count of your lists" else "On one of your lists", tint = MqColors.brassOnArt, modifier = Modifier.size(11.dp))
        if (count > 1) Text("$count", style = T.body(9.5f, 700), color = MqColors.brassOnArt)
    }
}

/** A search/discover result tile: TV/Film badge, score, list bookmark. */
@Composable
fun PosterTile(result: SearchResult, width: Dp? = MQ.tileWidth, modifier: Modifier = Modifier, trailing: @Composable BoxScope.() -> Unit = {}) {
    val nav = LocalNav.current
    val session = LocalSession.current
    Column(
        modifier.then(if (width != null) Modifier.width(width) else Modifier.fillMaxWidth()).clip(RoundedCornerShape(8.dp))
            .clickable { nav.push(if (result.isShow) ShowRoute(result.id) else MovieRoute(result.id)) },
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Box {
            Poster(result.poster, Modifier.fillMaxWidth())
            TypeBadge(result.isShow, Modifier.align(Alignment.TopStart).padding(6.dp))
            result.vote?.takeIf { it > 0 }?.let {
                OnArtBadge(LibraryFormat.one(it), Modifier.align(Alignment.TopEnd).padding(6.dp), icon = Icons.Filled.Star)
            }
            ListBookmark(session.listCount(result.type, result.id), Modifier.align(Alignment.BottomEnd).padding(6.dp))
            trailing()
        }
        Text(result.displayTitle, style = T.tile, color = C.ink, maxLines = 2, minLines = 2, overflow = TextOverflow.Ellipsis)
        Text(listOfNotNull(result.year?.toString(), result.stateLabel).filter { it.isNotEmpty() }.joinToString(" · "), style = T.caption, color = C.inkMuted, maxLines = 1)
    }
}

/** A Continue reading card: cover, progress, and +1 / log / stop. */
@Composable
fun ContinueReadingCard(item: ReadingItem, live: ActiveSession?, onIncrement: suspend () -> Unit, onLog: () -> Unit) {
    val nav = LocalNav.current
    val haptic = LocalHapticFeedback.current
    val scope = rememberCoroutineScope()
    val kind = item.readingKind
    var busy by remember { mutableStateOf(false) }
    val plusable = live == null && item.supportsIncrement(kind)
    val subline = when {
        live != null -> "Reading now"
        item.paceLine != null -> item.paceLine
        kind == ReadingKind.BOOK -> item.author
        else -> item.origin
    }
    Box(Modifier.width(MQ.upNextWidth).aspectRatio(MQ.posterAspect).shadow(10.dp, RoundedCornerShape(16.dp)).clip(RoundedCornerShape(16.dp))
        .clickable { nav.push(if (kind == ReadingKind.BOOK) BookRoute(item.id) else MangaRoute(item.id)) }) {
        Poster(item.cover, Modifier.fillMaxSize(), radius = 16.dp)
        Box(Modifier.fillMaxSize().background(artScrim))
        Column(Modifier.align(Alignment.BottomStart).padding(start = 12.dp, end = 12.dp, bottom = 11.dp), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(item.displayTitle, style = T.body(14.5f, 700), color = MqColors.inkOnArt, maxLines = 2, overflow = TextOverflow.Ellipsis)
            Text(item.progressLabel(kind), style = T.body(11.5f, 600), color = MqColors.brassOnArt, maxLines = 1)
            subline?.let { Text(it, style = T.caption, color = MqColors.inkSoftOnArt, maxLines = 2) }
            if (item.total(kind) != null) ProgressBar(item.fraction(kind), Modifier.padding(top = 5.dp), percentLabel = true, onArt = true)
        }
        OnArtBadge(if (live != null) "Live" else if (kind == ReadingKind.BOOK) "Book" else item.origin ?: "Manga", Modifier.align(Alignment.TopStart).padding(9.dp), dot = live != null)
        CornerAction(
            if (live != null) Icons.Filled.Stop else if (plusable) Icons.Filled.Add else Icons.Filled.Tune,
            if (live != null) "End the session on ${item.displayTitle}" else if (plusable) "Read one more chapter" else "Log progress",
            busy, Modifier.align(Alignment.TopEnd).padding(7.dp),
        ) {
            if (plusable) {
                busy = true; haptic.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick)
                scope.launch { onIncrement(); busy = false }
            } else onLog()
        }
    }
}

/** A watchlist tile on Home: poster, where it streams, how big a commitment. */
@Composable
fun WatchlistRailCard(show: ShowCard) {
    val nav = LocalNav.current
    val sub = if (show.aired == 0 && !show.nextAir.isNullOrEmpty()) "Premieres ${MQTime.upcomingLabel(show.nextAir)}"
    else listOfNotNull(show.prov?.name ?: show.network, LibraryFormat.hours(show.totalMin)).filter { it.isNotEmpty() }
        .joinToString(" · ").ifEmpty { show.year?.toString() ?: "" }
    Column(Modifier.width(MQ.tileWidth).clip(RoundedCornerShape(8.dp)).clickable { nav.push(ShowRoute(show.id)) }, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box {
            Poster(show.poster, Modifier.fillMaxWidth())
            show.household?.firstOrNull()?.let { Avatar(it.person, 20.dp, Modifier.align(Alignment.BottomStart).padding(5.dp).border(1.5.dp, C.ground, CircleShape)) }
        }
        Text(show.displayTitle, style = T.tile, color = C.ink, maxLines = 2, minLines = 2, overflow = TextOverflow.Ellipsis)
        Text(sub, style = T.caption, color = C.inkMuted, maxLines = 1)
    }
}

@Composable
fun NavRow(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, detail: String? = null, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(
        modifier.fillMaxWidth().mqPanel().clickable(onClick = onClick).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = C.brass, modifier = Modifier.size(22.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, style = T.body(15f, 700), color = C.ink)
            detail?.let { Text(it, style = T.caption, color = C.inkSoft) }
        }
        Icon(Icons.Filled.ChevronRight, null, tint = C.inkMuted, modifier = Modifier.size(18.dp))
    }
}

@Composable
fun EmptyQueuePrompt(waiting: Int, onClick: () -> Unit) {
    NavRow(Icons.Filled.LiveTv, "Nothing in the queue", "$waiting show${if (waiting == 1) "" else "s"} on your watchlist — start one tonight.",
        Modifier.padding(horizontal = MQ.gutter), onClick)
}

/** "Mia finished it · ★9", "On Jo's watchlist too" — the household in as few words as it takes. */
object HouseholdSummary {
    fun show(card: ShowCard): Pair<String, List<Person>>? {
        val hh = card.household ?: return null
        if (hh.isEmpty()) return null
        val aired = card.aired
        val finished = hh.filter { (it.watched ?: 0) > 0 && aired > 0 && (it.watched ?: 0) >= aired }
        val watching = hh.filter { (it.watched ?: 0) > 0 && it !in finished && it.stopped != true }
        val listed = hh.filter { (it.watched ?: 0) == 0 }
        val text = when {
            finished.isNotEmpty() -> "${names(finished.map { it.displayName })} finished it${star(finished.first().rating)}"
            watching.isNotEmpty() -> watching.first().let { w -> w.lastEpCode?.let { "${w.displayName} is on $it" } ?: "${w.displayName} is watching" } +
                if (watching.size > 1) " +${watching.size - 1}" else ""
            listed.isNotEmpty() -> "On ${names(listed.map { it.displayName }, possessive = true)} watchlist too"
            else -> "${names(hh.map { it.displayName })} stopped"
        }
        return text to hh.map { it.person }
    }

    fun film(card: dev.kadenthompson.marquee.model.MovieCard): Pair<String, List<Person>>? {
        val hh = card.household ?: return null
        if (hh.isEmpty()) return null
        val seen = hh.filter { it.state == "watched" }
        val text = if (seen.isNotEmpty()) "${names(seen.map { it.displayName })} watched it${star(seen.first().rating)}"
        else "On ${names(hh.map { it.displayName }, possessive = true)} watchlist too"
        return text to hh.map { it.person }
    }

    private fun names(all: List<String>, possessive: Boolean = false): String {
        val s = when (all.size) { 0 -> "Someone"; 1 -> all[0]; 2 -> "${all[0]} and ${all[1]}"; else -> "${all[0]} and ${all.size - 1} others" }
        return if (possessive) (if (all.size == 1) "${s}'s" else "$s's") else s
    }

    private fun star(r: Int?) = r?.let { " · ★$it" } ?: ""
}
