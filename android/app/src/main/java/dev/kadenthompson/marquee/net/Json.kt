package dev.kadenthompson.marquee.net

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.descriptors.nullable
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonNamingStrategy
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.longOrNull

/**
 * The API is hand-written literals rather than a generated schema, so decoding is
 * deliberately forgiving: unknown keys are ignored, a null where a default exists
 * takes the default, and properties map camelCase → snake_case. Every model field is
 * nullable or defaulted, so an older server that lacks a field still decodes.
 */
@OptIn(ExperimentalSerializationApi::class)
val MarqueeJson = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    explicitNulls = false
    isLenient = true
    encodeDefaults = false
    namingStrategy = JsonNamingStrategy.SnakeCase
}

/** An integer that may arrive as a number, a numeric string, a float, or nothing. */
typealias FlexInt = @Serializable(FlexIntSerializer::class) Int?

/** A double that may arrive as a number or a numeric string. */
typealias FlexDouble = @Serializable(FlexDoubleSerializer::class) Double?

/** A boolean that may arrive as true/false, 0/1, or "1". */
typealias FlexBool = @Serializable(FlexBoolSerializer::class) Boolean?

private fun JsonElement.primitiveOrNull(): JsonPrimitive? = (this as? JsonPrimitive)?.takeUnless { it is JsonNull }

object FlexIntSerializer : KSerializer<Int?> {
    @OptIn(ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("FlexInt", PrimitiveKind.INT).nullable
    override fun deserialize(decoder: Decoder): Int? {
        val p = (decoder as JsonDecoder).decodeJsonElement().primitiveOrNull() ?: return null
        p.longOrNull?.let { return it.toInt() }
        p.doubleOrNull?.let { return it.toInt() }
        if (p.isString) return p.content.take(8).trim().toIntOrNull()
        return p.booleanOrNull?.let { if (it) 1 else 0 }
    }
    override fun serialize(encoder: Encoder, value: Int?) {
        (encoder as JsonEncoder).encodeJsonElement(if (value == null) JsonNull else JsonPrimitive(value))
    }
}

object FlexDoubleSerializer : KSerializer<Double?> {
    @OptIn(ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("FlexDouble", PrimitiveKind.DOUBLE).nullable
    override fun deserialize(decoder: Decoder): Double? {
        val p = (decoder as JsonDecoder).decodeJsonElement().primitiveOrNull() ?: return null
        return p.doubleOrNull ?: p.content.toDoubleOrNull()
    }
    override fun serialize(encoder: Encoder, value: Double?) {
        (encoder as JsonEncoder).encodeJsonElement(if (value == null) JsonNull else JsonPrimitive(value))
    }
}

object FlexBoolSerializer : KSerializer<Boolean?> {
    @OptIn(ExperimentalSerializationApi::class)
    override val descriptor: SerialDescriptor = PrimitiveSerialDescriptor("FlexBool", PrimitiveKind.BOOLEAN).nullable
    override fun deserialize(decoder: Decoder): Boolean? {
        val p = (decoder as JsonDecoder).decodeJsonElement().primitiveOrNull() ?: return null
        p.booleanOrNull?.let { return it }
        p.longOrNull?.let { return it != 0L }
        return when (p.content.lowercase()) { "true", "yes" -> true; "false", "no", "" -> false; else -> null }
    }
    override fun serialize(encoder: Encoder, value: Boolean?) {
        (encoder as JsonEncoder).encodeJsonElement(if (value == null) JsonNull else JsonPrimitive(value))
    }
}
