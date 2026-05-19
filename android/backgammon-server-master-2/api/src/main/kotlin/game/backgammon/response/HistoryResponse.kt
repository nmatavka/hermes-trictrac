package game.backgammon.response

import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import java.io.Serializable

data class HistoryResponse(
    val items: List<HistoryResponseItem>,
    val firstToMove: Color,
    val gameId: Int,
    val thresholdPoints: Int,
    val type: BackgammonType
): Serializable

open class HistoryResponseItem(
    val type: HistoryResponseItemType,
): Serializable

enum class HistoryResponseItemType {
    MOVE,
    OFFER_DOUBLE,
    ACCEPT_DOUBLE,
    GAME_END,
}