package dev.kadenthompson.marquee.features.you

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material.icons.filled.Public
import androidx.compose.material.icons.filled.RemoveCircle
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.Avatar
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.EmptyState
import dev.kadenthompson.marquee.design.ErrorState
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.LoadingList
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.MQTime
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.SectionHeader
import dev.kadenthompson.marquee.design.Segmented
import dev.kadenthompson.marquee.design.Skeleton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.design.mqPanel
import dev.kadenthompson.marquee.features.common.OnArtBadge
import dev.kadenthompson.marquee.features.common.ProgressBar
import dev.kadenthompson.marquee.features.detail.mqFieldColors
import dev.kadenthompson.marquee.model.AppNotification
import dev.kadenthompson.marquee.model.CreatedList
import dev.kadenthompson.marquee.model.ListDetail
import dev.kadenthompson.marquee.model.ListVisibility
import dev.kadenthompson.marquee.model.ListsResponse
import dev.kadenthompson.marquee.model.MembersResponse
import dev.kadenthompson.marquee.model.MovieHistoryItem
import dev.kadenthompson.marquee.model.MovieHistoryPage
import dev.kadenthompson.marquee.model.NotificationsResponse
import dev.kadenthompson.marquee.model.Person
import dev.kadenthompson.marquee.model.TVHistoryGroup
import dev.kadenthompson.marquee.model.TVHistoryPage
import dev.kadenthompson.marquee.nav.EpisodeRoute
import dev.kadenthompson.marquee.nav.ListRoute
import dev.kadenthompson.marquee.nav.LocalNav
import dev.kadenthompson.marquee.nav.MovieRoute
import dev.kadenthompson.marquee.nav.Navigator
import dev.kadenthompson.marquee.nav.ShowRoute
import dev.kadenthompson.marquee.nav.push
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.rememberRemote
import kotlinx.coroutines.launch

private fun visIcon(v: ListVisibility) = when (v) { ListVisibility.PRIVATE -> Icons.Filled.Lock; ListVisibility.PUBLIC -> Icons.Filled.Public; ListVisibility.COLLAB -> Icons.Filled.Group }

/** Your lists and the collab lists shared with you; New list. */
@Composable
fun ListsScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val data = rememberRemote<ListsResponse>("lists") { it.get("lists") }
    var creating by remember { mutableStateOf(false) }
    ScreenScaffold("Lists", { nav.popBackStack() }, actions = { IconButton({ creating = true }) { Icon(Icons.Filled.Add, "New list", tint = C.brass) } }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        val v = data.value
        LazyVerticalGrid(GridCells.Adaptive(150.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            if (v == null) items(4) { Skeleton(height = 160.dp) }
            else {
                items(v.lists, key = { "l${it.id}" }) { l -> ListTile(l) { nav.push(ListRoute(l.id)) } }
                v.shared?.takeIf { it.isNotEmpty() }?.let { sh ->
                    item(span = { GridItemSpan(maxLineSpan) }) { SectionHeader("Shared with you", count = "${sh.size}") }
                    items(sh, key = { "s${it.id}" }) { l -> ListTile(l) { nav.push(ListRoute(l.id)) } }
                }
            }
        }
    }
    if (creating) NewListSheet(onDismiss = { creating = false }) { name, vis, shared ->
        scope.launch {
            val c = session.client ?: return@launch
            runCatching { c.post<CreatedList>("lists", body("name" to name, "visibility" to vis.key, "shared_with" to shared)) }.onSuccess { nav.push(ListRoute(it.id)) }
            data.refresh()
        }
    }
}

@Composable
private fun NewListSheet(onDismiss: () -> Unit, onCreate: (String, ListVisibility, List<Int>) -> Unit) {
    var name by remember { mutableStateOf("") }
    var vis by remember { mutableStateOf(ListVisibility.PRIVATE) }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("New list", style = T.headline, color = C.ink)
            OutlinedTextField(name, { name = it }, Modifier.fillMaxWidth(), singleLine = true, placeholder = { Text("Name", color = C.inkMuted) }, colors = mqFieldColors())
            Segmented(ListVisibility.entries.map { it.label }, vis.ordinal) { vis = ListVisibility.entries[it] }
            Text(vis.explanation, style = T.caption, color = C.inkMuted)
            PrimaryButton("Create", { onCreate(name.trim(), vis, emptyList()); onDismiss() }, enabled = name.isNotBlank())
        }
    }
}

