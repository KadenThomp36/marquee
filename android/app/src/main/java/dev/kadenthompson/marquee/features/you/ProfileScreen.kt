package dev.kadenthompson.marquee.features.you

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MoveToInbox
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.TheaterComedy
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.FoldSpread
import dev.kadenthompson.marquee.design.LibraryFormat
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.MqColors
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.RailHeader
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.SectionHeader
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.artUrl
import dev.kadenthompson.marquee.design.grouped
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.NavRow
import dev.kadenthompson.marquee.features.common.OnArtBadge
import dev.kadenthompson.marquee.features.common.Rail
import dev.kadenthompson.marquee.features.reading.BarChart
import dev.kadenthompson.marquee.features.reading.StatTile
import dev.kadenthompson.marquee.model.AdvancedStats
import dev.kadenthompson.marquee.model.BannerOptionsResponse
import dev.kadenthompson.marquee.model.ListCard
import dev.kadenthompson.marquee.model.MembersResponse
import dev.kadenthompson.marquee.model.Person
import dev.kadenthompson.marquee.model.ProfilePayload
import dev.kadenthompson.marquee.model.Stats
import dev.kadenthompson.marquee.model.WatchedItem
import dev.kadenthompson.marquee.model.WatchedPage
import dev.kadenthompson.marquee.nav.BookRequestsRoute
import dev.kadenthompson.marquee.nav.HistoryRoute
import dev.kadenthompson.marquee.nav.ListRoute
import dev.kadenthompson.marquee.nav.ListsRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MovieRoute
import dev.kadenthompson.marquee.nav.NotificationsRoute
import dev.kadenthompson.marquee.nav.ProfileRoute
import dev.kadenthompson.marquee.nav.RecapRoute
import dev.kadenthompson.marquee.nav.SettingsRoute
import dev.kadenthompson.marquee.nav.ShowRoute
import dev.kadenthompson.marquee.nav.WatchedRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

@Serializable data class UserListsResponse(val user: Person = Person(), val isMe: Boolean = false, val lists: List<ListCard> = emptyList())

