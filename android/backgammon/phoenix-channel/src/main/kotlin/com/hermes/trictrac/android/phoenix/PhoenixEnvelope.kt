package com.hermes.trictrac.android.phoenix

import com.google.gson.JsonElement
import com.google.gson.JsonObject

data class PhoenixEnvelope(
    val joinRef: String? = null,
    val ref: String? = null,
    val topic: String,
    val event: String,
    val payload: JsonElement = JsonObject(),
)

data class PhoenixReply(
    val envelope: PhoenixEnvelope,
    val status: String?,
    val response: JsonElement,
)

class PhoenixReplyException(
    val topic: String,
    val event: String,
    val status: String?,
    val response: JsonElement,
) : IllegalStateException("Phoenix reply for $topic:$event returned ${status ?: "unknown"}")

internal fun PhoenixEnvelope.reply(): PhoenixReply {
    val payloadObject = payload.asJsonObjectOrNull()
    val status = payloadObject?.get("status")?.asString
    val response = payloadObject?.get("response") ?: JsonObject()
    return PhoenixReply(this, status, response)
}

internal fun JsonElement.asJsonObjectOrNull(): JsonObject? =
    if (isJsonObject) asJsonObject else null
