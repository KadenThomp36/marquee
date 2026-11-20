package dev.kadenthompson.marquee.features.requests

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.DownloadForOffline
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tonality
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.model.OverseerrRequest
import dev.kadenthompson.marquee.model.PlexFile
import dev.kadenthompson.marquee.model.RequestDetail
import dev.kadenthompson.marquee.model.RequestDownload
import dev.kadenthompson.marquee.model.RequestState
import dev.kadenthompson.marquee.model.RequestStatus
import dev.kadenthompson.marquee.model.SeasonRequestState
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId

/** How a request feels, as a colour. Shared by film, TV and book requests. */
enum class RequestTone { IDLE, WAITING, WORKING, READY, PARTIAL, ATTENTION, FAILED, MUTED }

@Composable fun RequestTone.color(): Color = when (this) {
    RequestTone.IDLE, RequestTone.WAITING -> C.inkSoft
    RequestTone.WORKING -> C.brass
    RequestTone.READY -> C.chartGreen
    RequestTone.PARTIAL -> C.chartAqua
    RequestTone.ATTENTION -> C.chartOrange
    RequestTone.FAILED -> C.velvet
    RequestTone.MUTED -> C.inkMuted
}
@Composable fun RequestTone.wash(): Color = when (this) {
    RequestTone.IDLE, RequestTone.WAITING, RequestTone.MUTED -> C.panelRaised
    else -> color().copy(alpha = 0.14f)
}
@Composable fun RequestTone.edge(): Color = when (this) {
    RequestTone.IDLE, RequestTone.WAITING, RequestTone.MUTED -> C.hairlineBold
    else -> color().copy(alpha = 0.45f)
}

val RequestState.tone get() = when (this) {
    RequestState.NONE -> RequestTone.IDLE
    RequestState.PENDING, RequestState.PROCESSING -> RequestTone.WAITING
    RequestState.DOWNLOADING -> RequestTone.WORKING
    RequestState.PARTIAL -> RequestTone.PARTIAL
    RequestState.AVAILABLE -> RequestTone.READY
    RequestState.UNKNOWN -> RequestTone.MUTED
}
val RequestState.icon: ImageVector get() = when (this) {
    RequestState.NONE -> Icons.Outlined.Circle
    RequestState.PENDING -> Icons.Filled.Schedule
    RequestState.PROCESSING -> Icons.Filled.Search
    RequestState.DOWNLOADING -> Icons.Filled.DownloadForOffline
    RequestState.PARTIAL -> Icons.Filled.Tonality
    RequestState.AVAILABLE -> Icons.Filled.CheckCircle
    RequestState.UNKNOWN -> Icons.Filled.HelpOutline
}
val RequestState.pillLabel get() = when (this) {
    RequestState.NONE -> "Not on Plex"; RequestState.PENDING -> "Requested"; RequestState.PROCESSING -> "Searching"
    RequestState.DOWNLOADING -> "Downloading"; RequestState.PARTIAL -> "Partly on Plex"; RequestState.AVAILABLE -> "On Plex"
    RequestState.UNKNOWN -> "Status unknown"
}

@Composable
fun RequestStatusPill(label: String, icon: ImageVector, tone: RequestTone, compact: Boolean = false, modifier: Modifier = Modifier) {
    Row(
        modifier.clip(CircleShape).background(tone.wash()).border(1.dp, tone.edge(), CircleShape)
            .padding(horizontal = if (compact) 7.dp else 10.dp, vertical = if (compact) 3.dp else 5.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (compact) 4.dp else 5.dp),
    ) {
        Icon(icon, null, tint = tone.color(), modifier = Modifier.size(if (compact) 11.dp else 13.dp))
        Text(label, style = T.body(if (compact) 10.5f else 12f, 700), color = tone.color(), maxLines = 1)
    }
}

