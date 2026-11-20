package dev.kadenthompson.marquee.session

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import dev.kadenthompson.marquee.net.MarqueeClient
import dev.kadenthompson.marquee.net.MarqueeJson
import dev.kadenthompson.marquee.net.friendly
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.KSerializer
import kotlinx.serialization.serializer
import java.io.File
import java.security.MessageDigest

/**
 * The last good copy of each screen, in memory and on disk — so back-navigation never
 * flashes a skeleton and a launch without the server shows yesterday's paper.
 * Cleared on unpair, along with everything else.
 */
object ScreenCache {
    private val memory = object : LinkedHashMap<String, Any>(64, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Any>?) = size > 80
    }
    private var dir: File? = null

    fun init(context: Context) { dir = File(context.cacheDir, "screens").apply { mkdirs() } }

    private fun file(key: String): File? = dir?.let {
        val h = MessageDigest.getInstance("SHA-1").digest(key.toByteArray()).joinToString("") { b -> "%02x".format(b) }
        File(it, "$h.json")
    }

    @Suppress("UNCHECKED_CAST")
    fun <T> get(key: String, s: KSerializer<T>): T? {
        synchronized(memory) { memory[key]?.let { return it as T } }
        val f = file(key) ?: return null
        if (!f.exists()) return null
        return runCatching { MarqueeJson.decodeFromString(s, f.readText()) }.getOrNull()?.also {
            synchronized(memory) { memory[key] = it as Any }
        }
    }

    fun <T> put(key: String, value: T, s: KSerializer<T>, disk: Boolean) {
        synchronized(memory) { memory[key] = value as Any }
        if (disk) runCatching { file(key)?.writeText(MarqueeJson.encodeToString(s, value)) }
    }

    fun clear(context: Context) {
        synchronized(memory) { memory.clear() }
        File(context.cacheDir, "screens").listFiles()?.forEach { it.delete() }
    }
}

/** One screen's worth of data, stale-while-revalidate. */
class Remote<T>(
    private val key: String?,
    private val serializer: KSerializer<T>,
    private val session: Session,
    private val scope: CoroutineScope,
    private val disk: Boolean,
    private val fetch: suspend (MarqueeClient) -> T,
) {
    var value by mutableStateOf<T?>(key?.let { ScreenCache.get(it, serializer) })
        private set
    var error by mutableStateOf<String?>(null); private set
    var loading by mutableStateOf(false); private set
    /** What's on screen came from cache and the network hasn't answered yet. */
    var stale by mutableStateOf(value != null); private set
    var refreshing by mutableStateOf(false); private set

    val isEmpty get() = value == null && error == null

    suspend fun load(force: Boolean = false) {
        if (loading) return
        if (!force && value != null && !stale) return
        val client = session.client ?: return
        loading = true
        try {
            val fresh = fetch(client)
            error = null; stale = false
            if (fresh != value) value = fresh
            key?.let { ScreenCache.put(it, fresh, serializer, disk) }
        } catch (e: kotlinx.coroutines.CancellationException) {
            throw e
        } catch (e: Throwable) {
            session.handle(e)
            if (value == null) error = e.friendly
        } finally {
            loading = false
        }
    }

    fun refresh() = scope.launch { refreshing = true; try { load(force = true) } finally { refreshing = false } }

    /** Patch what's on screen without a refetch — after a punch, a rating, a list edit. */
    fun mutate(change: (T) -> T) {
        val cur = value ?: return
        val next = change(cur)
        value = next
        key?.let { ScreenCache.put(it, next, serializer, disk) }
    }

    fun replace(new: T) {
        value = new; stale = false; error = null
        key?.let { ScreenCache.put(it, new, serializer, disk) }
    }
}

@Composable
inline fun <reified T> rememberRemote(
    key: String?,
    disk: Boolean = false,
    vararg reloadKeys: Any?,
    noinline fetch: suspend (MarqueeClient) -> T,
): Remote<T> {
    val session = LocalSession.current
    val scope = rememberCoroutineScope()
    val s = remember { serializer<T>() }
    val remote = remember(key) { Remote(key, s, session, scope, disk, fetch) }
    LaunchedEffect(remote, *reloadKeys) { remote.load(force = reloadKeys.isNotEmpty() && remote.value != null && !remote.stale) }
    return remote
}
