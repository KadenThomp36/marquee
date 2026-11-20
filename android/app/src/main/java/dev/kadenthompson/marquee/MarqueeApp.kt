package dev.kadenthompson.marquee

import android.app.Application
import dev.kadenthompson.marquee.session.ScreenCache
import dev.kadenthompson.marquee.session.Session

class MarqueeApp : Application() {
    lateinit var session: Session
        private set

    override fun onCreate() {
        super.onCreate()
        ScreenCache.init(this)
        dev.kadenthompson.marquee.notify.Notifier.createChannels(this)
        session = Session(this)
    }
}
