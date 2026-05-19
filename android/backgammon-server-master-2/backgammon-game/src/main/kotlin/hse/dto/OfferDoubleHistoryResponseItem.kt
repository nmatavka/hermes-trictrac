package hse.dto

import game.backgammon.enums.Color
import game.backgammon.response.HistoryResponseItem
import game.backgammon.response.HistoryResponseItemType

data class OfferDoubleHistoryResponseItem(
    val by: Color,
    val newValue: Int,
) : HistoryResponseItem(HistoryResponseItemType.OFFER_DOUBLE)