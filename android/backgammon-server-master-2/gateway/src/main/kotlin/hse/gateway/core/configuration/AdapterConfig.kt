package hse.gateway.core.configuration

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.web.client.RestClient

@Configuration
class AdapterConfig {

    @Bean
    fun restClient(): RestClient {
        return RestClient.create()
    }
}