package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.gamelogic.*

class PlayerIsInGamePieceStrategy : PlayerPiecesActionStrategy() {

    override fun updateDiceBoxStatus(diceBox: DiceBox, list: PieceList, board: Board) {
        val headPieces = list.getHeadsPieces()
        headPieces.forEach { piece ->
            diceBox.allActiveDicesNumbers().forEach { number ->
                val pieceAfterMove = piece.pieceAfterMove(number)
                if (pieceAfterMove != null && board.canMovePiece(piece, pieceAfterMove)) {
                    // TODO: 10/11/19 Kayvan: View Interaction for active piece
                    diceBox.enableDiceWith(number)
                }
            }
        }
    }

    override fun move(dice: Dice, piece: Piece, board: Board): Boolean {
        if (piece.state != PieceState.IN_GAME) {
            throw ChooseStrategyException("Choose in game strategy with state: ${piece.state}")
        }
        if (piece.pieceAfterMove(dice.number!!) == null) {
            throw ChooseStrategyException("Selected piece with number is out of board range")
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
        if (StartCellNumber == null || destinationCellNumber == null) {
            throw ChooseStrategyException("Find dice called while one of selected cell is null")
        }
        val number = board.findDistanceBetweenTwoCell(StartCellNumber, destinationCellNumber)
        return diceBox.getActiveDiceWithNumber(number)
    }
}