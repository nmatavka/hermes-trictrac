package com.hermes.trictrac.android.phoenix

interface PhoenixSocketTransport {
    interface Listener {
        fun onOpen()
        fun onMessage(text: String)
        fun onFailure(throwable: Throwable)
        fun onClosed(code: Int, reason: String)
    }

    fun connect(listener: Listener)
    fun send(text: String): Boolean
    fun disconnect(code: Int = 1000, reason: String = "normal")
}
