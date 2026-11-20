package dev.kadenthompson.marquee.session

import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import dev.kadenthompson.marquee.model.BookRequestConfig
import dev.kadenthompson.marquee.model.Celebration
import dev.kadenthompson.marquee.model.CelebrationsResponse
import dev.kadenthompson.marquee.model.ListMembership
import dev.kadenthompson.marquee.model.MeResponse
import dev.kadenthompson.marquee.model.Person
import dev.kadenthompson.marquee.model.RequestConfig
import dev.kadenthompson.marquee.net.ApiError
import dev.kadenthompson.marquee.net.MarqueeClient
import dev.kadenthompson.marquee.net.PairedServer
import dev.kadenthompson.marquee.net.Vault
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject

/**
 * App-wide state: who we're paired with, who we are, and the celebrations waiting to
 * be shown. Everything that needs the server goes through [client], which only exists
 * once a server is paired — so an unpaired build genuinely cannot reach anything.
 */
class Session(private val context: Context) {

    enum class Phase { STARTING, UNPAIRED, READY }

    private val vault = Vault(context)
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val prefs = Prefs(context)

    var phase by mutableStateOf(Phase.STARTING); private set
    var server by mutableStateOf<PairedServer?>(null); private set
    var client by mutableStateOf<MarqueeClient?>(null); private set
    var me by mutableStateOf<Person?>(null); private set
    var signedOutReason by mutableStateOf<String?>(null); private set

    /** Celebrations waiting their turn. The fanfare shows one at a time. */
    val celebrationQueue = mutableStateListOf<Celebration>()
    var listMembership by mutableStateOf<Map<String, Int>>(emptyMap()); private set
    var requestConfig by mutableStateOf<RequestConfig?>(null); private set
    var bookRequestConfig by mutableStateOf<BookRequestConfig?>(null); private set
    /** Bumped whenever an episode is marked somewhere Home can't see, so it refetches. */
    var watchRevision by mutableIntStateOf(0); private set
    /** Bumped when reading progress changes anywhere. */
    var readingRevision by mutableIntStateOf(0); private set

    val tracksReading get() = me?.features?.tracksReading == true
    val tracksBooks get() = me?.features?.tracksBooks == true
    val tracksManga get() = me?.features?.tracksManga == true

    /** The name this device registers under, and the placeholder in the pairing field. */
    val suggestedDeviceName: String
        get() = runCatching { Settings.Global.getString(context.contentResolver, Settings.Global.DEVICE_NAME) }.getOrNull()
            ?.takeIf { it.isNotBlank() } ?: "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}"

    suspend fun start() {
        val stored = vault.load()
        if (stored == null) { phase = Phase.UNPAIRED; return }
        install(stored)
        me = Person(username = stored.username, displayName = stored.displayName, isAdmin = stored.isAdmin, isMe = true)
        phase = Phase.READY
        dev.kadenthompson.marquee.notify.RefreshWorker.schedule(context)
        refreshMe()
    }

    private fun install(s: PairedServer?) {
        server = s
        client = s?.let { MarqueeClient(it) }
    }

    /** Re-read `/api/me`: the session check and the source of the feature flags. */
    suspend fun refreshMe() {
        val c = client ?: return
        try {
            val r: MeResponse = c.get("me")
            me = r.person
            server?.let {
                val updated = it.copy(username = r.username, displayName = r.person.name, isAdmin = r.isAdmin == true)
                if (updated != it) { install(updated); vault.save(updated) }
            }
        } catch (e: ApiError.Unauthorized) {
            signOutLocally("That device was unpaired from the server.")
        } catch (_: Exception) {
            // Offline: keep going with what the vault remembered.
        }
    }

    suspend fun adopt(s: PairedServer, person: Person?) {
        vault.save(s)
        install(s)
        me = person ?: Person(username = s.username, displayName = s.displayName, isAdmin = s.isAdmin, isMe = true)
        signedOutReason = null
        phase = Phase.READY
        dev.kadenthompson.marquee.notify.RefreshWorker.schedule(context)
        refreshMe()
    }

    /** Unpair: revoke server-side first so the token dies even if the app is deleted. */
    suspend fun unpair() {
        // Stop the server pushing to this device before its token dies.
        runCatching { dev.kadenthompson.marquee.notify.PushSetup.disable(context) }
        runCatching { client?.send("logout") }
        signOutLocally(null)
    }

    fun signOutLocally(reason: String?) {
        scope.launch {
            vault.clear()
            dev.kadenthompson.marquee.widget.WidgetData.clear(context)
        }
        dev.kadenthompson.marquee.notify.RefreshWorker.cancel(context)
        dev.kadenthompson.marquee.notify.NotifyPrefs.clear(context)
        ScreenCache.clear(context)
        install(null)
        me = null
        listMembership = emptyMap()
        requestConfig = null
        bookRequestConfig = null
        celebrationQueue.clear()
        signedOutReason = reason
        phase = Phase.UNPAIRED
    }

    /** Any call that comes back 401 lands here. */
    fun handle(e: Throwable) {
        if (e is ApiError.Unauthorized && phase == Phase.READY) signOutLocally("That device was unpaired from the server.")
    }

    suspend fun refreshListMembership() {
        val c = client ?: return
        runCatching { c.get<ListMembership>("lists/members") }.onSuccess { listMembership = it.members }
    }

    fun listCount(type: String, id: Int) = listMembership["$type:$id"] ?: 0

    suspend fun loadRequestConfig() {
        val c = client ?: return
        if (requestConfig != null) return
        requestConfig = runCatching { c.get<RequestConfig>("request/config") }.getOrNull()
    }

    suspend fun loadBookRequestConfig(force: Boolean = false) {
        val c = client ?: return
        if (!force && bookRequestConfig != null) return
        val fresh = runCatching { c.get<BookRequestConfig>("book-requests/config") }.getOrNull()
        if (fresh != null) bookRequestConfig = fresh
        else if (bookRequestConfig == null) bookRequestConfig = BookRequestConfig(false)
    }

    suspend fun checkCelebrations() {
        val c = client ?: return
        runCatching { c.get<CelebrationsResponse>("celebrations") }.onSuccess { enqueue(it.celebrations) }
    }

    fun noteWatched() { watchRevision++ }
    fun noteReading() { readingRevision++ }

    fun enqueue(celebrations: List<Celebration>?) {
        val known = celebrationQueue.map { it.id }.toSet()
        celebrationQueue.addAll((celebrations ?: emptyList()).filter { it.id !in known })
    }

    fun finishCelebration(c: Celebration) {
        celebrationQueue.removeAll { it.id == c.id }
        val cl = client ?: return
        scope.launch {
            runCatching { cl.send("celebrations/seen", buildJsonObject { put("ids", JsonArray(listOf(JsonPrimitive(c.id)))) }) }
        }
    }

    fun updateMe(transform: (Person) -> Person) { me = me?.let(transform) }
}
