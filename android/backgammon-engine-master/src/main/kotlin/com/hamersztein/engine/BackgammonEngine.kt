package com.hamersztein.engine

import com.hamersztein.engine.model.Board
import com.hamersztein.engine.model.Colour
import com.hamersztein.engine.model.DiceThrow

class BackgammonEngine(private val board: Board = Board(), private val diceThrower: DiceThrower = DiceThrower()) {

    fun setup() {
        board.setup()
    }

    fun throwDice(): DiceThrow = diceThrower()

    fun isMovePossible(colour: Colour, from: Int, to: Int): Boolean {
        return board.isMovePossible(colour, from, to)
    }

    fun movePiece(colour: Colour, from: Int, to: Int) {
        board.movePiece(colour, from - 1, to - 1)
    }

    override fun toString(): String {
        return board.toString()
    }

}