package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.Constants.NORMAL_HOME_RANGE
import com.k1apps.backgammon.Constants.REVERSE_HOME_RANGE
import com.k1apps.backgammon.gamelogic.event.DiceBoxThrownEvent
import com.k1apps.backgammon.gamelogic.event.DiceThrownEvent
import com.k1apps.backgammon.gamelogic.event.GameEndedEvent
import com.k1apps.backgammon.gamelogic.event.MoveCompletedEvent
import com.k1apps.backgammon.gamelogic.strategy.PlayerPiecesContextStrategy
import org.greenrobot.eventbus.EventBus

class PlayerImpl(
    override val playerType: PlayerType = PlayerType.LocalPlayer,
    override val pieceList: PieceList,
    private val moveType: MoveType,
    private val board: Board,
    private val playerPiecesContextStrategy: PlayerPiecesContextStrategy
) : Player {
    override var dice: Dice? = null
    override var diceBox: DiceBox? = null
    override val homeCellIndexRange: IntRange = if (moveType == MoveType.Normal) {
        NORMAL_HOME_RANGE
    } else {
        REVERSE_HOME_RANGE
    }

    override fun roll() {
        dice?.let {
            it.roll()
            EventBus.getDefault().post(DiceThrownEvent(this))
        } ?: run {
            diceBox?.let {
                it.roll()
                EventBus.getDefault().post(DiceBoxThrownEvent(this))
            }
        }
    }

    override fun retakeDice() {
        dice = null
    }

    override fun retakeDiceBox() {
        diceBox = null
    }

    override fun updateDiceBoxStatus() {
        playerPiecesContextStrategy.getPlayerPiecesStrategy(pieceList)
            .updateDiceBoxStatus(diceBox!!, pieceList, board)
    }

    override fun move(startCellNumber: Int?, destinationCellNumber: Int?) {
        if (diceBox == null) {
            throw MoveException("Move called when player not have diceBox")
        }
        val piece: Piece? = if (startCellNumber != null) {
            board.getHeadPiece(startCellNumber)
        } else {
            if (pieceList.haveDiedPiece()) {
                getDeadPiece()
            } else {
                throw MoveException("Move called when startCell is null and player has not dead piece")
            }
        }
        if (piece != null && piece.moveType == moveType) {
            val playerPiecesStrategy = playerPiecesContextStrategy
                .getPlayerPiecesStrategy(pieceList)
            val dice = playerPiecesStrategy
                .findDice(startCellNumber, destinationCellNumber, diceBox!!, board)
            dice?.let {
                val moveResult = playerPiecesStrategy.move(it, piece, board)
                if (moveResult) {
                    it.use()
                    EventBus.getDefault().post(MoveCompletedEvent(this))
                    if (pieceList.allPieceAreWon()) {
                        EventBus.getDefault().post(GameEndedEvent(this))
                    }
                }
            }
        }
    }

    override fun getTargetCellsBasedOn(cellPosition: Int?): List<Int> {
//        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
        return arrayListOf()
    }

    private fun getDeadPiece(): Piece? {
        pieceList.list.forEach {
            if (it.state == PieceState.DEAD) {
                return it
            }
        }
        return null
    }
}

interface Player {
    val homeCellIndexRange: IntRange
    val pieceList: PieceList
    var diceBox: DiceBox?
    var dice: Dice?
    val playerType: PlayerType
    fun roll()
    fun retakeDice()
    fun retakeDiceBox()
    fun updateDiceBoxStatus()
    fun move(startCellNumber: Int?, destinationCellNumber: Int?)
    fun getTargetCellsBasedOn(cellPosition: Int?): List<Int>
}

enum class PlayerType {
    LocalPlayer, AndroidPlayer
}
