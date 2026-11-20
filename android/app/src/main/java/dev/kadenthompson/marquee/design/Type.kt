package dev.kadenthompson.marquee.design

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import dev.kadenthompson.marquee.R

/** Limelight: the wordmark and the big moments only. It's all caps and decorative. */
val Limelight = FontFamily(Font(R.font.limelight))

/** Archivo, a variable face — one file, every weight. */
val Archivo = FontFamily(
    listOf(400, 500, 600, 700, 800, 900).map { w ->
        Font(R.font.archivo, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))
    }
)

private fun archivo(size: Float, weight: Int, tracking: TextUnit = 0.sp, line: Float = 1.25f) = TextStyle(
    fontFamily = Archivo,
    fontWeight = FontWeight(weight),
    fontSize = size.sp,
    letterSpacing = tracking,
    lineHeight = (size * line).sp,
    lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
)

/** The type scale — the iOS app's, point for point. Sizes scale with the system font size. */
object T {
    val title = archivo(26f, 700, line = 1.15f)
    val headline = archivo(17f, 700)
    val tile = archivo(13f, 600)
    val body = archivo(15f, 400, line = 1.4f)
    val sub = archivo(13f, 500)
    val caption = archivo(12f, 500)
    val eyebrow = archivo(11f, 700, tracking = 0.15.em)
    val numeric = archivo(13f, 700).copy(fontFeatureSettings = "tnum")
    val rail = archivo(17f, 700)

    fun body(size: Float, weight: Int = 400) = archivo(size, weight)
    fun wordmark(size: Float) = TextStyle(fontFamily = Limelight, fontSize = size.sp, letterSpacing = 0.06.em, lineHeight = (size * 1.1f).sp)
}

val MarqueeTypography = Typography(
    displayLarge = T.wordmark(48f), displayMedium = T.wordmark(38f), displaySmall = T.wordmark(30f),
    headlineLarge = T.title, headlineMedium = archivo(22f, 700), headlineSmall = archivo(19f, 700),
    titleLarge = archivo(20f, 700), titleMedium = T.headline, titleSmall = archivo(14f, 600),
    bodyLarge = archivo(16f, 400, line = 1.4f), bodyMedium = T.body, bodySmall = T.caption,
    labelLarge = archivo(14f, 600), labelMedium = T.sub, labelSmall = T.eyebrow,
)