/** A list: its titles with progress, visibility and audience for the owner, remove for editors. */
@Composable
fun ListScreen(listId: Int) {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val data = rememberRemote<ListDetail>("list-$listId") { it.get("list/$listId") }
    var settings by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val l = data.value
    ScreenScaffold(l?.name ?: "List", { nav.popBackStack() }, actions = {
        if (l?.isOwner == true) IconButton({ settings = true }) { Icon(Icons.Filled.Tune, "List settings", tint = C.inkSoft) }
    }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        when {
            l != null -> LazyVerticalGrid(GridCells.Adaptive(104.dp), Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        val vis = ListVisibility.of(l.visibility)
                        Icon(visIcon(vis), null, tint = C.brass, modifier = Modifier.size(16.dp))
                        Text("${vis.label} · ${l.items.size} titles${if (!l.isOwner) " · ${l.owner.name}'s" else ""}", style = T.caption, color = C.inkSoft)
                    }
                }
                if (l.items.isEmpty()) item(span = { GridItemSpan(maxLineSpan) }) { EmptyState(Icons.Filled.Bookmark, "Nothing on this list yet", "Add titles from any show or film page.") }
                items(l.items, key = { it.uniqueId }) { it ->
                    Column(Modifier.clip(RoundedCornerShape(8.dp)).clickable { nav.push(if (it.isShow) ShowRoute(it.id) else MovieRoute(it.id)) }, verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        Box {
                            Poster(it.poster, Modifier.fillMaxWidth())
                            if (l.editable) Box(Modifier.align(Alignment.TopEnd).padding(4.dp).size(28.dp).clip(CircleShape).background(C.ground.copy(alpha = 0.7f)).clickable {
                                data.mutate { d -> d.copy(items = d.items.filterNot { x -> x.uniqueId == it.uniqueId }) }
                                scope.launch { runCatching { session.client?.send("list/$listId/item", body("item_type" to it.type, "item_id" to it.id, "remove" to true)) }; session.refreshListMembership() }
                            }, contentAlignment = Alignment.Center) { Icon(Icons.Filled.RemoveCircle, "Remove from list", tint = C.velvet, modifier = Modifier.size(18.dp)) }
                            if (it.isComplete) OnArtBadge("Done", Modifier.align(Alignment.BottomStart).padding(5.dp))
                        }
                        Text(it.displayTitle, style = T.tile, color = C.ink, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        if (it.isShow && (it.total ?: 0) > 0) ProgressBar(it.progress, height = 4.dp) else Text(it.year?.toString() ?: "", style = T.caption, color = C.inkMuted)
                    }
                }
            }
            data.error != null -> ErrorState(data.error!!) { data.refresh() }
            else -> Box(Modifier.padding(pad)) { LoadingList(3) }
        }
    }
    if (settings && l != null) ListSettingsSheet(l, onDismiss = { settings = false }, onSaved = { data.refresh() }, onDelete = { settings = false; confirmDelete = true })
    if (confirmDelete) AlertDialog(onDismissRequest = { confirmDelete = false }, containerColor = C.panelRaised,
        title = { Text("Delete ${l?.name}?", style = T.headline, color = C.ink) }, text = { Text("The list goes; the titles on it stay where they are.", style = T.body, color = C.inkSoft) },
        confirmButton = { TextButton({ confirmDelete = false; scope.launch { runCatching { session.client?.sendDelete("list/$listId") }; session.refreshListMembership(); nav.popBackStack() } }) { Text("Delete", color = C.velvet) } },
        dismissButton = { TextButton({ confirmDelete = false }) { Text("Cancel", color = C.brass) } })
}

