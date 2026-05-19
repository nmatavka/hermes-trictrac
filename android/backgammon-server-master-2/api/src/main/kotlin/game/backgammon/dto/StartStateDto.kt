package game.backgammon.dto

import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color

data class StartStateDto(
    val userMap: Map<Color, Int>,
    val type: BackgammonType,
    val deck: Map<Int, Int>,
    val turn: Int,
    val zarResult: List<Int>,
)