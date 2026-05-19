package com.hermes.trictrac.android.phoenix

import kotlin.test.Test
import kotlin.test.assertEquals

class PhoenixSocketUrlTest {
    @Test
    fun buildsPhoenixWebSocketUrlFromHttpOrigin() {
        assertEquals(
            "ws://localhost:4000/socket/websocket?vsn=2.0.0",
            PhoenixSocketUrl.build("http://localhost:4000"),
        )
    }

    @Test
    fun preservesSecureScheme() {
        assertEquals(
            "wss://example.com/socket/websocket?vsn=2.0.0",
            PhoenixSocketUrl.build("https://example.com"),
        )
    }
}
