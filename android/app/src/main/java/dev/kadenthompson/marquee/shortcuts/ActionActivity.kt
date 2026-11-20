package dev.kadenthompson.marquee.shortcuts

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import dev.kadenthompson.marquee.model.MarkResponse
import dev.kadenthompson.marquee.model.SessionStartResponse
import dev.kadenthompson.marquee.notify.Background
import dev.kadenthompson.marquee.notify.Notifier
import dev.kadenthompson.marquee.notify.RefreshWorker
import dev.kadenthompson.marquee.net.ApiError
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.net.friendly
import kotlinx.coroutines.launch

/**
 * Runs a shortcut's action without bringing the app up — mark the next episode, start
 * a reading session — then says so in a toast and finishes. Invisible.
 */
class ActionActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val i = intent
        lifecycleScope.launch {
            val client = Background.client(this@ActionActivity)
            if (client == null) { startActivity(Shortcuts.openIntent(this@ActionActivity, "next")); finish(); return@launch }
            val message = when (i?.action) {
                Shortcuts.ACTION_MARK -> {
                    val show = i.getIntExtra("show", 0); val s = i.getIntExtra("season", 0); val n = i.getIntExtra("number", 0)
                    Shortcuts.reportUsed(this@ActionActivity, "mark-$show")
                    try {
                        val r: MarkResponse = client.post("show/$show/watch", body("season" to s, "number" to n))
                        // A season finished from a shortcut still gets its moment, next time the app opens.
                        r.celebrate?.firstOrNull()?.let { c -> Notifier.show(this@ActionActivity, 20_000 + c.id, if (c.isSeries) "That's a wrap" else "Season complete", c.show.displayTitle, "show/${c.show.id}") }
                        "Marked S$s · E$n of ${i.getStringExtra("title") ?: "the show"} watched"
                    } catch (e: Exception) { "Couldn't mark it: ${e.friendly}" }
                }
                Shortcuts.ACTION_READ -> {
                    val kind = i.getStringExtra("kind") ?: "book"; val id = i.getIntExtra("item", 0)
                    Shortcuts.reportUsed(this@ActionActivity, "read-$kind-$id")
                    try {
                        client.post<SessionStartResponse>("$kind/$id/session/start")
                        "Reading session started: ${i.getStringExtra("title") ?: ""}"
                    } catch (e: ApiError.Http) { if (e.status == 409) "A session is already running" else "Couldn't start it: ${e.friendly}" }
                    catch (e: Exception) { "Couldn't start it: ${e.friendly}" }
                }
                else -> null
            }
            message?.let { Toast.makeText(applicationContext, it, Toast.LENGTH_SHORT).show() }
            RefreshWorker.now(applicationContext)
            finish()
        }
    }
}
