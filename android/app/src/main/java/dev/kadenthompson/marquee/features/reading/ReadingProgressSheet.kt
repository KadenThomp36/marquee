package dev.kadenthompson.marquee.features.reading

import androidx.compose.animation.AnimatedContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ChipRow
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.QuietButton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.model.ActiveSession
import dev.kadenthompson.marquee.model.ProgressMode
import dev.kadenthompson.marquee.model.ReadingItem
import dev.kadenthompson.marquee.model.ReadingKind
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.LocalDateTime
import kotlin.math.roundToInt

/** What the one progress sheet is logging against, with the unit maths for every mode. */
data class ProgressTarget(
    val kind: ReadingKind,
    val itemId: Int,
    val title: String,
    val progress: Int,
    val pages: Int?,
    val chapters: Int?,
    val rawMode: String?,
    val live: ActiveSession?,
    val chapterTitles: Map<Int, String> = emptyMap(),
) {
    constructor(item: ReadingItem, kind: ReadingKind, live: ActiveSession? = null) :
        this(kind, item.id, item.displayTitle, item.progress ?: 0, item.pages, item.chapters, item.mode, live)

    constructor(session: ActiveSession, progress: Int?) : this(
        session.readingKind, session.itemId, session.title ?: "Reading", progress ?: session.startPos ?: 0,
        session.pages, if (session.readingKind == ReadingKind.BOOK) session.bookChapters else session.chapters, session.mode, session,
    )

    val canonicalTotal: Int? get() = (if (kind == ReadingKind.BOOK) pages else chapters)?.takeIf { it > 0 }

    val mode: String
        get() {
            val natural = if (kind == ReadingKind.MANGA) ProgressMode.CHAPTERS else ProgressMode.PAGES
            return when (rawMode ?: natural) {
                ProgressMode.PCT -> if (canonicalTotal == null) natural else ProgressMode.PCT
                ProgressMode.CHAPTERS -> if (kind == ReadingKind.MANGA) ProgressMode.CHAPTERS
                    else if ((pages ?: 0) > 0 && (chapters ?: 0) > 0) ProgressMode.CHAPTERS else ProgressMode.PAGES
                else -> natural
            }
        }

    val displayTotal: Int?
        get() = when (mode) {
            ProgressMode.PCT -> 100
            ProgressMode.CHAPTERS -> if (kind == ReadingKind.BOOK) chapters else canonicalTotal
            else -> canonicalTotal
        }

    fun display(stored: Int): Int = when {
        mode == ProgressMode.PCT -> canonicalTotal?.let { minOf(100, (stored.toDouble() / it * 100).roundToInt()) } ?: stored
        mode == ProgressMode.CHAPTERS && kind == ReadingKind.BOOK && (pages ?: 0) > 0 && chapters != null ->
            minOf(chapters, (stored.toDouble() / pages!! * chapters).roundToInt())
        else -> stored
    }

    fun stored(shown: Int): Int = when {
        mode == ProgressMode.PCT -> canonicalTotal?.let { minOf(it, (shown / 100.0 * it).roundToInt()) } ?: shown
        mode == ProgressMode.CHAPTERS && kind == ReadingKind.BOOK && pages != null && (chapters ?: 0) > 0 ->
            minOf(pages, (shown.toDouble() / chapters!! * pages).roundToInt())
        else -> shown
    }

    fun unitName(n: Int) = when (mode) {
        ProgressMode.PCT -> "%"; ProgressMode.CHAPTERS -> if (n == 1) "chapter" else "chapters"; else -> if (n == 1) "page" else "pages"
    }

    fun positionLabel(shown: Int) = when (mode) { ProgressMode.PCT -> "$shown%"; ProgressMode.CHAPTERS -> "ch $shown"; else -> "p. $shown" }
}

sealed interface ProgressOutcome {
    data class Progress(val value: Int) : ProgressOutcome
    data class Finished(val value: Int) : ProgressOutcome
    data class SessionEnded(val value: Int) : ProgressOutcome
    data object Discarded : ProgressOutcome
}

/**
 * The one sheet every way of logging progress goes through — a detail page, a shelf
 * tile, Home, ending a session. One tap never finishes a book: "Finished it" only
 * appears at the end.
 */
