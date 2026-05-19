package com.example.features.leaderboard

import io.ktor.server.application.*
import io.ktor.server.routing.*

fun Application.configureLeaderboardRouting() {
    routing {
        post("/updateWins") {
            val leaderboardController = LeaderboardController(call)
            leaderboardController.updateWins()
        }

        post("/getLeaders") {
            val leaderboardController = LeaderboardController(call)
            leaderboardController.getLeaders()
        }
    }
}