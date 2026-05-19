package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.Constants.DICE_RANGE
import com.k1apps.backgammon.gamelogic.*

class PlayerIsInRemovePieceStrategy : PlayerPiecesActionStrategy() {

    override fun updateDiceBoxStatus(diceBox: DiceBox, pieceList: PieceList, board: Board) {
        if (pieceList.isInRemovePieceState().not()) {
            throw ChooseStrategyException("State is not in 'remove piece'")
        }
        diceBox.allActiveDicesNumbers().forEach { number ->
            if (isNumberLargestAllLocations(number, pieceList.list)) {
                val piece = findPieceWithLargestLocation(pieceList.list)
                // TODO: 10/11/19 Kayvan: View Interaction for active piece
                diceBox.enableDiceWith(number)
            }
            pieceList.list.forEach { piece ->
                if (number <= piece.locationInMySide()) {
                    val pieceAfterMove = piece.pieceAfterMove(number)
                    if (pieceAfterMove != null) {
                        if (board.canMovePiece(piece, pieceAfterMove)) {
                            // TODO: 10/11/19 Kayvan: View Interaction for active piece
                            diceBox.enableDiceWith(number)
                        }
                    } else {
                        // TODO: 10/11/19 Kayvan: View Interaction for active piece
                        diceBox.enableDiceWith(number)
                    }
                }
            }
        }
    }

    override fun move(dice: Dice, piece: Piece, board: Board): Boolean {
        if (piece.state != PieceState.IN_GAME) {
            throw ChooseStrategyException("Choose remove strategy with state: ${piece.state}")
        }
        if (piece.locationInMySide() !in DICE_RANGE) {
            throw ChooseStrategyException("Player is not on remove but selected")
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
            throw CellNumberException("Find dice called where StartCellNumber and destinationCellNumber are null")
        }
        if (StartCellNumber == null) {
            throw ChooseStrategyException("Find dice called while StartCellNumber is null")
        }
        if (StartCellNumber !in DICE_RANGE) {
            throw ChooseStrategyException("StartCellNumber is not in dice range")
        }

        if (destinationCellNumber == null) {
            return diceBox.getActiveDiceGreaterEqual(StartCellNumber)
        } else {
            val number = board.findDistanceBetweenTwoCell(StartCellNumber, destinationCellNumber)
            return diceBox.getActiveDiceWithNumber(number)
        }
    }

    private fun findPieceWithLargestLocation(pieces: List<Piece>): Piece? {
        if (pieces.isEmpty()) {
            return null
        }
        var piece = pieces[0]
        pieces.forEach {
            if (it.locationInMySide() > piece.locationInMySide()) {
                piece = it
            }
        }
        return piece
    }

    private fun isNumberLargestAllLocations(number: Byte, pieces: List<Piece>): Boolean {
        if (pieces.isEmpty()) {
            return false
        }
        pieces.forEach {
            if (number <= it.locationInMySide()) {
                return false
            }
        }
        return true
    }
}