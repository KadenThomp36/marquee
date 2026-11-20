package dev.kadenthompson.marquee.net

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.serializer
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import javax.net.ssl.SSLException

/** Where the household's server lives and the token that opens it. Both are secrets. */
@kotlinx.serialization.Serializable
data class PairedServer(
    /** Normalised origin, e.g. `https://example` — no trailing slash, no `/api`. */
    val baseUrl: String,
    val token: String,
    val username: String,
    val displayName: String,
    val isAdmin: Boolean,
    val deviceName: String,
)

object Http {
    /** One client for the whole app: no cookie jar — the bearer token is the credential. */
    val client: OkHttpClient by lazy {
        OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .callTimeout(120, TimeUnit.SECONDS)
            .build()
    }

    val jsonType = "application/json".toMediaType()

    fun reason(e: IOException, host: String? = null): String = when (e) {
        is UnknownHostException -> host?.let { "Couldn't find $it." } ?: "Couldn't reach your Marquee server. Is it on, and are you on the right network?"
        is ConnectException -> host?.let { "Nothing answered at $it." } ?: "Couldn't reach your Marquee server. Is it on, and are you on the right network?"
        is SocketTimeoutException -> "The server didn't answer in time."
        is SSLException -> "That server's HTTPS certificate wasn't accepted."
        else -> if (e.message?.contains("CLEARTEXT", ignoreCase = true) == true)
            "This build only allows https:// addresses." else "Couldn't reach your Marquee server."
    }

    /** FastAPI puts its message in `detail`; anything else falls back to the status. */
    fun detail(body: String?, status: Int): String {
        runCatching {
            val obj = MarqueeJson.parseToJsonElement(body ?: "").jsonObject
            (obj["detail"] as? JsonPrimitive)?.content?.takeIf { it.isNotBlank() }?.let { return it }
        }
        return when (status) {
            400 -> "Bad request"; 403 -> "Not allowed"; 404 -> "Not found"; 409 -> "Conflict"
            429 -> "Too many requests"; in 500..599 -> "The server had a problem ($status)"
            else -> "Request failed ($status)"
        }
    }
}

/**
 * Thin, typed wrapper over the Marquee JSON API. One instance per paired server; it
 * holds the address and token and nothing else, so signing out is just dropping it.
 */
class MarqueeClient(val server: PairedServer, private val http: OkHttpClient = Http.client) {

    private val api: HttpUrl = "${server.baseUrl}/api/".toHttpUrl()

    suspend inline fun <reified T> get(path: String, query: Map<String, String?> = emptyMap()): T =
        get(path, query, serializer())

    suspend inline fun <reified T> post(path: String, body: JsonObject? = null): T =
        post(path, body, serializer())

    suspend inline fun <reified T> delete(path: String): T = delete(path, serializer())

    /** POST where the answer doesn't matter beyond "it worked". */
    suspend fun send(path: String, body: JsonObject? = null) {
        execute(request(path).post((body ?: JsonObject(emptyMap())).toString().toRequestBody(Http.jsonType)).build())
    }

    suspend fun sendDelete(path: String) {
        execute(request(path).delete().build())
    }

    suspend fun <T> get(path: String, query: Map<String, String?>, s: KSerializer<T>): T =
        decode(execute(request(path, query).get().build()), s)

    suspend fun <T> post(path: String, body: JsonObject?, s: KSerializer<T>): T {
        // Several endpoints read the body unconditionally, so an empty POST still carries `{}`.
        val payload = (body ?: JsonObject(emptyMap())).toString().toRequestBody(Http.jsonType)
        return decode(execute(request(path).post(payload).build()), s)
    }

    suspend fun <T> delete(path: String, s: KSerializer<T>): T =
        decode(execute(request(path).delete().build()), s)

    /** Multipart upload — avatars, banners, TV Time and Goodreads imports. */
    suspend fun upload(path: String, bytes: ByteArray, filename: String, mime: String): JsonElement {
        val body: RequestBody = MultipartBody.Builder().setType(MultipartBody.FORM)
            .addFormDataPart("file", filename, bytes.toRequestBody(mime.toMediaType()))
            .build()
        return MarqueeJson.parseToJsonElement(execute(request(path).post(body).build()).ifEmpty { "{}" })
    }

    /** Absolute URL for a server-relative path (uploaded avatars come back as `/uploads/…`). */
    fun absolute(url: String?): String? = when {
        url.isNullOrEmpty() -> null
        url.startsWith("http://") || url.startsWith("https://") -> url
        url.startsWith("/") -> server.baseUrl + url
        else -> "${server.baseUrl}/$url"
    }

    private fun request(path: String, query: Map<String, String?> = emptyMap()): Request.Builder {
        val url = api.newBuilder().apply {
            path.trimStart('/').split('/').forEach { addPathSegment(it) }
            query.toSortedMap().forEach { (k, v) -> if (v != null) addQueryParameter(k, v) }
        }.build()
        return Request.Builder().url(url)
            .header("Authorization", "Bearer ${server.token}")
            .header("Accept", "application/json")
    }

    private suspend fun execute(req: Request): String = withContext(Dispatchers.IO) {
        val response = try {
            http.newCall(req).execute()
        } catch (e: IOException) {
            throw ApiError.Offline(Http.reason(e))
        }
        response.use { r ->
            val text = r.body.string()
            if (r.code == 401) throw ApiError.Unauthorized()
            if (!r.isSuccessful) throw ApiError.Http(r.code, Http.detail(text, r.code))
            text
        }
    }

    private fun <T> decode(text: String, s: KSerializer<T>): T = try {
        MarqueeJson.decodeFromString(s, text.ifEmpty { "{}" })
    } catch (e: Exception) {
        android.util.Log.w("Marquee", "decode ${s.descriptor.serialName} failed: ${e.message}")
        throw ApiError.Decoding(s.descriptor.serialName.substringAfterLast('.'))
    }
}
