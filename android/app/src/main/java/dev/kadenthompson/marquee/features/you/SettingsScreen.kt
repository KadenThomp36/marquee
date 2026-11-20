package dev.kadenthompson.marquee.features.you

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.LiveTv
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.BuildConfig
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ChipRow
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.FilterPill
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.grouped
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.library.FilterField
import dev.kadenthompson.marquee.features.reading.statDuration
import dev.kadenthompson.marquee.features.requests.SheetTitle
import dev.kadenthompson.marquee.model.BookSearchResponse
import dev.kadenthompson.marquee.model.BookSearchResult
import dev.kadenthompson.marquee.model.DeviceSessions
import dev.kadenthompson.marquee.model.FeaturesResponse
import dev.kadenthompson.marquee.model.FolioIntegration
import dev.kadenthompson.marquee.model.FolioWaiting
import dev.kadenthompson.marquee.model.IMDbStatus
import dev.kadenthompson.marquee.model.NotificationPref
import dev.kadenthompson.marquee.model.NotificationPrefsResponse
import dev.kadenthompson.marquee.model.OverseerrAccount
import dev.kadenthompson.marquee.model.PairCode
import dev.kadenthompson.marquee.model.PlexPin
import dev.kadenthompson.marquee.model.PlexPinPoll
import dev.kadenthompson.marquee.model.PlexStatus
import dev.kadenthompson.marquee.model.ReadingShelves
import dev.kadenthompson.marquee.nav.FolioRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

@Composable
fun SettingsGroup(title: String, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Eyebrow(title)
        Column(Modifier.fillMaxWidth().mqPanel(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp), content = content)
        footer?.let { Text(it, style = T.caption, color = C.inkMuted) }
    }
}

@Composable
fun ToggleRow(title: String, detail: String? = null, on: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().clickable { onChange(!on) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f)) { Text(title, style = T.body(15f, 600), color = C.ink); detail?.let { Text(it, style = T.caption, color = C.inkMuted) } }
        Switch(on, onChange, colors = SwitchDefaults.colors(checkedTrackColor = C.brassFill, checkedThumbColor = C.brassOnFill, uncheckedTrackColor = C.panelRaised, uncheckedBorderColor = C.hairlineBold, uncheckedThumbColor = C.inkMuted))
    }
}

@Composable
fun ValueRow(title: String, value: String?, detail: String? = null) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) { Text(title, style = T.body(15f, 600), color = C.ink); detail?.let { Text(it, style = T.caption, color = C.inkMuted) } }
        value?.let { Text(it, style = T.sub, color = C.inkSoft) }
    }
}

