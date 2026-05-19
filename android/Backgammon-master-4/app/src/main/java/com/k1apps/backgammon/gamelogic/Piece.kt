package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.Constants.BOARD_LOCATION_RANGE
import com.k1apps.backgammon.Utils.reverseLocation

class PieceImpl(override val moveType: MoveType) : Piece {

    override var state: PieceState = PieceState.IN_GAME

    override var location: Int = -1
        set(value) {
            if (value in BOARD_LOCATION_RANGE) {
                field = value
            }
        }

    override fun pieceAfterMove(number: Byte): Piece? {
        val piece = PieceImpl(moveType)
        piece.state = state
        when (state) {
            PieceState.DEAD -> {
                var gotoEndNumber = number.toInt()
                if (moveType == MoveType.Normal) {
                    gotoEndNumber = reverseLocation(number.toInt())
                }
                piece.location = gotoEndNumber
                piece.state = PieceState.IN_GAME
            }
            PieceState.IN_GAME -> {
                if (moveType == MoveType.Revers) {
                    piece.location = this.location + number
                } else {
                    piece.location = this.location - number
                }
                return if (piece.location in BOARD_LOCATION_RANGE) {
                    piece
                } else {
                    null
                }
            }
            PieceState.WON -> {
                return null
            }
        }
        return piece
    }


    override fun hashCode(): Int {
        var result = this.moveType.hashCode()
        result = 31 * result + this.state.hashCode()
        result = 31 * result + this.location
        return result
    }

    override fun copy(): Piece {
        val cp = PieceImpl(moveType)
        cp.location = location
        cp.state = state
        return cp
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as PieceImpl

        if (moveType != other.moveType) return false
        if (state != other.state) return false
        if (location != other.location) return false

        return true
    }

    override fun locationInMySide(): Int {
        return if (moveType == MoveType.Revers) {
            reverseLocation(location)
        } else {
            location
        }
    }

    override fun kill() {
        state = PieceState.DEAD
    }
}

interface Piece {
    fun pieceAfterMove(number: Byte): Piece?
    fun locationInMySide(): Int
    var state: PieceState
    var location: Int
    val moveType: MoveType
    fun copy(): Piece
    fun kill()
}

enum class PieceState {
    DEAD, IN_GAME, WON
}
