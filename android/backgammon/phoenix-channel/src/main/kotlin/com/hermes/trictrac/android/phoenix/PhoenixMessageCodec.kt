package com.hermes.trictrac.android.phoenix

import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonNull
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive

class PhoenixMessageCodec(
    private val gson: Gson = Gson(),
) {
    fun encode(envelope: PhoenixEnvelope): String {
        val frame = JsonArray().apply {
            add(envelope.joinRef?.let(::JsonPrimitive) ?: JsonNull.INSTANCE)
            add(envelope.ref?.let(::JsonPrimitive) ?: JsonNull.INSTANCE)
            add(envelope.topic)
            add(envelope.event)
            add(envelope.payload)
        }
        return gson.toJson(frame)
    }

    fun decode(raw: String): PhoenixEnvelope {
        val frame = JsonParser.parseString(raw).asJsonArray
        require(frame.size() == 5) { "Phoenix frame must contain 5 array elements." }

        return PhoenixEnvelope(
            joinRef = frame.stringOrNull(0),
            ref = frame.stringOrNull(1),
            topic = frame[2].asString,
            event = frame[3].asString,
            payload = frame[4].takeUnless { it is JsonNull } ?: JsonObject(),
        )
    }

    private fun JsonArray.stringOrNull(index: Int): String? {
        val value = get(index)
        return if (value is JsonNull) null else value.asString
    }
}
