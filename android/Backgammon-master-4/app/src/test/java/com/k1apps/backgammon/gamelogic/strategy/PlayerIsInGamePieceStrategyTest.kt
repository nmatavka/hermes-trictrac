package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.gamelogic.*
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class PlayerIsInGamePieceStrategyTest {

    private lateinit var playerPiecesActionStrategy: PlayerPiecesActionStrategy
    @Mock
    private lateinit var board: Board
    @Mock
    private lateinit var diceBox: DiceBox
    @Mock
    private lateinit var pieceList: PieceList
    private var num1: Byte = 1
    private var num2: Byte = 4

    @Before
    fun setUp() {
        playerPiecesActionStrategy = PlayerIsInGamePieceStrategy()
    }


    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_1_4_and_piece_is_exist_and_board_canMovePiece_return_true_then_diceBox_enableDiceWith_4_and_1_atLeast_1_time_must_be_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(num1, num2))
        `when`(board.canMovePiece(ArgumentMatchers.any(), ArgumentMatchers.any())).thenReturn(true)
        val lst = arrayListOf<Piece>()
        val mockPiece = mock(Piece::class.java)
        `when`(mockPiece.pieceAfterMove(ArgumentMatchers.anyByte())).thenReturn(mockPiece)
        lst.add(mockPiece)
        `when`(pieceList.getHeadsPieces()).thenReturn(lst)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeastOnce()).enableDiceWith(num1)
        verify(diceBox, atLeastOnce()).enableDiceWith(num2)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_1_4_and_piece_exist_is_and_board_canMovePiece_return_false_then_diceBox_enableDiceWith_4_and_1_never_not_called() {
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, never()).enableDiceWith(num1)
        verify(diceBox, never()).enableDiceWith(num2)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_1_4_and_piece_is_exist_and_board_canMovePiece1_return_true_then_diceBox_enableDiceWith_1_atLeast_1_time_must_be_called() {
        val piece = mock(Piece::class.java)
        `when`(piece.pieceAfterMove(ArgumentMatchers.anyByte())).thenReturn(piece)
        val lst = arrayListOf<Piece>()
        lst.add(piece)
        `when`(pieceList.getHeadsPieces()).thenReturn(lst)
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(num1, num2))
        `when`(board.canMovePiece(ArgumentMatchers.any(), ArgumentMatchers.any())).thenReturn(true)
            .thenReturn(false)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeastOnce()).enableDiceWith(num1)
        verify(diceBox, never()).enableDiceWith(num2)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_move_called_when_destination_cell_is_out_of_board_then_thrown_chooseStrategyException() {
        val dice = mock(Dice::class.java)
        `when`(dice.number).thenReturn(3)
        val piece = mock(Piece::class.java)
        `when`(piece.pieceAfterMove(3)).thenReturn(null)
        `when`(piece.state).thenReturn(PieceState.IN_GAME)
        playerPiecesActionStrategy.move(dice, piece, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun when_move_called_and_piece_state_is_not_inGame_then_thrown_chooseStrategyException() {
        val piece = mock(Piece::class.java)
        `when`(piece.state).thenReturn(PieceState.WON)
        val dice = mock(Dice::class.java)
        playerPiecesActionStrategy.move(dice, piece, board)
    }

    @Test
    fun given_move_called_then_move_should_be_true_and_board_move_called() {
        val piece = mock(Piece::class.java)
        val dice = mock(Dice::class.java)
        `when`(piece.state).thenReturn(PieceState.IN_GAME)
        `when`(piece.pieceAfterMove(ArgumentMatchers.anyByte())).thenReturn(piece)
        `when`(dice.number).thenReturn(num1)
        `when`(board.move(piece, num1)).thenReturn(true)
        val move = playerPiecesActionStrategy.move(dice, piece, board)
        assertTrue(move)
    }

    @Test(expected = CellNumberException::class)
    fun given_findDice_called_when_both_of_startCell_and_destinationCell_are_null_then_throw_CellNumberException() {
        playerPiecesActionStrategy.findDice(null, null, diceBox, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_findDice_called_and_startCell_is_null_when_destinationCell_is_8_then_throw_ChooseStrategyException() {
        playerPiecesActionStrategy.findDice(null, 8, diceBox, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_findDice_called_when_startCell_is_8_and_destinationCell_is_null_then_throw_ChooseStrategyException() {
        playerPiecesActionStrategy.findDice(8, null, diceBox, board)
    }

    @Test
    fun given_findDice_called_when_startCell_is_6_and_destinationCell_is_5_and_board_findDistanceBetweenTwoCell_return1_then_diceBox_getActiveDiceWithNumber_1_should_be_called() {
        `when`(board.findDistanceBetweenTwoCell(6, 5)).thenReturn(1)
        playerPiecesActionStrategy.findDice(6, 5, diceBox, board)
        verify(diceBox).getActiveDiceWithNumber(1)
    }

    @Test
    fun given_findDice_called_when_startCell_is_6_and_to_cell_is_6_then_return_null() {
        val result = playerPiecesActionStrategy.findDice(6, 6, diceBox, board)
        assertTrue(result == null)
    }
}