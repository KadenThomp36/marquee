package dev.kadenthompson.marquee.net

import dev.kadenthompson.marquee.model.AuthResponse
import dev.kadenthompson.marquee.model.BuildResponse
import dev.kadenthompson.marquee.model.SignupOpen
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.JsonObject
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Turning what someone types into a base URL, and proving there's a Marquee at the
 * other end. Forgiving about the input, strict about the answer: only Marquee answers
 * `/api/build`.
 */
object ServerAddress {

    /** Candidate origins for a typed address, best first (https before http). */
    fun candidates(input: String): List<String> {
        var text = input.trim()
        if (text.isEmpty()) return emptyList()
        text = text.trimEnd('/')
        for (suffix in listOf("/api/build", "/api", "/#", "/#/")) if (text.endsWith(suffix)) text = text.dropLast(suffix.length)
        text = text.trimEnd('/')
        if (text.isEmpty()) return emptyList()
        val lower = text.lowercase()
        if (lower.startsWith("http://") || lower.startsWith("https://")) {
            return listOfNotNull(origin(text))
        }
        return listOf("https://$text", "http://$text").mapNotNull(::origin)
    }

    private fun origin(s: String): String? {
        val url = s.toHttpUrlOrNull() ?: return null
        val default = (url.scheme == "https" && url.port == 443) || (url.scheme == "http" && url.port == 80)
        return "${url.scheme}://${url.host}${if (default) "" else ":${url.port}"}"
    }

    private val probe by lazy { Http.client.newBuilder().callTimeout(12, TimeUnit.SECONDS).build() }

    /** Ask each candidate for `/api/build`. The first that answers like Marquee wins. */
    suspend fun resolve(input: String): String {
        val options = candidates(input)
        if (options.isEmpty()) throw ApiError.BadAddress()
        var last: ApiError = ApiError.BadAddress()
        for (base in options) {
            try {
                build(base); return base
            } catch (e: ApiError) {
                last = e
                // A definite answer from a definite server: stop, don't downgrade to http.
                if (e is ApiError.Http || e is ApiError.NotMarquee) throw e
            }
        }
        throw last
    }

    suspend fun build(base: String): String = withContext(Dispatchers.IO) {
        val host = base.toHttpUrlOrNull()?.let { if (it.port in listOf(80, 443)) it.host else "${it.host}:${it.port}" }
        val r = try {
            probe.newCall(Request.Builder().url("$base/api/build").header("Accept", "application/json").build()).execute()
        } catch (e: IOException) {
            throw ApiError.Offline(Http.reason(e, host))
        }
        r.use {
            if (!it.isSuccessful) throw ApiError.Http(it.code, "That address answered with ${it.code}.")
            val payload = runCatching { MarqueeJson.decodeFromString<BuildResponse>(it.body.string()) }.getOrNull()
            if (payload == null || payload.build.isEmpty()) throw ApiError.NotMarquee()
            payload.build
        }
    }

    suspend fun signUpsOpen(base: String): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            probe.newCall(Request.Builder().url("$base/api/signup_open").build()).execute().use {
                MarqueeJson.decodeFromString<SignupOpen>(it.body.string()).open
            }
        }.getOrDefault(false)
    }

    /** Pairing happens before there's a client, so login/claim are made by hand. */
    suspend fun postAuth(base: String, path: String, body: JsonObject): AuthResponse = withContext(Dispatchers.IO) {
        val req = Request.Builder().url("$base/$path")
            .header("Accept", "application/json")
            .post(body.toString().toRequestBody(Http.jsonType)).build()
        val r = try {
            Http.client.newCall(req).execute()
        } catch (e: IOException) {
            throw ApiError.Offline(if (e is java.net.SocketTimeoutException) "The server didn't answer in time." else "Couldn't reach that server.")
        }
        r.use {
            val text = it.body.string()
            if (!it.isSuccessful) {
                val d = Http.detail(text, it.code)
                throw ApiError.Http(it.code, d.ifEmpty { "That didn't work." })
            }
            runCatching { MarqueeJson.decodeFromString<AuthResponse>(text) }.getOrElse { throw ApiError.Decoding("AuthResponse") }
        }
    }
}
