package game.backgammon

import game.backgammon.lng.RegularGammonGame
import game.backgammon.sht.ShortGammonGame

class GammonRestorer {

    data class GammonRestoreContext(
        val deck: Map<Int, Int>,
        val turn: Int,
        var zarResult: List<Int>,
        val bar: Map<Int, Int>,
        val endFlag: Boolean,
    )

    companion object {
        fun restoreBackgammon(
            context: GammonRestoreContext
        ): ShortGammonGame {
            return ShortGammonGame(context)
        }

        fun restoreGammon(context: GammonRestoreContext): RegularGammonGame {
            return RegularGammonGame(context)
        }
    }
}