package com.example.features.leaderboard

import com.example.database.tokens.Tokens
import com.example.database.users.Users
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*

class LeaderboardController (private val call: ApplicationCall) {
    suspend fun updateWins(){
        val receive = call.receive<UpdateScoreReceiveRemote>()
        val tokens = Tokens.fetchTokens(receive.login)
        if (!tokens.contains(receive.token)) {
            call.respond(HttpStatusCode.BadRequest, "User logged out or does not exist")
        } else {
            Users.updateScore(receive.login)
            call.respond(HttpStatusCode.OK)
        }
    }

    suspend fun getLeaders() {
        val leaders = Users.fetchLeaders()
        call.respond(HttpStatusCode.OK, leaders)
    }
}