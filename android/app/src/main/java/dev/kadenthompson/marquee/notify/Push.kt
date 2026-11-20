package dev.kadenthompson.marquee.notify

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import dev.kadenthompson.marquee.net.MarqueeJson
import dev.kadenthompson.marquee.net.body
import kotlinx.serialization.Serializable
import org.unifiedpush.android.connector.FailedReason
import org.unifiedpush.android.connector.PushService
import org.unifiedpush.android.connector.UnifiedPush
import org.unifiedpush.android.connector.data.PushEndpoint
import org.unifiedpush.android.connector.data.PushMessage

@Serializable data class PushKey(val enabled: Boolean = false, val key: String? = null)
@Serializable private data class PushPayload(val title: String = "Marquee", val body: String? = null, val link: String? = null)

/**
 * Receives UnifiedPush events. The server already sends standard Web Push (VAPID,
 * aes128gcm) to every subscription it holds — a UnifiedPush endpoint is just another
 * one — and the connector decrypts it here with the keys it generated.
 */
class MarqueePushService : PushService() {
    override fun onNewEndpoint(endpoint: PushEndpoint, instance: String) {
        val keys = endpoint.pubKeySet
        if (keys == null) { NotifyPrefs.setMode(this, NotifyPrefs.POLL); RefreshWorker.schedule(this); return }
        SubscribeWorker.enqueue(this, endpoint.url, keys.pubKey, keys.auth)
    }

    override fun onMessage(message: PushMessage, instance: String) {
        if (!message.decrypted) return
        val p = runCatching { MarqueeJson.decodeFromString(PushPayload.serializer(), message.content.decodeToString()) }.getOrNull() ?: return
        Notifier.show(this, (System.currentTimeMillis() % 1_000_000).toInt(), p.title, p.body, p.link)
        // Something changed server-side (a Plex mark, a download): bring the widgets up to date.
        RefreshWorker.now(this)
    }

    override fun onRegistrationFailed(reason: FailedReason, instance: String) {
        NotifyPrefs.setMode(this, NotifyPrefs.POLL); RefreshWorker.schedule(this)
    }

    override fun onUnregistered(instance: String) {
        if (NotifyPrefs.mode(this) == NotifyPrefs.PUSH) NotifyPrefs.setMode(this, NotifyPrefs.POLL)
        NotifyPrefs.setEndpoint(this, null)
    }
}

object PushSetup {
    fun distributors(context: Context): List<String> = runCatching { UnifiedPush.getDistributors(context) }.getOrDefault(emptyList())

    fun distributorLabel(context: Context): String? {
        val pkg = runCatching { UnifiedPush.getAckDistributor(context) }.getOrNull() ?: return null
        return runCatching { context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(pkg, 0)).toString() }
            .getOrElse { if (it is PackageManager.NameNotFoundException) pkg else pkg }
    }

    /**
     * Turn notifications on. Prefers push through a UnifiedPush distributor (asking which,
     * if there are several); with none installed it falls back to checking the inbox
     * every half hour. Calls back with the mode it ended up in.
     */
    suspend fun enable(activity: Activity, preferPush: Boolean = true, done: (String) -> Unit) {
        val client = Background.client(activity) ?: return
        // Baseline the inbox so the first poll doesn't replay old items.
        runCatching { client.get<dev.kadenthompson.marquee.model.NotificationsResponse>("notifications") }.getOrNull()
            ?.let { r -> NotifyPrefs.setLastId(activity, r.items.maxOfOrNull { it.id } ?: 0) }
        NotifyPrefs.setMode(activity, NotifyPrefs.POLL)
        RefreshWorker.schedule(activity)
        val key = runCatching { client.get<PushKey>("push/pubkey") }.getOrNull()
        if (!preferPush || key?.enabled != true || key.key.isNullOrEmpty() || distributors(activity).isEmpty()) { done(NotifyPrefs.POLL); return }
        UnifiedPush.tryUseCurrentOrDefaultDistributor(activity) { ok ->
            if (ok) {
                runCatching { UnifiedPush.register(activity, vapid = key.key) }
                done(NotifyPrefs.PUSH)
            } else done(NotifyPrefs.POLL)
        }
    }

    /** Off: tell the server to forget the endpoint, unregister, stop polling. */
    suspend fun disable(context: Context) {
        NotifyPrefs.endpoint(context)?.let { ep -> runCatching { Background.client(context)?.send("push/unsubscribe", body("endpoint" to ep)) } }
        runCatching { UnifiedPush.unregister(context) }
        NotifyPrefs.setEndpoint(context, null)
        NotifyPrefs.setMode(context, NotifyPrefs.OFF)
    }
}
