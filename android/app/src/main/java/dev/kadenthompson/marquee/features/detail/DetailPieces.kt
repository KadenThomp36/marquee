package dev.kadenthompson.marquee.features.detail

import android.content.Intent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.automirrored.filled.PlaylistAdd
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Reply
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import coil3.compose.AsyncImage
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.DetailSection
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.MqColors
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.RemoteImage
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.StarRating
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.artUrl
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.requests.SheetTitle
import dev.kadenthompson.marquee.model.ArtworkResponse
import dev.kadenthompson.marquee.model.CreatedList
import dev.kadenthompson.marquee.model.ExternalReview
import dev.kadenthompson.marquee.model.ExternalReviewsResponse
import dev.kadenthompson.marquee.model.FavoritesResponse
import dev.kadenthompson.marquee.model.ItemListRow
import dev.kadenthompson.marquee.model.ItemListsResponse
import dev.kadenthompson.marquee.model.Provider
import dev.kadenthompson.marquee.model.Review
import dev.kadenthompson.marquee.model.ReviewsResponse
import dev.kadenthompson.marquee.model.ShowRatings
import dev.kadenthompson.marquee.model.WatchProviders
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.LocalSnackbar
import kotlinx.coroutines.launch

/** A soft, blurred wash of the backdrop behind a detail hero. */
@Composable
fun BackdropWash(url: String?, height: androidx.compose.ui.unit.Dp = 380.dp, alpha: Float = 0.28f) {
    val resolved = artUrl(url) ?: return
    Box(Modifier.fillMaxWidth().height(height)) {
        AsyncImage(resolved, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize().blur(3.dp), alpha = if (C.isDark) alpha else alpha * 0.55f)
        Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to C.ground.copy(alpha = 0.2f), 0.55f to C.ground.copy(alpha = 0.6f), 1f to C.ground)))
    }
}

// ---------- where to watch

