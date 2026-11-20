package dev.kadenthompson.marquee.features.reading

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.DownloadForOffline
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.FindInPage
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HelpOutline
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.List
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ChipRow
import dev.kadenthompson.marquee.design.EmptyState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.SectionHeader
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.TwoPane
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.library.FilterField
import dev.kadenthompson.marquee.features.requests.ErrorLine
import dev.kadenthompson.marquee.features.requests.RequestDetailSection
import dev.kadenthompson.marquee.features.requests.RequestFactRow
import dev.kadenthompson.marquee.features.requests.RequestProgressTrack
import dev.kadenthompson.marquee.features.requests.RequestStatusPill
import dev.kadenthompson.marquee.features.requests.RequestTone
import dev.kadenthompson.marquee.features.requests.RequestWhen
import dev.kadenthompson.marquee.features.requests.RequesterRow
import dev.kadenthompson.marquee.features.requests.SheetTitle
import dev.kadenthompson.marquee.model.BookRequest
import dev.kadenthompson.marquee.model.BookRequestChoice
import dev.kadenthompson.marquee.model.BookRequestList
import dev.kadenthompson.marquee.model.BookRequestPhase
import dev.kadenthompson.marquee.model.CalibreCopy
import dev.kadenthompson.marquee.model.ShelfmarkBook
import dev.kadenthompson.marquee.model.ShelfmarkSearchResponse
import dev.kadenthompson.marquee.nav.BookRequestsRoute
import dev.kadenthompson.marquee.nav.BookRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.ApiError
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** How each Shelfmark phase reads on a title's page: label, icon, tone. */
fun BookRequestPhase.status(): Triple<String, ImageVector, RequestTone> = when (this) {
    BookRequestPhase.FINDING -> Triple("Finding a copy", Icons.Filled.Search, RequestTone.WORKING)
    BookRequestPhase.DOWNLOADING -> Triple("Downloading", Icons.Filled.DownloadForOffline, RequestTone.WORKING)
    BookRequestPhase.IMPORTING -> Triple("Adding to Calibre", Icons.Filled.LibraryBooks, RequestTone.WORKING)
    BookRequestPhase.DONE -> Triple("In Calibre", Icons.Filled.CheckCircle, RequestTone.READY)
    BookRequestPhase.PICK -> Triple("Choose a copy", Icons.Filled.TouchApp, RequestTone.ATTENTION)
    BookRequestPhase.FAILED -> Triple("No copy yet", Icons.Filled.ErrorOutline, RequestTone.FAILED)
    BookRequestPhase.CANCELLED -> Triple("Cancelled", Icons.Filled.Cancel, RequestTone.MUTED)
    BookRequestPhase.UNKNOWN -> Triple("Requested", Icons.Filled.Schedule, RequestTone.WAITING)
}

@Composable
fun PhasePill(p: BookRequestPhase, compact: Boolean = false, modifier: Modifier = Modifier) {
    val (l, i, t) = p.status(); RequestStatusPill(l, i, t, compact, modifier)
}

@Composable
private fun PhaseProgress(r: BookRequest, modifier: Modifier = Modifier) {
    if (r.phase.isActive) RequestProgressTrack(
        if (r.phase == BookRequestPhase.IMPORTING) 1f else r.fraction,
        if (r.phase == BookRequestPhase.DOWNLOADING) r.percent else null,
        note = if (r.phase == BookRequestPhase.FINDING) "Searching every indexer, about a minute" else r.message,
        indeterminate = r.phase == BookRequestPhase.FINDING, modifier = modifier,
    ) else r.message?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkSoft, modifier = modifier) }
}

/**
 * The Request control in a book's action area, like films have: "Request ebook", or the
 * request's status pill (polled every 4 s while it moves) opening the detail sheet.
 */
