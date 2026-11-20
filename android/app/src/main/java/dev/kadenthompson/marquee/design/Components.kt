package dev.kadenthompson.marquee.design

import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Movie
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.SubcomposeAsyncImage
import dev.kadenthompson.marquee.model.CastMember
import dev.kadenthompson.marquee.model.IMDbRating
import dev.kadenthompson.marquee.model.Person
import dev.kadenthompson.marquee.session.LocalSession

// ---------- surfaces

fun Modifier.panel(radius: Dp = 11.dp, fill: Color? = null, stroke: Color? = null) = this.then(
    Modifier.clip(RoundedCornerShape(radius))
)

@Composable
fun Modifier.mqPanel(radius: Dp = 11.dp, raised: Boolean = false): Modifier =
    this.clip(RoundedCornerShape(radius))
        .background(if (raised) C.panelRaised else C.panel)
        .border(1.dp, C.hairline, RoundedCornerShape(radius))

// ---------- art

/** Resolves server-relative art (uploaded avatars and banners) against the paired server. */
@Composable
fun artUrl(url: String?): String? {
    val client = LocalSession.current.client
    return client?.absolute(url) ?: url?.takeIf { it.startsWith("http") }
}

@Composable
fun RemoteImage(
    url: String?,
    modifier: Modifier = Modifier,
    contentDescription: String? = null,
    placeholder: ImageVector = Icons.Filled.Movie,
    contentScale: ContentScale = ContentScale.Crop,
) {
    val resolved = artUrl(url)
    Box(modifier.background(C.panelRaised), contentAlignment = Alignment.Center) {
        if (resolved == null) {
            Icon(placeholder, null, tint = C.hairlineBold, modifier = Modifier.size(26.dp))
        } else {
            SubcomposeAsyncImage(
                model = resolved, contentDescription = contentDescription, contentScale = contentScale,
                modifier = Modifier.fillMaxSize(),
                error = { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { Icon(placeholder, null, tint = C.hairlineBold, modifier = Modifier.size(26.dp)) } },
            )
        }
    }
}

/** Poster art: 2:3, clipped, with a faint edge so light art doesn't bleed into the page. */
@Composable
fun Poster(url: String?, modifier: Modifier = Modifier, radius: Dp = 11.dp, contentDescription: String? = null) {
    val shape = RoundedCornerShape(radius)
    RemoteImage(
        url, modifier.aspectRatio(MQ.posterAspect).clip(shape).border(0.5.dp, C.hairline.copy(alpha = 0.6f), shape),
        contentDescription,
    )
}

@Composable
fun Still(url: String?, modifier: Modifier = Modifier, radius: Dp = 11.dp) {
    val shape = RoundedCornerShape(radius)
    RemoteImage(url, modifier.aspectRatio(MQ.stillAspect).clip(shape).border(0.5.dp, C.hairline.copy(alpha = 0.6f), shape))
}

/** A face, or the web client's monogram on a hue derived from the name. */
@Composable
fun Avatar(person: Person?, size: Dp = 32.dp, modifier: Modifier = Modifier) {
    val url = artUrl(person?.avatar)
    val name = person?.name ?: "?"
    Box(
        modifier.size(size).clip(CircleShape)
            .background(Color.hsv(person?.monogramHue ?: 30f, 0.45f, 0.55f))
            .border(1.dp, C.hairlineBold, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(person?.monogram ?: "?", style = T.body((size.value * 0.42f), 700), color = Color.White)
        if (url != null) {
            SubcomposeAsyncImage(model = url, contentDescription = name, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        }
    }
}

/** Dark gradient foot under art so titles stay legible over any still. */
fun Modifier.scrimBottom(start: Float = 0.35f, strength: Float = 0.92f) = this.drawBehind {}.then(
    Modifier.background(
        Brush.verticalGradient(
            0f to Color.Transparent, start to Color.Transparent,
            1f to Color(0xFF0F0D0A).copy(alpha = strength),
        )
    )
)

// ---------- headers

@Composable
fun Eyebrow(text: String, modifier: Modifier = Modifier, color: Color = C.inkMuted) {
    Text(text.uppercase(), style = T.eyebrow, color = color, modifier = modifier.semantics { heading() })
}

/** `SECTION ─────────── 12` — the rule that separates one rail from the next. */
@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier, count: String? = null, trailing: @Composable RowScope.() -> Unit = {}) {
    Row(modifier.fillMaxWidth().semantics(mergeDescendants = true) { heading() }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(title.uppercase(), style = T.eyebrow, color = C.inkMuted)
        Box(Modifier.weight(1f).height(1.dp).background(C.hairline))
        if (count != null) Text(count, style = T.caption.copy(fontFeatureSettings = "tnum"), color = C.inkMuted)
        trailing()
    }
}

/** A rail title with a "See all" affordance. */
@Composable
fun RailHeader(title: String, modifier: Modifier = Modifier, more: String? = "All", onMore: (() -> Unit)? = null) {
    Row(modifier.fillMaxWidth().padding(horizontal = MQ.gutter), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = T.rail, color = C.ink, modifier = Modifier.weight(1f).semantics { heading() })
        if (onMore != null && more != null) {
            Row(Modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onMore).padding(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(more, style = T.caption, color = C.brass)
                Icon(Icons.Filled.ChevronRight, null, tint = C.brass, modifier = Modifier.size(14.dp))
            }
        }
    }
}

