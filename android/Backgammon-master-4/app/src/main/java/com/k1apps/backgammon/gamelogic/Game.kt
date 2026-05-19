package com.k1apps.backgammon.gamelogic

class GameImpl(
    private val board: Board,
    private val diceDistributor: DiceDistributor
) : Game {

    override fun start() {
        diceDistributor.start()
        board.initBoard()
    }

    override fun roll(playerType: PlayerType) {
        val pair = diceDistributor.whichPlayerHasDice()
        pair?.let {
            it.second?.let { second ->
                if (playerType == it.first.playerType) {
                    it.first.roll()
                } else if (playerType == second.playerType) {
                    second.roll()
                }
            } ?: run {
                if (it.first.playerType == playerType) {
                    it.first.roll()
                }
            }
        }
    }

    override fun getTargetCellsBasedOn(playerType: PlayerType, cellPosition: Int): List<Int> {
        var targetArray: List<Int> = arrayListOf()
        val pair = diceDistributor.whichPlayerHasDice()
        pair?.let {
            val player = it.first
            if (it.second != null || player.playerType != playerType) {
                return targetArray
            }
            targetArray = player.getTargetCellsBasedOn(cellPosition)
        }
        return targetArray
    }

    //move to InGame

    //Move to won

    //Move with two number (StartCellNumber, destinationCellNumber)
}

interface Game {
    fun start()
    fun roll(playerType: PlayerType)
    fun getTargetCellsBasedOn(playerType: PlayerType, cellPosition: Int): List<Int>
}

