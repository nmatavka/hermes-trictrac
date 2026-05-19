package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.Constants

abstract class PieceList {
    val list: MutableList<Piece> = arrayListOf()
    fun haveDiedPiece(): Boolean {
        list.forEach {
            if (it.state == PieceState.DEAD) {
                return true
            }
        }
        return false
    }

    fun deadPieces(): List<Piece> {
        val deadList = arrayListOf<Piece>()
        list.forEach {
            if (it.state == PieceState.DEAD) {
                deadList.add(it)
            }
        }
        return deadList
    }

    fun getHeadsPieces(): List<Piece> {
        val result = arrayListOf<Piece>()
        for (item in Constants.BOARD_LOCATION_RANGE) {
            loop@ for (piece in list) {
                if (item == piece.location && piece.state == PieceState.IN_GAME) {
                    result.add(piece)
                    break@loop
                }
            }
        }
        return result
    }

    fun isInRemovePieceState(): Boolean {
        list.forEach {
            if (it.state == PieceState.WON) return@forEach
            if (it.state == PieceState.DEAD) return false
            if (it.state == PieceState.IN_GAME && it.location !in getHomeCellIndexRange()) {
                return false
            }
        }
        return true
    }

    fun allPieceAreWon(): Boolean {
        list.forEach {
            if (it.state != PieceState.WON) {
                return false
            }
        }
        return true
    }

    abstract fun getHomeCellIndexRange(): IntRange
}

class NormalPieceList : PieceList() {
    init {
        for (item in 0 until 15) {
            list.add(PieceFactory.createNormalPiece())
        }
        pieceListArrangementNormal(list)
    }

    override fun getHomeCellIndexRange(): IntRange {
        return Constants.NORMAL_HOME_RANGE
    }

}

class ReversePieceList : PieceList() {
    init {
        for (item in 0 until 15) {
            list.add(PieceFactory.createReversePiece())
        }
        pieceListArrangementReverse(list)
    }

    override fun getHomeCellIndexRange(): IntRange {
        return Constants.REVERSE_HOME_RANGE
    }
}