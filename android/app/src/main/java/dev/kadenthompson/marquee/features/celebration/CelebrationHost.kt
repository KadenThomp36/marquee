package dev.kadenthompson.marquee.features.celebration

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.design.ChipButton
import dev.kadenthompson.marquee.design.MqColors
import dev.kadenthompson.marquee.design.Poster
import dev.kadenthompson.marquee.design.PrimaryButton
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.model.Celebration
import dev.kadenthompson.marquee.nav.Navigator
import dev.kadenthompson.marquee.nav.ShowRoute
import dev.kadenthompson.marquee.session.LocalSession
import kotlin.random.Random

private fun ordinal(n: Int): String {
    val s = if (n % 100 in 11..13) "th" else when (n % 10) { 1 -> "st"; 2 -> "nd"; 3 -> "rd"; else -> "th" }
    return "$n$s"
}

/**
 * Finishing a season or a whole series: marquee bulbs, spotlight rays, a foil COMPLETE
 * stamp slammed over the poster, confetti, run stats. A series finale gets red velvet.
 * One at a time, from the session's queue (banked server-side, so overnight Plex
 * completions celebrate on next launch).
 */
@Composable
fun CelebrationHost() {
    val session = LocalSession.current
    val current = session.celebrationQueue.firstOrNull()
    AnimatedVisibility(current != null, enter = fadeIn(tween(300)), exit = fadeOut(tween(250))) {
        current?.let { Fanfare(it, onDone = { session.finishCelebration(it) }, onSee = { session.finishCelebration(it); Navigator.open(ShowRoute(it.show.id)) }) }
    }
}

@Composable
private fun Fanfare(c: Celebration, onDone: () -> Unit, onSee: () -> Unit) {
    val haptic = LocalHapticFeedback.current
    val series = c.isSeries
    val ground = if (series) Color(0xFF3A0B12) else Color(0xFF0F0D0A)
    val gel = if (series) Color(0xFFE05C5C) else MqColors.brassOnArt
    val stamp = remember(c.id) { Animatable(2.4f) }
    val stampAlpha = remember(c.id) { Animatable(0f) }
    val shake = remember(c.id) { Animatable(0f) }
    LaunchedEffect(c.id) {
        kotlinx.coroutines.delay(500)
        stampAlpha.animateTo(1f, tween(120))
        stamp.animateTo(1f, spring(0.5f, 900f))
        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
        repeat(3) { shake.animateTo(6f, tween(40)); shake.animateTo(-6f, tween(40)) }
        shake.animateTo(0f, tween(40))
    }
    val t = rememberInfiniteTransition(label = "f")
    val rays by t.animateFloat(0f, 360f, infiniteRepeatable(tween(24000, easing = LinearEasing)), label = "rays")
    val chase by t.animateFloat(0f, 1f, infiniteRepeatable(tween(1400, easing = LinearEasing)), label = "chase")
    val fall by t.animateFloat(0f, 1f, infiniteRepeatable(tween(4200, easing = LinearEasing), RepeatMode.Restart), label = "fall")
    val confetti = remember(c.id) { List(70) { Triple(Random.nextFloat(), Random.nextFloat(), Random.nextInt(5)) } }
    val colors = listOf(Color(0xFFF0B544), Color(0xFFFFD98A), Color(0xFFE05C5C), Color(0xFF8F7FE8), Color(0xFF17A377))

    Box(Modifier.fillMaxSize().background(ground).clickable(remember { MutableInteractionSource() }, null) {}) {
        Canvas(Modifier.fillMaxSize()) {
            // spotlight rays
            val center = Offset(size.width / 2, size.height * 0.38f)
            for (i in 0 until 12) {
                val a = Math.toRadians((rays + i * 30).toDouble())
                val end = Offset(center.x + (size.maxDimension * Math.cos(a)).toFloat(), center.y + (size.maxDimension * Math.sin(a)).toFloat())
                drawLine(Brush.linearGradient(listOf(gel.copy(alpha = 0.16f), Color.Transparent), center, end), center, end, strokeWidth = 70f)
            }
            // bulbs around the frame, chasing
            val n = 22; val m = 12f
            for (i in 0 until n) {
                val lit = ((i / n.toFloat() + chase) % 1f) < 0.33f
                val x = m + i * (size.width - 2 * m) / (n - 1)
                drawCircle(if (lit) Color(0xFFFFD98A) else Color(0x55FFD98A), 6f, Offset(x, m + 24f))
                drawCircle(if (!lit) Color(0xFFFFD98A) else Color(0x55FFD98A), 6f, Offset(x, size.height - m - 24f))
            }
            // confetti
            confetti.forEach { (x, off, ci) ->
                val y = ((off + fall) % 1f) * size.height
                drawRect(colors[ci], Offset(x * size.width, y), Size(10f, 16f), alpha = 0.85f)
            }
        }
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp, Alignment.CenterVertically)) {
            Text(if (series) "THAT'S A WRAP" else "SEASON COMPLETE", style = T.wordmark(28f), color = gel, textAlign = TextAlign.Center)
            Box(contentAlignment = Alignment.Center, modifier = Modifier.graphicsLayer { translationX = shake.value }) {
                Poster(c.show.poster, Modifier.width(190.dp), radius = 14.dp)
                Column(Modifier.alpha(stampAlpha.value).scale(stamp.value).rotate(-12f).clip(RoundedCornerShape(8.dp))
                    .background(Brush.linearGradient(listOf(Color(0xFFFFE4A3), Color(0xFFD9A43A), Color(0xFFFFE4A3)))).border(3.dp, Color(0xFF6B4A0E), RoundedCornerShape(8.dp))
                    .padding(horizontal = 16.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(if (series) "SERIES" else "SEASON", style = T.body(12f, 800), color = Color(0xFF3A2606))
                    Text("COMPLETE", style = T.wordmark(30f), color = Color(0xFF2A1A04))
                }
            }
            Text(c.show.displayTitle, style = T.body(24f, 800), color = MqColors.inkOnArt, textAlign = TextAlign.Center)
            Text(if (series) "Every season, start to finish." else (c.seasonName ?: "Season ${c.season}"), style = T.sub, color = MqColors.inkSoftOnArt)
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                listOfNotNull("${c.episodes}" to "episodes", (c.minutes / 60).takeIf { it > 0 }?.let { "$it" to "hours" }, c.days?.let { "$it" to if (it == 1) "day" else "days" }, if (series) "${c.seasons}" to "seasons" else null).forEach { (v, l) ->
                    Column(Modifier.clip(RoundedCornerShape(11.dp)).background(Color.White.copy(alpha = 0.07f)).padding(horizontal = 14.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(v, style = T.body(20f, 800), color = gel); Text(l, style = T.caption, color = MqColors.inkSoftOnArt)
                    }
                }
            }
            if (c.nthThisYear > 0) Text("your ${ordinal(c.nthThisYear)} ${if (series) "series" else "season"} finished in ${c.year}", style = T.caption, color = MqColors.inkSoftOnArt)
            PrimaryButton("Take a bow", onDone, Modifier.width(240.dp))
            ChipButton("See the show", onClick = onSee)
        }
    }
}
