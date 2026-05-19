package com.k1apps.backgammon.gamelogic

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

import org.junit.Before
import org.junit.runner.RunWith
import org.mockito.Mock
import org.mockito.Mockito.*
import org.mockito.junit.MockitoJUnitRunner

@RunWith(MockitoJUnitRunner::class)
class BoardCellImplTest {
    private lateinit var boardCell: BoardCell

    @Mock
    private lateinit var pieces: ArrayList<Piece>

    @Before
    fun setup() {
        boardCell = BoardCellImpl(pieces)
    }

    @Test
    fun given_clean_called_then_pieces_clear_should_be_called() {
        boardCell.clear()
        verify(pieces).clear()
    }

    @Test
    fun given_insertPiece_when_pieces_are_empty_then_piece_should_added_to_pieces_and_return_INSERTED() {
        `when`(pieces.isEmpty()).thenReturn(true)
        val piece = mock(Piece::class.java)
        boardCell.insertPiece(piece)
        verify(pieces).add(piece)
        assert(boardCell.insertPiece(piece) == PieceInsertState.INSERT)
    }

    @Test
    fun given_insertPiece_when_pieces_has_one_opponent_then_piece_should_added_to_pieces_and_kill_opponent_piece_and_return_KILL_OPPONENT() {
        `when`(pieces.size).thenReturn(1)
        val opponentPiece = mock(Piece::class.java)
        `when`(opponentPiece.moveType).thenReturn(MoveType.Revers)
        `when`(pieces.first()).thenReturn(opponentPiece)
        val piece = mock(Piece::class.java)
        `when`(piece.moveType).thenReturn(MoveType.Normal)
        boardCell.insertPiece(piece)
        verify(pieces).add(piece)
        verify(opponentPiece).kill()
        assert(boardCell.insertPiece(piece) == PieceInsertState.INSERT_KILL_OPPONENT)
    }

    @Test
    fun given_insertPiece_when_pieces_has_more_than_one_opponent_then_piece_should_not_added_to_pieces_and_return_FAILED() {
        `when`(pieces.size).thenReturn(3)
        val opponentPiece = mock(Piece::class.java)
        `when`(opponentPiece.moveType).thenReturn(MoveType.Revers)
        `when`(pieces.first()).thenReturn(opponentPiece)
        val piece = mock(Piece::class.java)
        `when`(piece.moveType).thenReturn(MoveType.Normal)
        verify(pieces, never()).add(piece)
        assert(boardCell.insertPiece(piece) == PieceInsertState.FAILED)
    }

    @Test
    fun given_insertPiece_when_pieces_has_one_my_piece_then_piece_should_be_added_to_pieces_and_return_INSERTED() {
        `when`(pieces.size).thenReturn(1)
        val myPiece = mock(Piece::class.java)
        `when`(myPiece.moveType).thenReturn(MoveType.Normal)
        `when`(pieces.first()).thenReturn(myPiece)
        val piece = mock(Piece::class.java)
        `when`(piece.moveType).thenReturn(MoveType.Normal)
        verify(pieces, never()).add(piece)
        assert(boardCell.insertPiece(piece) == PieceInsertState.INSERT)
    }

    @Test
    fun given_insertPiece_when_pieces_has_more_than_one_my_piece_then_piece_should_be_added_to_pieces_and_return_INSERTED() {
        `when`(pieces.size).thenReturn(5)
        val myPiece = mock(Piece::class.java)
        `when`(myPiece.moveType).thenReturn(MoveType.Normal)
        `when`(pieces.first()).thenReturn(myPiece)
        val piece = mock(Piece::class.java)
        `when`(piece.moveType).thenReturn(MoveType.Normal)
        verify(pieces, never()).add(piece)
        assert(boardCell.insertPiece(piece) == PieceInsertState.INSERT)
    }

    @Test
    fun given_isBannedBy_NormalPiece_called_when_cell_is_empty_then_return_false() {
        `when`(pieces.isEmpty()).thenReturn(true)
        assertFalse(boardCell.isBannedBy(MoveType.Normal))
    }

    @Test
    fun given_isBannedBy_NormalPiece_called_when_cell_has_one_normal_piece_then_return_false() {
        `when`(pieces.size).thenReturn(1)
        assertFalse(boardCell.isBannedBy(MoveType.Normal))

    }

    @Test
    fun given_isBannedBy_NormalPiece_called_when_cell_has_one_revers_piece_then_return_false() {
        `when`(pieces.size).thenReturn(1)
        assertFalse(boardCell.isBannedBy(MoveType.Normal))
    }

    @Test
    fun given_isBannedBy_NormalPiece_called_when_cell_has_more_than_one_normal_piece_then_return_true() {
        `when`(pieces.size).thenReturn(3)
        val piece = mock(Piece::class.java)
        `when`(piece.moveType).thenReturn(MoveType.Normal)
        `when`(pieces.first()).thenReturn(piece)
        assertTrue(boardCell.isBannedBy(MoveType.Normal))
    }

}