package com.example.features.logout

import kotlinx.serialization.Serializable

@Serializable
data class LogoutReceiveRemote(
    val login: String,
    val token: String
)