@Composable
fun DetailSection(title: String, count: String? = null, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SectionHeader(title, Modifier.padding(horizontal = MQ.gutter), count)
        content()
    }
}

// ---------- buttons

@Composable
fun PrimaryButton(
    text: String, onClick: () -> Unit, modifier: Modifier = Modifier, enabled: Boolean = true,
    busy: Boolean = false, icon: ImageVector? = null, fill: Boolean = true,
) {
    val haptic = LocalHapticFeedback.current
    Row(
        modifier.then(if (fill) Modifier.fillMaxWidth() else Modifier)
            .alpha(if (enabled) 1f else 0.4f)
            .clip(CircleShape).background(C.brassFill)
            .clickable(enabled = enabled && !busy) { haptic.performHapticFeedback(HapticFeedbackType.ContextClick); onClick() }
            .padding(vertical = 14.dp, horizontal = 20.dp),
        horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically,
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(18.dp), color = C.brassOnFill, strokeWidth = 2.dp)
        else {
            if (icon != null) { Icon(icon, null, tint = C.brassOnFill, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(8.dp)) }
            Text(text, style = T.headline, color = C.brassOnFill)
        }
    }
}

@Composable
fun QuietButton(text: String, onClick: () -> Unit, modifier: Modifier = Modifier, color: Color = C.inkSoft) {
    Text(
        text, style = T.sub, color = color, textAlign = TextAlign.Center,
        modifier = modifier.clip(RoundedCornerShape(10.dp)).clickable(onClick = onClick).padding(vertical = 12.dp, horizontal = 16.dp),
    )
}