@Composable
fun WhereToWatch(providers: WatchProviders?, isOnPlex: Boolean) {
    val uri = LocalUriHandler.current
    var expanded by rememberSaveable { mutableStateOf(false) }
    val p = providers ?: return
    val groups = listOf(Triple("flatrate", if (isOnPlex) "Also streaming" else "Stream", p.flatrate), Triple("rent", "Rent", p.rent), Triple("buy", "Buy", p.buy))
        .filter { it.third.isNotEmpty() }
    if (!isOnPlex && groups.isEmpty()) return
    val unique = groups.flatMap { g -> g.third.mapNotNull { it.name } }.distinct()
    val summary = when {
        isOnPlex -> "Ready to play on your Plex"
        unique.isEmpty() -> "Nothing listed in the US right now"
        unique.size <= 2 -> unique.joinToString(", ")
        else -> "${unique.take(2).joinToString(", ")} and ${unique.size - 2} more"
    }
    val rot by animateFloatAsState(if (expanded) 90f else 0f, label = "r")
    DetailSection("Where to watch", p.region ?: "US") {
        Column(Modifier.padding(horizontal = MQ.gutter).fillMaxWidth().mqPanel(16.dp).animateContentSize()) {
            Row(Modifier.fillMaxWidth().clickable { expanded = !expanded }.padding(13.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(Modifier.size(30.dp).clip(RoundedCornerShape(9.dp)).background(C.brassSoft), contentAlignment = Alignment.Center) {
                    Icon(if (isOnPlex) Icons.Filled.LiveTv else Icons.Filled.ConfirmationNumber, null, tint = if (isOnPlex) C.plex else C.brass, modifier = Modifier.size(17.dp))
                }
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(if (isOnPlex) "On your Plex" else if (expanded) "Where to watch" else "See where to watch", style = T.body(14f, 700), color = C.ink)
                    Text(summary, style = T.caption, color = C.inkMuted, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                Icon(Icons.Filled.ChevronRight, null, tint = if (expanded) C.brass else C.inkMuted, modifier = Modifier.rotate(rot))
            }
            if (expanded) Column(Modifier.padding(start = 13.dp, end = 13.dp, bottom = 14.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                if (isOnPlex) Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(C.brassSoft).padding(11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp)) {
                    Icon(Icons.Filled.LiveTv, null, tint = C.plex)
                    Column(Modifier.weight(1f)) {
                        Text("On your Plex", style = T.body(13.5f, 700), color = C.ink)
                        Text("Ready to play now${if (groups.isEmpty()) "" else " — also streaming below"}", style = T.caption, color = C.inkSoft)
                    }
                    Icon(Icons.Filled.Check, null, tint = C.brass)
                }
                groups.forEach { (key, label, list) ->
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Box(Modifier.size(7.dp).clip(CircleShape).background(if (key == "flatrate") C.brass else C.inkMuted)); Eyebrow(label)
                        }
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) { list.forEach { ProviderTile(it) } }
                    }
                }
                p.link?.let { link ->
                    Row(Modifier.clickable { runCatching { uri.openUri(link) } }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Open on JustWatch", style = T.caption, color = C.brass); Icon(Icons.AutoMirrored.Filled.OpenInNew, null, tint = C.brass, modifier = Modifier.size(13.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun ProviderTile(p: Provider) {
    Column(Modifier.width(62.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
        RemoteImage(p.logo, Modifier.size(46.dp).clip(RoundedCornerShape(11.dp)).border(1.dp, C.hairline, RoundedCornerShape(11.dp)))
        Text(p.name ?: "", style = T.body(10f, 500), color = C.inkSoft, maxLines = 2, textAlign = TextAlign.Center)
    }
}

// ---------- favourite / lists / share / external link chips

@Composable
fun FavoriteChip(itemType: String, itemId: Int) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    var on by remember { mutableStateOf(false) }
    LaunchedEffect(itemType, itemId) {
        session.client?.let { c -> runCatching { c.get<FavoritesResponse>("favorites") }.onSuccess { r -> on = r.favorites.any { it.type == itemType && it.id == itemId } } }
    }
    ChipButton(if (on) "Favourite" else "Favourite", if (on) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder, on = on) {
        val was = on; on = !on; haptic.performHapticFeedback(HapticFeedbackType.ToggleOn)
        scope.launch {
            val c = session.client ?: return@launch
            runCatching { if (was) c.sendDelete("favorites/$itemType/$itemId") else c.send("favorites", body("item_type" to itemType, "item_id" to itemId)) }
                .onFailure { on = was }
        }
    }
}

@Composable
fun AddToListChip(itemType: String, itemId: Int, title: String) {
    val session = LocalSession.current
    var open by remember { mutableStateOf(false) }
    val count = session.listCount(itemType, itemId)
    ChipButton(if (count > 0) "On ${if (count == 1) "a list" else "$count lists"}" else "List", if (count > 0) Icons.Filled.Bookmark else Icons.Filled.BookmarkBorder, on = count > 0) { open = true }
    if (open) AddToListSheet(itemType, itemId, title) { open = false }
}

@Composable
fun AddToListSheet(itemType: String, itemId: Int, title: String, onDismiss: () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var rows by remember { mutableStateOf<List<ItemListRow>?>(null) }
    var newName by remember { mutableStateOf("") }
    suspend fun load() { session.client?.let { c -> rows = runCatching { c.get<ItemListsResponse>("item/$itemType/$itemId/lists").lists }.getOrDefault(rows ?: emptyList()) } }
    LaunchedEffect(Unit) { load() }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(bottom = 16.dp)) {
            SheetTitle("Add to list", "Done", onDismiss)
            Text(title, style = T.sub, color = C.inkMuted, modifier = Modifier.padding(horizontal = MQ.gutter))
            Spacer(Modifier.height(12.dp))
            Column(Modifier.padding(horizontal = MQ.gutter).fillMaxWidth().mqPanel(16.dp)) {
                (rows ?: emptyList()).forEachIndexed { i, r ->
                    Row(Modifier.fillMaxWidth().clickable {
                        rows = rows?.map { if (it.id == r.id) it.copy(has = !it.has) else it }
                        scope.launch {
                            runCatching { session.client?.send("list/${r.id}/item", body("item_type" to itemType, "item_id" to itemId, "remove" to if (r.has) true else null)) }
                            session.refreshListMembership()
                        }
                    }.padding(horizontal = 15.dp, vertical = 13.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(if (r.has) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = if (r.has) C.brass else C.hairlineBold)
                        Column(Modifier.weight(1f)) {
                            Text(r.name, style = T.body(15f, 600), color = C.ink)
                            if (r.collab == true && r.owner != null) Text("${r.owner}'s collab list", style = T.caption, color = C.inkMuted)
                        }
                    }
                    if (i < (rows?.lastIndex ?: 0)) HorizontalDivider(color = C.hairline)
                }
                if (rows?.isEmpty() == true) Text("No lists yet.", style = T.sub, color = C.inkMuted, modifier = Modifier.padding(15.dp))
            }
            Row(Modifier.padding(MQ.gutter), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(newName, { newName = it }, Modifier.weight(1f), singleLine = true, placeholder = { Text("New list", color = C.inkMuted) },
                    shape = RoundedCornerShape(11.dp), colors = mqFieldColors())
                ChipButton("Create", on = true, enabled = newName.isNotBlank()) {
                    val name = newName.trim(); newName = ""
                    scope.launch {
                        val c = session.client ?: return@launch
                        runCatching {
                            val created: CreatedList = c.post("lists", body("name" to name, "visibility" to "private", "shared_with" to emptyList<Int>()))
                            c.send("list/${created.id}/item", body("item_type" to itemType, "item_id" to itemId))
                        }
                        load(); session.refreshListMembership()
                    }
                }
            }
        }
    }
}

@Composable
fun mqFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedContainerColor = C.panel, unfocusedContainerColor = C.panel, focusedBorderColor = C.brassDim,
    unfocusedBorderColor = C.hairline, cursorColor = C.brass, focusedTextColor = C.ink, unfocusedTextColor = C.ink,
)

@Composable
fun ShareChip(path: String) {
    val session = LocalSession.current
    val ctx = LocalContext.current
    ChipButton("Share", Icons.Filled.Share) {
        val base = session.server?.baseUrl ?: return@ChipButton
        val send = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, "$base/#/$path") }
        ctx.startActivity(Intent.createChooser(send, null))
    }
}

