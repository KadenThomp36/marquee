package dev.kadenthompson.marquee.notify

import android.content.Context
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import dev.kadenthompson.marquee.model.Dashboard
import dev.kadenthompson.marquee.model.NotificationsResponse
import dev.kadenthompson.marquee.net.ApiError
import dev.kadenthompson.marquee.net.body
import dev.kadenthompson.marquee.widget.WidgetData
import java.util.concurrent.TimeUnit

/**
 * Every half hour, on any network: refresh the widgets and shortcuts from the
 * dashboard, and — when this device isn't on push — post any new inbox items as
 * notifications. The Android side of iOS's background refresh.
 */
class RefreshWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val client = Background.client(ctx) ?: return Result.success()
        try {
            client.get<Dashboard>("dashboard").let { WidgetData.publish(ctx, it, client) }
        } catch (e: ApiError.Unauthorized) {
            WidgetData.clear(ctx); return Result.success()
        } catch (_: Exception) {}
        if (!inputData.getBoolean(WIDGETS_ONLY, false) && NotifyPrefs.mode(ctx) == NotifyPrefs.POLL) checkInbox(ctx, client)
        return Result.success()
    }

    private suspend fun checkInbox(ctx: Context, client: dev.kadenthompson.marquee.net.MarqueeClient) {
        val inbox = runCatching { client.get<NotificationsResponse>("notifications") }.getOrNull() ?: return
        val last = NotifyPrefs.lastId(ctx)
        val maxId = inbox.items.maxOfOrNull { it.id } ?: last
        // The first check only sets the baseline, so turning this on doesn't replay the backlog.
        if (last >= 0) inbox.items.filter { it.id > last && it.read != true }.sortedBy { it.id }.takeLast(5)
            .forEach { Notifier.show(ctx, 10_000 + it.id, it.title, it.body, it.link) }
        NotifyPrefs.setLastId(ctx, maxOf(last, maxId))
    }

    companion object {
        const val WIDGETS_ONLY = "widgets_only"
        private const val PERIODIC = "marquee-refresh"
        private const val NOW = "marquee-refresh-now"

        fun schedule(context: Context) {
            val req = PeriodicWorkRequestBuilder<RefreshWorker>(30, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(PERIODIC, ExistingPeriodicWorkPolicy.KEEP, req)
        }

        /** Refresh widgets and shortcuts now (after a push, a widget punch, a shortcut). */
        fun now(context: Context, widgetsOnly: Boolean = true) {
            val req = OneTimeWorkRequestBuilder<RefreshWorker>().setInputData(workDataOf(WIDGETS_ONLY to widgetsOnly))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
            WorkManager.getInstance(context).enqueueUniqueWork(NOW, ExistingWorkPolicy.REPLACE, req)
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(PERIODIC)
            WorkManager.getInstance(context).cancelUniqueWork(NOW)
        }
    }
}

/** Hands a fresh UnifiedPush endpoint to the server's `/api/push/subscribe`, retrying until it lands. */
class SubscribeWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val ctx = applicationContext
        val endpoint = inputData.getString("endpoint") ?: return Result.failure()
        val client = Background.client(ctx) ?: return Result.failure()
        return try {
            client.send("push/subscribe", body("endpoint" to endpoint, "keys" to mapOf("p256dh" to inputData.getString("p256dh"), "auth" to inputData.getString("auth"))))
            NotifyPrefs.setEndpoint(ctx, endpoint); NotifyPrefs.setMode(ctx, NotifyPrefs.PUSH)
            Result.success()
        } catch (e: ApiError) { if (e.isTransient) Result.retry() else Result.failure() }
    }

    companion object {
        fun enqueue(context: Context, endpoint: String, p256dh: String, auth: String) {
            val req = OneTimeWorkRequestBuilder<SubscribeWorker>()
                .setInputData(workDataOf("endpoint" to endpoint, "p256dh" to p256dh, "auth" to auth))
                .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).build()
            WorkManager.getInstance(context).enqueueUniqueWork("marquee-push-subscribe", ExistingWorkPolicy.REPLACE, req)
        }
    }
}
