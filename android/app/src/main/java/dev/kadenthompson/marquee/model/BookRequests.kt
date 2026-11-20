package dev.kadenthompson.marquee.model

import dev.kadenthompson.marquee.net.FlexBool
import dev.kadenthompson.marquee.net.FlexDouble
import dev.kadenthompson.marquee.net.FlexInt
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.doubleOrNull
import java.util.Locale
import kotlin.math.roundToInt

// Book requests (Shelfmark): the server finds an ebook, downloads it and files it into
// the household's Calibre library.

@Serializable data class BookRequestConfig(val enabled: FlexBool = null) {
    val isEnabled get() = enabled == true
}

enum class BookRequestPhase {
    FINDING, DOWNLOADING, IMPORTING, DONE, PICK, FAILED, CANCELLED, UNKNOWN;

    val isActive get() = this == FINDING || this == DOWNLOADING || this == IMPORTING
    val isCancellable get() = isActive || this == PICK

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.name.equals(raw, ignoreCase = true) } ?: UNKNOWN
    }
}

/** A size that arrives as bytes or as already-formatted text. Exposed as text. */
typealias ReleaseSize = @Serializable(ReleaseSizeSerializer::class) String?

object ReleaseSizeSerializer : KSerializer<String?> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("ReleaseSize", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): String? {
        val p = (decoder as JsonDecoder).decodeJsonElement() as? JsonPrimitive ?: return null
        if (p is JsonNull) return null
        if (!p.isString) {
            val bytes = p.doubleOrNull ?: return null
            return if (bytes > 0) formatBytes(bytes) else null
        }
        return p.content.ifEmpty { null }
    }
    override fun serialize(encoder: Encoder, value: String?) = encoder.encodeString(value ?: "")

    fun formatBytes(bytes: Double): String {
        val units = listOf("bytes", "KB", "MB", "GB", "TB")
        var v = bytes; var i = 0
        while (v >= 1000 && i < units.lastIndex) { v /= 1000; i++ }
        return if (i == 0) "${v.toInt()} bytes" else String.format(Locale.US, if (v < 10) "%.1f %s" else "%.0f %s", v, units[i])
    }
}

/** An id that may be a string or a number. */
typealias LooseId = @Serializable(LooseIdSerializer::class) String

object LooseIdSerializer : KSerializer<String> {
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("LooseId", PrimitiveKind.STRING)
    override fun deserialize(decoder: Decoder): String {
        val p = (decoder as JsonDecoder).decodeJsonElement() as? JsonPrimitive ?: return ""
        return if (p is JsonNull) "" else p.content
    }
    override fun serialize(encoder: Encoder, value: String) = encoder.encodeString(value)
}

private fun copySummary(format: String?, size: String?, seeders: Int?): String {
    val parts = mutableListOf<String>()
    if (!format.isNullOrEmpty()) parts += format.uppercase()
    if (size != null) parts += size
    if (seeders != null) parts += "$seeders seeder${if (seeders == 1) "" else "s"}"
    return parts.joinToString(" · ")
}

@Serializable
data class BookRequestCopy(
    val title: String? = null,
    val size: ReleaseSize = null,
    val format: String? = null,
    val seeders: FlexInt = null,
) {
    val summary get() = copySummary(format, size, seeders)
}

@Serializable
data class BookRequestChoice(
    val sourceId: LooseId = "",
    val title: String? = null,
    val size: ReleaseSize = null,
    val format: String? = null,
    val seeders: FlexInt = null,
    val indexer: String? = null,
    val score: FlexDouble = null,
    val tried: FlexBool = null,
    val recommended: FlexBool = null,
) {
    val wasTried get() = tried == true
    val isRecommended get() = recommended == true
    val summary get() = copySummary(format, size, seeders)
}

@Serializable
data class BookRequest(
    val id: Int = 0,
    val userId: Int? = null,
    val bookId: Int? = null,
    val providerId: String? = null,
    val title: String? = null,
    val author: String? = null,
    val year: FlexInt = null,
    val cover: String? = null,
    val state: String? = null,
    val message: String? = null,
    val progress: FlexDouble = null,
    val attempts: FlexInt = null,
    val requestedBy: String? = null,
    val mine: FlexBool = null,
    val copy: BookRequestCopy? = null,
    val createdAt: String? = null,
    val updatedAt: String? = null,
    val finishedAt: String? = null,
    val already: FlexBool = null,
    val choices: List<BookRequestChoice>? = null,
) {
    val phase get() = BookRequestPhase.of(state)
    val isMine get() = mine == true
    val displayTitle get() = title ?: "Untitled"
    val fraction: Float get() = ((progress ?: 0.0) / 100).coerceIn(0.0, 1.0).toFloat()
    val percent get() = (progress ?: 0.0).roundToInt()
}

@Serializable
data class BookRequestList(
    val enabled: FlexBool = null,
    val requests: List<BookRequest>? = null,
    val inCalibre: CalibreCopy? = null,
)

@Serializable
data class CalibreCopy(
    val id: Int? = null,
    val title: String? = null,
    val authors: List<String>? = null,
    val formats: List<String>? = null,
    val size: ReleaseSize = null,
) {
    val summary: String
        get() {
            val parts = mutableListOf<String>()
            if (!formats.isNullOrEmpty()) parts += formats.joinToString(", ") { it.uppercase() }
            if (size != null) parts += size
            return parts.joinToString(" · ")
        }
}

@Serializable data class BookRequestRef(val id: Int = 0, val state: String? = null) {
    val phase get() = BookRequestPhase.of(state)
}

@Serializable
data class ShelfmarkBook(
    val provider: String? = null,
    val providerId: LooseId = "",
    val title: String? = null,
    val authors: List<String>? = null,
    val year: FlexInt = null,
    val cover: String? = null,
    val request: BookRequestRef? = null,
    val inCalibre: CalibreCopy? = null,
) {
    val key get() = "${provider ?: ""}/$providerId"
    val displayTitle get() = title ?: "Untitled"
    val authorLine get() = (authors ?: emptyList()).joinToString(", ")
}

@Serializable data class ShelfmarkSearchResponse(val results: List<ShelfmarkBook>? = null, val unavailable: FlexBool = null)
