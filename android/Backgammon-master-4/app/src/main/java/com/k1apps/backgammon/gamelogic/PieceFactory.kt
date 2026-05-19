package com.k1apps.backgammon.gamelogic

object PieceFactory {
    fun createReversePiece(): Piece {
        return PieceImpl(MoveType.Revers)
    }
    fun createNormalPiece(): Piece {
        return PieceImpl(MoveType.Normal)
    }
}