/** A bordered pill for secondary actions in a row — the web client's `.chip-btn`. */
@Composable
fun ChipButton(
    text: String, icon: ImageVector? = null, modifier: Modifier = Modifier, on: Boolean = false,
    destructive: Boolean = false, enabled: Boolean = true, onClick: () -> Unit,
) {
    val tint = when { destructive -> C.velvet; on -> C.brass; else -> C.inkSoft }
    val shape = RoundedCornerShape(10.dp)
    Row(
        modifier.alpha(if (enabled) 1f else 0.45f).clip(shape).background(if (on) C.brassSoft else C.panel)
            .border(1.dp, if (on) C.brassDim else C.hairline, shape)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(vertical = 9.dp, horizontal = 13.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (icon != null) Icon(icon, null, tint = tint, modifier = Modifier.size(16.dp))
        Text(text, style = T.sub, color = tint, maxLines = 1)
    }
}

@Composable
fun ChipRow(modifier: Modifier = Modifier, content: @Composable () -> Unit) {
    FlowRow(modifier, horizontalArrangement = Arrangement.spacedBy(7.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) { content() }
}

/** A selectable filter chip — shelves, segments. */
@Composable
fun FilterPill(text: String, selected: Boolean, count: Int? = null, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val shape = CircleShape
    Row(
        modifier.clip(shape).background(if (selected) C.brassFill else C.panel)
            .border(1.dp, if (selected) C.brassFill else C.hairline, shape)
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(text, style = T.sub.copy(fontWeight = FontWeight.SemiBold), color = if (selected) C.brassOnFill else C.inkSoft)
        if (count != null) Text("$count", style = T.caption.copy(fontFeatureSettings = "tnum"), color = if (selected) C.brassOnFill.copy(alpha = 0.7f) else C.inkMuted)
    }
}

/** Segmented control in the Marquee palette. */
@Composable
fun Segmented(options: List<String>, selected: Int, modifier: Modifier = Modifier, onSelect: (Int) -> Unit) {
    Row(modifier.clip(RoundedCornerShape(10.dp)).background(C.panel).border(1.dp, C.hairline, RoundedCornerShape(10.dp)).padding(3.dp)) {
        options.forEachIndexed { i, label ->
            Box(
                Modifier.weight(1f).clip(RoundedCornerShape(8.dp))
                    .background(if (i == selected) C.panelRaised else Color.Transparent)
                    .then(if (i == selected) Modifier.border(1.dp, C.brassDim, RoundedCornerShape(8.dp)) else Modifier)
                    .clickable { onSelect(i) }.padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) { Text(label, style = T.sub.copy(fontWeight = FontWeight.SemiBold), color = if (i == selected) C.brass else C.inkSoft, maxLines = 1) }
        }
    }
}

// ---------- facts

@Composable
fun MetaChip(text: String, icon: ImageVector? = null, tinted: Boolean = false) {
    val shape = RoundedCornerShape(6.dp)
    Row(
        Modifier.border(1.dp, if (tinted) C.brassDim else C.hairlineBold, shape).padding(horizontal = 8.dp, vertical = 3.5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        if (icon != null) Icon(icon, null, tint = if (tinted) C.brass else C.inkSoft, modifier = Modifier.size(11.dp))
        Text(text, style = T.body(11f, 700).copy(letterSpacing = 0.3.sp), color = if (tinted) C.brass else C.inkSoft, maxLines = 2)
    }
}

/** IMDb when the dataset has it — with the vote count — and TMDB otherwise. */
@Composable
fun RatingChip(imdb: IMDbRating?, tmdbVote: Double?) {
    val r = imdb?.rating
    if (r != null) {
        Row(
            Modifier.border(1.dp, C.brassDim.copy(alpha = 0.6f), RoundedCornerShape(6.dp)).padding(horizontal = 7.dp, vertical = 3.dp)
                .semantics(mergeDescendants = true) { contentDescription = "IMDb ${LibraryFormat.one(r)}" },
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text("IMDb", style = T.body(9.5f, 800), color = Color.Black,
                modifier = Modifier.clip(RoundedCornerShape(3.dp)).background(Color(0xFFF5C518)).padding(horizontal = 4.dp, vertical = 1.dp))
            Text(LibraryFormat.one(r), style = T.body(11.5f, 700), color = C.ink)
            imdb.votes?.takeIf { it > 0 }?.let { Text(LibraryFormat.compact(it), style = T.body(10f, 500), color = C.inkMuted) }
        }
    } else if (tmdbVote != null && tmdbVote > 0) {
        MetaChip(LibraryFormat.one(tmdbVote), Icons.Filled.Star, tinted = true)
    }
}

/** Five stars for a score out of ten — each star is worth two. Tap your star again to clear. */
@Composable
fun StarRating(rating: Int?, onChange: (Int?) -> Unit) {
    val haptic = LocalHapticFeedback.current
    Row(
        Modifier.clip(RoundedCornerShape(9.dp)).background(C.panelRaised).border(1.dp, C.brassDim, RoundedCornerShape(9.dp))
            .padding(horizontal = 8.dp, vertical = 3.dp),
        horizontalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        for (star in 1..5) {
            val value = star * 2
            val lit = (rating ?: 0) >= value
            val half = !lit && (rating ?: 0) == value - 1
            Box(
                Modifier.size(30.dp).clip(CircleShape).clickable {
                    haptic.performHapticFeedback(HapticFeedbackType.SegmentTick)
                    onChange(if (rating == value) null else value)
                }.semantics { contentDescription = "Rate $value out of 10" },
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Filled.Star, null, tint = if (lit || half) C.brass else C.hairlineBold, modifier = Modifier.size(19.dp).alpha(if (half) 0.6f else 1f))
            }
        }
    }
}

@Composable
fun ProgressTrack(fraction: Float, modifier: Modifier = Modifier, height: Dp = 4.dp, color: Color = C.brass, track: Color = C.hairline) {
    Box(modifier.fillMaxWidth().height(height).clip(CircleShape).background(track)) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).height(height).clip(CircleShape).background(color))
    }
}

/** Body copy that starts clamped and opens on a tap. */
@Composable
fun ExpandableText(text: String, lines: Int = 3, style: TextStyle = T.body, color: Color = C.inkSoft) {
    var expanded by rememberSaveable { mutableStateOf(false) }
    var truncated by remember { mutableStateOf(false) }
    Column(Modifier.animateContentSize().clickable(enabled = truncated || expanded) { expanded = !expanded }) {
        Text(
            text, style = style, color = color, maxLines = if (expanded) Int.MAX_VALUE else lines,
            overflow = TextOverflow.Ellipsis, onTextLayout = { if (!expanded) truncated = it.hasVisualOverflow },
        )
        if (truncated || expanded) Text(if (expanded) "Less" else "More", style = T.body(12.5f, 700), color = C.brass, modifier = Modifier.padding(top = 4.dp))
    }
}

