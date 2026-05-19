package kafka

import game.backgammon.enums.BackgammonType
import game.common.enums.TimePolicy

class GameEndMessage(
    val matchId: Long,
    val winnerId: Long,
    val loserId: Long,
    val gameType: BackgammonType,
    val gameTimePolicy: TimePolicy
)