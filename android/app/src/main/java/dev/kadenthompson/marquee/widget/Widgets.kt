package dev.kadenthompson.marquee.widget

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalSize
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionParametersOf
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.LinearProgressIndicator
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import dev.kadenthompson.marquee.MainActivity
import dev.kadenthompson.marquee.R
import dev.kadenthompson.marquee.model.Dashboard
import dev.kadenthompson.marquee.model.MarkResponse
import dev.kadenthompson.marquee.notify.Background
import dev.kadenthompson.marquee.notify.RefreshWorker
import dev.kadenthompson.marquee.net.body
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

// Midnight Marquee, pinned dark: a widget sits on wallpaper, not the app's ground.
private val Ground = Color(0xFF0F0D0A)
private val Panel = Color(0xFF1F1A13)
private val Ink = Color(0xFFF2ECDF)
private val InkSoft = Color(0xFFB3A88F)
private val Muted = Color(0xFF7C7360)
private val Brass = Color(0xFFF0B544)
private val OnBrass = Color(0xFF221703)
private fun cp(c: Color) = ColorProvider(c)

private fun open(c: Context, link: String) = actionStartActivity(
    Intent(Intent.ACTION_VIEW, Uri.parse("marquee://$link"), c, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
)

private val ShowKey = ActionParameters.Key<Int>("show")
private val SeasonKey = ActionParameters.Key<Int>("season")
private val NumberKey = ActionParameters.Key<Int>("number")
private val KindKey = ActionParameters.Key<String>("kind")
private val ItemKey = ActionParameters.Key<Int>("item")
private val ProgressKey = ActionParameters.Key<Int>("progress")

/** The widget's punch: marks the episode without opening the app, then redraws from a fresh dashboard. */
class PunchAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val show = parameters[ShowKey] ?: return
        val season = parameters[SeasonKey] ?: return
        val number = parameters[NumberKey] ?: return
        val client = Background.client(context) ?: return
        val ok = runCatching { client.post<MarkResponse>("show/$show/watch", body("season" to season, "number" to number)) }.isSuccess
        withContext(Dispatchers.Main) { Toast.makeText(context, if (ok) "Marked S$season · E$number watched" else "Couldn't reach your Marquee server", Toast.LENGTH_SHORT).show() }
        runCatching { WidgetData.publish(context, client.get<Dashboard>("dashboard"), client) }.onFailure { RefreshWorker.now(context) }
    }
}

/** +1 chapter from the Reading widget. */
class IncrementAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val kind = parameters[KindKey] ?: return
        val item = parameters[ItemKey] ?: return
        val progress = parameters[ProgressKey] ?: return
        val client = Background.client(context) ?: return
        runCatching { client.send("$kind/$item/state", body("progress" to progress)) }
        runCatching { WidgetData.publish(context, client.get<Dashboard>("dashboard"), client) }.onFailure { RefreshWorker.now(context) }
    }
}

/** The snapshot, re-read whenever WidgetData bumps this widget's version. */
@Composable
private fun snapshot(c: Context): WidgetSnapshot {
    val v = androidx.glance.currentState(WidgetData.Version) ?: 0L
    return androidx.compose.runtime.remember(v) { WidgetData.read(c) }
}

@Composable
private fun Frame(content: @Composable () -> Unit) {
    Box(GlanceModifier.fillMaxSize().background(Ground).cornerRadius(20.dp).padding(12.dp)) { content() }
}

@Composable
private fun Label(text: String) = Text(text, style = TextStyle(color = cp(Brass), fontSize = 10.sp, fontWeight = FontWeight.Bold))

@Composable
private fun Face(title: String, line: String, link: String, c: Context) {
    Column(GlanceModifier.fillMaxSize().clickable(open(c, link)), verticalAlignment = Alignment.CenterVertically, horizontalAlignment = Alignment.Start) {
        Text("MARQUEE", style = TextStyle(color = cp(Brass), fontSize = 13.sp, fontWeight = FontWeight.Bold))
        Spacer(GlanceModifier.height(6.dp))
        Text(title, style = TextStyle(color = cp(Ink), fontSize = 15.sp, fontWeight = FontWeight.Bold))
        Text(line, style = TextStyle(color = cp(InkSoft), fontSize = 12.sp))
    }
}

@Composable
private fun Art(path: String?, w: Int, h: Int) {
    val bmp = WidgetData.bitmap(path)
    if (bmp != null) Image(ImageProvider(bmp), null, GlanceModifier.size(w.dp, h.dp).cornerRadius(8.dp), contentScale = ContentScale.Crop)
    else Box(GlanceModifier.size(w.dp, h.dp).background(Panel).cornerRadius(8.dp)) {}
}

// ---------------- Up Next

class UpNextWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(120.dp, 120.dp), DpSize(170.dp, 170.dp), DpSize(260.dp, 120.dp), DpSize(260.dp, 260.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent { Frame { UpNext(snapshot(context), context) } }
    }

    @Composable
    private fun UpNext(s: WidgetSnapshot, c: Context) {
        val size = LocalSize.current
        when {
            !s.paired -> Face("Not paired", "Open the app to pair with your server.", "next", c)
            s.upNext.isEmpty() -> Face("All caught up", "Nothing in the queue.", "next", c)
            size.height >= 240.dp || (size.height >= 165.dp && size.width < 250.dp) -> Column(GlanceModifier.fillMaxSize()) {
                Label("UP NEXT")
                Spacer(GlanceModifier.height(8.dp))
                s.upNext.take(if (size.height >= 240.dp) 4 else 2).forEach { Row(c, it); Spacer(GlanceModifier.height(8.dp)) }
            }
            size.width >= 250.dp -> Column(GlanceModifier.fillMaxSize()) {
                Label("UP NEXT")
                Spacer(GlanceModifier.height(6.dp))
                androidx.glance.layout.Row(GlanceModifier.fillMaxWidth()) {
                    s.upNext.take(3).forEachIndexed { i, sh -> if (i > 0) Spacer(GlanceModifier.width(8.dp)); Card(c, sh, GlanceModifier.defaultWeight()) }
                }
            }
            else -> Single(c, s.upNext.first())
        }
    }

    /** One show, filling a small widget: art beside the title, the punch under it. */
    @Composable
    private fun Single(c: Context, s: WidgetShow) {
        Column(GlanceModifier.fillMaxSize().clickable(open(c, "show/${s.id}"))) {
            androidx.glance.layout.Row(GlanceModifier.fillMaxWidth().defaultWeight()) {
                Art(s.art, 54, 81)
                Spacer(GlanceModifier.width(8.dp))
                Column(GlanceModifier.defaultWeight()) {
                    Label("UP NEXT")
                    Text(s.title, style = TextStyle(color = cp(Ink), fontSize = 13.sp, fontWeight = FontWeight.Bold), maxLines = 3)
                }
            }
            androidx.glance.layout.Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(GlanceModifier.defaultWeight()) {
                    Text(s.code ?: "", style = TextStyle(color = cp(Brass), fontSize = 12.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                    if (s.aired > 0) LinearProgressIndicator(s.watched.toFloat() / s.aired, GlanceModifier.fillMaxWidth().height(4.dp).padding(top = 3.dp), color = cp(Brass), backgroundColor = cp(Panel))
                }
                if (s.season != null && s.number != null) { Spacer(GlanceModifier.width(8.dp)); Punch(s, 36) }
            }
        }
    }

    @Composable
    private fun Card(c: Context, s: WidgetShow, modifier: GlanceModifier, big: Boolean = false) {
        Column(modifier.clickable(open(c, "show/${s.id}"))) {
            Box(contentAlignment = Alignment.TopEnd) {
                Art(s.art, if (big) 64 else 70, if (big) 96 else 72)
                if (s.season != null && s.number != null) Punch(s, 30)
            }
            Spacer(GlanceModifier.height(4.dp))
            Text(s.title, style = TextStyle(color = cp(Ink), fontSize = 12.sp, fontWeight = FontWeight.Bold), maxLines = 1)
            Text(s.code ?: "", style = TextStyle(color = cp(Brass), fontSize = 11.sp, fontWeight = FontWeight.Medium), maxLines = 1)
        }
    }

    @Composable
    private fun Row(c: Context, s: WidgetShow) {
        androidx.glance.layout.Row(GlanceModifier.fillMaxWidth().clickable(open(c, "show/${s.id}")), verticalAlignment = Alignment.CenterVertically) {
            Art(s.art, 36, 54)
            Spacer(GlanceModifier.width(10.dp))
            Column(GlanceModifier.defaultWeight()) {
                Text(s.title, style = TextStyle(color = cp(Ink), fontSize = 13.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                Text(listOfNotNull(s.code, s.epTitle).joinToString(" "), style = TextStyle(color = cp(Brass), fontSize = 11.sp), maxLines = 1)
                if (s.aired > 0) LinearProgressIndicator(s.watched.toFloat() / s.aired, GlanceModifier.fillMaxWidth().height(4.dp).padding(top = 3.dp), color = cp(Brass), backgroundColor = cp(Panel))
            }
            Spacer(GlanceModifier.width(8.dp))
            if (s.season != null && s.number != null) Punch(s, 34)
        }
    }

    @Composable
    private fun Punch(s: WidgetShow, d: Int) {
        Box(GlanceModifier.size(d.dp).background(Brass).cornerRadius((d / 2).dp)
            .clickable(actionRunCallback<PunchAction>(actionParametersOf(ShowKey to s.id, SeasonKey to s.season!!, NumberKey to s.number!!))),
            contentAlignment = Alignment.Center) {
            Image(ImageProvider(R.drawable.ic_widget_check), "Mark ${s.code} watched", GlanceModifier.size((d * 0.55f).dp))
        }
    }
}

class UpNextWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = UpNextWidget() }

// ---------------- Episodes waiting

class WaitingWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val s = snapshot(context)
            Frame {
                if (!s.paired) Face("Not paired", "Open the app to pair.", "next", context)
                else Column(GlanceModifier.fillMaxSize().clickable(open(context, "next")), verticalAlignment = Alignment.CenterVertically) {
                    Label("UP NEXT")
                    Text("${s.waiting}", style = TextStyle(color = cp(Brass), fontSize = 44.sp, fontWeight = FontWeight.Bold))
                    Text(if (s.waiting == 1) "episode waiting" else "episodes waiting", style = TextStyle(color = cp(InkSoft), fontSize = 12.sp))
                    s.upNext.firstOrNull()?.let { Text("Next: ${it.title}", style = TextStyle(color = cp(Muted), fontSize = 11.sp), maxLines = 1) }
                }
            }
        }
    }
}

class WaitingWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = WaitingWidget() }

// ---------------- Reading

class ReadingWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(setOf(DpSize(120.dp, 120.dp), DpSize(170.dp, 170.dp), DpSize(260.dp, 120.dp), DpSize(260.dp, 260.dp)))

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val s = snapshot(context)
            Frame {
                val size = LocalSize.current
                when {
                    !s.paired -> Face("Not paired", "Open the app to pair.", "next", context)
                    s.reading.isEmpty() -> Face("Nothing on the go", "Start something from your shelf.", "library/reading", context)
                    size.width < 250.dp && size.height < 165.dp -> Big(context, s.reading.first())
                    else -> Column(GlanceModifier.fillMaxSize()) {
                        Label("READING")
                        Spacer(GlanceModifier.height(6.dp))
                        s.reading.take(if (size.height >= 240.dp) 4 else 2).forEach { ReadRow(context, it); Spacer(GlanceModifier.height(8.dp)) }
                    }
                }
            }
        }
    }

    @Composable
    private fun Big(c: Context, r: WidgetRead) {
        Column(GlanceModifier.fillMaxSize().clickable(open(c, "${r.kind}/${r.id}"))) {
            Row(verticalAlignment = Alignment.Top) {
                Art(r.art, 52, 78)
                Spacer(GlanceModifier.width(8.dp))
                Column(GlanceModifier.defaultWeight()) {
                    Label(if (r.kind == "book") "BOOK" else "MANGA")
                    Text(r.title, style = TextStyle(color = cp(Ink), fontSize = 13.sp, fontWeight = FontWeight.Bold), maxLines = 3)
                }
            }
            Spacer(GlanceModifier.defaultWeight())
            Text(r.label, style = TextStyle(color = cp(Brass), fontSize = 12.sp, fontWeight = FontWeight.Bold))
            r.fraction?.let { LinearProgressIndicator(it, GlanceModifier.fillMaxWidth().height(5.dp), color = cp(Brass), backgroundColor = cp(Panel)) }
        }
    }

    @Composable
    private fun ReadRow(c: Context, r: WidgetRead) {
        Row(GlanceModifier.fillMaxWidth().clickable(open(c, "${r.kind}/${r.id}")), verticalAlignment = Alignment.CenterVertically) {
            Art(r.art, 34, 50)
            Spacer(GlanceModifier.width(10.dp))
            Column(GlanceModifier.defaultWeight()) {
                Text(r.title, style = TextStyle(color = cp(Ink), fontSize = 13.sp, fontWeight = FontWeight.Bold), maxLines = 1)
                Text(listOfNotNull(r.label, r.subline).joinToString(" · "), style = TextStyle(color = cp(InkSoft), fontSize = 11.sp), maxLines = 1)
                r.fraction?.let { LinearProgressIndicator(it, GlanceModifier.fillMaxWidth().height(4.dp).padding(top = 3.dp), color = cp(Brass), backgroundColor = cp(Panel)) }
            }
            r.next?.let { n ->
                Spacer(GlanceModifier.width(8.dp))
                Box(GlanceModifier.size(32.dp).background(Brass).cornerRadius(16.dp)
                    .clickable(actionRunCallback<IncrementAction>(actionParametersOf(KindKey to r.kind, ItemKey to r.id, ProgressKey to n))), contentAlignment = Alignment.Center) {
                    Text("+1", style = TextStyle(color = cp(OnBrass), fontSize = 12.sp, fontWeight = FontWeight.Bold))
                }
            }
        }
    }
}

class ReadingWidgetReceiver : GlanceAppWidgetReceiver() { override val glanceAppWidget: GlanceAppWidget = ReadingWidget() }
