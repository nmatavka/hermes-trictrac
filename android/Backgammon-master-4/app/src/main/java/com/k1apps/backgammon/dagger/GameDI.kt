package com.k1apps.backgammon.dagger

import com.k1apps.backgammon.Constants
import com.k1apps.backgammon.Constants.NORMAL_PIECE_LIST
import com.k1apps.backgammon.Constants.NORMAL_PLAYER
import com.k1apps.backgammon.Constants.REVERSE_PIECE_LIST
import com.k1apps.backgammon.Constants.REVERSE_PLAYER
import com.k1apps.backgammon.DiceStatus
import com.k1apps.backgammon.gamelogic.*
import com.k1apps.backgammon.gamelogic.strategy.PlayerPiecesContextStrategy
import dagger.Component
import dagger.Module
import dagger.Provides
import javax.inject.Named
import javax.inject.Scope
import kotlin.random.Random

@Scope
@Retention
annotation class GameScope

@GameScope
@Component(modules = [GameModule::class])
interface GameComponent

@Module(includes = [BoardModule::class, DiceDistributorModule::class])
class GameModule {
    @Provides
    @GameScope
    fun provideGame(
        board: Board,
        diceDistributor: DiceDistributor
    ): Game {
        return GameImpl(board, diceDistributor)
    }
}

@Module(includes = [PlayerModule::class, DiceBoxModule::class])
open class DiceDistributorModule {

    @GameScope
    @Provides
    open fun provideDiceDistributor(
        @Named(NORMAL_PLAYER) player1: Player,
        @Named(REVERSE_PLAYER) player2: Player,
        diceBox: DiceBox
    ): DiceDistributor {
        return DiceDistributorImpl(player1, player2, diceBox)
    }
}

@Module
open class BoardModule {
    @Provides
    @GameScope
    open fun provideBoard(
        @Named(NORMAL_PIECE_LIST) normalPieceList: PieceList,
        @Named(REVERSE_PIECE_LIST) reversePieceList: PieceList,
        cells: List<BoardCell>
    ): Board {
        return BoardImpl(normalPieceList, reversePieceList, cells)
    }

    @Provides
    @GameScope
    fun provideCells(): List<BoardCell> {
        val list = arrayListOf<BoardCell>()
        for (item in Constants.BOARD_LOCATION_RANGE) {
            list.add(BoardCellImpl(arrayListOf()))
        }
        return list
    }
}

@Module(includes = [PieceListModule::class, BoardModule::class, PlayerPiecesStrategyModule::class])
open class PlayerModule {
    @GameScope
    @Provides
    @Named(NORMAL_PLAYER)
    open fun providePlayer1(
        @Named(NORMAL_PIECE_LIST) pieceList: PieceList,
        board: Board,
        playerPiecesContextStrategy: PlayerPiecesContextStrategy
    ): Player {
        return PlayerImpl(PlayerType.LocalPlayer, pieceList, MoveType.Normal, board,
            playerPiecesContextStrategy)
    }

    @GameScope
    @Provides
    @Named(REVERSE_PLAYER)
    open fun providePlayer2(
        @Named(REVERSE_PIECE_LIST) pieceList: PieceList,
        board: Board,
        playerPiecesContextStrategy: PlayerPiecesContextStrategy
    ): Player {
        return PlayerImpl(PlayerType.LocalPlayer, pieceList, MoveType.Revers, board,
            playerPiecesContextStrategy)
    }

}


@Module
open class PieceListModule {

    @Provides
    @GameScope
    @Named(NORMAL_PIECE_LIST)
    open fun provideNormalList(): PieceList {
        return NormalPieceList()
    }

    @Provides
    @GameScope
    @Named(REVERSE_PIECE_LIST)
    open fun provideReverseList(): PieceList {
        return ReversePieceList()
    }

}

@Module
open class DiceBoxModule {
    @Provides
    @GameScope
    open fun provideDiceBox(
        dice1: Dice,
        dice2: Dice
    ): DiceBox {
        return DiceBoxImpl(dice1, dice2)
    }

    @Provides
    open fun provideDice(random: Random, status: DiceStatus): Dice {
        return DiceImpl(random, status)
    }

    @Provides
    @GameScope
    open fun provideRandom(): Random {
        return Random
    }
}