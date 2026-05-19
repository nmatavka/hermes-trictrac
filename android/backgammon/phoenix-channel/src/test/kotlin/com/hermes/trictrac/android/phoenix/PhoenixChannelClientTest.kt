package com.hermes.trictrac.android.phoenix

import com.google.gson.JsonObject
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.async
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.runCurrent
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class PhoenixChannelClientTest {
    private val codec = PhoenixMessageCodec()

    @Test
    fun joinCorrelatesRepliesByRef() = runTest {
        val factory = FakeTransportFactory()
        val client = createClient(factory, this)
        val payload = JsonObject().apply {
            addProperty("user", "nick")
            addProperty("variant", "backgammon")
        }

        val reply = async { client.join("games:test", payload) }
        runCurrent()
        val joinFrame = codec.decode(factory.latest().sent.single())
        assertEquals("phx_join", joinFrame.event)
        assertEquals("games:test", joinFrame.topic)

        factory.latest().deliver(
            PhoenixEnvelope(
                joinRef = joinFrame.ref,
                ref = joinFrame.ref,
                topic = "games:test",
                event = "phx_reply",
                payload = replyPayload("ok") {
                    add("game", JsonObject())
                },
            )
        )

        val response = reply.await().asJsonObject
        assertTrue(response.has("game"))
        assertIs<PhoenixChannelClient.ConnectionState.Connected>(client.state.value)
    }

    @Test
    fun emitsHeartbeatFramesWhileConnected() = runTest {
        val factory = FakeTransportFactory()
        val client = createClient(
            factory = factory,
            scope = this,
            heartbeatIntervalMs = 1_000L,
        )

        client.connect()
        advanceTimeBy(1_000L)
        runCurrent()

        val heartbeat = codec.decode(factory.latest().sent.single())
        assertEquals("phoenix", heartbeat.topic)
        assertEquals("heartbeat", heartbeat.event)
    }

    @Test
    fun reconnectsAndRejoinsTrackedTopics() = runTest {
        val factory = FakeTransportFactory()
        val client = createClient(
            factory = factory,
            scope = this,
            heartbeatIntervalMs = 60_000L,
            reconnectDelayMs = 500L,
        )
        val payload = JsonObject().apply { addProperty("user", "nick") }

        val join = async { client.join("games:rejoin", payload) }
        runCurrent()
        val firstJoinFrame = codec.decode(factory.latest().sent.single())
        factory.latest().deliver(
            PhoenixEnvelope(
                joinRef = firstJoinFrame.ref,
                ref = firstJoinFrame.ref,
                topic = "games:rejoin",
                event = "phx_reply",
                payload = replyPayload("ok"),
            )
        )
        join.await()

        factory.latest().fail(IllegalStateException("boom"))
        advanceTimeBy(500L)
        runCurrent()

        val transports = factory.transports
        assertEquals(2, transports.size)
        val resentJoin = codec.decode(transports.last().sent.single())
        assertEquals("games:rejoin", resentJoin.topic)
        assertEquals("phx_join", resentJoin.event)
        assertIs<PhoenixChannelClient.ConnectionState.Connected>(client.state.value)
    }

    @Test
    fun routesUpdateEventsToSubscribers() = runTest {
        val factory = FakeTransportFactory()
        val client = createClient(factory, this)
        val received = mutableListOf<PhoenixEnvelope>()

        client.connect()
        client.on("games:table", "update") { received.add(it) }

        factory.latest().deliver(
            PhoenixEnvelope(
                topic = "games:table",
                event = "update",
                payload = JsonObject().apply {
                    add("game", JsonObject().apply { addProperty("status", "playing") })
                },
            )
        )

        runCurrent()
        assertEquals(1, received.size)
        assertEquals("playing", received.single().payload.asJsonObject["game"].asJsonObject["status"].asString)
    }

    private fun createClient(
        factory: FakeTransportFactory,
        scope: TestScope,
        heartbeatIntervalMs: Long = 60_000L,
        reconnectDelayMs: Long = 2_000L,
    ): PhoenixChannelClient {
        return PhoenixChannelClient(
            transportFactory = factory::create,
            scope = scope.backgroundScope,
            config = PhoenixChannelClient.Config(
                heartbeatIntervalMs = heartbeatIntervalMs,
                reconnectDelayMs = reconnectDelayMs,
                requestTimeoutMs = 5_000L,
            ),
        )
    }

    private fun replyPayload(status: String, build: (JsonObject.() -> Unit)? = null): JsonObject {
        val response = JsonObject().apply { build?.invoke(this) }
        return JsonObject().apply {
            addProperty("status", status)
            add("response", response)
        }
    }

    private class FakeTransportFactory {
        val transports = mutableListOf<FakeTransport>()

        fun create(): PhoenixSocketTransport {
            return FakeTransport(PhoenixMessageCodec()).also { transport ->
                transports += transport
            }
        }

        fun latest(): FakeTransport = transports.last()
    }

    private class FakeTransport(
        private val codec: PhoenixMessageCodec,
    ) : PhoenixSocketTransport {
        private var listener: PhoenixSocketTransport.Listener? = null
        val sent = mutableListOf<String>()

        override fun connect(listener: PhoenixSocketTransport.Listener) {
            this.listener = listener
            listener.onOpen()
        }

        override fun send(text: String): Boolean {
            sent += text
            return true
        }

        override fun disconnect(code: Int, reason: String) {
            listener?.onClosed(code, reason)
        }

        fun deliver(envelope: PhoenixEnvelope) {
            listener?.onMessage(codec.encode(envelope))
        }

        fun fail(throwable: Throwable) {
            listener?.onFailure(throwable)
        }
    }
}