@Composable
fun LinkChip(label: String, url: String) {
    val uri = LocalUriHandler.current
    ChipButton(label, Icons.AutoMirrored.Filled.OpenInNew) { runCatching { uri.openUri(url) } }
}

// ---------- artwork gallery

@Composable
fun ArtworkGallery(itemType: String, itemId: Int, title: String, onDismiss: () -> Unit) {
    val session = LocalSession.current
    var art by remember { mutableStateOf<ArtworkResponse?>(null) }
    var failed by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { runCatching { session.client?.get<ArtworkResponse>("images/$itemType/$itemId") }.onSuccess { art = it }.onFailure { failed = true } }
    Dialog(onDismiss, DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        Box(Modifier.fillMaxSize().background(Color.Black)) {
            val images = art?.all ?: emptyList()
            if (images.isNotEmpty()) {
                val pager = rememberPagerState { images.size }
                val scope = rememberCoroutineScope()
                Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
                    Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        IconButton(onDismiss) { Icon(Icons.Filled.Close, "Close", tint = Color.White) }
                        Text(title, style = T.headline, color = Color.White, modifier = Modifier.weight(1f), maxLines = 1)
                        Text("${pager.currentPage + 1} / ${images.size}", style = T.caption, color = Color.White.copy(alpha = 0.7f), modifier = Modifier.padding(end = 12.dp))
                    }
                    HorizontalPager(pager, Modifier.weight(1f).fillMaxWidth()) { i ->
                        Box(Modifier.fillMaxSize().padding(12.dp), contentAlignment = Alignment.Center) {
                            AsyncImage(images[i].full ?: images[i].thumb, null, contentScale = ContentScale.Fit, modifier = Modifier.fillMaxWidth().aspectRatio(images[i].aspect).clip(RoundedCornerShape(12.dp)))
                        }
                    }
                    LazyRow(contentPadding = PaddingValues(12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        itemsIndexed(images) { i, a ->
                            AsyncImage(a.thumb ?: a.full, null, contentScale = ContentScale.Crop,
                                modifier = Modifier.height(64.dp).aspectRatio(a.aspect).clip(RoundedCornerShape(6.dp))
                                    .border(2.dp, if (i == pager.currentPage) MqColors.brassOnArt else Color.Transparent, RoundedCornerShape(6.dp))
                                    .clickable { scope.launch { pager.animateScrollToPage(i) } })
                        }
                    }
                }
            } else {
                Text(if (failed || art != null) "No artwork to show." else "Loading artwork…", style = T.sub, color = Color.White.copy(alpha = 0.7f), modifier = Modifier.align(Alignment.Center))
                IconButton(onDismiss, Modifier.statusBarsPadding().padding(8.dp)) { Icon(Icons.Filled.Close, "Close", tint = Color.White) }
            }
        }
    }
}