/** You (username null) or a housemate: banner, favourites, recap, watched rails, lists, numbers. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ProfileScreen(username: String?) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    val isMe = username == null || username.equals(session.me?.username, true)
    val who = if (isMe) "me" else username!!
    var profile by remember { mutableStateOf<ProfilePayload?>(null) }
    var stats by remember { mutableStateOf<Stats?>(null) }
    var advanced by remember { mutableStateOf<AdvancedStats?>(null) }
    var shows by remember { mutableStateOf<WatchedPage?>(null) }
    var films by remember { mutableStateOf<WatchedPage?>(null) }
    var lists by remember { mutableStateOf<List<ListCard>>(emptyList()) }
    var members by remember { mutableStateOf<List<Person>>(emptyList()) }
    var refreshing by remember { mutableStateOf(false) }
    var banners by remember { mutableStateOf(false) }
    var confirmUnpair by remember { mutableStateOf(false) }

    suspend fun loadAll() {
        val c = session.client ?: return
        runCatching { c.get<ProfilePayload>(if (isMe) "profile" else "profile/$username") }.onSuccess { profile = it }
        val base = if (isMe) "stats" else "profile/$username/stats"
        runCatching { c.get<Stats>(base) }.onSuccess { stats = it }
        runCatching { c.get<AdvancedStats>(if (isMe) "stats/advanced" else "$base/advanced") }.onSuccess { advanced = it }
        runCatching { c.get<WatchedPage>("watched/$who/shows", mapOf("limit" to "14")) }.onSuccess { shows = it }
        runCatching { c.get<WatchedPage>("watched/$who/movies", mapOf("limit" to "14")) }.onSuccess { films = it }
        profile?.username?.let { n -> runCatching { c.get<UserListsResponse>("user/$n/lists") }.onSuccess { lists = it.lists } }
        runCatching { c.get<MembersResponse>("members") }.onSuccess { members = it.members }
        if (isMe) session.loadBookRequestConfig(force = true)
    }
    LaunchedEffect(username) { loadAll() }

    val avatarPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) scope.launch {
            val bytes = runCatching { ctx.contentResolver.openInputStream(uri)?.use { it.readBytes() } }.getOrNull() ?: return@launch
            runCatching { session.client?.upload("profile/avatar", bytes, "avatar.jpg", "image/jpeg") }
            loadAll(); session.refreshMe()
        }
    }

    val p = profile
    val content: @Composable (androidx.compose.foundation.layout.PaddingValues) -> Unit = { pad ->
        PullToRefreshBox(refreshing, { scope.launch { refreshing = true; loadAll(); refreshing = false } }, Modifier.fillMaxSize()) {
            if (p == null) Column(Modifier.padding(pad), verticalArrangement = Arrangement.spacedBy(14.dp)) { Skeleton(height = 190.dp, radius = 0.dp); Skeleton(Modifier.padding(horizontal = MQ.gutter), 90.dp) }
            else FoldSpread(contentPadding = PaddingValues(top = pad.calculateTopPadding()), spacing = 24.dp, leading = {
                Identity(p, isMe, onSettings = { nav.push(SettingsRoute) }, onAvatar = { avatarPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) }, onBanner = { banners = true })
                if (p.favorites.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionHeader("Favourites", Modifier.padding(horizontal = MQ.gutter), "${p.favorites.size}")
                    Rail { items(p.favorites, key = { it.uniqueId }) { f ->
                        Column(Modifier.width(96.dp).clip(RoundedCornerShape(8.dp)).combinedClickable(onClick = { nav.push(if (f.type == "show") ShowRoute(f.id) else MovieRoute(f.id)) },
                            onLongClick = { if (isMe) scope.launch { profile = profile?.copy(favorites = profile!!.favorites.filterNot { it.uniqueId == f.uniqueId }); runCatching { session.client?.sendDelete("favorites/${f.type}/${f.id}") } } }),
                            verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Poster(f.poster, Modifier.fillMaxWidth()); Text(f.displayTitle, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    } }
                }
                RecapTeaser(p, isMe) { y -> nav.push(RecapRoute(y, if (isMe) null else p.username)) }
                shows?.takeIf { it.items.isNotEmpty() }?.let { WatchedRail(it, "Shows watched") { nav.push(WatchedRoute(if (isMe) null else p.username, "shows")) } }
                films?.takeIf { it.items.isNotEmpty() }?.let { WatchedRail(it, "Films watched") { nav.push(WatchedRoute(if (isMe) null else p.username, "movies")) } }
                if (lists.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    RailHeader(if (isMe) "Lists" else "${p.person.shortName}'s lists", more = if (isMe) "All" else null) { nav.push(ListsRoute) }
                    Rail { items(lists, key = { it.id }) { l -> ListTile(l) { nav.push(ListRoute(l.id)) } } }
                }
                if (isMe) Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    NavRow(Icons.Filled.Bookmark, "My lists") { nav.push(ListsRoute) }
                    NavRow(Icons.Filled.History, "History") { nav.push(HistoryRoute) }
                    NavRow(Icons.Filled.Notifications, "Notifications") { nav.push(NotificationsRoute) }
                    if (session.bookRequestConfig?.isEnabled == true) NavRow(Icons.Filled.MoveToInbox, "Book requests") { nav.push(BookRequestsRoute()) }
                }
                val others = members.filter { !it.username.equals(p.username, true) }
                if (others.isNotEmpty()) Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    SectionHeader("The household", Modifier.padding(horizontal = MQ.gutter))
                    Rail { items(others, key = { it.username ?: it.name }) { m ->
                        Column(Modifier.width(72.dp).clip(RoundedCornerShape(8.dp)).clickable { m.username?.let { nav.push(ProfileRoute(it)) } }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                            Avatar(m, 56.dp); Text(m.shortName, style = T.body(12f, 600), color = C.ink, maxLines = 1)
                        }
                    } }
                }
            }, trailing = {
                stats?.let { StatsSection(it, advanced) }
                if (isMe) ChipButton("Unpair this device", Icons.AutoMirrored.Filled.Logout, Modifier.padding(horizontal = MQ.gutter), destructive = true) { confirmUnpair = true }
            })
        }
    }
    if (isMe) Box(Modifier.fillMaxSize()) {
        content(PaddingValues())
        Box(Modifier.fillMaxWidth().statusBarsPadding().background(Color.Transparent).height(0.dp))
        Box(Modifier.fillMaxWidth().height(androidx.compose.foundation.layout.WindowInsets.statusBars.asPaddingValues().calculateTopPadding()).background(C.ground.copy(alpha = 0.92f)))
    }
    else ScreenScaffold(p?.person?.name ?: username ?: "", { nav.popBackStack() }) { pad -> content(pad) }

    if (banners) BannerSheet(onDismiss = { banners = false }) { scope.launch { loadAll(); session.refreshMe() } }
    if (confirmUnpair) AlertDialog(onDismissRequest = { confirmUnpair = false }, containerColor = C.panelRaised,
        title = { Text("Unpair this device?", style = T.headline, color = C.ink) },
        text = { Text("The server forgets this device's session, and the app forgets the server. You can pair again any time.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmUnpair = false; scope.launch { session.unpair() } }) { Text("Unpair", color = C.velvet) } },
        dismissButton = { TextButton({ confirmUnpair = false }) { Text("Cancel", color = C.brass) } })
}

@Composable
private fun Identity(p: ProfilePayload, isMe: Boolean, onSettings: () -> Unit, onAvatar: () -> Unit, onBanner: () -> Unit) {
    val banner = artUrl(p.banner)
    Box(Modifier.fillMaxWidth()) {
        Box(Modifier.fillMaxWidth().height(if (banner != null) 210.dp else 120.dp)) {
            if (banner != null) AsyncImage(banner, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            else Box(Modifier.fillMaxSize().background(Brush.radialGradient(listOf(C.brass.copy(alpha = 0.18f), Color.Transparent))))
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0f to Color.Transparent, 0.5f to C.ground.copy(alpha = 0.3f), 1f to C.ground)))
            if (isMe) Row(Modifier.align(Alignment.TopEnd).statusBarsPadding().padding(10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.size(40.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)).clickable(onClick = onBanner), contentAlignment = Alignment.Center) { Icon(Icons.Filled.Image, "Change banner", tint = Color.White) }
                Box(Modifier.size(40.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.45f)).clickable(onClick = onSettings), contentAlignment = Alignment.Center) { Icon(Icons.Filled.Settings, "Settings", tint = Color.White) }
            }
        }
        Column(Modifier.padding(top = if (banner != null) 150.dp else 70.dp).padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(Modifier.clickable(enabled = isMe, onClick = onAvatar)) {
                    Avatar(p.person, 84.dp, Modifier.border(3.dp, C.ground, CircleShape))
                    if (isMe) Box(Modifier.align(Alignment.BottomEnd).size(26.dp).clip(CircleShape).background(C.brassFill), contentAlignment = Alignment.Center) { Icon(Icons.Filled.CameraAlt, "Change photo", tint = C.brassOnFill, modifier = Modifier.size(14.dp)) }
                }
                Column(Modifier.weight(1f).padding(bottom = 6.dp)) {
                    Text(p.person.name, style = T.title, color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text("@${p.username}${p.memberSince?.let { " · since ${MQTime.monthLabel(it)}" } ?: ""}", style = T.caption, color = C.inkMuted)
                }
            }
            p.headline?.let { h ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(h.episodes.grouped to "episodes", h.shows.grouped to "shows", h.movies.grouped to "films", h.hours.grouped to "hours").forEach { (v, l) ->
                        Column(Modifier.weight(1f).mqPanel().padding(vertical = 9.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(v, style = T.body(17f, 800).copy(fontFeatureSettings = "tnum"), color = C.brass); Text(l, style = T.caption, color = C.inkMuted)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RecapTeaser(p: ProfilePayload, isMe: Boolean, open: (Int) -> Unit) {
    val year = p.recapYears.firstOrNull()
    val (title, detail, locked) = when {
        year != null -> Triple("${if (isMe) "Your" else p.person.shortName + "'s"} $year, now showing", "The year in lights, with a quiz, a ticket and a few surprises", false)
        isMe && p.recapSoon == true -> Triple("${p.recapYear ?: LocalDate.now().year} is still being written",
            "Premieres ${MQTime.date(p.recapRelease)?.let { "${it.month.getDisplayName(TextStyle.FULL, Locale.getDefault())} ${it.dayOfMonth}" } ?: "in December"}", true)
        else -> return
    }
    Row(Modifier.padding(horizontal = MQ.gutter).fillMaxWidth().clip(RoundedCornerShape(16.dp))
        .background(Brush.linearGradient(listOf(C.velvet.copy(alpha = 0.55f), C.panel))).border(1.dp, C.brassDim, RoundedCornerShape(16.dp))
        .clickable(enabled = !locked && year != null) { year?.let(open) }.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text("YEAR IN REVIEW", style = T.eyebrow, color = MqColors.brassOnArt)
            Text(title, style = T.body(17f, 800), color = MqColors.inkOnArt)
            Text(detail, style = T.caption, color = MqColors.inkSoftOnArt)
        }
        Icon(if (locked) Icons.Filled.Lock else Icons.Filled.TheaterComedy, null, tint = MqColors.brassOnArt, modifier = Modifier.size(28.dp))
    }
}

@Composable
private fun WatchedRail(page: WatchedPage, title: String, onAll: () -> Unit) {
    val nav = LocalNav.current
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        RailHeader("$title · ${page.total.grouped}", onMore = onAll)
        Rail { items(page.items, key = { it.uniqueId }) { w -> WatchedTile(w, Modifier.width(MQ.watchedWidth)) { nav.push(if (w.type == "show") ShowRoute(w.id) else MovieRoute(w.id)) } } }
    }
}

@Composable
fun WatchedTile(w: WatchedItem, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Column(modifier.clip(RoundedCornerShape(8.dp)).clickable(onClick = onClick), verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Box {
            Poster(w.poster, Modifier.fillMaxWidth())
            w.rating?.let { OnArtBadge("★ $it", Modifier.align(Alignment.TopEnd).padding(5.dp)) }
            if (w.isFinishedSeries) OnArtBadge("Finished", Modifier.align(Alignment.BottomStart).padding(5.dp))
            else if (w.type == "show" && (w.aired ?: 0) > 0) OnArtBadge("${w.watched ?: 0}/${w.aired}", Modifier.align(Alignment.BottomStart).padding(5.dp))
        }
        Text(w.displayTitle, style = T.tile, color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(listOfNotNull(w.year?.toString(), w.watchedAt?.let { MQTime.short(it) }).joinToString(" · "), style = T.caption, color = C.inkMuted, maxLines = 1)
    }
}

@Composable
fun ListTile(l: ListCard, onClick: () -> Unit) {
    Column(Modifier.width(150.dp).clip(RoundedCornerShape(11.dp)).clickable(onClick = onClick), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Box(Modifier.fillMaxWidth().aspectRatio(1.25f).mqPanel()) {
            l.posters.take(3).forEachIndexed { i, url -> Poster(url, Modifier.width(62.dp).offset(x = (12 + i * 34).dp, y = (10 + (i % 2) * 6).dp), radius = 6.dp) }
            if (l.posters.isEmpty()) Icon(Icons.Filled.Bookmark, null, tint = C.brassDim, modifier = Modifier.align(Alignment.Center))
        }
        Text(l.name, style = T.tile, color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
        Text(listOfNotNull("${l.count} titles", l.visibility?.takeIf { it != "private" }, l.owner).joinToString(" · "), style = T.caption, color = C.inkMuted, maxLines = 1)
    }
}

@Composable
private fun BannerSheet(onDismiss: () -> Unit, onChanged: () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var opts by remember { mutableStateOf<BannerOptionsResponse?>(null) }
    LaunchedEffect(Unit) { opts = runCatching { session.client?.get<BannerOptionsResponse>("profile/banner/options") }.getOrNull() ?: BannerOptionsResponse() }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter).padding(bottom = 16.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("Choose a banner", style = T.headline, color = C.ink)
            Text("Backdrops from what you've watched.", style = T.caption, color = C.inkMuted)
            opts?.options?.forEach { o ->
                Box(Modifier.fillMaxWidth().aspectRatio(16f / 6f).clip(RoundedCornerShape(11.dp)).clickable {
                    scope.launch { runCatching { session.client?.send("profile/banner", body("url" to o.backdrop)) }; onChanged(); onDismiss() }
                }) {
                    AsyncImage(o.backdrop, o.title, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    Text(o.title, style = T.body(12f, 700), color = Color.White, modifier = Modifier.align(Alignment.BottomStart).background(Color.Black.copy(alpha = 0.5f)).padding(horizontal = 8.dp, vertical = 4.dp))
                }
            }
            ChipButton("Remove banner", destructive = true) { scope.launch { runCatching { session.client?.send("profile/banner", body("clear" to true)) }; onChanged(); onDismiss() } }
        }
    }
}

// ================= Stats

/** The numbers: tiles, records, month by month, the watch clock, top shows, genres, shelves, decades, ratings, deeper cuts. */
@Composable
fun StatsSection(s: Stats, adv: AdvancedStats?) {
    Column(Modifier.padding(horizontal = MQ.gutter), verticalArrangement = Arrangement.spacedBy(18.dp)) {
        SectionHeader("The numbers")
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatTile(MQTime.duration(s.totalMinutes), "watched in all", Modifier.weight(1f), true)
            StatTile(s.episodes.grouped, "episodes · ${s.shows} shows", Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatTile(s.movies.grouped, "films · ${MQTime.duration(s.movieMinutes)}", Modifier.weight(1f))
            StatTile("${s.streak.current}", "day streak · best ${s.streak.longest}", Modifier.weight(1f), s.streak.current > 0)
        }
        s.thisYear?.let { y -> Text("This year: ${y.episodes.grouped} episodes and ${y.movies} films${s.perDay?.let { " · ${LibraryFormat.one(it)} episodes a day" } ?: ""}", style = T.sub, color = C.inkSoft) }
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            s.bigDay?.let { Text("Biggest day: ${MQTime.medium(it.date)} — ${it.count} episodes${it.top?.let { t -> " of $t" } ?: ""}", style = T.caption, color = C.inkSoft) }
            s.firstWatch?.let { f -> Text("First logged: ${f.title ?: ""}${f.watchedAt?.let { " · ${MQTime.medium(it)}" } ?: ""}", style = T.caption, color = C.inkSoft) }
        }
        if (s.monthly.isNotEmpty()) {
            Eyebrow("Month by month")
            BarChart(s.monthly.map { it.count.toFloat() }, Modifier.fillMaxWidth().height(130.dp), C.brass, C.hairline)
            Row { Text(MQTime.monthKeyLabel(s.monthly.first().ym), style = T.caption, color = C.inkMuted); Spacer(Modifier.weight(1f)); Text(MQTime.monthKeyLabel(s.monthly.last().ym), style = T.caption, color = C.inkMuted) }
        }
        s.heatmap?.takeIf { it.size == 7 }?.let { hm -> Eyebrow("The watch clock"); WatchClock(hm) }
        if (s.topShows.isNotEmpty()) {
            Eyebrow("Most watched")
            val max = s.topShows.maxOf { it.eps }.coerceAtLeast(1)
            s.topShows.take(8).forEachIndexed { i, t ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("${i + 1}", style = T.numeric, color = C.inkMuted, modifier = Modifier.width(18.dp))
                    Poster(t.poster, Modifier.width(30.dp), radius = 4.dp)
                    Column(Modifier.weight(1f)) {
                        Text(t.title, style = T.body(13.5f, 600), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        Box(Modifier.fillMaxWidth(t.eps.toFloat() / max).height(4.dp).clip(CircleShape).background(C.brass))
                    }
                    Text("${t.eps}", style = T.numeric, color = C.brass)
                }
            }
        }
        if (s.genres.isNotEmpty()) { Eyebrow("Genres"); HBars(s.genres.take(8).map { it.name to it.count }, C.categorical) }
        s.completion?.takeIf { it.total > 0 }?.let { c ->
            Eyebrow("Your shows")
            val parts = listOf(c.finished to C.chartViolet, c.upToDate to C.chartGreen, c.inProgress to C.brass, c.notStarted to C.chartBlue, c.dropped to C.velvet)
            Row(Modifier.fillMaxWidth().height(14.dp).clip(CircleShape)) { parts.filter { it.first > 0 }.forEach { (n, col) -> Box(Modifier.weight(n.toFloat()).fillMaxSize().background(col)) } }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOf("finished" to c.finished, "caught up" to c.upToDate, "watching" to c.inProgress, "not started" to c.notStarted, "stopped" to c.dropped).zip(parts).filter { it.first.second > 0 }.forEach { (lv, pc) ->
                    Row(verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(7.dp).clip(CircleShape).background(pc.second)); Text(" ${lv.second} ${lv.first}", style = T.caption, color = C.inkSoft) }
                }
            }
        }
        s.movieDecades?.takeIf { it.isNotEmpty() }?.let { d -> Eyebrow("Films by decade"); HBars(d.sortedBy { it.dec ?: 0 }.map { it.label to it.c }, listOf(C.chartAqua)) }
        s.ratingHist?.takeIf { it.isNotEmpty() }?.let { h ->
            Eyebrow("How you rate")
            BarChart((1..10).map { (h[it.toString()] ?: 0).toFloat() }, Modifier.fillMaxWidth().height(90.dp), C.brass, C.hairline, colorFor = { MqColors.rating(it + 1) })
            Row { (1..10).forEach { Text("$it", style = T.caption, color = C.inkMuted, modifier = Modifier.weight(1f), textAlign = androidx.compose.ui.text.style.TextAlign.Center) } }
        }
        if (adv != null && !adv.isEmpty) {
            SectionHeader("Deeper cuts")
            if (adv.networks.isNotEmpty()) { Eyebrow("Networks"); HBars(adv.networks.take(6).map { it.name to it.count }, C.categorical) }
            if (adv.studios.isNotEmpty()) { Eyebrow("Studios"); HBars(adv.studios.take(6).map { it.name to it.count }, C.categorical) }
            if (adv.countries.isNotEmpty()) { Eyebrow("Countries"); HBars(adv.countries.take(6).map { it.name to it.count }, C.categorical) }
            if (adv.actors.isNotEmpty()) { Eyebrow("Faces you keep seeing"); HBars(adv.actors.take(8).map { it.name to it.total }, listOf(C.chartPink)) }
            if (adv.directors.isNotEmpty()) { Eyebrow("Directors"); HBars(adv.directors.take(6).map { it.name to it.count }, listOf(C.chartOrange)) }
        }
    }
}

