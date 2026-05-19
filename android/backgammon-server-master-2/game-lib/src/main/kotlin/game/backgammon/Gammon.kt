package game.backgammon

import game.backgammon.dto.*
import java.util.*

abstract class Gammon(
    val zar: Random = Random()
) {

    var turn = 0
    var zarResults: ArrayList<Int> = arrayListOf()
    var foolZar = ArrayList<Int>()
    var endFlag: Boolean = false

    companion object {
        const val BLACK = -1
        const val WHITE = 1

        const val REGULAR_DEFEAT = 1
        const val MARS_DEFEAT = 2
        const val KOKS_DEFEAT = 3
    }

    abstract fun reload(): Gammon
    abstract fun getConfiguration(): ConfigDto
    abstract fun move(user: Int, moves: List<MoveDto>): ChangeDto
    abstract fun getEndState(): EndDto?
    abstract fun tossBothZar(user: Int = turn): TossZarDto
    abstract fun checkEnd(): Boolean
    abstract fun getWinPoints(): Int
    abstract fun hasInStore(user: Int): Boolean
}