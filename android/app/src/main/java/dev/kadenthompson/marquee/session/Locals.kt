package dev.kadenthompson.marquee.session

import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.staticCompositionLocalOf

val LocalSession = staticCompositionLocalOf<Session> { error("No Session in scope") }
val LocalSnackbar = staticCompositionLocalOf { SnackbarHostState() }
