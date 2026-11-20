package dev.kadenthompson.marquee.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import dev.kadenthompson.marquee.model.Dashboard
import dev.kadenthompson.marquee.model.ReadingKind
import dev.kadenthompson.marquee.net.Http
import dev.kadenthompson.marquee.net.MarqueeClient
import dev.kadenthompson.marquee.net.MarqueeJson
import dev.kadenthompson.marquee.shortcuts.Shortcuts
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import okhttp3.Request
import java.io.File
import java.security.MessageDigest

@Serializable
data class WidgetShow(
    val id: Int, val title: String, val art: String? = null, val code: String? = null, val epTitle: String? = null,
    val season: Int? = null, val number: Int? = null, val watched: Int = 0, val aired: Int = 0,
)

@Serializable
data class WidgetRead(
    val kind: String, val id: Int, val title: String, val art: String? = null, val label: String = "",
    val fraction: Float? = null, val next: Int? = null, val subline: String? = null,
)

@Serializable
data class WidgetSnapshot(
    val paired: Boolean = false,
    val upNext: List<WidgetShow> = emptyList(),
    val reading: List<WidgetRead> = emptyList(),
    val waiting: Int = 0,
    val updatedAt: Long = 0,
)

/**
 * What the home-screen widgets and dynamic shortcuts show: a small snapshot written
 * whenever Home loads (and by the half-hourly refresh), with poster art downscaled to
 * files — RemoteViews can't fetch URLs, and bitmaps have to stay small.
 */
object WidgetData {
    private fun file(c: Context) = File(c.filesDir, "widget.json")
    private fun artDir(c: Context) = File(c.filesDir, "widget-art").apply { mkdirs() }

    fun read(c: Context): WidgetSnapshot =
        runCatching { MarqueeJson.decodeFromString(WidgetSnapshot.serializer(), file(c).readText()) }.getOrDefault(WidgetSnapshot())

    fun bitmap(path: String?): Bitmap? = path?.let { runCatching { BitmapFactory.decodeFile(it) }.getOrNull() }

    suspend fun publish(context: Context, d: Dashboard, client: MarqueeClient) = withContext(Dispatchers.IO) {
        val c = context.applicationContext
        val shows = (d.upNext + d.stale).filter { it.nextEp != null }.distinctBy { it.id }.take(6).map { s ->
            WidgetShow(s.id, s.displayTitle, art(c, client.absolute(s.poster)), s.nextEp?.code, s.nextEp?.title, s.nextEp?.season, s.nextEp?.number, s.watched, s.aired)
        }
        val reads = (d.reading ?: emptyList()).take(4).map { r ->
            val k = r.readingKind
            val total = r.total(k)
            val next = r.incrementedProgress(k).takeIf { r.supportsIncrement(k) && (total == null || it < total) }
            WidgetRead(k.path, r.id, r.displayTitle, art(c, client.absolute(r.cover)), r.progressLabel(k),
                total?.let { r.fraction(k) }, next, r.paceLine ?: if (k == ReadingKind.BOOK) r.author else r.origin)
        }
        val snap = WidgetSnapshot(true, shows, reads, (d.upNext + d.stale).distinctBy { it.id }.sumOf { it.remaining }, System.currentTimeMillis())
        file(c).writeText(MarqueeJson.encodeToString(WidgetSnapshot.serializer(), snap))
        prune(c, (shows.mapNotNull { it.art } + reads.mapNotNull { it.art }).toSet())
        updateAll(c)
        Shortcuts.publish(c, snap)
    }

    /** Unpaired: the widgets ask you to open the app, and the art goes with the token. */
    suspend fun clear(context: Context) = withContext(Dispatchers.IO) {
        val c = context.applicationContext
        file(c).writeText(MarqueeJson.encodeToString(WidgetSnapshot.serializer(), WidgetSnapshot()))
        artDir(c).listFiles()?.forEach { it.delete() }
        updateAll(c)
        Shortcuts.clear(c)
    }

    val Version = androidx.datastore.preferences.core.longPreferencesKey("snapshot_version")

    /** Bump each placed widget's state so a running Glance session re-reads the snapshot. */
    suspend fun updateAll(c: Context) {
        val mgr = androidx.glance.appwidget.GlanceAppWidgetManager(c)
        val stamp = System.currentTimeMillis()
        for (w in listOf(UpNextWidget(), WaitingWidget(), ReadingWidget())) runCatching {
            mgr.getGlanceIds(w.javaClass).forEach { id ->
                androidx.glance.appwidget.state.updateAppWidgetState(c, id) { it[Version] = stamp }
                w.update(c, id)
            }
        }
    }

    private fun art(c: Context, url: String?): String? {
        url ?: return null
        val name = MessageDigest.getInstance("SHA-1").digest(url.toByteArray()).joinToString("") { "%02x".format(it) } + ".png"
        val f = File(artDir(c), name)
        if (f.exists()) return f.path
        return runCatching {
            val bytes = Http.client.newCall(Request.Builder().url(url).build()).execute().use { it.body.bytes() }
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= 180) sample *= 2
            val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
            val scaled = if (bmp.width > 200) Bitmap.createScaledBitmap(bmp, 200, (200f * bmp.height / bmp.width).toInt(), true) else bmp
            f.outputStream().use { scaled.compress(Bitmap.CompressFormat.PNG, 90, it) }
            f.path
        }.getOrNull()
    }

    private fun prune(c: Context, keep: Set<String>) {
        artDir(c).listFiles()?.filter { it.path !in keep }?.forEach { it.delete() }
    }
}