/** Settings: this device, Plex, requests, IMDb, notifications, tracking extras, Folio, appearance. */
@Composable
fun SettingsScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val uri = LocalUriHandler.current
    var plex by remember { mutableStateOf<PlexStatus?>(null) }
    var overseerr by remember { mutableStateOf<OverseerrAccount?>(null) }
    var imdb by remember { mutableStateOf<IMDbStatus?>(null) }
    var prefs by remember { mutableStateOf<List<NotificationPref>?>(null) }
    var devices by remember { mutableStateOf<DeviceSessions?>(null) }
    var pin by remember { mutableStateOf<PlexPin?>(null) }
    var confirmUnpair by remember { mutableStateOf(false) }
    var confirmOthers by remember { mutableStateOf(false) }
    var pairCode by remember { mutableStateOf<PairCode?>(null) }

    suspend fun load() {
        val c = session.client ?: return
        plex = runCatching { c.get<PlexStatus>("plex/status") }.getOrNull()
        overseerr = runCatching { c.get<OverseerrAccount>("overseerr/me") }.getOrNull()
        imdb = runCatching { c.get<IMDbStatus>("imdb/status") }.getOrNull()
        prefs = runCatching { c.get<NotificationPrefsResponse>("notifications/prefs").prefs }.getOrNull() ?: emptyList()
        devices = runCatching { c.get<DeviceSessions>("sessions") }.getOrNull()
    }
    LaunchedEffect(Unit) { load() }
    LaunchedEffect(pin) {
        val p = pin ?: return@LaunchedEffect
        repeat(60) {
            delay(3000)
            val poll = runCatching { session.client?.get<PlexPinPoll>("plex/pin/${p.id}") }.getOrNull()
            if (poll?.linked == true) { pin = null; plex = runCatching { session.client?.get<PlexStatus>("plex/status") }.getOrNull(); return@LaunchedEffect }
        }
        pin = null
    }
    fun setPref(p: NotificationPref, enabled: Boolean, value: String?) {
        prefs = prefs?.map { if (it.type == p.type) it.copy(enabled = enabled, value = value) else it }
        scope.launch { runCatching { session.client?.send("notifications/prefs", body("type" to p.type, "enabled" to enabled, "value" to value)) } }
    }

    ScreenScaffold("Settings", { nav.popBackStack() }) { pad ->
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
            item {
                SettingsGroup("This device", "Marquee forgets your server address and signs this device out.") {
                    ValueRow("Server", session.server?.baseUrl?.toHttpUrlOrNull()?.host)
                    ValueRow("Signed in as", session.me?.name, session.server?.deviceName?.let { "This device is “$it”" })
                    ChipButton("Unpair", Icons.AutoMirrored.Filled.Logout, destructive = true) { confirmUnpair = true }
                }
            }
            item {
                SettingsGroup("Devices", devices?.hidden?.takeIf { it > 0 }?.let { "$it older session${if (it == 1) "" else "s"} not shown. Signing out every other device clears them." }) {
                    val d = devices
                    if (d == null) Text("Loading…", style = T.caption, color = C.inkMuted)
                    else d.sessions.forEachIndexed { i, s ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Icon(Icons.Filled.Devices, null, tint = if (s.current) C.brass else C.inkMuted, modifier = Modifier.size(18.dp))
                            Column(Modifier.weight(1f)) {
                                Text(s.deviceName + if (s.current) " · this device" else "", style = T.body(14f, 600), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text("Last seen ${MQTime.relative(s.lastSeen ?: s.createdAt)}", style = T.caption, color = C.inkMuted)
                            }
                            if (!s.current) Text("Sign out", style = T.body(12f, 700), color = C.velvet, modifier = Modifier.clickable {
                                devices = d.copy(sessions = d.sessions.filterNot { it.id == s.id })
                                scope.launch { runCatching { session.client?.sendDelete("sessions/${s.id}") } }
                            })
                        }
                        if (i < d.sessions.lastIndex) HorizontalDivider(color = C.hairline)
                    }
                    ChipRow {
                        ChipButton("Pair a new device", on = true) { scope.launch { pairCode = runCatching { session.client?.post<PairCode>("pair/start") }.getOrNull() } }
                        if ((devices?.sessions?.size ?: 0) > 1) ChipButton("Sign out every other device", destructive = true) { confirmOthers = true }
                    }
                }
            }
            item { DeviceNotificationsGroup() }
            item { HomeScreenGroup() }
            item {
                SettingsGroup("Plex", "Linking lets the server mark what you watch on Plex automatically.") {
                    val p = plex
                    if (p?.isLinked == true) {
                        ValueRow("Linked to ${p.plexUsername}", null, p.lastEvent?.let { "Last sync ${MQTime.medium(it)}" })
                        ChipRow { ChipButton("Re-link") { scope.launch { pin = runCatching { session.client?.post<PlexPin>("plex/pin") }.getOrNull(); pin?.let { runCatching { uri.openUri(it.url) } } } }
                            ChipButton("Unlink", destructive = true) { scope.launch { runCatching { session.client?.send("plex/unlink") }; plex = p.copy(plexUsername = null) } } }
                    } else if (pin != null) {
                        Text("Waiting for you to approve it in Plex… code ${pin!!.code}", style = T.sub, color = C.inkSoft)
                        ChipButton("Open Plex again") { runCatching { uri.openUri(pin!!.url) } }
                    } else ChipButton("Link Plex", Icons.Filled.LiveTv, on = true) {
                        scope.launch { pin = runCatching { session.client?.post<PlexPin>("plex/pin") }.getOrNull(); pin?.let { runCatching { uri.openUri(it.url) } } }
                    }
                }
            }
            overseerr?.takeIf { it.enabled }?.let { o ->
                item { SettingsGroup("Requests") { ValueRow("Overseerr", if (o.linked == true) "Linked" else "Not linked", o.account ?: o.reason) } }
            }
            imdb?.let { i ->
                item {
                    SettingsGroup("IMDb ratings") {
                        ValueRow("${(i.episodesRated ?: 0).grouped} rated", if (i.running) "Syncing…" else null, "of ${(i.episodes ?: 0).grouped} episodes")
                        ValueRow("Last sync", i.last?.let { MQTime.relative(it) } ?: "never")
                        if (session.me?.isAdmin == true) ChipButton("Sync now", enabled = !i.running) { scope.launch { runCatching { session.client?.send("imdb/sync") }; imdb = i.copy(running = true) } }
                    }
                }
            }
            prefs?.takeIf { it.isNotEmpty() }?.let { ps ->
                item {
                    SettingsGroup("What you hear about", "Applies to the inbox and to notifications on every device.") {
                        ps.forEachIndexed { i, p ->
                            ToggleRow(p.label, p.help, p.enabled == true) { setPref(p, it, p.value) }
                            if (p.hasDays == true && p.enabled == true) FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                listOf("0" to "Same day", "1" to "1 day", "3" to "3 days", "7" to "A week").forEach { (k, l) ->
                                    val sel = k in p.leadDays
                                    FilterPill(l, sel) { val next = if (sel) p.leadDays - k else p.leadDays + k; setPref(p, true, next.sortedBy { it.toInt() }.joinToString(",")) }
                                }
                            }
                            if (i < ps.lastIndex) HorizontalDivider(color = C.hairline)
                        }
                    }
                }
            }
            item {
                val f = session.me?.features
                SettingsGroup("Tracking extras", "Reading is opt-in per person. Switching it on adds Reading to Library and Home.") {
                    ToggleRow("Books", "Hardcover-backed shelves, sessions and stats", f?.tracksBooks == true) { v ->
                        scope.launch { runCatching { session.client?.post<FeaturesResponse>("profile/features", body("books" to if (v) 1 else 0)) }.getOrNull()?.let { r -> session.updateMe { it.copy(features = r.features) } } }
                    }
                    ToggleRow("Manga", "Manga, manhwa and manhua from AniList", f?.tracksManga == true) { v ->
                        scope.launch { runCatching { session.client?.post<FeaturesResponse>("profile/features", body("manga" to if (v) 1 else 0)) }.getOrNull()?.let { r -> session.updateMe { it.copy(features = r.features) } } }
                    }
                    if (f?.tracksBooks == true) Row(Modifier.fillMaxWidth().clickable { nav.push(FolioRoute) }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(Icons.Filled.AutoStories, null, tint = C.chartAqua)
                        Column(Modifier.weight(1f)) { Text("Folio", style = T.body(15f, 600), color = C.ink); Text("Sittings from your e-reader", style = T.caption, color = C.inkMuted) }
                        Icon(Icons.Filled.ChevronRight, null, tint = C.inkMuted)
                    }
                }
            }
            item {
                SettingsGroup("Appearance") {
                    val opts = listOf("dark", "system", "light")
                    Segmented(listOf("Dark", "System", "Light"), opts.indexOf(session.prefs.appearance).coerceAtLeast(0)) { session.prefs.chooseAppearance(opts[it]) }
                }
            }
            item {
                Text("Marquee ${BuildConfig.VERSION_NAME} talks to your server and to the image CDNs your server points at — nothing else. No analytics, no crash reporting.", style = T.caption, color = C.inkMuted)
            }
        }
    }
    if (confirmUnpair) AlertDialog(onDismissRequest = { confirmUnpair = false }, containerColor = C.panelRaised,
        title = { Text("Unpair this device?", style = T.headline, color = C.ink) }, text = { Text("Marquee forgets your server address and signs this device out.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmUnpair = false; scope.launch { session.unpair() } }) { Text("Unpair", color = C.velvet) } },
        dismissButton = { TextButton({ confirmUnpair = false }) { Text("Cancel", color = C.brass) } })
    if (confirmOthers) AlertDialog(onDismissRequest = { confirmOthers = false }, containerColor = C.panelRaised,
        title = { Text("Sign out every other device?", style = T.headline, color = C.ink) },
        confirmButton = { TextButton({ confirmOthers = false; scope.launch { runCatching { session.client?.sendDelete("sessions/others") }; load() } }) { Text("Sign them out", color = C.velvet) } },
        dismissButton = { TextButton({ confirmOthers = false }) { Text("Cancel", color = C.brass) } })
    pairCode?.let { PairCodeSheet(it, "Pair a new device", "In Marquee on the new device, choose “Use a pairing code” and type this. It lasts five minutes and works once.") { pairCode = null } }
}

@Composable
fun PairCodeSheet(code: PairCode, title: String, help: String, onDismiss: () -> Unit) {
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter).padding(bottom = 28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(title, style = T.headline, color = C.ink)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                code.code.forEach { ch -> Box(Modifier.width(44.dp).clip(RoundedCornerShape(11.dp)).background(C.panel).border(1.dp, C.brassDim, RoundedCornerShape(11.dp)).padding(vertical = 12.dp), contentAlignment = Alignment.Center) { Text("$ch", style = T.wordmark(28f), color = C.brass) } }
            }
            Text(help, style = T.sub, color = C.inkSoft, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
    }
}

