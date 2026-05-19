package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.Constants.DICE_RANGE

class DiceBoxImpl(override val dice1: Dice, override val dice2: Dice) : DiceBox {

    override fun roll() {
        if (dice1.roll() == dice2.roll()) {
            dice1.twice()
            dice2.twice()
        }
    }

    override fun enableDiceWith(number: Byte) {
        assert(number in DICE_RANGE)
        if (dice1.enableWith(number).not()) {
            dice2.enableWith(number)
        }
    }

    override fun isEnabled(): Boolean {
        return dice1.isActive() || dice2.isActive()
    }

    override fun allActiveDicesNumbers(): List<Byte> {
        val list = arrayListOf<Byte>()
        list.addAll(dice1.getActiveNumbers())
        list.addAll(dice2.getActiveNumbers())
        return list
    }

    override fun getActiveDiceWithNumber(number: Int): Dice? {
        if (dice1.isActive() && dice1.number == number.toByte()) {
            return dice1
        }
        if (dice1.isActive() && dice2.number == number.toByte()) {
            return dice2
        }
        return null
    }

    override fun getActiveDiceGreaterEqual(number: Int): Dice? {
        if (number !in DICE_RANGE) {
            throw DiceRangeException("$number is not in dice range($DICE_RANGE)")
        }
        for (num in number until 7) {
            val result = getActiveDiceWithNumber(num)
            if (result != null) {
                return result
            }
        }
        return null
    }
}

interface DiceBox {
    fun roll()
    val dice1: Dice
    val dice2: Dice
    fun enableDiceWith(number: Byte)
    fun isEnabled(): Boolean
    fun allActiveDicesNumbers(): List<Byte>
    fun getActiveDiceWithNumber(number: Int): Dice?
    fun getActiveDiceGreaterEqual(number: Int): Dice?
}

