package game.backgammon.dto

import com.fasterxml.jackson.annotation.JsonInclude
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color

data class ConfigResponseDto(
    val color: Color?,
    val turn: Color,
    @JsonInclude(JsonInclude.Include.NON_EMPTY)
    val bar: Map<Color, Int>,
    val deck: Set<DeckItemDto>,
    val zar: List<Int>,
    val first: Boolean,
    val type: BackgammonType
)