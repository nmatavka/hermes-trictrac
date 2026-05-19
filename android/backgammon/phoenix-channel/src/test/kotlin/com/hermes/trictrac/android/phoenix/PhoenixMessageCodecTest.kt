package com.hermes.trictrac.android.phoenix

import com.google.gson.JsonObject
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class PhoenixMessageCodecTest {
    private val codec = PhoenixMessageCodec()

    @Test
    fun roundTripsEnvelopeFrames() {
        val payload = JsonObject().apply {
            addProperty("user", "nick")
            addProperty("variant", "backgammon")
        }

        val encoded = codec.encode(
            PhoenixEnvelope(
                joinRef = "12",
                ref = "15",
                topic = "games:table-1",
                event = "phx_join",
                payload = payload,
            )
        )

        val decoded = codec.decode(encoded)
        assertEquals("12", decoded.joinRef)
        assertEquals("15", decoded.ref)
        assertEquals("games:table-1", decoded.topic)
        assertEquals("phx_join", decoded.event)
        assertEquals("nick", decoded.payload.asJsonObject["user"].asString)
        assertEquals("backgammon", decoded.payload.asJsonObject["variant"].asString)
    }

    @Test
    fun preservesNullReferences() {
        val decoded = codec.decode("""[null,null,"phoenix","heartbeat",{}]""")
        assertNull(decoded.joinRef)
        assertNull(decoded.ref)
        assertEquals("phoenix", decoded.topic)
        assertEquals("heartbeat", decoded.event)
    }
}
