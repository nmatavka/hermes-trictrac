package hse.dto

import hse.entity.DoubleCube
import hse.wrapper.BackgammonWrapper

data class GameWithDoubleCubes(
    val game: BackgammonWrapper,
    val doubleCubes: List<DoubleCube>
)