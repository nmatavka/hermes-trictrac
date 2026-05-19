package com.example

import com.example.features.leaderboard.configureLeaderboardRouting
import com.example.features.login.configureLoginRouting
import com.example.features.logout.configureLogoutRouting
import com.example.features.register.configureRegisterRouting
import io.ktor.server.application.*
import io.ktor.server.cio.*
import io.ktor.server.engine.*
import org.jetbrains.exposed.sql.Database

fun main() {
    Database.connect("jdbc:oracle:thin:@localhost:1521", "oracle.jdbc.OracleDriver", "backgammon", "backgammon")
    embeddedServer(CIO, port = 9090, host = "0.0.0.0", module = Application::module)
        .start(wait = true)
}

fun Application.module() {
    configureSerialization()
    configureRegisterRouting()
    configureLoginRouting()
    configureLogoutRouting()
    configureLeaderboardRouting()
}