// ================= Folio

/** Settings › Folio: switch it on, auto capture, paired readers, Pair a reader, and books waiting for a match. */
@Composable
fun FolioScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    var state by remember { mutableStateOf<FolioIntegration?>(null) }
    var error by remember { mutableStateOf<String?>(null) }
    var code by remember { mutableStateOf<PairCode?>(null) }
    var matching by remember { mutableStateOf<FolioWaiting?>(null) }
    suspend fun load() { runCatching { session.client!!.get<FolioIntegration>("integrations/folio") }.onSuccess { state = it }.onFailure { error = it.friendly } }
    fun change(b: JsonObject) = scope.launch { runCatching { session.client!!.post<FolioIntegration>("integrations/folio", b) }.onSuccess { state = it } }
    fun waitingAction(path: String, b: JsonObject) = scope.launch { runCatching { session.client!!.post<FolioIntegration>("integrations/folio/waiting/$path", b) }.onSuccess { state = it } }
    LaunchedEffect(Unit) { load() }
    LaunchedEffect(code) {
        // The reader appears the moment Folio registers.
        val before = state?.devices?.size ?: 0
        while (code != null) { delay(3000); load(); if ((state?.devices?.size ?: 0) > before) code = null }
    }
    ScreenScaffold("Folio", { nav.popBackStack() }) { pad ->
        val s = state
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
            if (s == null) item { Text(error ?: "Loading…", style = T.sub, color = C.inkMuted) }
            else {
                item {
                    SettingsGroup(s.title ?: "Folio", "Folio is the household's e-reader app. Its sittings land on the matching book's page and stats.") {
                        ToggleRow("Sync reading from Folio", null, s.enabled) { change(body("enabled" to it)) }
                        if (s.enabled) ToggleRow("Record sittings automatically", "Controls recording on the reader", s.autoCapture) { change(body("auto_capture" to it)) }
                        s.imported?.takeIf { it > 0 }?.let { Text("${it.grouped} sittings synced", style = T.caption, color = C.inkMuted) }
                    }
                }
                if (s.enabled) item {
                    SettingsGroup("Readers") {
                        if (s.devices.isEmpty()) Text("No reader paired yet.", style = T.sub, color = C.inkMuted)
                        s.devices.forEachIndexed { i, d ->
                            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Icon(Icons.Filled.AutoStories, null, tint = C.chartAqua, modifier = Modifier.size(18.dp))
                                Column(Modifier.weight(1f)) {
                                    Text(d.displayName, style = T.body(14.5f, 600), color = C.ink)
                                    Text(listOfNotNull(d.lastSyncAt?.let { "synced ${MQTime.relative(it)}" } ?: "never synced", "${d.sessionsSynced} sittings", d.appVersion?.let { "v$it" }).joinToString(" · "), style = T.caption, color = C.inkMuted)
                                }
                                Text("Unpair", style = T.body(12f, 700), color = C.velvet, modifier = Modifier.clickable { scope.launch { runCatching { session.client?.sendDelete("integrations/folio/devices/${d.id}") }; load() } })
                            }
                            if (i < s.devices.lastIndex) HorizontalDivider(color = C.hairline)
                        }
                        ChipButton("Pair a reader", on = true) { scope.launch { code = runCatching { session.client?.post<PairCode>("pair/start") }.getOrNull() } }
                    }
                }
                s.waiting?.takeIf { it.isNotEmpty() }?.let { w ->
                    item {
                        SettingsGroup("Waiting for a book", "Sittings Folio sent for a file Marquee can't place yet. Match puts them on the right book; Ignore drops personal documents.") {
                            w.forEachIndexed { i, x ->
                                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(x.title, style = T.body(14.5f, 700), color = C.ink)
                                    Text(x.byline, style = T.caption, color = C.inkSoft)
                                    Text(listOfNotNull("${x.sittings} sitting${if (x.sittings == 1) "" else "s"}", statDuration(x.minutes), x.reason, x.nextAttemptAt?.let { "looks again ${MQTime.relative(it)}" }).joinToString(" · "), style = T.caption, color = C.inkMuted)
                                    ChipRow {
                                        ChipButton("Match", on = true) { matching = x }
                                        ChipButton("Look now") { waitingAction("retry", body("key" to x.key)) }
                                        ChipButton("Ignore", destructive = true) { waitingAction("ignore", body("key" to x.key)) }
                                    }
                                }
                                if (i < w.lastIndex) HorizontalDivider(color = C.hairline)
                            }
                        }
                    }
                }
            }
        }
    }
    code?.let { PairCodeSheet(it, "Pair a reader", "In Folio's setup, enter this code. The reader appears here the moment it registers.") { code = null } }
    matching?.let { w -> FolioMatchSheet(w, onDismiss = { matching = null }) { b -> matching = null; waitingAction("match", b) } }
}