// ---------- ratings panel

/**
 * Per-episode ratings as a line per season, IMDb first with TMDB fallback drawn as
 * hollow points, plus season averages as a strip of tiles coloured on the quality ramp.
 */
@Composable
fun RatingsPanel(r: ShowRatings) {
    val seasons = r.seasonAvg.map { it.season }.ifEmpty { r.episodes.map { it.season }.distinct() }
    var sel by rememberSaveable { mutableIntStateOf(-1) }
    val shown = if (sel < 0) r.episodes else r.episodes.filter { it.season == sel }
    val brass = C.brass; val hair = C.hairline; val muted = C.inkMuted; val ground = C.panel
    DetailSection("Ratings", if (r.source == "imdb") "IMDb" else "TMDB") {
        Column(Modifier.padding(horizontal = MQ.gutter).fillMaxWidth().mqPanel(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                SeasonTile("All", null, sel < 0) { sel = -1 }
                r.seasonAvg.forEach { a -> SeasonTile("S${a.season}", a.avg, sel == a.season) { sel = a.season } }
            }
            if (shown.size >= 2) {
                val lo = (shown.minOf { it.rating } - 0.5).coerceAtLeast(0.0).let { Math.floor(it) }
                val hi = (shown.maxOf { it.rating } + 0.3).coerceAtMost(10.0).let { Math.ceil(it) }
                Box(Modifier.fillMaxWidth().height(170.dp)) {
                    Canvas(Modifier.fillMaxSize().padding(start = 26.dp, top = 6.dp, bottom = 6.dp)) {
                        val w = size.width; val h = size.height
                        fun y(v: Double) = (h - (v - lo) / (hi - lo).coerceAtLeast(0.5) * h).toFloat()
                        // grid
                        var g = lo
                        while (g <= hi) { drawLine(hair, Offset(0f, y(g)), Offset(w, y(g)), 1f); g += 1.0 }
                        val step = if (shown.size > 1) w / (shown.size - 1) else w
                        // one path per season so lines break between seasons
                        shown.groupBy { it.season }.forEach { (_, eps) ->
                            val path = Path()
                            val fill = Path()
                            eps.forEachIndexed { i, e ->
                                val x = shown.indexOf(e) * step; val yy = y(e.rating)
                                if (i == 0) { path.moveTo(x, yy); fill.moveTo(x, h); fill.lineTo(x, yy) } else { path.lineTo(x, yy); fill.lineTo(x, yy) }
                                if (i == eps.lastIndex) { fill.lineTo(x, h); fill.close() }
                            }
                            drawPath(fill, Brush.verticalGradient(listOf(brass.copy(alpha = 0.22f), Color.Transparent)))
                            drawPath(path, brass, style = Stroke(2.2f))
                        }
                        shown.forEachIndexed { i, e ->
                            val c = Offset(i * step, y(e.rating))
                            if (e.isImdb) drawCircle(MqColors.rating(Math.round(e.rating).toInt()), 4.2f, c)
                            else { drawCircle(ground, 4.2f, c); drawCircle(muted, 4.2f, c, style = Stroke(1.6f)) }
                        }
                        // emphasised best episode
                        shown.maxByOrNull { it.rating }?.let { b -> val i = shown.indexOf(b); drawCircle(brass, 7f, Offset(i * step, y(b.rating)), style = Stroke(2f)) }
                    }
                    Column(Modifier.fillMaxSize().padding(vertical = 0.dp), verticalArrangement = Arrangement.SpaceBetween) {
                        Text(LibraryFormat.one(hi), style = T.body(10f, 600), color = muted)
                        Text(LibraryFormat.one(lo), style = T.body(10f, 600), color = muted)
                    }
                }
                shown.maxByOrNull { it.rating }?.let { b ->
                    Text("Best: S${b.season} · E${b.number}${b.title?.let { " $it" } ?: ""} — ${LibraryFormat.one(b.rating)}", style = T.caption, color = C.inkSoft, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
            if (r.isMixed) Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).clip(CircleShape).background(C.chartGreen)); Text("IMDb", style = T.caption, color = C.inkMuted)
                Box(Modifier.size(8.dp).clip(CircleShape).border(1.5.dp, C.inkMuted, CircleShape)); Text("TMDB where IMDb has none", style = T.caption, color = C.inkMuted)
            }
        }
    }
    @Suppress("UNUSED_EXPRESSION") seasons
}

