package dev.kadenthompson.marquee.features.you

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.ChipRow
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.notify.Notifier
import dev.kadenthompson.marquee.notify.NotifyPrefs
import dev.kadenthompson.marquee.notify.PushSetup
import dev.kadenthompson.marquee.session.LocalSession
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

@Serializable private data class PushTest(val ok: Boolean? = null, val reason: String? = null, val devices: Int? = null)

/**
 * Settings › Notifications on this device. Push through a UnifiedPush distributor
 * (ntfy and friends) when one's installed — real time, straight from the server's Web
 * Push — otherwise the app checks the inbox every half hour in the background.
 */
@Composable
fun DeviceNotificationsGroup() {
    val session = LocalSession.current
    val ctx = LocalContext.current
    val activity = ctx as? Activity
    val scope = rememberCoroutineScope()
    val uri = LocalUriHandler.current
    var mode by remember { mutableStateOf(NotifyPrefs.mode(ctx)) }
    var permitted by remember { mutableStateOf(Notifier.permitted(ctx)) }
    var note by remember { mutableStateOf<String?>(null) }
    val distributors = remember(mode) { PushSetup.distributors(ctx) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { mode = NotifyPrefs.mode(ctx); permitted = Notifier.permitted(ctx) }

    fun turnOn(preferPush: Boolean) {
        val a = activity ?: return
        scope.launch { PushSetup.enable(a, preferPush) { m -> mode = m; note = null } }
    }
    val askPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        permitted = granted
        if (granted) turnOn(true) else note = "Android is holding notifications for Marquee. Allow them in system settings to turn this on."
    }
    fun start(preferPush: Boolean = true) {
        if (Build.VERSION.SDK_INT >= 33 && !Notifier.permitted(ctx)) askPermission.launch(Manifest.permission.POST_NOTIFICATIONS) else turnOn(preferPush)
    }

    SettingsGroup("Notifications on this device", when (mode) {
        NotifyPrefs.PUSH -> "The server's notifications arrive the moment they're sent. Choose what you hear about below."
        NotifyPrefs.POLL -> if (distributors.isEmpty()) "Install a UnifiedPush distributor such as ntfy for instant delivery; until then Marquee checks every half hour." else "Checks every half hour. Switch to push for instant delivery."
        else -> "Premieres, new episodes, finished downloads and the household, as Android notifications."
    }) {
        val status = when {
            mode != NotifyPrefs.OFF && !permitted -> "Blocked in system settings"
            mode == NotifyPrefs.PUSH -> "Push via ${PushSetup.distributorLabel(ctx) ?: "UnifiedPush"}"
            mode == NotifyPrefs.POLL -> "Checking every 30 minutes"
            else -> "Off"
        }
        ToggleRow("Notifications", status, mode != NotifyPrefs.OFF) { on ->
            if (on) start() else scope.launch { PushSetup.disable(ctx); mode = NotifyPrefs.OFF }
        }
        if (mode != NotifyPrefs.OFF) ChipRow {
            if (mode == NotifyPrefs.POLL && distributors.isNotEmpty()) ChipButton("Use push", Icons.Filled.NotificationsActive, on = true) { start(true) }
            if (mode == NotifyPrefs.POLL && distributors.isEmpty()) ChipButton("Get ntfy") { runCatching { uri.openUri("https://unifiedpush.org/users/distributors/") } }
            if (mode == NotifyPrefs.PUSH) ChipButton("Send a test") {
                scope.launch {
                    val r = runCatching { session.client?.post<PushTest>("push/test") }.getOrNull()
                    note = when { r?.ok == true -> "Sent — it should arrive in a moment."; r?.reason == "no_device" -> "The server hasn't registered this device yet. Try again in a minute."; else -> "Couldn't send a test." }
                }
            }
            if (!permitted) ChipButton("System settings", Icons.Filled.NotificationsOff) {
                ctx.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        }
        note?.let { Text(it, style = T.caption, color = C.inkSoft) }
    }
}


/** Settings › Home screen: pin a widget through the launcher's own "Add to home screen" sheet. */
@Composable
fun HomeScreenGroup() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val mgr = remember { androidx.glance.appwidget.GlanceAppWidgetManager(ctx) }
    SettingsGroup("Home screen", "Widgets refresh when Home loads and every half hour; their buttons work without opening the app. Long-press the app icon for shortcuts.") {
        ChipRow {
            ChipButton("Up Next widget") { scope.launch { runCatching { mgr.requestPinGlanceAppWidget(dev.kadenthompson.marquee.widget.UpNextWidgetReceiver::class.java) } } }
            ChipButton("Episodes waiting") { scope.launch { runCatching { mgr.requestPinGlanceAppWidget(dev.kadenthompson.marquee.widget.WaitingWidgetReceiver::class.java) } } }
            ChipButton("Reading widget") { scope.launch { runCatching { mgr.requestPinGlanceAppWidget(dev.kadenthompson.marquee.widget.ReadingWidgetReceiver::class.java) } } }
        }
    }
}
