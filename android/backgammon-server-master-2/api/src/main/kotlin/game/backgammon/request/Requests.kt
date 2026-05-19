package game.backgammon.request

import game.backgammon.dto.MoveDto
import game.backgammon.enums.BackgammonType
import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy

data class CreateGameRequest(
    val type: GameType,
    val points: Int = GammonGamePoints.THREE.value,
    val timePolicy: TimePolicy = TimePolicy.NO_TIMER,
)

data class MoveRequest(
    val moves: List<MoveDto>
)

data class CreateBackgammonGameRequest(
    val type: BackgammonType,
    val firstUserId: Int,
    val secondUserId: Int,
    val points: Int,
    val timePolicy: TimePolicy = TimePolicy.NO_TIMER
)