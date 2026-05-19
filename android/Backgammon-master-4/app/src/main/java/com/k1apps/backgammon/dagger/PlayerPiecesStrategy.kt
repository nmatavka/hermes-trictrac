package com.k1apps.backgammon.dagger

import com.k1apps.backgammon.Constants.PLAYER_PIECES_STATE_DEAD
import com.k1apps.backgammon.Constants.PLAYER_PIECES_STATE_IN_GAME
import com.k1apps.backgammon.Constants.PLAYER_PIECES_STATE_REMOVE
import com.k1apps.backgammon.gamelogic.strategy.*
import dagger.Module
import dagger.Provides
import javax.inject.Named

@Module
open class PlayerPiecesStrategyModule {
    @Provides
    @GameScope
    open fun providePlayerPiecesContextStrategy(
        @Named(PLAYER_PIECES_STATE_IN_GAME)
        inGamePieceStrategy: PlayerPiecesActionStrategy,
        @Named(PLAYER_PIECES_STATE_REMOVE)
        removePieceStrategy: PlayerPiecesActionStrategy,
        @Named(PLAYER_PIECES_STATE_DEAD)
        deadPieceStrategy: PlayerPiecesActionStrategy
        ): PlayerPiecesContextStrategy {
        return PlayerPiecesContextStrategyImpl(
            inGamePieceStrategy,
            removePieceStrategy,
            deadPieceStrategy
        )
    }

    @Provides
    @Named(PLAYER_PIECES_STATE_IN_GAME)
    open fun providePlayerIsInGamePieceStrategy(): PlayerPiecesActionStrategy {
        return PlayerIsInGamePieceStrategy()
    }

    @Provides
    @Named(PLAYER_PIECES_STATE_REMOVE)
    open fun providePlayerIsInRemovePieceStrategy(): PlayerPiecesActionStrategy {
        return PlayerIsInRemovePieceStrategy()
    }

    @Provides
    @Named(PLAYER_PIECES_STATE_DEAD)
    open fun providePlayerIsInDeadPieceStrategy(): PlayerPiecesActionStrategy {
        return PlayerIsInDeadPieceStrategy()
    }
}