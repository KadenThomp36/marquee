package dev.kadenthompson.marquee.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

/**
 * "Midnight Marquee" — the art-deco cinema palette the web and iOS clients share,
 * near-black by night and warm paper by day. Values are the iOS asset catalog's.
 */
@Immutable
data class MqColors(
    val ground: Color,
    val panel: Color,
    val panelRaised: Color,
    val hairline: Color,
    val hairlineBold: Color,
    val ink: Color,
    val inkSoft: Color,
    val inkMuted: Color,
    /** The accent, as text or an icon. */
    val brass: Color,
    val brassBright: Color,
    /** The accent as a fill — always carries [brassOnFill]. */
    val brassFill: Color,
    val brassOnFill: Color,
    val brassDim: Color,
    val brassSoft: Color,
    val velvet: Color,
    val scrim: Color,
    val overseerr: Color,
    val plex: Color,
    val chartAmber: Color,
    val chartBlue: Color,
    val chartAqua: Color,
    val chartViolet: Color,
    val chartOrange: Color,
    val chartRed: Color,
    val chartPink: Color,
    val chartGreen: Color,
    val chartYellow: Color,
    val chartNeutral: Color,
    val isDark: Boolean,
) {
    /** Fixed hue order for identity charts — a genre keeps its colour across screens. */
    val categorical get() = listOf(chartBlue, chartAqua, chartYellow, chartGreen, chartViolet, chartRed, chartPink, chartOrange)

    companion object {
        // On artwork: pinned dark-mode values, because a poster is dark whatever the
        // phone's appearance is.
        val brassOnArt = Color(0xFFF0B544)
        val inkOnArt = Color(0xFFF9F4EC)
        val inkSoftOnArt = Color(0xC7F9F4EC)

        /** Red → amber → green quality ramp for a 1–10 score. */
        fun rating(score: Int): Color = listOf(
            0xFFE0524A, 0xFFE2664A, 0xFFE58248, 0xFFE89C46, 0xFFECB544,
            0xFFD8C13F, 0xFFA9C247, 0xFF7DC157, 0xFF57C06A, 0xFF3FBF6F,
        ).map { Color(it) }[score.coerceIn(1, 10) - 1]
    }
}

val DarkMq = MqColors(
    ground = Color(0xFF0F0D0A), panel = Color(0xFF17140F), panelRaised = Color(0xFF1F1A13),
    hairline = Color(0xFF2B251B), hairlineBold = Color(0xFF3D3425),
    ink = Color(0xFFF2ECDF), inkSoft = Color(0xFFB3A88F), inkMuted = Color(0xFF7C7360),
    brass = Color(0xFFF0B544), brassBright = Color(0xFFFFD98A), brassFill = Color(0xFFF0B544),
    brassOnFill = Color(0xFF221703), brassDim = Color(0xFF8F6D28), brassSoft = Color(0x24F0B544),
    velvet = Color(0xFFB0404F), scrim = Color(0xB80F0D0A), overseerr = Color(0xFF8B7CD8), plex = Color(0xFFE5A00D),
    chartAmber = Color(0xFFF0B544), chartBlue = Color(0xFF3987E5), chartAqua = Color(0xFF17A377),
    chartViolet = Color(0xFF8F7FE8), chartOrange = Color(0xFFDB6330), chartRed = Color(0xFFE05C5C),
    chartPink = Color(0xFFD75C95), chartGreen = Color(0xFF22A85A), chartYellow = Color(0xFFC08118),
    chartNeutral = Color(0xFF6B6252), isDark = true,
)