/** Your own shelf first (works while Hardcover is down), then Hardcover's search. */
@Composable
private fun FolioMatchSheet(w: FolioWaiting, onDismiss: () -> Unit, onPick: (JsonObject) -> Unit) {
    val session = LocalSession.current
    var q by remember { mutableStateOf(w.title) }
    var shelf by remember { mutableStateOf<List<dev.kadenthompson.marquee.model.ReadingItem>>(emptyList()) }
    var results by remember { mutableStateOf<List<BookSearchResult>>(emptyList()) }
    LaunchedEffect(Unit) { shelf = runCatching { session.client?.get<ReadingShelves>("reading")?.books?.all }.getOrNull() ?: emptyList() }
    LaunchedEffect(q) { delay(450); if (q.trim().length >= 3) results = runCatching { session.client?.get<BookSearchResponse>("books/search", mapOf("q" to q.trim()))?.results }.getOrNull() ?: emptyList() }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding()) {
            SheetTitle("Match “${w.title}”", onClose = onDismiss)
            Column(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                FilterField(q, { q = it }, "Search", icon = Icons.Filled.Search)
                val mine = shelf.filter { q.isBlank() || it.displayTitle.contains(q.trim(), true) || (it.author?.contains(q.trim(), true) ?: false) }.take(8)
                if (mine.isNotEmpty()) { Eyebrow("On your shelf"); mine.forEach { b -> PickRow(b.cover, b.displayTitle, b.author) { onPick(body("key" to w.key, "book_id" to b.id)) } } }
                if (results.isNotEmpty()) { Eyebrow("Hardcover"); results.forEach { r -> PickRow(r.cover, r.displayTitle, listOfNotNull(r.author, r.year?.toString()).joinToString(" · ")) {
                    onPick(body("key" to w.key, "hc_id" to r.hcId, "title" to r.title, "author" to r.author, "pages" to r.pages, "cover" to r.cover, "slug" to r.slug)) } } }
            }
        }
    }
}

@Composable
private fun PickRow(cover: String?, title: String, sub: String?, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().mqPanel().clickable(onClick = onClick).padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Poster(cover, Modifier.width(38.dp), radius = 5.dp)
        Column(Modifier.weight(1f)) { Text(title, style = T.body(14f, 700), color = C.ink, maxLines = 2); sub?.let { Text(it, style = T.caption, color = C.inkMuted, maxLines = 1) } }
    }
}
