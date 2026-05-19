package com.joris.Backgammon.service

import com.joris.Backgammon.dto.*
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.awaitBody
import org.springframework.web.reactive.function.client.awaitExchange
import org.springframework.web.reactive.function.client.*


@Component
class BackgammonClient (
    @Value("\${backgammon.service.host}") final val backgammonServiceHost : String,
    @Value("\${backgammon.service.port}") final val backgammonServicePort : String

) {

    private val client = WebClient.create("${this.backgammonServiceHost}:$${this.backgammonServicePort}");
    private val logger = LoggerFactory.getLogger(this@BackgammonClient.javaClass)

    suspend fun predict(request: BackgammonServiceRequest): BackGammonServiceResponse {
        return client.post()
            .uri("/predict")
            .contentType(MediaType.APPLICATION_JSON)
            .bodyValue(request)
            .awaitExchange { response ->
                if (response.statusCode() == HttpStatus.OK) {
                    logger.info("successfully gotten the prediction result")
                    response.awaitBody()
                } else {
                    throw response.createExceptionAndAwait()
                }
            }
    }


}


