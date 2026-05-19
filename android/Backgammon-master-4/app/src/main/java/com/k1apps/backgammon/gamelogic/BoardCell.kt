package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.gamelogic.PieceInsertState.*

interface BoardCell {
    val pieces: List<Piece>
    fun clear()
    fun insertState(piece: Piece): PieceInsertState
    fun insertPiece(piece: Piece): PieceInsertState
    fun isBannedBy(moveType: MoveType): Boolean
    fun remove()
}

class BoardCellImpl(override val pieces: ArrayList<Piece>) : BoardCell {
    override fun clear() {
        pieces.clear()
    }

    override fun insertState(piece: Piece): PieceInsertState {
        if (pieces.isEmpty()) {
            return INSERT
        }
        val first = pieces.first()
        if (pieces.size == 1) {
            return if (first.moveType != piece.moveType) {
                INSERT_KILL_OPPONENT
            } else {
                pieces.add(piece)
                INSERT
            }
        } else {
            if (first.moveType != piece.moveType) {
                return FAILED
            }
            return INSERT
        }
    }

    override fun insertPiece(piece: Piece): PieceInsertState {
        val insertState = insertState(piece)
        if (insertState == INSERT) {
            pieces.add(piece)
        }
        if (insertState == INSERT_KILL_OPPONENT) {
            val first = pieces.first()
            pieces.remove(first)
            first.kill()
            pieces.add(piece)
        }
        return insertState
    }

    override fun isBannedBy(moveType: MoveType): Boolean {
        if (pieces.isEmpty()) {
            return false
        }
        if (pieces.size == 1) {
            return false
        }
        return moveType == pieces.first().moveType
    }

    override fun remove() {
        if (pieces.isNotEmpty()) {
            pieces.remove(pieces.first())
        }
    }
}

enum class PieceInsertState {
    INSERT,
    INSERT_KILL_OPPONENT,
    FAILED
}