@Composable
fun BookRequestControl(bookId: Int, title: String, cover: String?) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    var request by remember { mutableStateOf<BookRequest?>(null) }
    var inCalibre by remember { mutableStateOf<CalibreCopy?>(null) }
    var loaded by remember { mutableStateOf(false) }
    var confirming by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }
    var notFound by remember { mutableStateOf(false) }
    var notice by remember { mutableStateOf<String?>(null) }
    var details by remember { mutableStateOf(false) }
    var anyway by remember { mutableStateOf(false) }
    val enabled = session.bookRequestConfig?.isEnabled == true

    suspend fun load() {
        if (!enabled) { loaded = true; return }
        runCatching { session.client?.get<BookRequestList>("book-requests", mapOf("book_id" to bookId.toString())) }.getOrNull()?.let {
            request = it.requests?.firstOrNull(); inCalibre = it.inCalibre
        }
        loaded = true
    }
    suspend fun create() {
        val c = session.client ?: return
        busy = true; failure = null; notFound = false
        try {
            val created: BookRequest = c.post("book-requests", body("book_id" to bookId))
            request = created
            if (created.already == true) notice = if (created.isMine) "You'd already asked for this one." else "${created.requestedBy ?: "Someone"} had already asked for this one."
        } catch (e: ApiError.Http) { failure = e.friendly; notFound = e.status == 404 } catch (e: Exception) { failure = e.friendly } finally { busy = false }
    }
    suspend fun act(verb: String) { val id = request?.id ?: return; runCatching { session.client?.post<BookRequest>("book-requests/$id/$verb") }.getOrNull()?.let { request = it } }

    LaunchedEffect(bookId) { session.loadBookRequestConfig(); load() }
    val active = request?.phase?.isActive == true
    LaunchedEffect(active) { while (active) { delay(4000); load(); if (request?.phase?.isActive != true) break } }

    if (!enabled || !loaded) return
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        val r = request
        if (r != null && r.phase != BookRequestPhase.CANCELLED && !(r.phase == BookRequestPhase.FAILED && inCalibre != null && !anyway)) {
            PhasePill(r.phase, modifier = Modifier.clip(CircleShape).clickable { details = true })
            PhaseProgress(r, Modifier.widthIn(max = 260.dp))
        } else if (inCalibre != null && !anyway) {
            RequestStatusPill("In Calibre", Icons.Filled.CheckCircle, RequestTone.READY, modifier = Modifier.clip(CircleShape).clickable { details = true })
        } else if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = C.brass, strokeWidth = 2.dp)
        else ChipButton("Request ebook", Icons.Filled.Download, on = true) { confirming = true }
        failure?.let { f ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(f, style = T.caption, color = C.inkSoft, modifier = Modifier.weight(1f, fill = false))
                if (notFound) Text("Search for it", style = T.body(12f, 700), color = C.brass, modifier = Modifier.clickable { nav.push(BookRequestsRoute(title)) })
            }
        }
        notice?.let { Text(it, style = T.caption, color = C.inkMuted) }
    }
    if (confirming) AlertDialog(onDismissRequest = { confirming = false }, containerColor = C.panelRaised,
        title = { Text("Request $title?", style = T.headline, color = C.ink) },
        text = { Text("Marquee finds an ebook copy and adds it to Calibre. Everyone in the house can see the request.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirming = false; scope.launch { create() } }) { Text("Request ebook", color = C.brass) } },
        dismissButton = { TextButton({ confirming = false }) { Text("Not now", color = C.inkSoft) } })
    if (details) BookRequestDetailSheet(title, cover, request?.takeIf { it.phase != BookRequestPhase.CANCELLED }, inCalibre,
        onDismiss = { details = false }, onUpdate = { request = it }, onDeleted = { request = null; load() },
        onRequestAnother = { anyway = true; if (request?.phase == BookRequestPhase.DONE) act("retry") else create() })
}

@Composable
fun BookRequestDetailSheet(
    title: String, cover: String?, request: BookRequest?, inCalibre: CalibreCopy?,
    onDismiss: () -> Unit, onUpdate: (BookRequest) -> Unit = {}, onDeleted: suspend () -> Unit = {}, onRequestAnother: suspend () -> Unit = {},
) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val sheet = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var current by remember { mutableStateOf(request) }
    var detail by remember { mutableStateOf<BookRequest?>(null) }
    var picking by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    var confirmCancel by remember { mutableStateOf(false) }
    var confirmAnother by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }
    val shown = current
    val phase = shown?.phase
    val canManage = shown?.isMine == true || session.me?.isAdmin == true
    val copy = detail?.copy ?: shown?.copy
    val choices = detail?.choices ?: emptyList()
    val isInCalibre = inCalibre != null || phase == BookRequestPhase.DONE
    LaunchedEffect(shown?.id) { shown?.id?.let { id -> detail = runCatching { session.client?.get<BookRequest>("book-requests/$id") }.getOrNull() } }
    fun close() = scope.launch { sheet.hide(); onDismiss() }
    fun act(verb: String) = scope.launch {
        val id = shown?.id ?: return@launch
        busy = true; failure = null
        try { val u: BookRequest = session.client!!.post("book-requests/$id/$verb"); current = u; onUpdate(u) } catch (e: Exception) { failure = e.friendly } finally { busy = false }
    }

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheet, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding()) {
            SheetTitle(if (shown == null) "In Calibre" else "Book request") { close() }
            Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(13.dp)) {
                    Poster(shown?.cover ?: cover, Modifier.width(64.dp), radius = 8.dp)
                    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Text(shown?.displayTitle ?: title, style = T.headline, color = C.ink)
                        listOfNotNull(shown?.author ?: inCalibre?.authors?.joinToString(", "), shown?.year?.toString()).filter { it.isNotEmpty() }.joinToString(", ").takeIf { it.isNotEmpty() }
                            ?.let { Text(it, style = T.sub, color = C.inkSoft) }
                        if (phase == null || (phase == BookRequestPhase.FAILED && inCalibre != null)) RequestStatusPill("In Calibre", Icons.Filled.CheckCircle, RequestTone.READY)
                        else PhasePill(phase)
                    }
                }
                shown?.let { if (it.phase.isActive || it.phase == BookRequestPhase.PICK || it.phase == BookRequestPhase.FAILED) PhaseProgress(it) }
                if (isInCalibre) RequestDetailSection("In Calibre") {
                    if (inCalibre != null) RequestFactRow(Icons.Filled.LibraryBooks, RequestTone.READY, inCalibre.title ?: shown?.displayTitle ?: title,
                        listOf(inCalibre.authors?.joinToString(", ") ?: "", inCalibre.summary).filter { it.isNotEmpty() }.joinToString(" · "))
                    else RequestFactRow(Icons.Filled.LibraryBooks, RequestTone.READY, "Filed into the library",
                        listOf(copy?.format?.uppercase() ?: "", RequestWhen.relative(shown?.finishedAt ?: shown?.updatedAt)).filter { it.isNotEmpty() }.joinToString(" · "))
                }
                if (shown != null) {
                    val others = choices.count { it.title != copy?.title }
                    RequestDetailSection("The copy") {
                        if (copy != null) RequestFactRow(Icons.Filled.Description, if (shown.phase == BookRequestPhase.DONE) RequestTone.READY else if (shown.phase.isActive) RequestTone.WORKING else RequestTone.MUTED,
                            copy.title ?: "Untitled copy", copy.summary, dense = true)
                        else RequestFactRow(Icons.Filled.FindInPage, RequestTone.MUTED, if (shown.phase == BookRequestPhase.FINDING) "Still looking" else "No copy chosen yet",
                            if (shown.phase == BookRequestPhase.FINDING) "The indexers are being searched." else if (choices.isEmpty()) null else "${choices.size} cop${if (choices.size == 1) "y" else "ies"} found to choose from")
                        if (copy != null && others > 0) {
                            HorizontalDivider(Modifier.padding(start = 50.dp), color = C.hairline)
                            RequestFactRow(Icons.Filled.Inventory2, RequestTone.MUTED, "$others other cop${if (others == 1) "y" else "ies"} found", if ((shown.attempts ?: 0) > 1) "${shown.attempts} tried so far" else null)
                        }
                    }
                    RequestDetailSection("Request") {
                        RequesterRow(shown.requestedBy, shown.isMine, shown.createdAt, emptyList(), null, canManage, busy) { confirmDelete = true }
                    }
                }
                failure?.let { ErrorLine(it) }
                val showChoose = canManage && phase != null && (phase == BookRequestPhase.PICK || ((phase == BookRequestPhase.DOWNLOADING || phase == BookRequestPhase.FAILED) && choices.isNotEmpty()))
                val showRetry = canManage && phase == BookRequestPhase.FAILED && inCalibre == null
                val showCancel = canManage && phase?.isActive == true
                val showAnother = isInCalibre && phase?.isActive != true
                ChipRow {
                    if (showChoose) ChipButton(if (phase == BookRequestPhase.PICK) "Choose a copy" else "Choose another copy", Icons.Filled.List, on = true, enabled = !busy) { picking = true }
                    if (showRetry) ChipButton("Try again", Icons.Filled.Refresh, enabled = !busy) { act("retry") }
                    if (showAnother) ChipButton("Request another copy", Icons.Filled.Download, enabled = !busy) { confirmAnother = true }
                    if (showCancel) ChipButton("Cancel", Icons.Filled.Close, destructive = true, enabled = !busy) { confirmCancel = true }
                }
            }
        }
    }
    if (picking && shown != null) CopyPickerSheet(shown, onDismiss = { picking = false }) { current = it; onUpdate(it) }
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, containerColor = C.panelRaised,
        title = { Text(if (shown?.isMine == true) "Delete your request?" else "Delete ${shown?.requestedBy ?: "their"}’s request?", style = T.headline, color = C.ink) },
        text = { Text("The request comes off the list for everyone${if (phase?.isActive == true) " and its download stops" else ""}. ${if (isInCalibre) "The copy in Calibre stays." else "Nothing in Calibre changes."}", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({
            confirmDelete = false
            scope.launch {
                val id = shown?.id ?: return@launch
                busy = true
                try { session.client?.send("book-requests/$id/delete"); onDeleted(); close() } catch (e: Exception) { failure = e.friendly } finally { busy = false }
            }
        }) { Text("Delete request", color = C.velvet) } },
        dismissButton = { TextButton({ confirmDelete = false }) { Text("Keep it", color = C.brass) } })
    if (confirmCancel) AlertDialog(onDismissRequest = { confirmCancel = false }, containerColor = C.panelRaised,
        title = { Text("Cancel the request for ${shown?.displayTitle ?: title}?", style = T.headline, color = C.ink) },
        text = { Text(if (phase == BookRequestPhase.DOWNLOADING) "The download stops and nothing goes into Calibre." else "Nothing goes into Calibre.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmCancel = false; act("cancel") }) { Text("Cancel request", color = C.velvet) } },
        dismissButton = { TextButton({ confirmCancel = false }) { Text("Keep it", color = C.brass) } })
    if (confirmAnother) AlertDialog(onDismissRequest = { confirmAnother = false }, containerColor = C.panelRaised,
        title = { Text("Request another copy?", style = T.headline, color = C.ink) },
        text = { Text("Marquee finds a fresh ebook copy and adds it to Calibre. The copy that’s there now stays.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmAnother = false; scope.launch { onRequestAnother(); close() } }) { Text("Request another copy", color = C.brass) } },
        dismissButton = { TextButton({ confirmAnother = false }) { Text("Not now", color = C.inkSoft) } })
}

/** When no copy matched well enough: what the indexers found, good matches first, tried ones marked. */
@Composable
fun CopyPickerSheet(request: BookRequest, onDismiss: () -> Unit, onPicked: (BookRequest) -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var detail by remember { mutableStateOf<BookRequest?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var confirming by remember { mutableStateOf<BookRequestChoice?>(null) }
    var busy by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { runCatching { session.client!!.get<BookRequest>("book-requests/${request.id}") }.onSuccess { detail = it }.onFailure { error = it.friendly } }
    val all = detail?.choices ?: emptyList()
    val choices = all.filter { it.isRecommended } + all.filter { !it.isRecommended }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding()) {
            SheetTitle("Choose a copy", onClose = onDismiss)
            Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                (detail ?: request).message?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.sub, color = C.inkSoft) }
                when {
                    detail == null && error == null -> CircularProgressIndicator(color = C.brass)
                    error != null -> ErrorLine(error!!)
                    choices.isEmpty() -> Text("No copies to choose from. Search again from the request.", style = T.sub, color = C.inkMuted)
                    else -> Column(Modifier.fillMaxWidth().mqPanel(16.dp)) {
                        choices.forEachIndexed { i, ch ->
                            Column(Modifier.fillMaxWidth().alpha(if (ch.wasTried) 0.6f else 1f).clickable(enabled = !busy) { confirming = ch }.padding(14.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                if (ch.isRecommended || ch.wasTried) Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    if (ch.isRecommended) RequestStatusPill("Good match", Icons.Filled.Star, RequestTone.WORKING, true)
                                    if (ch.wasTried) RequestStatusPill("Tried, didn’t work", Icons.AutoMirrored.Filled.Undo, RequestTone.MUTED, true)
                                }
                                Text(ch.title ?: "Untitled copy", style = T.body(14f, 600), color = C.ink)
                                Text(listOf(ch.summary, ch.indexer ?: "").filter { it.isNotEmpty() }.joinToString(" · "), style = T.caption, color = C.inkMuted)
                            }
                            if (i < choices.lastIndex) HorizontalDivider(color = C.hairline)
                        }
                    }
                }
            }
        }
    }
    confirming?.let { ch ->
        AlertDialog(onDismissRequest = { confirming = null }, containerColor = C.panelRaised,
            title = { Text("Download this copy?", style = T.headline, color = C.ink) }, text = { Text(ch.title ?: "", style = T.body, color = C.inkSoft) },
            confirmButton = { TextButton({
                confirming = null
                scope.launch {
                    busy = true
                    try { val u: BookRequest = session.client!!.post("book-requests/${request.id}/pick", body("source_id" to ch.sourceId)); onPicked(u); onDismiss() }
                    catch (e: Exception) { error = e.friendly } finally { busy = false }
                }
            }) { Text("Download it", color = C.brass) } },
            dismissButton = { TextButton({ confirming = null }) { Text("Cancel", color = C.inkSoft) } })
    }
}

