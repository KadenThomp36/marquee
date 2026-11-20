package dev.kadenthompson.marquee.shortcuts

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import dev.kadenthompson.marquee.MainActivity
import dev.kadenthompson.marquee.R
import dev.kadenthompson.marquee.widget.WidgetSnapshot

/**
 * Launcher shortcuts — the Android side of iOS's App Intents. Static ones (Up Next,
 * Search) live in res/xml/shortcuts.xml; these dynamic ones follow your queue:
 * "Mark S2 · E5 of The Bear" for the top shows, and "Start reading …" for what's on the go.
 */
object Shortcuts {
    const val ACTION_MARK = "dev.kadenthompson.marquee.action.MARK_NEXT"
    const val ACTION_READ = "dev.kadenthompson.marquee.action.START_SESSION"

    fun publish(context: Context, s: WidgetSnapshot) {
        val max = ShortcutManagerCompat.getMaxShortcutCountPerActivity(context).coerceAtMost(5) - 2 // leave room for the static two
        val list = mutableListOf<ShortcutInfoCompat>()
        s.upNext.filter { it.season != null && it.number != null }.take(2).forEachIndexed { i, sh ->
            list += ShortcutInfoCompat.Builder(context, "mark-${sh.id}")
                .setShortLabel(trim("${sh.code?.replace(" · ", "")} ${sh.title}", 24))
                .setLongLabel(trim("Mark ${sh.code} of ${sh.title} watched", 40))
                .setIcon(IconCompat.createWithResource(context, R.drawable.ic_shortcut_check))
                .setIntent(Intent(context, ActionActivity::class.java).setAction(ACTION_MARK)
                    .putExtra("show", sh.id).putExtra("season", sh.season!!).putExtra("number", sh.number!!).putExtra("title", sh.title))
                .setRank(if (i == 0) 0 else 2).build()
        }
        s.reading.firstOrNull()?.let { r ->
            list += ShortcutInfoCompat.Builder(context, "read-${r.kind}-${r.id}")
                .setShortLabel(trim("Read ${r.title}", 24))
                .setLongLabel(trim("Start a reading session: ${r.title}", 40))
                .setIcon(IconCompat.createWithResource(context, R.drawable.ic_shortcut_reading))
                .setIntent(Intent(context, ActionActivity::class.java).setAction(ACTION_READ)
                    .putExtra("kind", r.kind).putExtra("item", r.id).putExtra("title", r.title))
                .setRank(1).build()
        }
        // Launchers show about four in all: the two static ones, the top show, then what you're reading.
        runCatching { ShortcutManagerCompat.setDynamicShortcuts(context, list.sortedBy { it.rank }.take(maxOf(1, max))) }
    }

    fun clear(context: Context) { runCatching { ShortcutManagerCompat.removeAllDynamicShortcuts(context) } }

    fun reportUsed(context: Context, id: String) { runCatching { ShortcutManagerCompat.reportShortcutUsed(context, id) } }

    fun openIntent(context: Context, link: String) = Intent(Intent.ACTION_VIEW, Uri.parse("marquee://$link"), context, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)

    private fun trim(s: String, n: Int) = if (s.length <= n) s else s.take(n - 1) + "…"
}
