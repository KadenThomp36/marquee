package dev.kadenthompson.marquee.notify

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.edit
import dev.kadenthompson.marquee.MainActivity
import dev.kadenthompson.marquee.R
import dev.kadenthompson.marquee.net.MarqueeClient
import dev.kadenthompson.marquee.net.Vault

/** A client for work done outside the UI — workers, push, widgets, shortcuts — straight from the vault. */
object Background {
    suspend fun client(context: Context): MarqueeClient? = Vault(context.applicationContext).load()?.let { MarqueeClient(it) }
}

/** How this device hears about Marquee notifications. */
object NotifyPrefs {
    const val OFF = "off"
    /** A WorkManager job checks the inbox every 30 minutes — works with nothing else installed. */
    const val POLL = "poll"
    /** UnifiedPush: the server's Web Push lands through a distributor such as ntfy, in real time. */
    const val PUSH = "push"

    private fun sp(c: Context) = c.applicationContext.getSharedPreferences("notify", Context.MODE_PRIVATE)
    fun mode(c: Context) = sp(c).getString("mode", OFF) ?: OFF
    fun setMode(c: Context, m: String) = sp(c).edit { putString("mode", m) }
    fun lastId(c: Context) = sp(c).getInt("last_id", -1)
    fun setLastId(c: Context, id: Int) = sp(c).edit { putInt("last_id", id) }
    fun endpoint(c: Context) = sp(c).getString("endpoint", null)
    fun setEndpoint(c: Context, e: String?) = sp(c).edit { if (e == null) remove("endpoint") else putString("endpoint", e) }
    fun clear(c: Context) = sp(c).edit { clear() }
}

object Notifier {
    const val CHANNEL = "inbox"

    fun createChannels(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Marquee", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Premieres, new episodes, finished downloads and the household"
        })
    }

    fun permitted(context: Context): Boolean =
        (Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            NotificationManagerCompat.from(context).areNotificationsEnabled()

    /** `link` is a web hash route ("show/1396"); tapping opens it in the app. */
    fun show(context: Context, id: Int, title: String, body: String?, link: String?) {
        if (!permitted(context)) return
        val uri = link?.trim('#', '/', ' ')?.takeIf { it.isNotEmpty() }?.let { Uri.parse("marquee://$it") }
        val open = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = uri ?: Uri.parse("marquee://inbox")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pi = PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_marquee)
            .setColor(0xFFF0B544.toInt())
            .setContentTitle(title)
            .apply { if (!body.isNullOrBlank()) setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body)) }
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try { NotificationManagerCompat.from(context).notify(id, n) } catch (_: SecurityException) {}
    }
}
