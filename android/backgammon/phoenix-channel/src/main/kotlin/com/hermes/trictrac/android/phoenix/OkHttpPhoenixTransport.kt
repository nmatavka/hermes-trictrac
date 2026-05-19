package com.hermes.trictrac.android.phoenix

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener

class OkHttpPhoenixTransport(
    private val websocketUrl: String,
    private val client: OkHttpClient = OkHttpClient(),
) : PhoenixSocketTransport {
    @Volatile
    private var webSocket: WebSocket? = null

    override fun connect(listener: PhoenixSocketTransport.Listener) {
        val request = Request.Builder().url(websocketUrl).build()
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                listener.onOpen()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                listener.onMessage(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                listener.onFailure(t)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                listener.onClosed(code, reason)
            }
        })
    }

    override fun send(text: String): Boolean = webSocket?.send(text) == true

    override fun disconnect(code: Int, reason: String) {
        webSocket?.close(code, reason)
        webSocket = null
    }
}
