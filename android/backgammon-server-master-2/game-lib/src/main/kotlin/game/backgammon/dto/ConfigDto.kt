package game.backgammon.dto

data class ConfigDto(
    val zar: List<Int>,
    val turn: Int,
    val deck: List<Int>,
    val bar: Map<Int, Int>,
)