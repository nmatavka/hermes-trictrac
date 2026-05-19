package com.k1apps.backgammon.gamelogic.strategy

import com.k1apps.backgammon.gamelogic.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class PlayerIsInDeadPieceStrategyTest {


    private lateinit var playerPiecesActionStrategy: PlayerPiecesActionStrategy
    @Mock
    private lateinit var board: Board
    @Mock
    private lateinit var diceBox: DiceBox
    @Mock
    private lateinit var pieceList: PieceList
    private var num1: Byte = 4
    private var num2: Byte = 5

    @Before
    fun setUp() {
        playerPiecesActionStrategy = PlayerIsInDeadPieceStrategy()
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_4_5_and_two_pieces_are_dead_and_board_canMovePiece_is_true_then_diceBox_enableDiceWith_4_5_must_be_called() {
        val deadPiece = mock(Piece::class.java)
        val pieceAfterMove = mock(Piece::class.java)
        `when`(pieceAfterMove.state).thenReturn(PieceState.IN_GAME)
        `when`(deadPiece.pieceAfterMove(ArgumentMatchers.anyByte())).thenReturn(pieceAfterMove)
        val lst = arrayListOf<Piece>()
        lst.add(deadPiece)
        lst.add(deadPiece)

        `when`(pieceList.deadPieces()).thenReturn(lst)
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(num1, num2))
        `when`(board.canMovePiece(deadPiece, pieceAfterMove)).thenReturn(true)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeastOnce()).enableDiceWith(num1)
        verify(diceBox, atLeastOnce()).enableDiceWith(num2)
    }

    @Test
    fun given_updateDiceBoxStatus_with_called_when_dices_numbers_are_4_5_and_two_pieces_are_dead_and_board_canMovePiece_is_false_then_diceBox_enableDiceWith_4_5_never_must_be_called() {
        val deadPiece = mock(Piece::class.java)
        val pieceAfterMove = mock(Piece::class.java)
        `when`(pieceAfterMove.state).thenReturn(PieceState.IN_GAME)
        `when`(deadPiece.pieceAfterMove(ArgumentMatchers.anyByte())).thenReturn(pieceAfterMove)
        val lst = arrayListOf<Piece>()
        lst.add(deadPiece)
        lst.add(deadPiece)
        `when`(pieceList.deadPieces()).thenReturn(lst)
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(num1, num2))
        `when`(board.canMovePiece(deadPiece, pieceAfterMove)).thenReturn(false)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, never()).enableDiceWith(num1)
        verify(diceBox, never()).enableDiceWith(num2)
    }

    @Test
    fun given_updateDiceBoxStatus_called_when_dices_numbers_are_4_5_and_two_pieces_are_dead_and_board_canMovePiece4_is_true_then_diceBox_enableDiceWith_4_must_be_called() {
        val deadPiece = mock(Piece::class.java)
        val pieceAfterMove = mock(Piece::class.java)
        `when`(pieceAfterMove.state).thenReturn(PieceState.IN_GAME)
        val pieceAfterMove1 = mock(Piece::class.java)
        `when`(pieceAfterMove1.state).thenReturn(PieceState.IN_GAME)
        `when`(deadPiece.pieceAfterMove(num1)).thenReturn(pieceAfterMove)
        `when`(deadPiece.pieceAfterMove(num2)).thenReturn(pieceAfterMove1)
        val lst = arrayListOf<Piece>()
        lst.add(deadPiece)
        lst.add(deadPiece)
        `when`(pieceList.deadPieces()).thenReturn(lst)
        `when`(diceBox.allActiveDicesNumbers()).thenReturn(arrayListOf(num1, num2))
        `when`(board.canMovePiece(deadPiece, pieceAfterMove)).thenReturn(true)
        `when`(board.canMovePiece(deadPiece, pieceAfterMove1)).thenReturn(false)
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
        verify(diceBox, atLeastOnce()).enableDiceWith(num1)
        verify(diceBox, never()).enableDiceWith(num2)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_updateDiceBoxStatus_called_when_no_any_piece_dead_then_throw_exception() {
        `when`(pieceList.deadPieces()).thenReturn(arrayListOf())
        playerPiecesActionStrategy.updateDiceBoxStatus(diceBox, pieceList, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_move_called_when_piece_is_alive_then_thrown_chooseStrategyException() {
        val piece = mock(Piece::class.java)
        `when`(piece.state).thenReturn(PieceState.IN_GAME)
        playerPiecesActionStrategy.move(mock(Dice::class.java), piece, board)
    }

    @Test
    fun given_move_called_when_piece_is_dead_then_board_move_should_be_called() {
        val piece = mock(Piece::class.java)
        `when`(piece.state).thenReturn(PieceState.DEAD)
        val dice = mock(Dice::class.java)
        `when`(dice.number).thenReturn(num1)
        playerPiecesActionStrategy.move(dice, piece, board)
        verify(board).move(piece, num1)
    }

    @Test(expected = CellNumberException::class)
    fun given_findDice_called_when_both_of_startCell_and_destinationCell_are_null_then_throw_CellNumberException() {
        playerPiecesActionStrategy.findDice(null, null, diceBox, board)
    }

    @Test(expected = CellNumberException::class)
    fun given_findDice_called_when_startCell_is_null_and_to_cell_is_not_in_dice_range_then_throw_CellNumberException() {
        playerPiecesActionStrategy.findDice(null, 8, diceBox, board)
    }

    @Test(expected = ChooseStrategyException::class)
    fun given_findDice_called_when_startCell_is_not_null_then_throw_ChooseStrategyException() {
        playerPiecesActionStrategy.findDice(6, 8, diceBox, board)
    }

    @Test
    fun given_findDice_called_when_startCell_is_null_and_to_cell_is_5_then_diceBox_getDiceWithNumber_should_be_called() {
        val mockDiceBox = mock(DiceBox::class.java)
        playerPiecesActionStrategy.findDice(null, 5, mockDiceBox, board)
        verify(mockDiceBox).getActiveDiceWithNumber(5)
    }
}