@Composable
private fun SeasonTile(label: String, avg: Double?, selected: Boolean, onClick: () -> Unit) {
    val col = avg?.let { MqColors.rating(Math.round(it).toInt()) } ?: C.brass
    Column(
        Modifier.clip(RoundedCornerShape(9.dp)).background(if (selected) C.brassSoft else C.panelRaised)
            .border(1.dp, if (selected) C.brassDim else C.hairline, RoundedCornerShape(9.dp)).clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(label, style = T.body(10.5f, 700), color = if (selected) C.brass else C.inkSoft)
        avg?.let { Text(LibraryFormat.one(it), style = T.body(13f, 800).copy(fontFeatureSettings = "tnum"), color = col) }
    }
}

// ---------- reviews

/** Household reviews and the community's, veiled until you've watched it. */
@Composable
fun ReviewsSection(itemType: String, itemId: Int, subject: String, earned: Boolean) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val snackbar = LocalSnackbar.current
    var reviews by remember { mutableStateOf<List<Review>>(emptyList()) }
    var external by remember { mutableStateOf<List<ExternalReview>>(emptyList()) }
    var revealed by rememberSaveable { mutableStateOf(false) }
    var editing by remember { mutableStateOf<Review?>(null) }
    var writing by remember { mutableStateOf(false) }
    var replyTo by remember { mutableStateOf<Review?>(null) }
    var deleting by remember { mutableStateOf<Review?>(null) }
    suspend fun load() {
        val c = session.client ?: return
        runCatching { c.get<ReviewsResponse>("reviews/$itemType/$itemId") }.onSuccess { reviews = it.reviews }
        runCatching { c.get<ExternalReviewsResponse>("external_reviews/$itemType/$itemId") }.onSuccess { external = it.reviews }
    }
    LaunchedEffect(itemType, itemId) { load() }
    val hiding = !earned && !revealed

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        DetailSection("Reviews", reviews.size.takeIf { it > 0 }?.toString()) {
            Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                val mine = reviews.firstOrNull { it.mine }
                if (mine != null) ReviewCard(mine, onEdit = { editing = mine; writing = true }, onDelete = { deleting = mine }, onReply = { replyTo = mine })
                else Row(Modifier.fillMaxWidth().mqPanel().clickable { editing = null; writing = true }.padding(vertical = 13.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Edit, null, tint = C.brass, modifier = Modifier.size(16.dp)); Spacer(Modifier.width(6.dp)); Text("Write a review", style = T.sub, color = C.brass)
                }
                val others = reviews.filter { !it.mine }
                if (others.isNotEmpty()) {
                    if (hiding) SpoilerCover(if (others.size == 1) "1 review" else "${others.size} reviews", subject) { revealed = true }
                    else others.forEach { r -> ReviewCard(r, onReply = { replyTo = r }) }
                }
                if (reviews.isEmpty()) Text("No reviews from the house yet — be the first.", style = T.sub, color = C.inkMuted, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(vertical = 18.dp))
            }
        }
        if (external.isNotEmpty()) DetailSection("From the community", "${external.size}") {
            Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (hiding) SpoilerCover(if (external.size == 1) "1 comment" else "${external.size} comments", subject) { revealed = true }
                else external.take(12).forEach { ExternalReviewCard(it) }
            }
        }
    }

    if (writing) ReviewEditor(editing, onDismiss = { writing = false }) { rating, text ->
        val c = session.client ?: return@ReviewEditor false
        runCatching { c.send("reviews/$itemType/$itemId", body("rating" to rating, "body" to text)) }
            .onFailure { scope.launch { snackbar.showSnackbar(it.friendly) } }.isSuccess.also { if (it) load() }
    }
    replyTo?.let { r ->
        TextEditorSheet("Reply to ${r.author.name}", "Reply", onDismiss = { replyTo = null }) { text ->
            runCatching { session.client?.send("review/${r.id}/reply", body("body" to text)) }.isSuccess.also { if (it) load() }
        }
    }
    deleting?.let { r ->
        AlertDialog(onDismissRequest = { deleting = null }, containerColor = C.panelRaised,
            title = { Text("Delete your review?", style = T.headline, color = C.ink) },
            confirmButton = { TextButton({ deleting = null; scope.launch { runCatching { session.client?.sendDelete("review/${r.id}") }; load() } }) { Text("Delete", color = C.velvet) } },
            dismissButton = { TextButton({ deleting = null }) { Text("Cancel", color = C.brass) } })
    }
}

