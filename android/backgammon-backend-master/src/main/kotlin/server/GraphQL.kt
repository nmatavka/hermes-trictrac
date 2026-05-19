package server

import com.expediagroup.graphql.server.ktor.*
import com.expediagroup.graphql.server.operations.Query
import com.lordcodes.turtle.shellRun
import gnubg.shellProcess
import io.ktor.http.*
import io.ktor.server.application.*
import io.ktor.server.plugins.cors.routing.*
import io.ktor.server.routing.*
import utils.dotenvInstance
import utils.getEnvVar

object HelloQuery : Query {
    fun hello() = "Hello :)"
}

object GnubgVersion : Query {
    fun gnubgVersion(): String {
        val command = getEnvVar("GNUBG_COMMAND") ?: "gnubg"

        return shellRun(command, listOf("-t", "--version")).lines().firstOrNull()
            ?: "No GNUBG version found."
    }
}

fun Application.configureGraphQl() {
    install(CORS) {
        allowHeader(HttpHeaders.AccessControlAllowOrigin)
        allowHeader(HttpHeaders.ContentType)

        anyHost()
        anyMethod()
    }

    install(GraphQL) {
        schema {
            packages =
                listOf(
                    "server",
                    "game",
                    "gnubg",
                    "analysis",
                    "utils",
                    "match",
                )


            queries = listOf(HelloQuery, GnubgVersion)

            mutations = listOf(GameMutations)

            subscriptions = listOf(
                GameSubscription,
                LobbySubscription
            )
        }
    }


    routing {
        graphQLGetRoute()
        graphQLPostRoute()
        graphQLSubscriptionsRoute()
        graphiQLRoute()
        graphQLSDLRoute()
    }
}
