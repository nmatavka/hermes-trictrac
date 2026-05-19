package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.gamelogic.*
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class PlayerIsInRemovePieceStrategyTest {

    private lateinit var playerPiecesActionStrategy: PlayerPiecesActionStrategy
    @Mock
    private lateinit var board: Board
    @Mock
    private lateinit var diceBox: DiceBox
    @Mock
    private lateinit var pieceList: PieceList
    private var num1: Byte = 4
    private var num2: Byte = 5
    private val lst = arrayListOf<Piece>()

    @Before
    fun setUp() {
        `when`(pieceList.list).thenReturn(lst)
        playerPiecesActionStrategy = PlayerIsInRemovePieceStrategy()
        `when`(pieceList.isInRemovePieceState()).thenReturn(true)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_4_5_and_piece_with_locations_4_5_are_exist_then_diceBox_enableDiceWith_4_5_must_be_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(num1, num2))
        val piece = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(num1.toInt()).thenReturn(num2.toInt())
        lst.add(piece)
        lst.add(piece)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeastOnce()).enableDiceWith(num1)
        verify(diceBox, atLeastOnce()).enableDiceWith(num2)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_4_4_and_there_are_4_piece_with_location_4_then_diceBox_enableDiceWith_4_times_must_be_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(4, 4, 4, 4))
        val piece = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(4)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeast(4)).enableDiceWith(4)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_4_4_and_3_pieces_locations_is_1_then_diceBox_enableDiceWith4_atLeast_4_times_must_be_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(4, 4, 4, 4))
        val piece = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(1)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeast(4)).enableDiceWith(4)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_4_4_and_3_pieces_locations_are_1_except_one_which_is_5_and_board_canMovePiece_is_true_every_time_then_diceBox_enableDiceWith4_atLeast_4_times_must_be_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(4, 4, 4, 4))
        val piece = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(1).thenReturn(1).thenReturn(1).thenReturn(5)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
//        `when`(board.canMovePiece(ArgumentMatchers.any(), ArgumentMatchers.any())).thenReturn(true)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeast(4)).enableDiceWith(4)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_1_4_and_5_pieces_locations_are_2_and_board_canMovePiece_with_1_is_false_then_diceBox_enableDiceWith_4_atLeast_1_time_must_be_called_but_1_never_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(1, 4))
        val piece = mock(Piece::class.java)
        val piece1 = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(2)
        `when`(piece.pieceAfterMove(1)).thenReturn(piece1)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        `when`(board.canMovePiece(piece, piece1)).thenReturn(false)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeast(1)).enableDiceWith(4)
        verify(diceBox, never()).enableDiceWith(1)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_1_2_and_all_pieces_locations_are_4_and_board_canMovePiece_with_1_3_are_false_then_diceBox_enableDiceWith_2_atLeast_1_time_must_be_called_but_1_never_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(1, 2))
        val piece = mock(Piece::class.java)
        val piece1 = mock(Piece::class.java)
        val piece2 = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(4)
        `when`(piece.pieceAfterMove(1)).thenReturn(piece1)
        `when`(piece.pieceAfterMove(2)).thenReturn(piece2)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        `when`(board.canMovePiece(piece, piece1)).thenReturn(false)
        `when`(board.canMovePiece(piece, piece2)).thenReturn(true)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeast(1)).enableDiceWith(2)
        verify(diceBox, never()).enableDiceWith(1)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_1_4_and_all_pieces_locations_is_2_and_board_canMovePiece_with1_is_false_then_diceBox_enableDiceWith_4_atLeast_1_time_must_be_called_but_1_never_called() {
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(1, 4))
        val piece = mock(Piece::class.java)
        val piece1 = mock(Piece::class.java)
        `when`(piece.locationInMySide()).thenReturn(2)
        `when`(piece.pieceAfterMove(1)).thenReturn(piece1)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        lst.add(piece)
        `when`(board.canMovePiece(piece, piece1)).thenReturn(false)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeast(1)).enableDiceWith(4)
        verify(diceBox, never()).enableDiceWith(1)
    }

    @Test
    fun given_move_called_when_piece_is_in_game_with_location4_and_board_move_is_true_then_move_should_be_true() {
        val piece = mock(Piece::class.java)
        val dice = mock(Dice::class.java)
        `when`(piece.state).thenReturn(PieceState.IN_GAME)
        `when`(piece.locationInMySide()).thenReturn(4)
        `when`(dice.number).thenReturn(4)
        `when`(board.move(piece, 4)).thenReturn(true)
        val move = playerPiecesActionStrategy.move(dice, piece, board)
        assertTrue(move)
    }


    @Test(expected = CellNumberException::class)
    fun given_findDice_called_when_both_of_startCell_and_destinationCell_are_null_then_throw_CellNumberException() {
        playerPiecesActionStrategy.findDice(null, null, diceBox, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_findDice_called_when_startCell_is_null_then_throw_ChooseStrategyException() {
        playerPiecesActionStrategy.findDice(null, 8, diceBox, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_findDice_called_when_startCell_is_not_in_DiceRange_then_throw_ChooseStrategyException() {
        playerPiecesActionStrategy.findDice(13, 8, diceBox, board)
    }

    @Test
    fun given_findDice_called_when_startCell_is_6_and_destinationCell_is_5_and_board_findDistanceBetweenTwoCell_return1_then_diceBox_getActiveDiceWithNumber_1_should_be_called() {
        `when`(board.findDistanceBetweenTwoCell(6, 5)).thenReturn(1)
        playerPiecesActionStrategy.findDice(6, 5, diceBox, board)
        verify(diceBox).getActiveDiceWithNumber(1)
    }

    @Test
    fun given_findDice_called_when_startCell_is_2_and_destinationCell_is_null_then_diceBox_getDiceGreaterEqual_2_should_be_called() {
        playerPiecesActionStrategy.findDice(2, null, diceBox, board)
        verify(diceBox).getActiveDiceGreaterEqual(2)
    }

    @Test
    fun given_findDice_called_when_startCell_is_6_and_destinationCell_is_6_then_return_null() {
        val result = playerPiecesActionStrategy.findDice(6, 6, diceBox, board)
        assertTrue(result == null)
    }
}