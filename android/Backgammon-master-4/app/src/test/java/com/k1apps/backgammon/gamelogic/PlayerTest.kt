package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.gamelogic.event.DiceThrownEvent
import com.k1apps.backgammon.gamelogic.event.DiceBoxThrownEvent
import com.k1apps.backgammon.gamelogic.event.GameEndedEvent
import com.k1apps.backgammon.gamelogic.event.MoveCompletedEvent
import com.k1apps.backgammon.gamelogic.strategy.PlayerPiecesActionStrategy
import com.k1apps.backgammon.gamelogic.strategy.PlayerPiecesContextStrategy
import org.greenrobot.eventbus.EventBus
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.*
import org.mockito.Mock
import org.mockito.Spy
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class PlayerTest {

    private lateinit var player: Player
    @Mock
    private lateinit var diceDistributor: DiceDistributorImpl
    @Mock
    private lateinit var board: Board
    @Spy
    private var diceBox = DiceBoxImpl(mock(Dice::class.java), mock(Dice::class.java))
    @Mock
    private lateinit var contextStrategy: PlayerPiecesContextStrategy
    @Spy
    private var pieceList = NormalPieceList()

    @Before
    fun setup() {
        player =
            PlayerImpl(PlayerType.LocalPlayer, pieceList, MoveType.Normal, board, contextStrategy)
        EventBus.getDefault().register(diceDistributor)
    }

    @Test
    fun given_roll_called_when_player_has_dice_then_roll_dice_and_post_dice_thrown_event_invoked() {
        val diceMock: Dice = mock(Dice::class.java)
        `when`(diceMock.roll()).thenReturn(2)
        player.dice = diceMock
        player.roll()
        verify(diceDistributor, times(1)).onEvent(DiceThrownEvent(player))
    }

    @Test
    fun given_roll_called_when_player_has_diceBox_then_roll_diceBox_and_post_dice_box_thrown_event_callback_invoked() {
        player.diceBox = diceBox
        player.roll()
        verify(diceBox).roll()
        verify(diceDistributor, times(1)).onEvent(DiceBoxThrownEvent(player))
    }

    @Test
    fun given_retakeDice_called_then_dice_should_be_null() {
        player.dice = diceBox.dice1
        assertTrue(player.dice != null)
        player.retakeDice()
        assertTrue(player.dice == null)
    }

    @Test
    fun given_retakeDiceBox_called_then_diceBox_should_be_null() {
        player.diceBox = diceBox
        assertTrue(player.diceBox != null)
        player.retakeDiceBox()
        assertTrue(player.diceBox == null)
    }

    @Test
    fun given_roll_called_with_dice_box_then_roll_dice_box() {
        player.diceBox = diceBox
        player.roll()
        verify(player.diceBox, times(1))!!.roll()
    }

    @Test
    fun given_updateDiceBoxStatus_called_then_playerPieceContextStrategy_updateDiceBoxStatus_should_be_called() {
        player.diceBox = diceBox
        val mockStrategy = mock(PlayerPiecesActionStrategy::class.java)
        `when`(contextStrategy.getPlayerPiecesStrategy(pieceList)).thenReturn(mockStrategy)
        player.updateDiceBoxStatus()
        verify(mockStrategy).updateDiceBoxStatus(diceBox, pieceList, board)
    }

    @Test(expected = MoveException::class)
    fun given_move_called_when_player_does_not_have_diceBox_then_throw_MoveException() {
        player.move(null, null)
    }

    @Test(expected = MoveException::class)
    fun given_move_called_when_startCellNumber_is_null_and_player_does_not_have_dead_piece_then_throw_MoveException() {
        val mockInGamePiece = mock(Piece::class.java)
        mockInGamePiece.state = PieceState.IN_GAME
        pieceList.list.add(mockInGamePiece)
        pieceList.list.add(mockInGamePiece)
        player.move(null, 5)
    }

    @Test(expected = MoveException::class)
    fun given_move_called_when_startCellNumber_is_1_and_player_does_not_have_piece_with_location_1_then_throw_MoveException() {
        val mockInGamePiece = mock(Piece::class.java)
        mockInGamePiece.state = PieceState.IN_GAME
        mockInGamePiece.location = 4
        pieceList.list.add(mockInGamePiece)
        pieceList.list.add(mockInGamePiece)
        player.move(null, 5)
    }

    @Test
    fun given_move_called_when_startCellNumber_is_1_then_board_getHeadPiece_1_should_be_called() {
        player.diceBox = diceBox
        player.move(1, 5)
        verify(board).getHeadPiece(1)
    }

    @Test
    fun given_move_called_when_startCellNumber_is_1_and_destinationCellNumber_is_4_and_then_playerPieceStrategy_findDice_should_be_called() {
        player.diceBox = diceBox
        val mockedPiece = mock(Piece::class.java)
        `when`(mockedPiece.moveType).thenReturn(MoveType.Normal)
        `when`(board.getHeadPiece(1)).thenReturn(mockedPiece)
        val strategy = mock(PlayerPiecesActionStrategy::class.java)
        `when`(contextStrategy.getPlayerPiecesStrategy(pieceList)).thenReturn(strategy)
        player.move(1, 4)
        verify(strategy).findDice(1, 4, diceBox, board)
    }

    @Test
    fun given_move_24_23_called_when_piece_and_dice_is_exist_then_strategy_move_should_be_called() {
        player.diceBox = diceBox
        val startCellNumber = 24
        val destinationCellNumber = 23
        val mockedPiece = mock(Piece::class.java)
        `when`(mockedPiece.moveType).thenReturn(MoveType.Normal)
        `when`(board.getHeadPiece(startCellNumber)).thenReturn(mockedPiece)
        val strategy = mock(PlayerPiecesActionStrategy::class.java)
        `when`(contextStrategy.getPlayerPiecesStrategy(pieceList)).thenReturn(strategy)
        val mockDice = mock(Dice::class.java)
        `when`(strategy.findDice(startCellNumber, destinationCellNumber,
            diceBox, board)).thenReturn(mockDice)
        player.move(startCellNumber, destinationCellNumber)
        verify(strategy).move(mockDice, mockedPiece, board)
    }

    @Test
    fun given_move_24_23_called_when_piece_and_dice_is_exist_and_strategy_move_is_true_then_dice_use_should_be_called() {
        player.diceBox = diceBox
        val startCellNumber = 24
        val destinationCellNumber = 23
        val mockedPiece = mock(Piece::class.java)
        `when`(mockedPiece.moveType).thenReturn(MoveType.Normal)
        `when`(board.getHeadPiece(startCellNumber)).thenReturn(mockedPiece)
        val strategy = mock(PlayerPiecesActionStrategy::class.java)
        `when`(contextStrategy.getPlayerPiecesStrategy(pieceList)).thenReturn(strategy)
        val mockDice = mock(Dice::class.java)
        `when`(strategy.findDice(startCellNumber, destinationCellNumber,
            diceBox, board)).thenReturn(mockDice)
        `when`(strategy.move(mockDice, mockedPiece, board)).thenReturn(true)
        player.move(startCellNumber, destinationCellNumber)
        verify(mockDice).use()
    }

    @Test
    fun given_move_24_23_called_when_piece_and_dice_is_exist_and_strategy_move_is_true_then_MoveCompletedEvent_should_be_invoked() {
        player.diceBox = diceBox
        val startCellNumber = 24
        val destinationCellNumber = 23
        val mockedPiece = mock(Piece::class.java)
        `when`(mockedPiece.moveType).thenReturn(MoveType.Normal)
        `when`(board.getHeadPiece(startCellNumber)).thenReturn(mockedPiece)
        val strategy = mock(PlayerPiecesActionStrategy::class.java)
        `when`(contextStrategy.getPlayerPiecesStrategy(pieceList)).thenReturn(strategy)
        val mockDice = mock(Dice::class.java)
        `when`(strategy.findDice(startCellNumber, destinationCellNumber,
            diceBox, board)).thenReturn(mockDice)
        `when`(strategy.move(mockDice, mockedPiece, board)).thenReturn(true)
        player.move(startCellNumber, destinationCellNumber)
        verify(diceDistributor).onEvent(MoveCompletedEvent(player))
    }

    @Test
    fun given_move_24_23_called_when_piece_and_dice_is_exist_and_strategy_move_is_true_and_all_pieces_are_in_won_state_then_GameEndedEvent_should_be_invoked() {
        player.diceBox = diceBox
        val startCellNumber = 24
        val destinationCellNumber = 23
        val mockedPiece = mock(Piece::class.java)
        `when`(mockedPiece.moveType).thenReturn(MoveType.Normal)
        `when`(board.getHeadPiece(startCellNumber)).thenReturn(mockedPiece)
        val strategy = mock(PlayerPiecesActionStrategy::class.java)
        `when`(contextStrategy.getPlayerPiecesStrategy(pieceList)).thenReturn(strategy)
        val mockDice = mock(Dice::class.java)
        `when`(strategy.findDice(startCellNumber, destinationCellNumber,
            diceBox, board)).thenReturn(mockDice)
        `when`(strategy.move(mockDice, mockedPiece, board)).thenReturn(true)
        `when`(pieceList.allPieceAreWon()).thenReturn(true)
        player.move(startCellNumber, destinationCellNumber)
        verify(diceDistributor).onEvent(GameEndedEvent(player))
    }

    @Test(expected = MoveException::class)
    fun given_move_with_null_and_2_called_when_player_has_not_dead_piece_then_throw_move_exception() {
        player.diceBox = diceBox
        player.move(null, 2)
    }
}