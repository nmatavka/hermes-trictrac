package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.Constants.BOARD_LOCATION_RANGE
import com.k1apps.backgammon.Constants.DICE_RANGE
import javax.inject.Inject
import kotlin.math.abs

interface Board {
    val cells: List<BoardCell>
    fun initBoard()
    fun canMovePiece(fromPiece: Piece?, toPiece: Piece?): Boolean
    fun isRangeFilledWithNormalPiece(range: IntRange): Boolean
    fun isRangeFilledWithReversePiece(range: IntRange): Boolean
    fun move(piece: Piece, number: Byte): Boolean
    fun getHeadPiece(cellNumber: Int): Piece?
    fun findDistanceBetweenTwoCell(startCell: Int, destinationCell: Int): Int
}

class BoardImpl @Inject constructor(
    private val pieceList1: PieceList,
    private val pieceList2: PieceList,
    override val cells: List<BoardCell>
) : Board {

    override fun initBoard() {
        clearCell()
        initLists()
    }

    private fun clearCell() {
        cells.forEach {
            it.clear()
        }
    }

    private fun initLists() {
        pieceList1.list.forEach {
            cells[it.location].insertPiece(it)
        }
        pieceList2.list.forEach {
            cells[it.location].insertPiece(it)
        }
    }

    override fun canMovePiece(fromPiece: Piece?, toPiece: Piece?): Boolean {
        if (fromPiece == null || toPiece == null) {
            return false
        }
        val cell = cells[toPiece.location]
        return cell.insertState(toPiece) != PieceInsertState.FAILED
    }

    override fun getHeadPiece(cellNumber: Int): Piece? {
        if (cellNumber !in BOARD_LOCATION_RANGE) {
            throw CellNumberException("Selected cell number is: $cellNumber")
        }
        val cell = cells[cellNumber]
        return cell.pieces.last()
    }

    override fun findDistanceBetweenTwoCell(startCell: Int, destinationCell: Int): Int {
        if (startCell !in BOARD_LOCATION_RANGE) {
            throw CellNumberException("startCell number is: $startCell")
        }
        if (destinationCell !in BOARD_LOCATION_RANGE) {
            throw CellNumberException("destinationCell number is: $destinationCell")
        }
        return abs(startCell - destinationCell)
    }

    override fun isRangeFilledWithNormalPiece(range: IntRange): Boolean {
        range.forEach { index ->
            if (cells[index].isBannedBy(MoveType.Normal).not()) {
                return false
            }
        }
        return true
    }

    override fun isRangeFilledWithReversePiece(range: IntRange): Boolean {
        range.forEach { index ->
            if (cells[index].isBannedBy(MoveType.Revers).not()) {
                return false
            }
        }
        return true
    }

    override fun move(piece: Piece, number: Byte): Boolean {
        var moveCompleted = false
        if (number !in DICE_RANGE) {
            throw MoveException("Dice number range is incorrect")
        }
        if (piece.state == PieceState.WON) {
            throw MoveException("You can't move piece with won state")
        }
        val pieceAfterMove = piece.pieceAfterMove(number)
        if (pieceAfterMove == null) {
            cells[piece.location].remove()
            piece.state = PieceState.WON
            moveCompleted = true
        } else {
            if (canMovePiece(piece, pieceAfterMove)) {
                piece.state = pieceAfterMove.state
                piece.location = pieceAfterMove.location
                moveCompleted = cells[piece.location].insertPiece(piece) != PieceInsertState.FAILED
            }
        }
        return moveCompleted
    }
}