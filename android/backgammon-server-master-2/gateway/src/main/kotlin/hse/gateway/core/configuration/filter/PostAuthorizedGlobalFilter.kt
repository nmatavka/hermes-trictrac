package hse.gateway.core.configuration.filter

import com.fasterxml.jackson.databind.ObjectMapper
import hse.gateway.core.constant.toAuth
import org.reactivestreams.Publisher
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.cloud.gateway.filter.GatewayFilterChain
import org.springframework.cloud.gateway.filter.GlobalFilter
import org.springframework.cloud.gateway.filter.NettyWriteResponseFilter
import org.springframework.core.Ordered
import org.springframework.core.io.buffer.DataBuffer
import org.springframework.core.io.buffer.DefaultDataBufferFactory
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseCookie
import org.springframework.http.server.reactive.ServerHttpResponse
import org.springframework.http.server.reactive.ServerHttpResponseDecorator
import org.springframework.stereotype.Component
import org.springframework.web.server.ServerWebExchange
import player.response.JwtResponse
import reactor.core.publisher.Flux
import reactor.core.publisher.Mono


@Component
class PostAuthorizedGlobalFilter(
    @Value("\${route.token.name}") private val tokenName: String,
    @Value("\${route.header.auth-user.name}") private val authUserHeaderName: String,
    private val objectMapper: ObjectMapper,
) : GlobalFilter, Ordered {

    private val logger = LoggerFactory.getLogger(PostAuthorizedGlobalFilter::class.java)

    override fun filter(exchange: ServerWebExchange?, chain: GatewayFilterChain?): Mono<Void> {
        val path = exchange!!.request.path.value()

        if (path !in toAuth) {
            return chain!!.filter(exchange)
        }

        val response = putAuthTokenToResponse(exchange.response)

        return chain!!.filter(exchange.mutate().response(response).build())
    }

    override fun getOrder(): Int {
        return NettyWriteResponseFilter.WRITE_RESPONSE_FILTER_ORDER - 1
    }


    private fun putAuthTokenToResponse(response: ServerHttpResponse): ServerHttpResponseDecorator {
        return object : ServerHttpResponseDecorator(response) {
            override fun writeWith(body: Publisher<out DataBuffer>): Mono<Void> {
                if (body is Flux<out DataBuffer>) {
                    if (statusCode != HttpStatus.OK) {
                        return super.writeWith(body)
                    }
                    return super.writeWith(body.buffer().map { dataBuffers ->
                        val joinedBuffers = DefaultDataBufferFactory().join(dataBuffers)
                        val content = ByteArray(joinedBuffers.readableByteCount())
                        joinedBuffers.read(content)
                        val responseBody = String(content)
                        logger.info("получил $responseBody")
                        val jwtResponse = objectMapper.readValue(responseBody, JwtResponse::class.java)
                        response.addCookie(
                            ResponseCookie.from(tokenName, jwtResponse.token).secure(false).path("/").build()
                        )
                        response.bufferFactory().wrap(content)
                    })
                }
                return super.writeWith(body)
            }
        }
    }
}