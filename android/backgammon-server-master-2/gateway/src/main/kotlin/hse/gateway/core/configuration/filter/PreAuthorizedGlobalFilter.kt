package hse.gateway.core.configuration.filter

import hse.gateway.core.adapter.PlayerAdapter
import hse.gateway.core.service.SecurePathService
import org.springframework.beans.factory.annotation.Value
import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.core.Ordered
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseCookie
import org.springframework.stereotype.Component
import org.springframework.web.server.ResponseStatusException
import org.springframework.web.server.ServerWebExchange
import reactor.core.publisher.Mono

@Component
class PreAuthorizedGlobalFilter(
    @Value("\${route.token.name}") private val tokenName: String,
    @Value("\${route.header.auth-user.name}") private val authUserHeaderName: String,
    private val playerAdapter: PlayerAdapter,
    private val securePathService: SecurePathService,
) : GlobalFilter, Ordered {


    override fun filter(exchange: ServerWebExchange?, chain: GatewayFilterChain?): Mono<Void> {
        val path = exchange!!.request.path.value()

        if (!securePathService.isSecure(path, exchange.request.method)) {
            return chain!!.filter(exchange)
        }

        val currentToken =
            exchange.request.cookies[tokenName]?.firstOrNull()?.value
                ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Token not found")

        val jwt = playerAdapter.checkAuth(currentToken)

        exchange.response.cookies[tokenName] =
            mutableListOf(ResponseCookie.from(tokenName, jwt.token).path("/").build())

        val newRequest = exchange.mutate().request(
            exchange.request.mutate()
                .header(authUserHeaderName, jwt.userId.toString())
                .build()
        ).build()

        return chain!!.filter(newRequest)
    }

    override fun getOrder(): Int {
        return -2
    }
}