package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.Constants.BOARD_LOCATION_RANGE
import com.k1apps.backgammon.gamelogic.*

abstract class PlayerPiecesActionStrategy {
    abstract fun updateDiceBoxStatus(diceBox: DiceBox, list: PieceList, board: Board)

    abstract fun move(dice: Dice, piece: Piece, board: Board): Boolean

    abstract fun findDice(StartCellNumber: Int?,
                          destinationCellNumber: Int?,
                          diceBox: DiceBox,
                          board: Board): Dice?
}