@Composable
private fun HBars(rows: List<Pair<String, Int>>, palette: List<Color>) {
    val max = rows.maxOfOrNull { it.second }?.coerceAtLeast(1) ?: 1
    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
        rows.forEachIndexed { i, (name, n) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(name, style = T.body(12.5f, 500), color = C.inkSoft, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.width(110.dp))
                Box(Modifier.weight(1f).height(10.dp).clip(CircleShape).background(C.panelRaised)) {
                    Box(Modifier.fillMaxWidth(n.toFloat() / max).fillMaxSize().clip(CircleShape).background(palette[i % palette.size]))
                }
                Text(n.grouped, style = T.numeric, color = C.ink, modifier = Modifier.width(44.dp), textAlign = androidx.compose.ui.text.style.TextAlign.End)
            }
        }
    }
}

/** Day × hour heatmap. */
@Composable
private fun WatchClock(hm: List<List<Int>>) {
    val max = hm.flatten().maxOrNull()?.coerceAtLeast(1) ?: 1
    val brass = C.brass; val empty = C.panelRaised
    val days = listOf("S", "M", "T", "W", "T", "F", "S")
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        Column(verticalArrangement = Arrangement.SpaceEvenly, modifier = Modifier.height(130.dp)) { days.forEach { Text(it, style = T.caption, color = C.inkMuted) } }
        Column(Modifier.weight(1f)) {
            Canvas(Modifier.fillMaxWidth().height(130.dp)) {
                val cw = size.width / 24; val ch = size.height / 7
                hm.forEachIndexed { d, row -> row.forEachIndexed { h, v ->
                    drawRoundRect(if (v > 0) brass.copy(alpha = 0.15f + 0.85f * v / max) else empty, Offset(h * cw + 1, d * ch + 1), Size(cw - 2, ch - 2), CornerRadius(2f))
                } }
            }
            Row { listOf("12a", "6a", "12p", "6p").forEach { Text(it, style = T.caption, color = C.inkMuted, modifier = Modifier.weight(1f)) } }
        }
    }
}