/** "1 h 22 min left", not `01:22:05`; also `1.02:00:00` day-prefixed clocks. */
object RequestEta {
    fun readable(raw: String?): String? {
        val r = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        var days = 0.0
        var clock = r
        val colon = r.indexOf(':')
        if (colon > 0) { val dot = r.substring(0, colon).indexOf('.'); if (dot >= 0) { days = r.substring(0, dot).toDoubleOrNull() ?: 0.0; clock = r.substring(dot + 1) } }
        val parts = clock.split(":").mapNotNull { it.toDoubleOrNull() }
        if (parts.size != 3) return r
        val secs = days * 86400 + parts[0] * 3600 + parts[1] * 60 + parts[2]
        if (secs < 60) return "under a minute left"
        val mins = Math.round(secs / 60).toInt()
        if (mins < 60) return "$mins min left"
        val h = mins / 60; val rest = mins % 60
        if (h < 24) return if (rest == 0) "$h h left" else "$h h $rest min left"
        val d = h / 24; val rh = h % 24
        return if (rh == 0) "$d d left" else "$d d $rh h left"
    }
}

@Composable
fun RequestProgressTrack(
    fraction: Float = 0f, percent: Int? = null, eta: String? = null, note: String? = null,
    tone: RequestTone = RequestTone.WORKING, indeterminate: Boolean = false, height: Dp = 7.dp, modifier: Modifier = Modifier,
) {
    val f by animateFloatAsState(fraction.coerceIn(0f, 1f), spring(0.85f), label = "rt")
    val sweep by rememberInfiniteTransition(label = "sw").animateFloat(0f, 0.68f, infiniteRepeatable(tween(1250), RepeatMode.Reverse), label = "s")
    val col = tone.color()
    Column(modifier, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        BoxWithConstraints(Modifier.fillMaxWidth().height(height).clip(CircleShape).background(C.panelRaised).border(0.5.dp, C.hairline, CircleShape)) {
            if (indeterminate) Box(Modifier.offset(x = maxWidth * sweep).width(maxWidth * 0.32f).fillMaxHeight()
                .background(Brush.horizontalGradient(listOf(col.copy(alpha = 0f), col, col.copy(alpha = 0f)))))
            else if (f > 0) Box(Modifier.fillMaxWidth(f).fillMaxHeight().clip(CircleShape).background(Brush.horizontalGradient(listOf(col.copy(alpha = 0.65f), col))))
        }
        val e = RequestEta.readable(eta)
        if (percent != null || e != null || note != null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            note?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.body(11.5f, 600), color = C.inkSoft, maxLines = 2) }
            Spacer(Modifier.weight(1f))
            percent?.let { Text("$it%", style = T.body(11.5f, 600).copy(fontFeatureSettings = "tnum"), color = col) }
            e?.let { Text(it, style = T.body(11.5f, 600), color = C.inkMuted) }
        }
    }
}

/** The landing moment after a request goes through. */
@Composable
fun RequestConfirmation(title: String, detail: String?) {
    val haptic = LocalHapticFeedback.current
    var landed by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { landed = true; haptic.performHapticFeedback(HapticFeedbackType.Confirm) }
    val s by animateFloatAsState(if (landed) 1f else 0.3f, spring(0.6f, 300f), label = "c")
    Column(Modifier.fillMaxSize().background(C.ground.copy(alpha = 0.95f)).padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
        Box(Modifier.size(86.dp).scale(s).clip(CircleShape).background(C.brassSoft), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.Check, null, tint = C.brass, modifier = Modifier.size(42.dp).rotate((1 - s) * -18f))
        }
        Text(title, style = T.body(19f, 700), color = C.ink)
        detail?.let { Text(it, style = T.sub, color = C.inkSoft, textAlign = TextAlign.Center) }
    }
}

/** The request control in a title's action row: "Request", or a pill that opens the details. */
@Composable
fun RequestButton(status: RequestStatus, onClick: () -> Unit) {
    val seasons = status.seasons ?: emptyList()
    val canMore = seasons.any { it.isSelectable }
    when {
        status.state == RequestState.AVAILABLE && !canMore ->
            RequestStatusPill(status.state.pillLabel, status.state.icon, RequestTone.READY, modifier = Modifier.clip(CircleShape).clickable(onClick = onClick))
        status.state == RequestState.NONE -> ChipButton("Request", Icons.Filled.Download, on = true, onClick = onClick)
        else -> Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
            val shown = if (status.download != null) RequestState.DOWNLOADING else status.state
            val label = when {
                status.download != null -> "Downloading"
                (status.state == RequestState.AVAILABLE || status.state == RequestState.PARTIAL) && canMore -> "Request more"
                else -> status.state.pillLabel
            }
            RequestStatusPill(label, shown.icon, shown.tone, modifier = Modifier.clip(CircleShape).clickable(onClick = onClick))
            status.download?.let { RequestProgressTrack(it.fraction, it.progress, it.eta, height = 5.dp, modifier = Modifier.widthIn(max = 210.dp)) }
        }
    }
}