/** Faces, in billing order. Every one is a door to that person's filmography. */
@Composable
fun CastStrip(people: List<CastMember>, onPerson: (Int) -> Unit) {
    LazyRow(contentPadding = PaddingValues(horizontal = MQ.gutter), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        items(people.size) { i ->
            val p = people[i]
            Column(
                Modifier.width(82.dp).clip(RoundedCornerShape(8.dp)).clickable(enabled = p.id != null) { p.id?.let(onPerson) },
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                RemoteImage(p.img, Modifier.size(64.dp).clip(CircleShape).border(1.dp, C.hairlineBold, CircleShape), placeholder = Icons.Filled.Person)
                Text(p.name, style = T.body(11.5f, 600), color = C.ink, maxLines = 2, textAlign = TextAlign.Center)
                p.character?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.body(10.5f), color = C.inkMuted, maxLines = 2, textAlign = TextAlign.Center) }
            }
        }
    }
}

// ---------- states

@Composable
fun Skeleton(modifier: Modifier = Modifier, height: Dp = 64.dp, radius: Dp = 11.dp) {
    val t = rememberInfiniteTransition(label = "sk")
    val a by t.animateFloat(0.45f, 0.9f, infiniteRepeatable(tween(900, easing = LinearEasing), RepeatMode.Reverse), label = "a")
    Box(modifier.fillMaxWidth().height(height).clip(RoundedCornerShape(radius)).background(C.panel.copy(alpha = a)))
}

@Composable
fun LoadingList(rows: Int = 5) {
    Column(Modifier.padding(MQ.gutter), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Skeleton(height = 180.dp, radius = 16.dp)
        repeat(rows) { Skeleton() }
    }
}

@Composable
fun ErrorState(message: String, onRetry: (() -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().padding(32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(Icons.Outlined.ErrorOutline, null, tint = C.inkMuted, modifier = Modifier.size(34.dp))
        Text(message, style = T.sub, color = C.inkSoft, textAlign = TextAlign.Center)
        if (onRetry != null) ChipButton("Try again", onClick = onRetry)
    }
}

@Composable
fun EmptyState(icon: ImageVector, title: String, message: String? = null, action: (@Composable () -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(icon, null, tint = C.brassDim, modifier = Modifier.size(38.dp))
        Text(title, style = T.headline, color = C.ink, textAlign = TextAlign.Center)
        if (message != null) Text(message, style = T.sub, color = C.inkMuted, textAlign = TextAlign.Center)
        action?.invoke()
    }
}

@Composable
fun StaleFooter(show: Boolean) {
    if (!show) return
    Row(Modifier.fillMaxWidth().padding(14.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.WifiOff, null, tint = C.inkMuted, modifier = Modifier.size(14.dp))
        Spacer(Modifier.width(6.dp))
        Text("Showing your last sync", style = T.caption, color = C.inkMuted)
    }
}

/** A row of marquee bulbs — the pairing header and the celebration frame. */
@Composable
fun BulbRow(count: Int = 9, modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "bulbs")
    val phase by t.animateFloat(0f, count.toFloat(), infiniteRepeatable(tween(count * 260, easing = LinearEasing)), label = "p")
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
        repeat(count) { i ->
            val lit = ((phase.toInt() - i) % 3 + 3) % 3 == 0
            Box(Modifier.size(7.dp).clip(CircleShape).background(if (lit) C.brassBright else C.brassDim.copy(alpha = 0.6f)))
        }
    }
}

// ---------- screen chrome

/** A pushed screen: back arrow, title, the Marquee ground, optional pull to refresh. */
@Composable
fun ScreenScaffold(
    title: String,
    onBack: (() -> Unit)?,
    actions: @Composable RowScope.() -> Unit = {},
    refreshing: Boolean = false,
    onRefresh: (() -> Unit)? = null,
    transparentBar: Boolean = false,
    content: @Composable BoxScope.(PaddingValues) -> Unit,
) {
    Scaffold(
        containerColor = C.ground,
        topBar = {
            TopAppBar(
                title = { Text(title, style = T.headline, color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis) },
                navigationIcon = {
                    if (onBack != null) IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = C.ink) }
                },
                actions = actions,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = if (transparentBar) Color.Transparent else C.ground,
                    scrolledContainerColor = C.panel,
                ),
            )
        },
    ) { pad ->
        if (onRefresh != null) {
            PullToRefreshBox(isRefreshing = refreshing, onRefresh = onRefresh, modifier = Modifier.fillMaxSize()) { content(pad) }
        } else Box(Modifier.fillMaxSize()) { content(pad) }
    }
}

/** Constrains reading-width content on wide screens. */
fun Modifier.readable(max: Dp = 720.dp) = this.widthIn(max = max)

fun LazyListScope.gap(h: Dp) = item { Spacer(Modifier.height(h)) }
