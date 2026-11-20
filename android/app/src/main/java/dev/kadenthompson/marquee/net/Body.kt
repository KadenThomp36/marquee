package dev.kadenthompson.marquee.net

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive

/**
 * A request body from pairs. A `null` value is dropped ("leave it alone"); pass
 * [JsonNull] to send an explicit null — the server only clears a rating when the key
 * is present.
 */
fun body(vararg pairs: Pair<String, Any?>): JsonObject =
    JsonObject(pairs.mapNotNull { (k, v) -> toJson(v)?.let { k to it } }.toMap())

private fun toJson(v: Any?): JsonElement? = when (v) {
    null -> null
    is JsonElement -> v
    is String -> JsonPrimitive(v)
    is Number -> JsonPrimitive(v)
    is Boolean -> JsonPrimitive(v)
    is Collection<*> -> JsonArray(v.mapNotNull { toJson(it) ?: JsonNull })
    is Map<*, *> -> JsonObject(v.entries.mapNotNull { (k, x) -> toJson(x)?.let { k.toString() to it } }.toMap())
    else -> JsonPrimitive(v.toString())
}