@Composable
private fun SeasonStrip(seasons: List<SeasonRequestState>) {
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        seasons.forEach { s ->
            val col = s.state.tone.color()
            Box(Modifier.weight(1f).height(10.dp).clip(RoundedCornerShape(3.dp)).background(if (s.state == RequestState.NONE) C.panelRaised else col.copy(alpha = 0.28f))) {
                if (s.state == RequestState.DOWNLOADING) Box(Modifier.fillMaxWidth((s.progress ?: 0) / 100f).fillMaxHeight().background(col))
                else if (s.state != RequestState.NONE) Box(Modifier.fillMaxSize().background(col))
            }
        }
    }
}

/** Season picker + request details for a show. Delete lives in the details panel. */
@Composable
fun SeasonRequestSheet(showId: Int, status: RequestStatus, onDismiss: () -> Unit, onDone: suspend () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val seasons = status.seasons ?: emptyList()
    val selectable = seasons.filter { it.isSelectable }
    var selected by remember { mutableStateOf(setOf<Int>()) }
    var busy by remember { mutableStateOf(false) }
    var confirmed by remember { mutableStateOf<List<Int>?>(null) }
    var failure by remember { mutableStateOf<String?>(null) }
    val all = selectable.isNotEmpty() && selected.size == selectable.size
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    fun request() = scope.launch {
        val c = session.client ?: return@launch
        busy = true; failure = null
        val nums = selected.sorted()
        try {
            c.send("request", body("item_type" to "show", "item_id" to showId, "seasons" to nums))
            selected = emptySet(); confirmed = nums
            onDone(); delay(1600); sheet.hide(); onDismiss(); delay(2000); onDone()
        } catch (e: Exception) { failure = e.friendly } finally { busy = false }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = C.ground) {
        Box {
            Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
                SheetTitle(if (status.state == RequestState.NONE) "Request seasons" else "Request details") { scope.launch { sheet.hide(); onDismiss() } }
                Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter).padding(bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // overview
                    val available = seasons.count { it.state == RequestState.AVAILABLE }
                    val downloading = seasons.count { it.state == RequestState.DOWNLOADING }
                    val asked = seasons.count { it.state.isRequested && it.state != RequestState.DOWNLOADING }
                    val headline = when {
                        seasons.isNotEmpty() && available == seasons.size -> if (seasons.size == 1) "On Plex" else "All ${seasons.size} seasons on Plex"
                        downloading > 0 -> "Downloading $downloading season${if (downloading == 1) "" else "s"}"
                        available > 0 -> "$available of ${seasons.size} seasons on Plex"
                        asked > 0 -> "Requested, waiting to download"
                        else -> "Not on Plex yet"
                    }
                    Column(Modifier.fillMaxWidth().mqPanel(16.dp).padding(15.dp), verticalArrangement = Arrangement.spacedBy(11.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(headline, style = T.headline, color = C.ink, modifier = Modifier.weight(1f))
                            val shown = if (status.download != null) RequestState.DOWNLOADING else status.state
                            RequestStatusPill(shown.pillLabel, shown.icon, shown.tone, compact = true)
                        }
                        if (seasons.size > 1) SeasonStrip(seasons)
                        status.download?.let { RequestProgressTrack(it.fraction, it.progress, it.eta, if (it.active > 1) "${it.active} downloads running" else null) }
                        val counts = listOfNotNull(
                            available.takeIf { it > 0 }?.let { "$it on Plex" }, downloading.takeIf { it > 0 }?.let { "$it downloading" },
                            asked.takeIf { it > 0 }?.let { "$it requested" }, selectable.size.takeIf { it > 0 }?.let { "$it not requested" })
                        if (counts.isNotEmpty()) Text(counts.joinToString(", "), style = T.caption, color = C.inkMuted)
                    }
                    RequestDetailsPanel("show", showId, onChanged = onDone)
                    if (seasons.isNotEmpty()) Eyebrow(if (selectable.isEmpty()) "Seasons" else "Request more")
                    if (selectable.isNotEmpty()) Row(
                        Modifier.fillMaxWidth().mqPanel(16.dp).clickable { selected = if (all) emptySet() else selectable.map { it.number }.toSet(); haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                            .padding(horizontal = 15.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Icon(if (all) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = if (all) C.brass else C.hairlineBold, modifier = Modifier.size(22.dp))
                        Text(if (all) "Clear selection" else "Select every season not on Plex", style = T.sub, color = C.ink, modifier = Modifier.weight(1f))
                        Text("${selectable.size}", style = T.numeric, color = C.inkMuted)
                    }
                    if (seasons.isNotEmpty()) Column(Modifier.fillMaxWidth().mqPanel(16.dp)) {
                        seasons.forEachIndexed { i, s ->
                            val isSel = s.number in selected
                            Row(
                                Modifier.fillMaxWidth().background(if (isSel) C.brassSoft else Color.Transparent)
                                    .clickable(enabled = s.isSelectable) { selected = if (isSel) selected - s.number else selected + s.number; haptic.performHapticFeedback(HapticFeedbackType.SegmentTick) }
                                    .padding(horizontal = 15.dp, vertical = 13.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
                            ) {
                                if (s.isSelectable) Icon(if (isSel) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked, null, tint = if (isSel) C.brass else C.hairlineBold, modifier = Modifier.size(22.dp))
                                else Icon(s.state.icon, null, tint = s.state.tone.color(), modifier = Modifier.size(22.dp))
                                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                    Text("Season ${s.number}", style = T.body(15f, 700), color = C.ink)
                                    Text(listOfNotNull("${s.episodes} episode${if (s.episodes == 1) "" else "s"}",
                                        if (s.state == RequestState.DOWNLOADING) RequestEta.readable(s.eta) else null).joinToString(" · "), style = T.caption, color = C.inkMuted)
                                }
                                if (!s.isSelectable) {
                                    if (s.state == RequestState.DOWNLOADING && s.progress != null) RequestStatusPill("${s.progress}%", s.state.icon, s.state.tone, true)
                                    else RequestStatusPill(s.state.pillLabel, s.state.icon, s.state.tone, true)
                                }
                            }
                            if (i < seasons.lastIndex) HorizontalDivider(Modifier.padding(start = 50.dp), color = C.hairline)
                        }
                    }
                    failure?.let { ErrorLine(it) }
                }
                if (selectable.isNotEmpty()) PrimaryButton(
                    when { selected.isEmpty() -> "Pick seasons to request"; selected.size == 1 -> "Request season ${selected.first()}"; else -> "Request ${selected.size} seasons" },
                    { request() }, Modifier.padding(horizontal = MQ.gutter, vertical = 10.dp), enabled = selected.isNotEmpty(), busy = busy,
                )
            }
            confirmed?.let { n ->
                Box(Modifier.matchParentSize()) {
                    RequestConfirmation("Requested", if (n.size == 1) "Season ${n[0]} is on its way to Plex." else "${n.size} seasons are on their way to Plex.")
                }
            }
        }
    }
}

