package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

// ---- Overseerr

@Serializable data class RequestConfig(val enabled: Boolean = false, val url: String? = null)

@Serializable
data class OverseerrAccount(
    val enabled: Boolean = false,
    val linked: FlexBool = null,
    val account: String? = null,
    val reason: String? = null,
)

enum class RequestState(val key: String, val label: String) {
    NONE("none", "Not on server"),
    PENDING("pending", "Requested"),
    PROCESSING("processing", "Processing"),
    PARTIAL("partial", "Partial"),
    DOWNLOADING("downloading", "Downloading"),
    AVAILABLE("available", "On Plex"),
    UNKNOWN("unknown", "Unknown");

    val isRequested get() = this == PENDING || this == PROCESSING || this == PARTIAL || this == DOWNLOADING

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.key == (raw ?: "none") } ?: UNKNOWN
    }
}

@Serializable
data class RequestStatus(
    val enabled: Boolean = false,
    val status: String? = null,
    val download: DownloadProgress? = null,
    val seasons: List<SeasonRequestState>? = null,
) {
    val state get() = RequestState.of(status)
    val isBusy get() = download != null || (seasons ?: emptyList()).any { it.state == RequestState.DOWNLOADING } ||
        state == RequestState.PENDING || state == RequestState.PROCESSING
}

@Serializable
data class DownloadProgress(val active: Int = 0, val progress: Int = 0, val eta: String? = null) {
    val fraction: Float get() = progress.coerceIn(0, 100) / 100f
}

@Serializable
data class SeasonRequestState(
    val number: Int = 0,
    val episodes: Int = 0,
    val status: String = "none",
    val progress: FlexInt = null,
    val eta: String? = null,
) {
    val state get() = RequestState.of(status)
    val isSelectable get() = state == RequestState.NONE
}

@Serializable data class RequestResult(val ok: Boolean? = null, val status: String? = null)

@Serializable
data class RequestDetail(
    val enabled: FlexBool = null,
    val unavailable: FlexBool = null,
    val status: String? = null,
    val requests: List<OverseerrRequest>? = null,
    val downloads: List<RequestDownload>? = null,
    val file: PlexFile? = null,
) {
    val isEmpty get() = requests.isNullOrEmpty() && downloads.isNullOrEmpty() && file == null
}

@Serializable
data class OverseerrRequest(
    val id: Int = 0,
    val status: String? = null,
    val requestedBy: String? = null,
    val createdAt: String? = null,
    val is4k: FlexBool = null,
    val seasons: List<Int>? = null,
    val mine: FlexBool = null,
    val canDelete: FlexBool = null,
)

@Serializable
data class RequestDownload(
    val title: String? = null,
    val status: String? = null,
    val size: String? = null,
    val progress: FlexInt = null,
    val eta: String? = null,
    val season: FlexInt = null,
    val episode: FlexInt = null,
)

@Serializable
data class PlexFile(
    val resolution: String? = null,
    val video: String? = null,
    val audio: String? = null,
    val hdr: String? = null,
    val container: String? = null,
    val size: String? = null,
    val bitrate: String? = null,
    val copies: FlexInt = null,
    val mixed: FlexBool = null,
    val episodes: FlexInt = null,
)

// ---- Plex

@Serializable
data class PlexStatus(
    val plexUsername: String? = null,
    val hasOwnToken: FlexBool = null,
    val directSync: FlexBool = null,
    val lastEvent: String? = null,
    val lastEventUser: String? = null,
    val lastPoll: String? = null,
) {
    val isLinked get() = !plexUsername.isNullOrEmpty()
}

@Serializable data class PlexPin(val id: Long = 0, val code: String = "", val url: String = "")

@Serializable
data class PlexPinPoll(val linked: Boolean = false, val username: String? = null, val thumb: String? = null, val email: String? = null)

// ---- IMDb

@Serializable
data class IMDbStatus(
    val last: String? = null,
    val running: Boolean = false,
    val stats: IMDbSyncStats? = null,
    val episodes: FlexInt = null,
    val episodesRated: FlexInt = null,
)

@Serializable
data class IMDbSyncStats(
    val episodes: FlexInt = null, val shows: FlexInt = null, val movies: FlexInt = null,
    val newIds: FlexInt = null, val seconds: FlexDouble = null,
)

// ---- Imports

@Serializable
data class ImportStatus(
    val state: String = "idle",
    val done: FlexInt = null,
    val total: FlexInt = null,
    val errors: List<String>? = null,
) {
    val isRunning get() = state == "running"
    val fraction: Float get() = if ((total ?: 0) > 0) minOf(1f, (done ?: 0).toFloat() / total!!) else 0f
}

// ---- Household admin

@Serializable
data class AdminUser(
    val id: Int = 0,
    val username: String = "",
    val displayName: String? = null,
    val avatar: String? = null,
    val isAdmin: FlexInt = null,
    val plexUsername: String? = null,
    val createdAt: String? = null,
) {
    val person get() = Person(id, username, displayName, avatar, isAdmin = (isAdmin ?: 0) != 0, isMe = false)
}

@Serializable data class RegistrationState(val closed: Boolean = false)
