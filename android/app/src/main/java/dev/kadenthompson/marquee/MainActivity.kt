package dev.kadenthompson.marquee

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import dev.kadenthompson.marquee.design.MarqueeTheme
import dev.kadenthompson.marquee.nav.Navigator
import dev.kadenthompson.marquee.session.LocalSession

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val session = (application as MarqueeApp).session
        enableEdgeToEdge(SystemBarStyle.dark(android.graphics.Color.TRANSPARENT), SystemBarStyle.dark(android.graphics.Color.TRANSPARENT))
        handle(intent)
        setContent {
            CompositionLocalProvider(LocalSession provides session) {
                MarqueeTheme(session.prefs.appearance) { RootView() }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent?) {
        val uri = intent?.data ?: return
        Navigator.route(uri)?.let(Navigator::open)
    }
}