@Composable
fun SpoilerCover(what: String, subject: String, onReveal: () -> Unit) {
    var confirm by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().mqPanel(16.dp).padding(18.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(42.dp).clip(CircleShape).background(C.brassFill), contentAlignment = Alignment.Center) { Icon(Icons.Filled.VisibilityOff, null, tint = C.brassOnFill) }
        Text("SPOILERS AHEAD", style = T.wordmark(18f), color = C.ink)
        Text("$what for $subject. You haven't watched it yet.", style = T.caption, color = C.inkMuted, textAlign = TextAlign.Center)
        ChipButton("Show anyway") { confirm = true }
    }
    if (confirm) AlertDialog(onDismissRequest = { confirm = false }, containerColor = C.panelRaised,
        title = { Text("Show spoilers?", style = T.headline, color = C.ink) },
        confirmButton = { TextButton({ confirm = false; onReveal() }) { Text("Show them", color = C.brass) } },
        dismissButton = { TextButton({ confirm = false }) { Text("Keep hidden", color = C.inkSoft) } })
}

@Composable
private fun ReviewCard(r: Review, onEdit: (() -> Unit)? = null, onDelete: (() -> Unit)? = null, onReply: (() -> Unit)? = null) {
    Column(Modifier.fillMaxWidth().mqPanel().padding(13.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Avatar(r.author, 26.dp)
            Column(Modifier.weight(1f)) {
                Text(if (r.mine) "You" else r.author.name, style = T.body(13.5f, 700), color = C.ink)
                Text(MQTime.relative(r.updatedAt ?: r.createdAt), style = T.caption, color = C.inkMuted)
            }
            r.rating?.let { Row(verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Filled.Star, null, tint = C.brass, modifier = Modifier.size(13.dp)); Text(" $it", style = T.body(13f, 700), color = C.brass) } }
        }
        r.body?.takeIf { it.isNotBlank() }?.let { Text(it, style = T.body, color = C.inkSoft) }
        r.replies?.forEach { rep ->
            Row(Modifier.padding(start = 12.dp).fillMaxWidth().clip(RoundedCornerShape(9.dp)).background(C.panelRaised).padding(9.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Avatar(rep.author, 20.dp)
                Column { Text(if (rep.mine) "You" else rep.author.name, style = T.body(12f, 700), color = C.ink); Text(rep.body, style = T.caption, color = C.inkSoft) }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            onReply?.let { Text("Reply", style = T.body(12f, 700), color = C.brass, modifier = Modifier.clickable(onClick = it)) }
            onEdit?.let { Text("Edit", style = T.body(12f, 700), color = C.brass, modifier = Modifier.clickable(onClick = it)) }
            onDelete?.let { Text("Delete", style = T.body(12f, 700), color = C.velvet, modifier = Modifier.clickable(onClick = it)) }
        }
    }
}

@Composable
private fun ExternalReviewCard(r: ExternalReview) {
    Column(Modifier.fillMaxWidth().mqPanel().padding(13.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(r.author ?: "Someone", style = T.body(13f, 700), color = C.ink, modifier = Modifier.weight(1f))
            Text(r.source.uppercase(), style = T.eyebrow, color = C.inkMuted)
            r.rating?.let { Text("★ $it", style = T.body(12f, 700), color = C.brass) }
            r.likes?.takeIf { it > 0 }?.let { Text("♥ $it", style = T.body(12f, 600), color = C.inkMuted) }
        }
        var expanded by remember { mutableStateOf(false) }
        Text(r.body, style = T.caption, color = C.inkSoft, maxLines = if (expanded) Int.MAX_VALUE else 6, overflow = TextOverflow.Ellipsis, modifier = Modifier.clickable { expanded = !expanded })
    }
}

@Composable
private fun ReviewEditor(existing: Review?, onDismiss: () -> Unit, onSave: suspend (Int?, String) -> Boolean) {
    val scope = rememberCoroutineScope()
    var rating by remember { mutableStateOf(existing?.rating) }
    var text by remember { mutableStateOf(existing?.body ?: "") }
    var busy by remember { mutableStateOf(false) }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().imePaddingCompat().padding(horizontal = MQ.gutter, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(if (existing == null) "Write a review" else "Edit your review", style = T.headline, color = C.ink)
            StarRating(rating) { rating = it }
            OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 140.dp), placeholder = { Text("What did you think?", color = C.inkMuted) },
                shape = RoundedCornerShape(11.dp), colors = mqFieldColors())
            PrimaryButton("Post", { scope.launch { busy = true; if (onSave(rating, text.trim())) { sheet.hide(); onDismiss() }; busy = false } }, enabled = text.isNotBlank() || rating != null, busy = busy)
        }
    }
}

@Composable
fun TextEditorSheet(title: String, action: String, initial: String = "", onDismiss: () -> Unit, onSave: suspend (String) -> Boolean) {
    val scope = rememberCoroutineScope()
    var text by remember { mutableStateOf(initial) }
    var busy by remember { mutableStateOf(false) }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().imePaddingCompat().padding(horizontal = MQ.gutter, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(title, style = T.headline, color = C.ink)
            OutlinedTextField(text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 110.dp), shape = RoundedCornerShape(11.dp), colors = mqFieldColors())
            PrimaryButton(action, { scope.launch { busy = true; if (onSave(text.trim())) { sheet.hide(); onDismiss() }; busy = false } }, enabled = text.isNotBlank(), busy = busy)
        }
    }
}

fun Modifier.imePaddingCompat() = this.imePadding()
