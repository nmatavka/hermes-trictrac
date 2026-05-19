package com.example.features.leaderboard

import kotlinx.serialization.Serializable

@Serializable
data class UpdateScoreReceiveRemote(
    val login: String,
    val token: String
)