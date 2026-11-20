package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.Serializable

@Serializable
data class UserFeatures(val books: FlexInt = null, val manga: FlexInt = null) {
    val tracksBooks get() = (books ?: 0) != 0
    val tracksManga get() = (manga ?: 0) != 0
    /** Reading is opt-in per user; the whole destination stays hidden until it's on. */
    val tracksReading get() = tracksBooks || tracksManga
}

/** The public face of an account. Bylines carry only a display name and an avatar. */
@Serializable
data class Person(
    val id: Int? = null,
    val username: String? = null,
    val displayName: String? = null,
    val avatar: String? = null,
    val banner: String? = null,
    val features: UserFeatures? = null,
    val isAdmin: FlexBool = null,
    val isMe: FlexBool = null,
) {
    val name: String
        get() = displayName?.takeIf { it.isNotBlank() } ?: username?.takeIf { it.isNotBlank() } ?: "Someone"
    val shortName: String get() = name.split(" ").firstOrNull() ?: name
    /** Deterministic hue for the fallback monogram, matching the web client's rule. */
    val monogramHue: Float get() = (name.sumOf { it.code } % 360).toFloat()
    val monogram: String get() = name.trim().firstOrNull()?.uppercase() ?: "?"
}

@Serializable
data class MeResponse(
    val id: Int? = null,
    val username: String = "",
    val displayName: String? = null,
    val avatar: String? = null,
    val banner: String? = null,
    val features: UserFeatures? = null,
    val isAdmin: FlexBool = null,
) {
    val person get() = Person(id, username, displayName, avatar, banner, features, isAdmin, true)
}

/** `POST /api/login` and `POST /api/pair/claim` */
@Serializable
data class AuthResponse(
    val token: String? = null,
    val username: String? = null,
    val isAdmin: FlexBool = null,
    val user: MeResponse? = null,
)

@Serializable data class BuildResponse(val build: String = "")
@Serializable data class SignupOpen(val open: Boolean = false)

@Serializable
data class PairCode(val code: String = "", val expiresAt: String? = null, val expiresIn: Int? = null)

@Serializable
data class DeviceSession(
    val id: String = "",
    val deviceName: String = "",
    val createdAt: String? = null,
    val lastSeen: String? = null,
    val current: Boolean = false,
)

@Serializable
data class DeviceSessions(val sessions: List<DeviceSession> = emptyList(), val total: Int? = null) {
    val hidden get() = maxOf(0, (total ?: sessions.size) - sessions.size)
}

@Serializable data class MembersResponse(val members: List<Person> = emptyList())

@Serializable data class OkResponse(val ok: Boolean? = null, val detail: String? = null)
