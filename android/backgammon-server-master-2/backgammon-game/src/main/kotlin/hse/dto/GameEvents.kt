package hse.dto

import game.backgammon.dto.MoveResponseDto
import game.backgammon.enums.Color
import hse.enums.EventType

abstract class GameEvent(val type: EventType)

data class GameStartedEvent(
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.GAME_STARTED_EVENT)

data class MoveEvent(
    val moves: List<MoveResponseDto>,
    val color: Color,
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.MOVE_EVENT)

data class PlayerConnectedEvent(
    val color: Color,
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.PLAYER_CONNECTED_EVENT)

data class EndGameEvent(
    val win: Color,
    val blackPoints: Int,
    val whitePoints: Int,
    val isMatchEnd: Boolean,
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.END_GAME_EVENT)


data class TossZarEvent(
    val value: Collection<Int>,
    val tossedBy: Color,
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.TOSS_ZAR_EVENT)

data class DoubleEvent(
    val by: Color,
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.DOUBLE_EVENT)

data class AcceptDoubleEvent(
    val by: Color,
    val remainBlackTime: Long?,
    val remainWhiteTime: Long?,
) : GameEvent(EventType.ACCEPT_DOUBLE_EVENT)