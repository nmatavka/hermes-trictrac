package hse.menu.dto

import game.common.enums.GameType
import java.util.concurrent.CountDownLatch

data class ConnectionDto(
    val userId: Long,
    val latch: CountDownLatch,
    val gameType: GameType,
    val userRating: Int,
    var gameId: Int? = null,
)