@Composable
fun MovieRequestSheet(movieId: Int, status: RequestStatus, onDismiss: () -> Unit, onDone: suspend () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var busy by remember { mutableStateOf(false) }
    var sent by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val shown = if (status.download != null) RequestState.DOWNLOADING else status.state
    fun request() = scope.launch {
        val c = session.client ?: return@launch
        busy = true; failure = null
        try {
            c.send("request", body("item_type" to "movie", "item_id" to movieId))
            sent = true; onDone(); delay(1600); sheet.hide(); onDismiss(); delay(2000); onDone()
        } catch (e: Exception) { failure = e.friendly } finally { busy = false }
    }
    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = C.ground) {
        Box {
            Column(Modifier.fillMaxWidth().navigationBarsPadding()) {
                SheetTitle(if (status.state == RequestState.NONE) "Request" else "Request details") { scope.launch { sheet.hide(); onDismiss() } }
                Column(Modifier.weight(1f, fill = false).verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter).padding(bottom = 16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(when (shown) {
                            RequestState.NONE -> "Not on Plex yet"; RequestState.AVAILABLE -> "Ready to watch"; RequestState.DOWNLOADING -> "On its way"
                            RequestState.UNKNOWN -> "Overseerr didn’t answer"; else -> "Requested"
                        }, style = T.body(19f, 700), color = C.ink, modifier = Modifier.weight(1f))
                        RequestStatusPill(shown.pillLabel, shown.icon, shown.tone)
                    }
                    status.download?.let { RequestProgressTrack(it.fraction, it.progress, it.eta) }
                    Text(when (shown) {
                        RequestState.NONE -> "Ask Overseerr for it and it lands on Plex once it’s downloaded. Everyone in the house can see the request."
                        RequestState.PENDING -> "Waiting for approval in Overseerr."
                        RequestState.PROCESSING -> "Approved. Radarr is looking for a copy."
                        RequestState.DOWNLOADING -> "Downloading now. It appears on Plex when it finishes."
                        RequestState.PARTIAL, RequestState.AVAILABLE -> "It’s on Plex."
                        RequestState.UNKNOWN -> "The request server didn’t answer. Try again in a bit."
                    }, style = T.sub, color = C.inkSoft)
                    RequestDetailsPanel("movie", movieId, onChanged = onDone)
                    failure?.let { ErrorLine(it) }
                }
                if (status.state == RequestState.NONE) PrimaryButton("Request this film", { request() }, Modifier.padding(horizontal = MQ.gutter, vertical = 10.dp), busy = busy)
            }
            if (sent) Box(Modifier.matchParentSize()) { RequestConfirmation("Requested", "Overseerr will fetch it and put it on Plex.") }
        }
    }
}

