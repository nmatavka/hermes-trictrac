package com.hermes.trictrac.android.phoenix

import com.google.gson.JsonElement
import com.google.gson.JsonObject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeout
import java.io.Closeable
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicLong

class PhoenixChannelClient(
    private val transportFactory: () -> PhoenixSocketTransport,
    private val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
    private val codec: PhoenixMessageCodec = PhoenixMessageCodec(),
    private val config: Config = Config(),
) {
    data class Config(
        val heartbeatIntervalMs: Long = 30_000L,
        val reconnectDelayMs: Long = 2_000L,
        val requestTimeoutMs: Long = 10_000L,
    )

    sealed interface ConnectionState {
        data object Disconnected : ConnectionState
        data object Connecting : ConnectionState
        data object Connected : ConnectionState
        data class Reconnecting(val attempt: Int) : ConnectionState
    }

    private data class EventKey(val topic: String, val event: String)

    private val connectionState = MutableStateFlow<ConnectionState>(ConnectionState.Disconnected)
    private val incomingEvents = MutableSharedFlow<PhoenixEnvelope>(extraBufferCapacity = 64)
    private val replyWaiters = ConcurrentHashMap<String, kotlinx.coroutines.CompletableDeferred<PhoenixEnvelope>>()
    private val joinPayloads = ConcurrentHashMap<String, JsonElement>()
    private val joinRefs = ConcurrentHashMap<String, String>()
    private val handlers =
        ConcurrentHashMap<EventKey, CopyOnWriteArrayList<(PhoenixEnvelope) -> Unit>>()
    private val refCounter = AtomicLong(0L)
    private val connectionMutex = Mutex()

    @Volatile
    private var currentTransport: PhoenixSocketTransport? = null

    @Volatile
    private var openGate: kotlinx.coroutines.CompletableDeferred<Unit>? = null

    @Volatile
    private var manualDisconnect = false

    @Volatile
    private var reconnectAttempt = 0

    private var heartbeatJob: Job? = null
    private var reconnectJob: Job? = null

    val state: StateFlow<ConnectionState> = connectionState.asStateFlow()
    val events: SharedFlow<PhoenixEnvelope> = incomingEvents.asSharedFlow()

    suspend fun connect() {
        if (connectionState.value is ConnectionState.Connected) return

        val gate = connectionMutex.withLock {
            if (connectionState.value is ConnectionState.Connected) {
                return
            }

            openGate?.takeUnless { it.isCompleted } ?: kotlinx.coroutines.CompletableDeferred<Unit>().also { deferred ->
                openGate = deferred
                manualDisconnect = false
                connectionState.value = ConnectionState.Connecting
                currentTransport = transportFactory().also { transport ->
                    transport.connect(socketListener)
                }
            }
        }

        gate.await()
    }

    suspend fun disconnect() {
        connectionMutex.withLock {
            manualDisconnect = true
            heartbeatJob?.cancel()
            reconnectJob?.cancel()
            reconnectJob = null
            replyWaiters.values.forEach { it.cancel() }
            replyWaiters.clear()
            openGate?.cancel()
            openGate = null
            currentTransport?.disconnect()
            currentTransport = null
            connectionState.value = ConnectionState.Disconnected
        }
    }

    suspend fun join(
        topic: String,
        payload: JsonObject,
        timeoutMs: Long = config.requestTimeoutMs,
    ): JsonElement {
        joinPayloads[topic] = payload.deepCopy()
        return pushAwaitReply(
            topic = topic,
            event = EVENT_JOIN,
            payload = payload,
            timeoutMs = timeoutMs,
            recordJoinRef = true,
        )
    }

    suspend fun push(
        topic: String,
        event: String,
        payload: JsonElement = JsonObject(),
        timeoutMs: Long = config.requestTimeoutMs,
    ): JsonElement = pushAwaitReply(topic, event, payload, timeoutMs)

    fun on(topic: String, event: String, handler: (PhoenixEnvelope) -> Unit): Closeable {
        val key = EventKey(topic, event)
        val bucket = handlers.computeIfAbsent(key) { CopyOnWriteArrayList() }
        bucket.add(handler)
        return Closeable { bucket.remove(handler) }
    }

    private suspend fun pushAwaitReply(
        topic: String,
        event: String,
        payload: JsonElement,
        timeoutMs: Long,
        recordJoinRef: Boolean = false,
    ): JsonElement {
        connect()

        val ref = nextRef()
        val joinRef = if (event == EVENT_JOIN) ref else joinRefs[topic]
        val envelope = PhoenixEnvelope(
            joinRef = joinRef,
            ref = ref,
            topic = topic,
            event = event,
            payload = payload,
        )

        val waiter = kotlinx.coroutines.CompletableDeferred<PhoenixEnvelope>()
        replyWaiters[ref] = waiter

        val sent = currentTransport?.send(codec.encode(envelope)) == true
        if (!sent) {
            replyWaiters.remove(ref)
            throw IllegalStateException("Unable to send Phoenix frame for $topic:$event")
        }

        val reply = try {
            withTimeout(timeoutMs) { waiter.await() }.reply()
        } finally {
            replyWaiters.remove(ref)
        }

        if (recordJoinRef && reply.status == STATUS_OK) {
            joinRefs[topic] = ref
        }

        if (reply.status != STATUS_OK) {
            throw PhoenixReplyException(topic, event, reply.status, reply.response)
        }

        return reply.response
    }

    private fun nextRef(): String = refCounter.incrementAndGet().toString()

    private val socketListener = object : PhoenixSocketTransport.Listener {
        override fun onOpen() {
            reconnectAttempt = 0
            connectionState.value = ConnectionState.Connected
            openGate?.complete(Unit)
            heartbeatJob?.cancel()
            heartbeatJob = scope.launch {
                while (true) {
                    delay(config.heartbeatIntervalMs)
                    if (connectionState.value !is ConnectionState.Connected) break
                    sendFireAndForget(
                        PhoenixEnvelope(
                            ref = nextRef(),
                            topic = TOPIC_SYSTEM,
                            event = EVENT_HEARTBEAT,
                            payload = JsonObject(),
                        )
                    )
                }
            }
            if (joinRefs.isNotEmpty()) {
                scope.launch {
                    rejoinTopics()
                }
            }
        }

        override fun onMessage(text: String) {
            val envelope = codec.decode(text)
            scope.launch {
                if (envelope.event == EVENT_REPLY) {
                    val ref = envelope.ref
                    if (ref != null) {
                        replyWaiters.remove(ref)?.complete(envelope)
                    }
                }

                incomingEvents.emit(envelope)
                handlers[EventKey(envelope.topic, envelope.event)]?.forEach { handler ->
                    handler(envelope)
                }
            }
        }

        override fun onFailure(throwable: Throwable) {
            openGate?.completeExceptionally(throwable)
            openGate = null
            markDisconnectedAndReconnect()
        }

        override fun onClosed(code: Int, reason: String) {
            openGate = null
            markDisconnectedAndReconnect()
        }
    }

    private fun sendFireAndForget(envelope: PhoenixEnvelope) {
        currentTransport?.send(codec.encode(envelope))
    }

    private suspend fun rejoinTopics() {
        joinPayloads.entries
            .sortedBy { it.key }
            .forEach { (topic, payload) ->
                val ref = nextRef()
                joinRefs[topic] = ref
                sendFireAndForget(
                    PhoenixEnvelope(
                        joinRef = ref,
                        ref = ref,
                        topic = topic,
                        event = EVENT_JOIN,
                        payload = payload.deepCopy(),
                    )
                )
            }
    }

    private fun markDisconnectedAndReconnect() {
        heartbeatJob?.cancel()
        heartbeatJob = null
        currentTransport = null

        if (manualDisconnect) {
            connectionState.value = ConnectionState.Disconnected
            return
        }

        reconnectJob?.cancel()
        reconnectAttempt += 1
        connectionState.value = ConnectionState.Reconnecting(reconnectAttempt)
        reconnectJob = scope.launch {
            delay(config.reconnectDelayMs)
            runCatching {
                connect()
            }
        }
    }

    companion object {
        const val EVENT_HEARTBEAT = "heartbeat"
        const val EVENT_JOIN = "phx_join"
        const val EVENT_REPLY = "phx_reply"
        const val STATUS_OK = "ok"
        const val TOPIC_SYSTEM = "phoenix"
    }
}
