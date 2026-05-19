package hse.gateway.core.adapter

import hse.gateway.core.constant.AUTH
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient
import org.springframework.web.server.ResponseStatusException
import player.response.JwtResponse

@Component
class PlayerAdapter(
    private val restClient: RestClient,
    @Value("\${route.config.player-service.uri}") private val authUri: String,
    @Value("\${route.token.name}") private val tokenName: String,
) {
    fun checkAuth(currentToken: String): JwtResponse {
        return restClient.get().uri("$authUri/$AUTH?$tokenName=$currentToken")
            .header("Content-Type", "application/json")
            .retrieve()
            .onStatus(
                { x -> x.isError },
                { _, _ -> throw ResponseStatusException(HttpStatus.UNAUTHORIZED) }
            )
            .body(JwtResponse::class.java) ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED)
    }
}