@Composable
fun SheetTitle(title: String, closeLabel: String = "Close", onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(start = MQ.gutter, end = 8.dp, bottom = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = T.headline, color = C.ink, modifier = Modifier.weight(1f))
        TextButton(onClose) { Text(closeLabel, style = T.sub, color = C.brass) }
    }
}

@Composable
fun ErrorLine(text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Filled.Warning, null, tint = C.velvet, modifier = Modifier.size(15.dp))
        Text(text, style = T.caption, color = C.velvet)
    }
}

// ---------- the details panel: what's on Plex, what's downloading, who asked, Delete

object RequestWhen {
    fun relative(raw: String?): String {
        if (raw.isNullOrEmpty()) return ""
        val iso = runCatching { OffsetDateTime.parse(raw).atZoneSameInstant(ZoneId.systemDefault()).toLocalDateTime() }.getOrNull()
            ?: runCatching { Instant.parse(raw).atZone(ZoneId.systemDefault()).toLocalDateTime() }.getOrNull()
        return MQTime.relative(iso?.let { MQTime.stamp(it) } ?: raw)
    }
}

object RequestDetailText {
    fun seasons(numbers: List<Int>): String {
        val s = numbers.toSortedSet().toList()
        if (s.isEmpty()) return ""
        if (s.size == 1) return "Season ${s[0]}"
        if (s.last() - s.first() + 1 == s.size) return "Seasons ${s.first()}–${s.last()}"
        return "Seasons " + s.dropLast(1).joinToString(", ") + " and " + s.last()
    }
    fun headline(f: PlexFile, isShow: Boolean): String {
        val parts = listOfNotNull(
            f.resolution?.takeIf { it.isNotEmpty() }?.let { if (f.mixed == true) "Mostly $it" else it },
            f.hdr?.takeIf { it.isNotEmpty() }, f.video?.takeIf { it.isNotEmpty() }, f.audio?.takeIf { it.isNotEmpty() }, f.size?.takeIf { it.isNotEmpty() })
        return if (parts.isEmpty()) (if (isShow) "On Plex" else "On Plex, details unknown") else parts.joinToString(" · ")
    }
    fun detail(f: PlexFile, isShow: Boolean): String = if (isShow) listOfNotNull(f.episodes?.let { "$it episode${if (it == 1) "" else "s"}" }).joinToString(" · ")
    else listOfNotNull(f.container?.takeIf { it.isNotEmpty() }, f.bitrate?.takeIf { it.isNotEmpty() }, f.copies?.takeIf { it > 1 }?.let { "$it copies" }).joinToString(" · ")
}