@Composable
private fun ListSettingsSheet(l: ListDetail, onDismiss: () -> Unit, onSaved: () -> Unit, onDelete: () -> Unit) {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    var vis by remember { mutableStateOf(ListVisibility.of(l.visibility)) }
    var shared by remember { mutableStateOf(l.sharedWith?.toSet() ?: emptySet()) }
    var members by remember { mutableStateOf<List<Person>>(emptyList()) }
    LaunchedEffect(Unit) { members = runCatching { session.client?.get<MembersResponse>("members")?.members }.getOrNull()?.filter { it.isMe != true && !it.username.equals(session.me?.username, true) } ?: emptyList() }
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = C.ground) {
        Column(Modifier.navigationBarsPadding().padding(horizontal = MQ.gutter).padding(bottom = 20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("Who can see ${l.name}", style = T.headline, color = C.ink)
            Segmented(ListVisibility.entries.map { it.label }, vis.ordinal) { vis = ListVisibility.entries[it] }
            Text(vis.explanation, style = T.caption, color = C.inkMuted)
            if (vis == ListVisibility.COLLAB && members.isNotEmpty()) {
                Eyebrow("Shared with (none ticked = everyone)")
                members.forEach { m -> val id = m.id ?: return@forEach
                    Row(Modifier.fillMaxWidth().clickable { shared = if (id in shared) shared - id else shared + id }, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Checkbox(id in shared, { shared = if (id in shared) shared - id else shared + id }, colors = CheckboxDefaults.colors(checkedColor = C.brassFill, checkmarkColor = C.brassOnFill))
                        Avatar(m, 26.dp); Text(m.name, style = T.body, color = C.ink)
                    }
                }
            }
            PrimaryButton("Save", { scope.launch { runCatching { session.client?.send("list/${l.id}/visibility", body("visibility" to vis.key, "shared_with" to if (vis == ListVisibility.COLLAB) shared.toList() else null)) }; onSaved(); onDismiss() } })
            if (l.isDefault != true) ChipButton("Delete list", Icons.Filled.Delete, Modifier.align(Alignment.CenterHorizontally), destructive = true, onClick = onDelete)
        }
    }
}

// ================= History

