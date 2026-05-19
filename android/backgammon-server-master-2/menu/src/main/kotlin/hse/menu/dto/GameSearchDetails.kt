package hse.menu.dto

import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy

data class GameSearchDetails(
    val gameType: GameType,
    val points: GammonGamePoints,
    val timePolicy: TimePolicy
)