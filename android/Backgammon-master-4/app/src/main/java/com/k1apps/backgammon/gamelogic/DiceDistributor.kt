package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.gamelogic.event.DiceBoxThrownEvent
import com.k1apps.backgammon.gamelogic.event.DiceThrownEvent
import com.k1apps.backgammon.gamelogic.event.GameEndedEvent
import com.k1apps.backgammon.gamelogic.event.MoveCompletedEvent
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe

class DiceDistributorImpl(
    private val player1: Player,
    private val player2: Player,
    private val diceBox: DiceBox
) : DiceDistributor {

    init {
        EventBus.getDefault().register(this)
    }

    override fun whichPlayerHasDice(): Pair<Player, Player?>? {
        if (player1.diceBox != null) {
            return Pair(player1, null)
        }
        if (player2.diceBox != null) {
            return Pair(player2, null)
        }
        if (player1.dice != null && player2.dice != null) {
            return Pair(player1, player2)
        }
        return null
    }

    @Synchronized
    @Subscribe
    override fun onEvent(event: DiceThrownEvent) {
        with(diceBox) {
            if (dice1.number == null || dice2.number == null) {
                return
            }
            retakeDices()
            when {
                dice1.number!! > dice2.number!! -> {
                    setDiceBox(player1)
                }
                dice1.number!! < dice2.number!! -> {
                    setDiceBox(player2)
                }
                else -> setDiceToPlayers()
            }
        }
    }

    private fun retakeDices() {
        player1.retakeDice()
        player2.retakeDice()
    }

    private fun setDiceBox(player: Player) {
        getOpponent(player).retakeDiceBox()
        player.diceBox = diceBox
    }

    @Subscribe
    override fun onEvent(event: DiceBoxThrownEvent) {
        with(event.player) {
            updateDiceBoxStatus()
            if (diceBox!!.isEnabled().not()) {
                // TODO: 10/11/19 Kayvan: View interaction: no move
                setDiceBox(getOpponent(this))
            }
        }
    }

    @Subscribe
    override fun onEvent(event: GameEndedEvent) {
//        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    @Subscribe
    override fun onEvent(event: MoveCompletedEvent) {
//        TODO("not implemented") //To change body of created functions use File | Settings | File Templates.
    }

    private fun getOpponent(player: Player): Player {
        if (player === player1) {
            return player2
        } else {
            return player1
        }
    }

    override fun start() {
        setDiceToPlayers()
    }

    private fun setDiceToPlayers() {
        player1.dice = diceBox.dice1
        player2.dice = diceBox.dice2
    }
}

interface DiceDistributor {
    fun start()
    fun whichPlayerHasDice(): Pair<Player, Player?>?
    fun onEvent(event: DiceThrownEvent)
    fun onEvent(event: DiceBoxThrownEvent)
    fun onEvent(event: GameEndedEvent)
    fun onEvent(event: MoveCompletedEvent)
}