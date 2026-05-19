import io.ktor.server.application.*
import io.ktor.server.engine.*
import io.ktor.server.netty.*
import io.ktor.server.websocket.*
import server.configureGraphQl


fun main(args: Array<String>) {
    embeddedServer(Netty, port = 8080) {
        install(WebSockets)

        configureGraphQl()
    }.start(wait = true)
}

