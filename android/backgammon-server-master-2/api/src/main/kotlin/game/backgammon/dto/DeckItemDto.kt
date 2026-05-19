package game.backgammon.dto

import game.backgammon.enums.Color

data class DeckItemDto(
    val color: Color,
    val count: Int,
    val id: Int
)