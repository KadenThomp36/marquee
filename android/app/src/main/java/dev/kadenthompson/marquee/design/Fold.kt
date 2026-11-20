package dev.kadenthompson.marquee.design

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfo
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.window.core.layout.WindowSizeClass

/** A vertical crease across the window, in window pixels — Jetpack WindowManager's hinge. */
data class Crease(val left: Float, val right: Float, val separating: Boolean)

/** The vertical hinge of a book-style foldable, if there is one. */
@Composable
fun verticalCrease(): Crease? {
    val posture = currentWindowAdaptiveInfo().windowPosture
    val h = posture.hingeList.firstOrNull { it.isVertical } ?: return null
    return Crease(h.bounds.left, h.bounds.right, h.isSeparating)
}

/** The hinge runs left-right and the device is half open — on a table like a laptop. */
@Composable
fun isTabletop(): Boolean = currentWindowAdaptiveInfo().windowPosture.isTabletop

@Composable
fun isWideWindow(): Boolean =
    currentWindowAdaptiveInfo().windowSizeClass.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_EXPANDED_LOWER_BOUND)

@Composable
fun isMediumWindow(): Boolean =
    currentWindowAdaptiveInfo().windowSizeClass.isWidthAtLeastBreakpoint(WindowSizeClass.WIDTH_DP_MEDIUM_LOWER_BOUND)

private const val MIN_PAGE = 320f

/**
 * A detail page that becomes an open book on a foldable's inner display or a tablet.
 *
 * Phone-sized, it's one scrolling column: [leading], then [trailing]. Opened out, the
 * halves become facing pages that scroll on their own, with the crease falling in the
 * gutter between them — the iOS app's FoldSpread, driven by WindowManager's hinge.
 */
@Composable
fun FoldSpread(
    modifier: Modifier = Modifier,
    contentPadding: PaddingValues = PaddingValues(),
    spacing: Dp = 24.dp,
    leading: @Composable ColumnScope.() -> Unit,
    trailing: @Composable ColumnScope.() -> Unit,
) {
    val crease = verticalCrease()
    val density = LocalDensity.current
    var originX by remember { mutableFloatStateOf(0f) }
    BoxWithConstraints(modifier.fillMaxSize().onGloballyPositioned { originX = it.positionInWindow().x }) {
        val width = with(density) { maxWidth.toPx() }
        val pages: Triple<Float, Float, Float>? = when {
            crease != null -> {
                val l = (crease.left - originX).coerceAtLeast(0f)
                val r = (width - (crease.right - originX)).coerceAtLeast(0f)
                val gap = (crease.right - crease.left).coerceAtLeast(with(density) { 16.dp.toPx() })
                if (with(density) { l.toDp().value } >= MIN_PAGE && with(density) { r.toDp().value } >= MIN_PAGE) Triple(l, gap, width - l - gap) else null
            }
            maxWidth.value >= 2 * MIN_PAGE + 120 -> {
                val gap = with(density) { 28.dp.toPx() }
                val l = ((width - gap) * 0.52f)
                Triple(l, gap, width - gap - l)
            }
            else -> null
        }
        if (pages != null) {
            Row(Modifier.fillMaxSize()) {
                Column(
                    Modifier.width(with(density) { pages.first.toDp() }).fillMaxHeight().verticalScroll(rememberScrollState()).padding(contentPadding),
                    verticalArrangement = Arrangement.spacedBy(spacing),
                ) { leading(); Spacer(Modifier.height(32.dp)) }
                FoldGutter(Modifier.width(with(density) { pages.second.toDp() }).fillMaxHeight())
                Column(
                    Modifier.width(with(density) { pages.third.toDp() }).fillMaxHeight().verticalScroll(rememberScrollState()).padding(contentPadding),
                    verticalArrangement = Arrangement.spacedBy(spacing),
                ) { trailing(); Spacer(Modifier.height(32.dp)) }
            }
        } else {
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(contentPadding),
                verticalArrangement = Arrangement.spacedBy(spacing),
            ) { leading(); trailing(); Spacer(Modifier.height(40.dp)) }
        }
    }
}

/** The gutter: a faint shadow either side of the crease, like a bound book's. */
@Composable
fun FoldGutter(modifier: Modifier = Modifier) {
    Box(modifier.background(Brush.horizontalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.18f), Color.Transparent)))) {
        Box(Modifier.fillMaxHeight().width(1.dp).align(androidx.compose.ui.Alignment.Center).background(C.hairline))
    }
}

/** Two independent panes for list screens (search | results, requests | search). */
@Composable
fun TwoPane(
    modifier: Modifier = Modifier,
    leading: @Composable () -> Unit,
    trailing: @Composable () -> Unit,
    single: @Composable () -> Unit,
) {
    val crease = verticalCrease()
    val density = LocalDensity.current
    var originX by remember { mutableFloatStateOf(0f) }
    BoxWithConstraints(modifier.fillMaxSize().onGloballyPositioned { originX = it.positionInWindow().x }) {
        val width = with(density) { maxWidth.toPx() }
        val split: Pair<Float, Float>? = when {
            crease != null -> {
                val l = (crease.left - originX).coerceAtLeast(0f)
                val gap = (crease.right - crease.left).coerceAtLeast(with(density) { 16.dp.toPx() })
                if (with(density) { l.toDp().value } >= MIN_PAGE && with(density) { (width - l - gap).toDp().value } >= MIN_PAGE) l to gap else null
            }
            maxWidth.value >= 2 * MIN_PAGE + 120 -> (width - with(density) { 28.dp.toPx() }) * 0.5f to with(density) { 28.dp.toPx() }
            else -> null
        }
        if (split == null) single() else Row(Modifier.fillMaxSize()) {
            Box(Modifier.width(with(density) { split.first.toDp() }).fillMaxHeight()) { leading() }
            FoldGutter(Modifier.width(with(density) { split.second.toDp() }).fillMaxHeight())
            Box(Modifier.weight(1f).fillMaxHeight()) { trailing() }
        }
    }
}
