package com.hermes.trictrac.android.phoenix

import java.net.URI

object PhoenixSocketUrl {
    fun build(
        baseUrl: String,
        socketPath: String = "/socket/websocket",
        vsn: String = "2.0.0",
    ): String {
        val base = URI(baseUrl)
        val scheme = when (base.scheme) {
            "http" -> "ws"
            "https" -> "wss"
            "ws", "wss" -> base.scheme
            else -> throw IllegalArgumentException("Unsupported scheme in $baseUrl")
        }
        val path = if (socketPath.startsWith("/")) socketPath else "/$socketPath"
        val query = listOfNotNull(base.query?.takeIf { it.isNotBlank() }, "vsn=$vsn").joinToString("&")

        return URI(
            scheme,
            base.userInfo,
            base.host,
            base.port,
            path,
            query,
            null,
        ).toString()
    }
}
