package dev.kadenthompson.marquee.net

/** Everything that can go wrong talking to the server, phrased for a person. */
sealed class ApiError(message: String) : Exception(message) {
    /** The token was rejected — the session was revoked, or the server was rebuilt. */
    class Unauthorized : ApiError("Your session has expired. Sign in again.")
    class NotMarquee : ApiError("That address answered, but it isn't a Marquee server.")
    class NeedsServerUpdate : ApiError(
        "That Marquee server is running an older build that can't pair with the app yet. Update it (main.py and static/) and restart it, then try again."
    )
    class Http(val status: Int, detail: String) : ApiError(detail)
    class Offline(why: String) : ApiError(why)
    class Decoding(what: String) : ApiError("The server sent something unexpected ($what).")
    class BadAddress : ApiError("That doesn't look like a web address.")

    /** True when retrying later could plausibly work. */
    val isTransient: Boolean
        get() = this is Offline || (this is Http && (status >= 500 || status == 429))
}

val Throwable.friendly: String
    get() = (this as? ApiError)?.message ?: message ?: "Something went wrong."
