package dev.kadenthompson.marquee

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.features.celebration.CelebrationHost
import dev.kadenthompson.marquee.features.pairing.PairingScreen
import dev.kadenthompson.marquee.nav.MainShell
import dev.kadenthompson.marquee.session.LocalSession
import dev.kadenthompson.marquee.session.Session
import kotlinx.coroutines.launch

/** Decides which of the app's three states you're in, and hosts the completion fanfare over all of them. */
@Composable
fun RootView() {
    val session = LocalSession.current
    LaunchedEffect(Unit) { if (session.phase == Session.Phase.STARTING) session.start() }
    LaunchedEffect(session.phase) {
        if (session.phase != Session.Phase.READY) return@LaunchedEffect
        session.refreshListMembership()
        session.loadRequestConfig()
        session.loadBookRequestConfig()
        session.checkCelebrations()
    }
    // Plex may have finished a season for you while you were away.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) {
        if (session.phase == Session.Phase.READY) session.scope.launch { session.checkCelebrations() }
    }
    Box(Modifier.fillMaxSize().background(C.ground)) {
        Crossfade(session.phase, label = "phase") { phase ->
            when (phase) {
                Session.Phase.STARTING -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text("MARQUEE", style = T.wordmark(34f), color = C.brass)
                }
                Session.Phase.UNPAIRED -> PairingScreen()
                Session.Phase.READY -> MainShell()
            }
        }
        CelebrationHost()
    }
}