private fun OverseerrRequest.pillSpec(): Triple<String, ImageVector, RequestTone> {
    val words = status ?: "Requested"
    val l = words.lowercase()
    val (icon, tone) = when {
        "waiting" in l || "pending" in l -> Icons.Filled.Schedule to RequestTone.WAITING
        "approved" in l -> Icons.Filled.Verified to RequestTone.WORKING
        "declined" in l -> Icons.Filled.Cancel to RequestTone.FAILED
        "failed" in l -> Icons.Filled.Warning to RequestTone.FAILED
        "completed" in l || "available" in l -> Icons.Filled.CheckCircle to RequestTone.READY
        else -> Icons.Filled.Schedule to RequestTone.MUTED
    }
    return Triple(words, icon, tone)
}

@Composable
fun RequestDetailSection(title: String, count: Int? = null, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Eyebrow(title)
            if (count != null && count > 1) Text("$count", style = T.caption, color = C.inkMuted)
        }
        Column(Modifier.fillMaxWidth().mqPanel(16.dp)) { content() }
    }
}

@Composable
fun RequestSymbol(icon: ImageVector, tone: RequestTone) {
    Box(Modifier.size(26.dp).clip(CircleShape).background(tone.wash()).border(1.dp, tone.edge(), CircleShape), contentAlignment = Alignment.Center) {
        Icon(icon, null, tint = tone.color(), modifier = Modifier.size(14.dp))
    }
}

@Composable
fun RequestFactRow(icon: ImageVector, tone: RequestTone, headline: String, detail: String? = null, dense: Boolean = false, trailing: @Composable () -> Unit = {}) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
        RequestSymbol(icon, tone)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(headline, style = if (dense) T.body(13f, 600) else T.body(15f, 700), color = C.ink, maxLines = if (dense) 3 else 2, overflow = TextOverflow.MiddleEllipsis)
            detail?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkMuted) }
        }
        trailing()
    }
}

@Composable
fun RequesterRow(name: String?, isMine: Boolean, whenRaw: String?, extras: List<String>, pill: (@Composable () -> Unit)?, canDelete: Boolean, deleting: Boolean, onDelete: () -> Unit) {
    val who = if (isMine) "You" else name?.takeIf { it.isNotEmpty() } ?: "Someone"
    Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(13.dp)) {
            Box(Modifier.size(26.dp).clip(CircleShape).background(if (isMine) C.brassSoft else C.panelRaised).border(1.dp, if (isMine) C.brassDim else C.hairlineBold, CircleShape), contentAlignment = Alignment.Center) {
                Text((name?.takeIf { it.isNotEmpty() } ?: who).take(1).uppercase(), style = T.body(12f, 700), color = if (isMine) C.brass else C.inkSoft)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                val ago = RequestWhen.relative(whenRaw)
                Text(if (ago.isEmpty()) "$who asked" else "$who asked $ago", style = T.body(15f, 700), color = C.ink)
                if (extras.isNotEmpty()) Text(extras.joinToString(" · "), style = T.caption, color = C.inkMuted)
            }
            pill?.invoke()
        }
        if (canDelete) Box(Modifier.padding(start = 39.dp)) {
            if (deleting) CircularProgressIndicator(Modifier.size(18.dp), color = C.velvet, strokeWidth = 2.dp)
            else ChipButton("Delete request", Icons.Filled.Delete, destructive = true, onClick = onDelete)
        }
    }
}