/** The timeline, newest first: TV runs grouped by day, films on their own tab, endless scroll. */
@Composable
fun HistoryScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var tv by remember { mutableStateOf<List<TVHistoryGroup>>(emptyList()) }
    var films by remember { mutableStateOf<List<MovieHistoryItem>>(emptyList()) }
    var tvCursor by remember { mutableStateOf<String?>("") }
    var filmCursor by remember { mutableStateOf<String?>("") }
    var loading by remember { mutableStateOf(false) }
    suspend fun more() {
        if (loading) return
        val c = session.client ?: return
        loading = true
        if (tab == 0) tvCursor?.let { cur -> runCatching { c.get<TVHistoryPage>("history", mapOf("type" to "tv", "cursor" to cur.ifEmpty { null })) }.onSuccess { tv = tv + it.items; tvCursor = it.cursor?.takeIf { x -> x.isNotEmpty() && it.items.isNotEmpty() } }.onFailure { tvCursor = null } }
        else filmCursor?.let { cur -> runCatching { c.get<MovieHistoryPage>("history", mapOf("type" to "movie", "cursor" to cur.ifEmpty { null })) }.onSuccess { films = films + it.items; filmCursor = it.cursor?.takeIf { x -> x.isNotEmpty() && it.items.isNotEmpty() } }.onFailure { filmCursor = null } }
        loading = false
    }
    LaunchedEffect(tab) { if ((tab == 0 && tv.isEmpty()) || (tab == 1 && films.isEmpty())) more() }
    ScreenScaffold("History", { nav.popBackStack() }) { pad ->
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { Segmented(listOf("TV", "Films"), tab) { tab = it } }
            if (tab == 0) {
                var lastMonth = ""; var lastDay = ""
                tv.forEach { g ->
                    val month = g.day.take(7)
                    if (month != lastMonth) { lastMonth = month; item(key = "m$month") { Text(MQTime.monthLabel(g.day).uppercase(), style = T.wordmark(18f), color = C.brass, modifier = Modifier.padding(top = 10.dp)) } }
                    if (g.day != lastDay) { lastDay = g.day; item(key = "d${g.day}") { Eyebrow(MQTime.dayLabel(g.day)) } }
                    item(key = g.key) {
                        val eps = g.episodes
                        val range = when { eps.isEmpty() -> ""; eps.size == 1 -> "S${eps[0].season} · E${eps[0].number}${eps[0].title?.let { " $it" } ?: ""}"
                            else -> { val f = eps.minWith(compareBy({ it.season }, { it.number })); val l = eps.maxWith(compareBy({ it.season }, { it.number })); "S${f.season} E${f.number} – ${if (l.season != f.season) "S${l.season} " else ""}E${l.number} · ${eps.size} episodes" } }
                        Row(Modifier.fillMaxWidth().mqPanel().clickable {
                            if (eps.size == 1) nav.push(EpisodeRoute(g.showId, eps[0].season, eps[0].number)) else nav.push(ShowRoute(g.showId))
                        }.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Poster(g.poster, Modifier.width(40.dp), radius = 6.dp)
                            Column(Modifier.weight(1f)) {
                                Text(g.title ?: "", style = T.body(14.5f, 700), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(range, style = T.caption, color = C.brassBright, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            }
                            Text(MQTime.clock(g.minutes), style = T.caption, color = C.inkMuted)
                        }
                    }
                }
                if (tvCursor != null) item { LaunchedEffect(tv.size) { more() }; Skeleton(height = 60.dp) }
                else if (tv.isEmpty()) item { EmptyState(Icons.Filled.DoneAll, "Nothing watched yet") }
            } else {
                var lastMonth = ""
                films.forEach { f ->
                    val month = f.watchedAt.take(7)
                    if (month != lastMonth) { lastMonth = month; item(key = "fm$month") { Text(MQTime.monthLabel(f.watchedAt).uppercase(), style = T.wordmark(18f), color = C.brass, modifier = Modifier.padding(top = 10.dp)) } }
                    item(key = "f${f.id}-${f.watchedAt}") {
                        Row(Modifier.fillMaxWidth().mqPanel().clickable { nav.push(MovieRoute(f.id)) }.padding(10.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Poster(f.poster, Modifier.width(40.dp), radius = 6.dp)
                            Column(Modifier.weight(1f)) {
                                Text(f.title ?: "", style = T.body(14.5f, 700), color = C.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
                                Text(listOfNotNull(f.year?.toString(), MQTime.dayLabel(f.watchedAt), f.runtime?.let { MQTime.clock(it) }).joinToString(" · "), style = T.caption, color = C.inkSoft)
                            }
                            f.rating?.let { Text("★ $it", style = T.body(13f, 700), color = C.brass) }
                        }
                    }
                }
                if (filmCursor != null) item { LaunchedEffect(films.size) { more() }; Skeleton(height = 60.dp) }
                else if (films.isEmpty()) item { EmptyState(Icons.Filled.DoneAll, "No films logged yet") }
            }
        }
    }
}

// ================= Notifications

/** The in-app inbox. Tapping one marks it read and follows its link. Preferences live in Settings. */
@Composable
fun NotificationsScreen() {
    val session = LocalSession.current
    val nav = LocalNav.current
    val scope = rememberCoroutineScope()
    val data = rememberRemote<NotificationsResponse>("notifications") { it.get("notifications") }
    ScreenScaffold("Notifications", { nav.popBackStack() }, actions = {
        if ((data.value?.unread ?: 0) > 0) TextButton({
            data.mutate { it.copy(unread = 0, items = it.items.map { n -> n.copy(read = true) }) }
            scope.launch { runCatching { session.client?.send("notifications/read") } }
        }) { Text("Mark all read", color = C.brass, style = T.sub) }
    }, refreshing = data.refreshing, onRefresh = { data.refresh() }) { pad ->
        val v = data.value
        LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(start = MQ.gutter, end = MQ.gutter, top = pad.calculateTopPadding() + 8.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            if (v == null) items(5) { Skeleton(height = 64.dp) }
            else if (v.items.isEmpty()) item { EmptyState(Icons.Filled.NotificationsNone, "All quiet", "Premieres, new episodes and household reviews show up here.") }
            else items(v.items, key = { it.id }) { n -> NotificationRow(n) {
                if (n.read != true) { data.mutate { it.copy(unread = maxOf(0, it.unread - 1), items = it.items.map { x -> if (x.id == n.id) x.copy(read = true) else x }) }
                    scope.launch { runCatching { session.client?.send("notifications/read", body("id" to n.id)) } } }
                n.link?.let { Navigator.route(it) }?.let { nav.push(it) }
            } }
        }
    }
}

@Composable
private fun NotificationRow(n: AppNotification, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().mqPanel().clickable(onClick = onClick).padding(13.dp), horizontalArrangement = Arrangement.spacedBy(11.dp)) {
        Box(Modifier.padding(top = 6.dp).size(8.dp).clip(CircleShape).background(if (n.read == true) C.hairline else C.velvet))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(n.title, style = T.body(14.5f, if (n.read == true) 500 else 700), color = C.ink)
            n.body?.takeIf { it.isNotEmpty() }?.let { Text(it, style = T.caption, color = C.inkSoft, maxLines = 3, overflow = TextOverflow.Ellipsis) }
            Text(MQTime.relative(n.createdAt), style = T.caption, color = C.inkMuted)
        }
    }
}
