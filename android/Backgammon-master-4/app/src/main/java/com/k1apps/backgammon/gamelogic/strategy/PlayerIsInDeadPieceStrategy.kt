package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.Constants
import com.k1apps.backgammon.gamelogic.*

class PlayerIsInDeadPieceStrategy : PlayerPiecesActionStrategy() {
    override fun updateDiceBoxStatus(diceBox: DiceBox, list: PieceList, board: Board) {
        val deadList = list.deadPieces()
        if (deadList.isEmpty()) {
            throw ChooseStrategyException("There are no dead piece in list")
        }
        deadList.forEach { deadPiece ->
            diceBox.allActiveDicesNumbers().forEach { number->
                val pieceAfterMove = deadPiece.pieceAfterMove(number)
                pieceAfterMove?.let {
                    if (it.state == PieceState.IN_GAME && board.canMovePiece(deadPiece, it)) {
                        // TODO: 10/11/19 Kayvan: View Interaction for active piece
                        diceBox.enableDiceWith(number)
                    }
                }
            }
        }
    }

    override fun move(dice: Dice, piece: Piece, board: Board): Boolean {
        if (piece.state != PieceState.DEAD) {
            throw ChooseStrategyException("The selected piece is alive")
        }
        return board.move(piece, dice.number!!)
    }

    override fun findDice(
        StartCellNumber: Int?,
        destinationCellNumber: Int?,
        diceBox: DiceBox,
        board: Board
    ): Dice? {
        if (StartCellNumber == null && destinationCellNumber == null) {
            throw CellNumberException("Move method called where StartCellNumber and destinationCellNumber are null")
        }
        if (StartCellNumber != null) {
            throw ChooseStrategyException("There are no dead piece in list")
        }
        if (destinationCellNumber == null) {
            throw ChooseStrategyException("There are no dead piece in list")
        }
        if (destinationCellNumber !in Constants.DICE_RANGE) {
            throw CellNumberException("Move piece to Game with range greater than dice")
        }
        return diceBox.getActiveDiceWithNumber(destinationCellNumber)
    }
}