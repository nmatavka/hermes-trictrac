package com.hamersztein

import com.hamersztein.engine.BackgammonEngine
import com.hamersztein.engine.model.Colour.DARK
import com.hamersztein.engine.model.Colour.LIGHT
import com.hamersztein.engine.model.DiceThrow

fun main() {
    val engine = BackgammonEngine()
    engine.setup()

    var currentPlayer = LIGHT
    var thrownDice: DiceThrow

    while (true) {
        thrownDice = engine.throwDice()

        println("$currentPlayer rolled ${thrownDice.left} and ${thrownDice.right}")

        when {
            thrownDice.difference == 2 -> {
                engine.movePiece(currentPlayer, 8, 8 - thrownDice.larger)
                engine.movePiece(currentPlayer, 6, 6 - thrownDice.smaller)
            }

            thrownDice.isDouble -> {
                engine.movePiece(currentPlayer, 8, 8 - thrownDice.left)
                engine.movePiece(currentPlayer, 8, 8 - thrownDice.left)

                engine.movePiece(currentPlayer, 13, 13 - thrownDice.left)
                engine.movePiece(currentPlayer, 13, 13 - thrownDice.left)
            }

            else -> {
                engine.movePiece(currentPlayer, 24, 24 - thrownDice.total)
            }
        }

        println(engine)
        println("---")
        println()

        currentPlayer = if (currentPlayer == LIGHT) DARK else LIGHT
        Thread.sleep(5000)
    }
}
