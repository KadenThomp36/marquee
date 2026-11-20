package dev.kadenthompson.marquee.features.requests

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.kadenthompson.marquee.BuildConfig
import dev.kadenthompson.marquee.design.C
import dev.kadenthompson.marquee.design.Eyebrow
import dev.kadenthompson.marquee.design.MQ
import dev.kadenthompson.marquee.design.ScreenScaffold
import dev.kadenthompson.marquee.design.T
import dev.kadenthompson.marquee.features.reading.PhasePill
import dev.kadenthompson.marquee.model.BookRequestPhase
import dev.kadenthompson.marquee.model.DownloadProgress
import dev.kadenthompson.marquee.model.OverseerrRequest
import dev.kadenthompson.marquee.model.PlexFile
import dev.kadenthompson.marquee.model.RequestDetail
import dev.kadenthompson.marquee.model.RequestDownload
import dev.kadenthompson.marquee.model.RequestStatus
import dev.kadenthompson.marquee.model.SeasonRequestState
import dev.kadenthompson.marquee.nav.LocalNav

/** Debug builds only: every request state side by side from sample data (`marquee://debug/requests`). */
@Composable
fun RequestStatesGallery() {
    val nav = LocalNav.current
    var sheet by remember { mutableStateOf(false) }
    fun season(n: Int, s: String, p: Int? = null, eta: String? = null) = SeasonRequestState(n, 8 + n, s, p, eta)
    val samples = listOf(
        "Not requested" to RequestStatus(true, "none"),
        "Requested" to RequestStatus(true, "pending"),
        "Searching" to RequestStatus(true, "processing"),
        "Downloading" to RequestStatus(true, "processing", DownloadProgress(1, 62, "00:14:40")),
        "Partly on Plex, more to request" to RequestStatus(true, "partial", DownloadProgress(2, 38, "01:22:05"),
            listOf(season(1, "available"), season(2, "available"), season(3, "downloading", 38, "01:22:05"), season(4, "pending"), season(5, "none"), season(6, "none"))),
        "On Plex" to RequestStatus(true, "available"),
    )
    val detail = RequestDetail(true, file = PlexFile("1080p", "HEVC", "EAC3 5.1", "HDR10", episodes = 22, size = "38.2 GB"),
        downloads = listOf(RequestDownload("Show.S03E04.1080p.WEB", "downloading", "2.1 GB", 38, "01:22:05", 3, 4)),
        requests = listOf(OverseerrRequest(1, "Approved", "Mia", "2026-11-18T19:00:00Z", seasons = listOf(3, 4), canDelete = true), OverseerrRequest(2, "Pending approval", "You", "2026-11-20T09:00:00Z", mine = true, seasons = listOf(5), canDelete = true)))
    ScreenScaffold("Request states", { nav.popBackStack() }) { pad ->
        if (!BuildConfig.DEBUG) return@ScreenScaffold
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(top = pad.calculateTopPadding()).padding(MQ.gutter), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Eyebrow("Films and TV (Overseerr)")
            samples.forEach { (label, s) -> Text(label, style = T.caption, color = C.inkMuted); RequestButton(s) { sheet = true } }
            Eyebrow("Books (Shelfmark)")
            BookRequestPhase.entries.forEach { PhasePill(it) }
            Eyebrow("Details panel")
            RequestDetailsPanel("show", 0, sample = detail)
        }
    }
    if (sheet) SeasonRequestSheet(0, samples[4].second, onDismiss = { sheet = false }) {}
}
