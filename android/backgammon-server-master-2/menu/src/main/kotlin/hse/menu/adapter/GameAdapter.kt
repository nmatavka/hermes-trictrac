package hse.menu.adapter

import game.backgammon.enums.BackgammonType
import game.backgammon.request.CreateBackgammonGameRequest
import game.common.enums.GameType
import hse.menu.entity.Game
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Component
import org.springframework.web.client.RestTemplate
import java.net.URI


@Component
class GameAdapter(
    @Value("\${route.config.backgammon-game.uri}") private val gameUri: String
) {

    private val restTemplate = RestTemplate()

    private val logger: Logger = LoggerFactory.getLogger(GameAdapter::class.java)

    private val gameAddr = "game"

    private val createRoomTemplate = "$gameUri/$gameAddr/%s/create-room/%d"
    fun gameCreation(game: Game): Int? {
        val uri = URI(
            when (game.gameType.type) {
                GameType.GeneralGameType.BACKGAMMON -> createRoomTemplate.format("backgammon", game.id)
            }
        )
        val request = when (game.gameType.type) {
            GameType.GeneralGameType.BACKGAMMON -> CreateBackgammonGameRequest(
                type = BackgammonType.valueOf(game.gameType.toString()),
                firstUserId = game.firstPlayerId.toInt(),
                secondUserId = game.secondPlayerId.toInt(),
                points = game.gamePoints.value,
                timePolicy = game.timePolicy
            )
        }

        return try {
            restTemplate.postForObject(uri, request, Int::class.java)
                ?: -1
        } catch (e: Exception) {
            logger.error(e.message)
            -1
        }
    }

}