@Composable
fun RequestDetailsPanel(itemType: String, itemId: Int, sample: RequestDetail? = null, onChanged: suspend () -> Unit = {}) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    var detail by remember { mutableStateOf(sample) }
    var loaded by remember { mutableStateOf(sample != null) }
    var confirming by remember { mutableStateOf<OverseerrRequest?>(null) }
    var deleting by remember { mutableStateOf<Int?>(null) }
    var failure by remember { mutableStateOf<String?>(null) }
    val isShow = itemType == "show"
    suspend fun load() {
        if (sample != null) return
        session.client?.let { c -> runCatching { c.get<RequestDetail>("request/detail/$itemType/$itemId") }.onSuccess { detail = it } }
        loaded = true
    }
    LaunchedEffect(itemType, itemId) { load() }

    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        val d = detail
        if (d != null && d.enabled != false) {
            if (d.unavailable == true) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.WifiOff, null, tint = C.inkMuted, modifier = Modifier.size(15.dp))
                Text("Overseerr didn’t answer, so the request details can’t be shown right now.", style = T.caption, color = C.inkMuted)
            } else {
                d.file?.let { f ->
                    RequestDetailSection("On Plex") { RequestFactRow(Icons.Filled.PlayCircle, RequestTone.READY, RequestDetailText.headline(f, isShow), RequestDetailText.detail(f, isShow)) }
                }
                val downloads = d.downloads ?: emptyList()
                if (downloads.isNotEmpty()) RequestDetailSection("Downloading", downloads.size) {
                    downloads.forEachIndexed { i, dl -> DownloadRow(dl); if (i < downloads.lastIndex) HorizontalDivider(Modifier.padding(start = 50.dp), color = C.hairline) }
                }
                val requests = d.requests ?: emptyList()
                if (requests.isNotEmpty()) RequestDetailSection(if (requests.size == 1) "Request" else "Requests", requests.size) {
                    requests.forEachIndexed { i, r ->
                        val (label, icon, tone) = r.pillSpec()
                        RequesterRow(r.requestedBy, r.mine == true, r.createdAt,
                            listOfNotNull(r.seasons?.takeIf { it.isNotEmpty() }?.let { RequestDetailText.seasons(it) }, if (r.is4k == true) "4K" else null),
                            { RequestStatusPill(label, icon, tone, true) }, r.canDelete == true, deleting == r.id) { confirming = r }
                        if (i < requests.lastIndex) HorizontalDivider(Modifier.padding(start = 50.dp), color = C.hairline)
                    }
                } else if (d.file == null && downloads.isEmpty()) Text("Nobody has asked for this yet.", style = T.caption, color = C.inkMuted)
            }
        } else if (!loaded) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { Skeleton(Modifier.width(90.dp), 12.dp); Skeleton(height = 64.dp, radius = 16.dp) }
        failure?.let { ErrorLine(it) }
    }

    confirming?.let { r ->
        AlertDialog(
            onDismissRequest = { confirming = null }, containerColor = C.panelRaised,
            title = { Text(if (r.mine == true) "Delete your request?" else "Delete ${r.requestedBy ?: "their"}’s request?", style = T.headline, color = C.ink) },
            text = { Text("Overseerr forgets the request${if (isShow) " for those seasons" else ""}. Whatever is already on Plex stays.", style = T.body, color = C.inkSoft) },
            confirmButton = {
                TextButton({
                    confirming = null
                    scope.launch {
                        failure = null
                        if (sample != null) { detail = detail?.copy(requests = detail?.requests?.filterNot { it.id == r.id }); return@launch }
                        val c = session.client ?: return@launch
                        deleting = r.id
                        try {
                            c.send("request/${r.id}/delete")
                            detail = detail?.copy(requests = detail?.requests?.filterNot { it.id == r.id })
                            haptic.performHapticFeedback(HapticFeedbackType.Confirm)
                            onChanged(); load()
                        } catch (e: Exception) { failure = e.friendly } finally { deleting = null }
                    }
                }) { Text("Delete request", color = C.velvet) }
            },
            dismissButton = { TextButton({ confirming = null }) { Text("Keep it", color = C.brass) } },
        )
    }
}

@Composable
private fun DownloadRow(d: RequestDownload) {
    Column {
        RequestFactRow(Icons.Filled.DownloadForOffline, RequestTone.WORKING, d.title ?: "A release",
            listOfNotNull(d.season?.let { s -> d.episode?.let { "S$s · E$it" } ?: "Season $s" }, d.size?.takeIf { it.isNotEmpty() }).joinToString(" · "), dense = true)
        RequestProgressTrack((d.progress ?: 0) / 100f, d.progress, d.eta,
            note = if (d.progress == null) d.status?.replaceFirstChar { it.uppercase() } else null,
            indeterminate = d.progress == null, height = 5.dp, modifier = Modifier.padding(start = 53.dp, end = 14.dp, bottom = 12.dp))
    }
}
