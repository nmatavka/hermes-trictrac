package hse.dto

import game.backgammon.response.HistoryResponseItem
import game.backgammon.response.HistoryResponseItemType
import java.io.Serializable

data class MoveHistoryResponseItem(
    val dice: List<Int>,
    val moves: List<MoveItem>
) : HistoryResponseItem(HistoryResponseItemType.MOVE) {
    data class MoveItem(val from: Int, val to: Int) : Serializable
}