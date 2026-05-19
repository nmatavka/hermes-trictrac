package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.gamelogic.PieceList

interface PlayerPiecesContextStrategy {
    fun getPlayerPiecesStrategy(pieces: PieceList): PlayerPiecesActionStrategy
}

class PlayerPiecesContextStrategyImpl(
    private val inGamePieceStrategy: PlayerPiecesActionStrategy,
    private val removePieceStrategy: PlayerPiecesActionStrategy,
    private val deadPieceStrategy: PlayerPiecesActionStrategy
) : PlayerPiecesContextStrategy {
    override fun getPlayerPiecesStrategy(pieces: PieceList): PlayerPiecesActionStrategy {
        when {
            pieces.haveDiedPiece() -> return deadPieceStrategy
            pieces.isInRemovePieceState() -> return removePieceStrategy
        }
        return inGamePieceStrategy
    }
}