val LightMq = MqColors(
    ground = Color(0xFFF6F1E7), panel = Color(0xFFFFFCF5), panelRaised = Color(0xFFF1EADB),
    hairline = Color(0xFFE4DBC8), hairlineBold = Color(0xFFCFC3A9),
    ink = Color(0xFF1E1810), inkSoft = Color(0xFF5A4F3B), inkMuted = Color(0xFF877C66),
    brass = Color(0xFF9A6B10), brassBright = Color(0xFF7A5300), brassFill = Color(0xFFF0B544),
    brassOnFill = Color(0xFF241703), brassDim = Color(0xFFC9A05A), brassSoft = Color(0x219A6B10),
    velvet = Color(0xFFA5303F), scrim = Color(0xB80F0D0A), overseerr = Color(0xFF6A5AC4), plex = Color(0xFFB87F0B),
    chartAmber = Color(0xFFB07B10), chartBlue = Color(0xFF2668B5), chartAqua = Color(0xFF0E7B58),
    chartViolet = Color(0xFF6355C4), chartOrange = Color(0xFFA8481F), chartRed = Color(0xFFB33F3F),
    chartPink = Color(0xFFA93F6E), chartGreen = Color(0xFF187F42), chartYellow = Color(0xFF8E5F0F),
    chartNeutral = Color(0xFF6B6252), isDark = false,
)

val LocalMqColors = staticCompositionLocalOf { DarkMq }

/** The palette in scope: `C.brass`, `C.ink`. */
val C: MqColors
    @Composable @ReadOnlyComposable get() = LocalMqColors.current

/** Appearance preference: "system", "dark" or "light". Dark is Marquee's home. */
@Composable
fun MarqueeTheme(appearance: String = "system", content: @Composable () -> Unit) {
    val dark = when (appearance) { "light" -> false; "dark" -> true; else -> isSystemInDarkTheme() }
    val c = if (dark) DarkMq else LightMq
    val scheme = if (dark) darkColorScheme(
        primary = c.brassFill, onPrimary = c.brassOnFill, primaryContainer = c.brassSoft, onPrimaryContainer = c.brass,
        secondary = c.brass, onSecondary = c.brassOnFill, secondaryContainer = c.brassSoft, onSecondaryContainer = c.brass,
        tertiary = c.velvet, background = c.ground, onBackground = c.ink, surface = c.ground, onSurface = c.ink,
        surfaceVariant = c.panelRaised, onSurfaceVariant = c.inkSoft, surfaceContainerLowest = c.ground,
        surfaceContainerLow = c.panel, surfaceContainer = c.panel, surfaceContainerHigh = c.panelRaised,
        surfaceContainerHighest = c.panelRaised, outline = c.hairlineBold, outlineVariant = c.hairline,
        error = c.velvet, onError = Color.White, inverseSurface = c.ink, inverseOnSurface = c.ground,
        inversePrimary = c.brassDim, scrim = Color.Black, surfaceTint = Color.Transparent,
    ) else lightColorScheme(
        primary = c.brassFill, onPrimary = c.brassOnFill, primaryContainer = c.brassSoft, onPrimaryContainer = c.brass,
        secondary = c.brass, onSecondary = Color.White, secondaryContainer = c.brassSoft, onSecondaryContainer = c.brass,
        tertiary = c.velvet, background = c.ground, onBackground = c.ink, surface = c.ground, onSurface = c.ink,
        surfaceVariant = c.panelRaised, onSurfaceVariant = c.inkSoft, surfaceContainerLowest = c.panel,
        surfaceContainerLow = c.panel, surfaceContainer = c.panel, surfaceContainerHigh = c.panelRaised,
        surfaceContainerHighest = c.panelRaised, outline = c.hairlineBold, outlineVariant = c.hairline,
        error = c.velvet, onError = Color.White, inverseSurface = c.ink, inverseOnSurface = c.ground,
        inversePrimary = c.brassDim, scrim = Color.Black, surfaceTint = Color.Transparent,
    )
    CompositionLocalProvider(LocalMqColors provides c) {
        MaterialTheme(colorScheme = scheme, typography = MarqueeTypography, content = content)
    }
}

/** Shape and rhythm constants, so a poster is the same poster everywhere. */
object MQ {
    val radius = 16f
    val radiusSmall = 11f
    const val posterAspect = 2f / 3f
    const val stillAspect = 16f / 9f
    val gutter = 18.dp
    val railGap = 13.dp
    val upNextWidth = 158.dp
    val tileWidth = 124.dp
    val watchedWidth = 116.dp
}