/** Everything watched as a grid with year dividers. */
@Composable
fun WatchedGridScreen(username: String?, kind: String) {
    val session = LocalSession.current
    val nav = LocalNav.current
    var items by remember { mutableStateOf<List<WatchedItem>>(emptyList()) }
    var next by remember { mutableStateOf<Int?>(0) }
    var total by remember { mutableStateOf(0) }
    var loading by remember { mutableStateOf(false) }
    val who = username ?: "me"
    suspend fun more() {
        val off = next ?: return
        if (loading) return
        loading = true
        runCatching { session.client?.get<WatchedPage>("watched/$who/$kind", mapOf("offset" to off.toString(), "limit" to "60")) }.getOrNull()?.let { p ->
            items = items + p.items; next = p.next; total = p.total
        } ?: run { next = null }
        loading = false
    }
    LaunchedEffect(Unit) { more() }
    ScreenScaffold(if (kind == "shows") "Shows watched" else "Films watched", { nav.popBackStack() }) { pad ->
        LazyVerticalGrid(GridCells.Adaptive(104.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            item(span = { GridItemSpan(maxLineSpan) }) { Text("${total.grouped} in all", style = T.caption, color = C.inkMuted) }
            items.groupBy { it.watchedAt?.take(4) ?: "Undated" }.forEach { (year, group) ->
                item(span = { GridItemSpan(maxLineSpan) }, key = "y$year") { SectionHeader(year, count = "${group.size}") }
                items(group, key = { it.uniqueId }) { w -> WatchedTile(w) { nav.push(if (w.type == "show") ShowRoute(w.id) else MovieRoute(w.id)) } }
            }
            if (next != null) item(span = { GridItemSpan(maxLineSpan) }) { LaunchedEffect(items.size) { more() }; Skeleton(height = 40.dp) }
        }
    }
}