@Composable
fun ReadingProgressSheet(target: ProgressTarget, onDismiss: () -> Unit, onSaved: suspend (ProgressOutcome) -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val haptic = LocalHapticFeedback.current
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var position by remember { mutableStateOf(target.display(target.progress)) }
    var typing by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }
    var summary by remember { mutableStateOf<String?>(null) }
    var confirmDiscard by remember { mutableStateOf(false) }
    val upper = target.displayTotal
    val isLive = target.live != null
    val reachedEnd = upper != null && target.canonicalTotal != null && position >= upper
    fun clamp(v: Int) = v.coerceIn(0, upper ?: Int.MAX_VALUE)
    fun storedPos() = if (position == target.display(target.progress)) target.progress else target.stored(position)
    val path = "${target.kind.path}/${target.itemId}"
    val startDisplay = target.live?.let { target.display(it.startPos ?: target.progress) }
    val gained = maxOf(0, position - (startDisplay ?: position))

    fun close() = scope.launch { sheet.hide(); onDismiss() }

    fun save() = scope.launch {
        val c = session.client ?: return@launch
        busy = true; failure = null
        val pos = storedPos()
        try {
            if (isLive) {
                try { c.send("$path/session/end", body("pos" to pos)) } catch (e: Exception) {
                    failure = "Couldn't save the session — it's still running. Try again in a moment."; return@launch
                }
                haptic.performHapticFeedback(HapticFeedbackType.Confirm)
                summary = if (gained > 0) "Nice session — ${if (target.mode == ProgressMode.PCT) "+$gained%" else "+$gained ${target.unitName(gained)}"}." else "Session saved."
                onSaved(ProgressOutcome.SessionEnded(pos)); session.noteReading()
                delay(1600); close(); return@launch
            }
            if (pos == target.progress) { close(); return@launch }
            try { c.send("$path/state", body("progress" to pos)) } catch (e: Exception) {
                failure = "Couldn't save — check your connection and try again."; return@launch
            }
            haptic.performHapticFeedback(HapticFeedbackType.Confirm)
            onSaved(ProgressOutcome.Progress(pos)); session.noteReading()
            close()
        } finally { busy = false }
    }

    fun finish() = scope.launch {
        val c = session.client ?: return@launch
        val total = target.canonicalTotal ?: return@launch
        busy = true; failure = null
        try {
            if (isLive) try { c.send("$path/session/end", body("pos" to total)) } catch (e: Exception) {
                failure = "Couldn't save the session — it's still running. Try again in a moment."; return@launch
            }
            try { c.send("$path/state", body("state" to "finished", "progress" to total)) } catch (e: Exception) {
                failure = "Couldn't save — check your connection and try again."; return@launch
            }
            haptic.performHapticFeedback(HapticFeedbackType.Confirm)
            summary = "Finished ${target.title}."
            onSaved(ProgressOutcome.Finished(total)); session.noteReading()
            delay(1400); close()
        } finally { busy = false }
    }

    fun discard() = scope.launch {
        val c = session.client ?: return@launch
        busy = true
        try { c.send("$path/session/end", body("discard" to true)); onSaved(ProgressOutcome.Discarded); session.noteReading(); close() }
        catch (e: Exception) { failure = "Couldn't discard the session. Try again in a moment." }
        finally { busy = false }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = C.ground, dragHandle = null) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().padding(MQ.gutter), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(if (isLive) "End session" else "Progress", style = T.headline, color = C.ink, modifier = Modifier.weight(1f))
                TextButton(onClick = { close() }) { Text("Cancel", style = T.sub, color = C.brass) }
            }
            AnimatedContent(summary, label = "sum") { s ->
                if (s != null) Column(Modifier.fillMaxWidth().padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.CheckCircle, null, tint = C.brass, modifier = Modifier.size(46.dp))
                    Text(s, style = T.headline, color = C.ink, textAlign = TextAlign.Center)
                } else Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                    target.live?.let { live -> SessionStrip(live, gained, target) }
                    // Readout
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(target.title, style = T.body(15f, 700), color = C.inkSoft, maxLines = 2)
                        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (typing) {
                                var text by remember { mutableStateOf(position.toString()) }
                                BasicTextField(text, { t -> text = t.filter(Char::isDigit).take(6); text.toIntOrNull()?.let { position = clamp(it) } },
                                    textStyle = T.body(44f, 700).copy(color = C.ink), singleLine = true,
                                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                                    keyboardActions = KeyboardActions(onDone = { typing = false }), modifier = Modifier.width(170.dp))
                            } else Text(if (target.mode == ProgressMode.PCT) "$position%" else "$position", style = T.body(44f, 700).copy(fontFeatureSettings = "tnum"),
                                color = C.ink, modifier = Modifier.clickable { typing = true })
                            Text(caption(target, position, upper), style = T.sub, color = C.inkMuted, modifier = Modifier.padding(bottom = 10.dp))
                        }
                        if (target.mode == ProgressMode.CHAPTERS && position > 0) target.chapterTitles[position]?.takeIf { it.isNotEmpty() }?.let {
                            Text(it, style = T.caption, color = C.brass, maxLines = 1)
                        }
                    }
                    if (upper != null && upper > 0) Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        var lastTick by remember { mutableStateOf(position) }
                        Slider(
                            value = position.toFloat(), valueRange = 0f..upper.toFloat(), steps = if (upper <= 60) maxOf(0, upper - 1) else 0,
                            onValueChange = {
                                val v = it.roundToInt(); position = v
                                val step = when (target.mode) { ProgressMode.CHAPTERS -> 1; ProgressMode.PCT -> 5; else -> maxOf(1, upper / 40) }
                                if (v / step != lastTick / step) { haptic.performHapticFeedback(HapticFeedbackType.SegmentFrequentTick); lastTick = v }
                            },
                            colors = SliderDefaults.colors(thumbColor = C.brassFill, activeTrackColor = C.brass, inactiveTrackColor = C.hairline,
                                activeTickColor = C.brassOnFill.copy(alpha = 0.3f), inactiveTickColor = C.hairlineBold),
                        )
                        Row {
                            Text("0", style = T.caption, color = C.inkMuted)
                            Spacer(Modifier.weight(1f))
                            if (isLive && startDisplay != null) Text("session began at ${target.positionLabel(startDisplay)}", style = T.caption, color = C.inkMuted)
                            Spacer(Modifier.weight(1f))
                            Text(if (target.mode == ProgressMode.PCT) "100%" else "$upper", style = T.caption, color = C.inkMuted)
                        }
                    }
                    ChipRow {
                        ChipButton("", Icons.Filled.Remove) { position = clamp(position - 1) }
                        val inc = when (target.mode) { ProgressMode.PAGES -> listOf(1, 10, 25, 50); ProgressMode.CHAPTERS -> listOf(1, 3, 5); else -> listOf(1, 5, 10) }
                        inc.forEach { s -> ChipButton("+$s") { position = clamp(position + s) } }
                    }
                    failure?.let {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Icon(Icons.Filled.Warning, null, tint = C.velvet, modifier = Modifier.size(16.dp)); Text(it, style = T.caption, color = C.velvet)
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        PrimaryButton(if (isLive) "Save session" else "Save", { save() }, busy = busy)
                        if (reachedEnd) ChipButton("Finished it", Icons.Filled.Verified, on = true, enabled = !busy) { finish() }
                        if (isLive) QuietButton("Discard session", { confirmDiscard = true })
                    }
                }
            }
        }
    }
    if (confirmDiscard) AlertDialog(
        onDismissRequest = { confirmDiscard = false }, containerColor = C.panelRaised,
        title = { Text("Discard this session?", style = T.headline, color = C.ink) },
        text = { Text("Nothing from it will be logged, and your progress stays where it was.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmDiscard = false; discard() }) { Text("Discard session", color = C.velvet) } },
        dismissButton = { TextButton({ confirmDiscard = false }) { Text("Keep it running", color = C.brass) } },
    )
}

private fun caption(t: ProgressTarget, pos: Int, upper: Int?) = when (t.mode) {
    ProgressMode.PCT -> t.canonicalTotal?.let { "p. ${t.stored(pos)} of $it" } ?: ""
    ProgressMode.CHAPTERS -> if (upper == null) t.unitName(pos) else if (t.kind == ReadingKind.BOOK) "of $upper chapters · p. ${t.stored(pos)}" else "of $upper chapters"
    else -> upper?.let { "of $it pages" } ?: "pages"
}

@Composable
private fun SessionStrip(live: ActiveSession, gained: Int, t: ProgressTarget) {
    val started = MQTime.dateTime(live.startedAt) ?: return
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) { while (true) { delay(1000); now = System.currentTimeMillis() } }
    val secs = maxOf(0, Duration.between(started, LocalDateTime.now()).seconds)
    val pace = (secs / 60.0).takeIf { it >= 3 && gained > 0 }?.let { m ->
        "~${(gained / m * 60).roundToInt()} ${when (t.mode) { ProgressMode.PCT -> "%/hr"; ProgressMode.CHAPTERS -> "ch/hr"; else -> "p/hr" }}"
    }
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(11.dp)).background(C.brassSoft).padding(12.dp), horizontalArrangement = Arrangement.spacedBy(18.dp)) {
        Stat("Reading for", formatTimer(secs + 0 * now))
        Stat("This session", if (t.mode == ProgressMode.PCT) "+$gained%" else "+$gained ${t.unitName(gained)}")
        pace?.let { Stat("Pace", it) }
    }
}

fun formatTimer(secs: Long): String {
    val h = secs / 3600; val m = (secs % 3600) / 60; val s = secs % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s) else "%d:%02d".format(m, s)
}

@Composable
private fun Stat(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Eyebrow(label)
        Text(value, style = T.headline.copy(fontFeatureSettings = "tnum"), color = C.ink)
    }
}
