package com.example.features.logout

import com.example.database.tokens.TokenDTO
import com.example.database.tokens.Tokens
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.request.*
import io.ktor.server.response.*

class LogoutController(private val call: ApplicationCall) {
    suspend fun performLogout() {
        val receive = call.receive<LogoutReceiveRemote>()
        val tokens = Tokens.fetchTokens(receive.login)
        if (!tokens.contains(receive.token)) {
            call.respond(HttpStatusCode.BadRequest, "User logged out or does not exist")
        } else {
            Tokens.deleteToken(TokenDTO(receive.login, receive.token))
            call.respond(HttpStatusCode.OK)
        }
    }
}