/** One request in the household list: cover, who asked, where it stands, Cancel on your own. */
@Composable
fun BookRequestCard(r: BookRequest, onUpdate: (BookRequest) -> Unit, onDeleted: () -> Unit) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    var choosing by remember { mutableStateOf(false) }
    var details by remember { mutableStateOf(false) }
    var confirmCancel by remember { mutableStateOf(false) }
    var failure by remember { mutableStateOf<String?>(null) }
    val phase = r.phase
    val canManage = r.isMine || session.me?.isAdmin == true
    fun act(verb: String) = scope.launch {
        try { onUpdate(session.client!!.post<BookRequest>("book-requests/${r.id}/$verb")) } catch (e: Exception) { failure = e.friendly }
    }
    Column(Modifier.fillMaxWidth().mqPanel(16.dp).alpha(if (phase == BookRequestPhase.CANCELLED) 0.72f else 1f).clickable { details = true }.padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(13.dp)) {
            Poster(r.cover, Modifier.width(56.dp), radius = 8.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(r.displayTitle, style = T.body(15f, 700), color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                listOfNotNull(r.author, r.year?.toString()).filter { it.isNotEmpty() }.joinToString(", ").takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkSoft) }
                PhasePill(phase, compact = true)
                val w = MQTime.relative(r.createdAt)
                Text((if (r.isMine) "You asked" else "${r.requestedBy ?: "Someone"} asked") + if (w.isEmpty()) "" else " $w", style = T.caption, color = C.inkMuted)
            }
        }
        when (phase) {
            BookRequestPhase.FINDING -> RequestProgressTrack(note = "Looking for copies… this takes a minute or two", indeterminate = true)
            BookRequestPhase.DOWNLOADING -> Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                RequestProgressTrack(r.fraction, r.percent, note = r.message)
                r.copy?.summary?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkMuted) }
            }
            BookRequestPhase.IMPORTING -> RequestProgressTrack(maxOf(r.fraction, 0.99f), note = "Adding to Calibre")
            BookRequestPhase.PICK, BookRequestPhase.FAILED -> r.message?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkSoft) }
            else -> Unit
        }
        failure?.let { ErrorLine(it) }
        val showChoose = phase == BookRequestPhase.PICK && canManage
        val showCancel = phase.isCancellable && r.isMine
        val showOpen = r.bookId != null
        if (showChoose || showCancel || showOpen) ChipRow {
            if (showChoose) ChipButton("Choose a copy", Icons.Filled.List, on = true) { choosing = true }
            if (showOpen) ChipButton("Open book", Icons.AutoMirrored.Filled.MenuBook) { nav.push(BookRoute(r.bookId!!)) }
            if (showCancel) ChipButton("Cancel", Icons.Filled.Close, destructive = true) { confirmCancel = true }
        }
    }
    if (choosing) CopyPickerSheet(r, onDismiss = { choosing = false }, onPicked = onUpdate)
    if (details) BookRequestDetailSheet(r.displayTitle, r.cover, r, null, onDismiss = { details = false }, onUpdate = onUpdate, onDeleted = onDeleted)
    if (confirmCancel) AlertDialog(onDismissRequest = { confirmCancel = false }, containerColor = C.panelRaised,
        title = { Text("Cancel the request for ${r.displayTitle}?", style = T.headline, color = C.ink) },
        text = { Text(if (phase == BookRequestPhase.DOWNLOADING) "The download stops and nothing goes into Calibre." else "Nothing goes into Calibre.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmCancel = false; act("cancel") }) { Text("Cancel request", color = C.velvet) } },
        dismissButton = { TextButton({ confirmCancel = false }) { Text("Keep it", color = C.brass) } })
}

/** You › Book requests: search the downloader, request a result, and every request in the house. */
@Composable
fun BookRequestsScreen(initialQuery: String?) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    var query by rememberSaveable { mutableStateOf(initialQuery ?: "") }
    var results by remember { mutableStateOf<List<ShelfmarkBook>?>(null) }
    var unavailable by remember { mutableStateOf(false) }
    var requests by remember { mutableStateOf<List<BookRequest>?>(null) }
    var enabled by remember { mutableStateOf<Boolean?>(null) }
    var confirm by remember { mutableStateOf<ShelfmarkBook?>(null) }
    var failure by remember { mutableStateOf<String?>(null) }

    suspend fun loadRequests() {
        runCatching { session.client?.get<BookRequestList>("book-requests") }.getOrNull()?.let { requests = it.requests ?: emptyList(); enabled = it.enabled != false }
    }
    LaunchedEffect(Unit) { session.loadBookRequestConfig(force = true); if (session.bookRequestConfig?.isEnabled != true) enabled = false else loadRequests() }
    val anyActive = requests?.any { it.phase.isActive } == true
    LaunchedEffect(anyActive) { while (anyActive) { delay(4000); loadRequests() } }
    LaunchedEffect(query) {
        val q = query.trim()
        if (q.length < 2) { results = null; return@LaunchedEffect }
        delay(500)
        val r = runCatching { session.client?.get<ShelfmarkSearchResponse>("book-requests/search", mapOf("q" to q)) }.getOrNull()
        results = r?.results ?: emptyList(); unavailable = r?.unavailable == true
    }
    fun replace(u: BookRequest) { requests = requests?.map { if (it.id == u.id) u else it } }

    val searchItems: androidx.compose.foundation.lazy.LazyListScope.() -> Unit = {
            item { FilterField(query, { query = it }, "Title or author", icon = Icons.Filled.Search) }
            item { failure?.let { ErrorLine(it) } }
            val res = results
            when {
                query.trim().length < 2 -> item { Text("Search by title or author. A request finds an ebook and files it into Calibre, usually within a few minutes.", style = T.caption, color = C.inkMuted) }
                res == null -> items(3) { Skeleton(height = 80.dp) }
                unavailable -> item { Text("The book downloader didn’t answer. Try again in a bit.", style = T.caption, color = C.inkMuted) }
                res.isEmpty() -> item { Text("Nothing found for “${query.trim()}”. Try the author’s surname, or fewer words.", style = T.caption, color = C.inkMuted) }
                else -> items(res, key = { it.key }) { b ->
                    Row(Modifier.fillMaxWidth().mqPanel().padding(11.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(11.dp)) {
                        Poster(b.cover, Modifier.width(44.dp), radius = 6.dp)
                        Column(Modifier.weight(1f)) {
                            Text(b.displayTitle, style = T.body(14f, 700), color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(listOfNotNull(b.authorLine.takeIf { it.isNotEmpty() }, b.year?.toString()).joinToString(" · "), style = T.caption, color = C.inkMuted, maxLines = 1)
                        }
                        when {
                            b.request != null -> PhasePill(b.request.phase, true)
                            b.inCalibre != null -> RequestStatusPill("In Calibre", Icons.Filled.CheckCircle, RequestTone.READY, true)
                            else -> ChipButton("Request", on = true) { confirm = b }
                        }
                    }
                }
            }
    }
    val listItems: androidx.compose.foundation.lazy.LazyListScope.() -> Unit = {
            item { SectionHeader("Requests in the house", count = requests?.size?.toString()) }
            val rs = requests
            if (rs == null) items(3) { Skeleton(height = 110.dp) }
            else if (rs.isEmpty()) item { Text("Nobody has asked for a book yet. Search to request one.", style = T.sub, color = C.inkMuted) }
            else items(rs, key = { it.id }) { r -> BookRequestCard(r, ::replace) { requests = requests?.filterNot { it.id == r.id } } }
    }
    val pad = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = 8.dp, bottom = 32.dp)

    ScreenScaffold("Book requests", { nav.popBackStack() }) { sp ->
        Box(Modifier.padding(top = sp.calculateTopPadding())) {
            if (enabled == false) EmptyState(Icons.Filled.LibraryBooks, "Book requests aren’t set up", "Book requests aren’t set up on this server. An admin can add the book downloader in the web app’s settings.")
            else TwoPane(
                leading = { LazyColumn(contentPadding = pad, verticalArrangement = Arrangement.spacedBy(10.dp), content = searchItems) },
                trailing = { LazyColumn(contentPadding = pad, verticalArrangement = Arrangement.spacedBy(12.dp), content = listItems) },
                single = { LazyColumn(contentPadding = pad, verticalArrangement = Arrangement.spacedBy(12.dp)) { searchItems(); item { Spacer(Modifier.height(10.dp)) }; listItems() } },
            )
        }
    }
    confirm?.let { b ->
        AlertDialog(onDismissRequest = { confirm = null }, containerColor = C.panelRaised,
            title = { Text("Request ${b.displayTitle}?", style = T.headline, color = C.ink) },
            text = { Text("${if (b.authorLine.isEmpty()) "" else "By ${b.authorLine}. "}Marquee finds an ebook copy and adds it to Calibre. Everyone in the house can see the request.", style = T.body, color = C.inkSoft) },
            confirmButton = { TextButton({
                confirm = null
                scope.launch {
                    failure = null
                    try {
                        val created: BookRequest = session.client!!.post("book-requests", body("provider" to b.provider, "provider_id" to b.providerId, "title" to b.title,
                            "authors" to b.authors, "year" to b.year, "cover" to b.cover))
                        requests = listOf(created) + (requests ?: emptyList()).filterNot { it.id == created.id }
                        query = ""
                    } catch (e: Exception) { failure = e.friendly }
                }
            }) { Text("Request ebook", color = C.brass) } },
            dismissButton = { TextButton({ confirm = null }) { Text("Not now", color = C.inkSoft) } })
    }
}
