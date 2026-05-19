package hse.dto

import game.backgammon.enums.Color
import game.backgammon.response.HistoryResponseItem
import game.backgammon.response.HistoryResponseItemType

data class GameEndHistoryResponseItem(
    val white: Int,
    val black: Int,
    val winner: Color,
    val isSurrendered: Boolean,
) : HistoryResponseItem(HistoryResponseItemType.GAME_END)