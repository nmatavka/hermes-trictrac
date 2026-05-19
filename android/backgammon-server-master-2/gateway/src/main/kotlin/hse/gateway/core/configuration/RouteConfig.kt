package hse.gateway.core.configuration

import org.springframework.beans.factory.annotation.Value
import org.springframework.cloud.gateway.route.RouteLocator
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration

@Configuration
class RouteConfig(
    @Value("\${route.config.menu.uri}") private val menuUri: String,
    @Value("\${route.config.menu.path}") private val menuPath: String,
    @Value("\${route.config.backgammon-game.uri}") private val gammonUri: String,
    @Value("\${route.config.backgammon-game.path}") private val gammonPath: String,
    @Value("\${route.config.player-service.uri}") private val playerServiceUri: String,
    @Value("\${route.config.player-service.path}") private val playerServicePath: String,
) {

    @Bean
    fun routeLocator(builder: RouteLocatorBuilder): RouteLocator {
        return builder.routes()
            .route {
                it.path(menuPath)
                    .uri(menuUri)
            }
            .route {
                it.path(gammonPath)
                    .uri(gammonUri)
            }
            .route {
                it.path(playerServicePath)
                    .uri(playerServiceUri)
            }
            .build()
    }
}