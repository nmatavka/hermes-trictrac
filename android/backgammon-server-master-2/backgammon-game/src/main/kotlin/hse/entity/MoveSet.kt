package hse.entity

import game.backgammon.dto.ChangeDto
import game.backgammon.enums.Color

data class MoveSet(
    val moves: ChangeDto,
    val gameId: Int,
    val moveId: Int,
    val color: Color,
)