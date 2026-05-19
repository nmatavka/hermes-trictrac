package com.k1apps.backgammon.gamelogic

import com.k1apps.backgammon.DiceStatus
import com.k1apps.backgammon.gamelogic.memento.Memento
import com.k1apps.backgammon.gamelogic.memento.Originator
import kotlin.random.Random

class DiceImpl(
    override val random: Random,
    override val status: DiceStatus
) : Dice {
    private var twice = false
        set(value) {
            status.setTwice(value)
            field = value
        }

    override var number: Byte? = null
        private set

    override fun roll(): Byte {
        if (isRolled()) {
            throw DiceException("Roll dice twice!")
        }
        number = random.nextInt(1, 7).toByte()
        return number!!
    }

    private fun isRolled(): Boolean {
        return number != null
    }

    override fun isActive() = isRolled() && status.enable

    override fun enableWith(number: Byte): Boolean {
        if (isRolled().not()) {
            throw DiceException("Dice is not rolled!")
        }
        if (this.number != number) {
            return false
        }
        if (status.isFullEnabled()) {
            return false
        }
        status.enable = true
        return true
    }

    override fun use(): Boolean {
        if (isRolled().not()) {
            throw DiceException("Dice is not roll yet!")
        }
        if (status.enable.not()) {
            return false
        }
        status.enable = false
        if (twice) {
            twice = false
        } else {
            number = null
        }
        return true
    }

    override fun twice() {
        if (isRolled().not()) {
            throw DiceException("Dice is not roll yet!")
        }
        twice = true
    }

    override fun getActiveNumbers(): List<Byte> {
        val lst = arrayListOf<Byte>()
        for (item in 0 until status.enableCount()) {
            lst.add(number!!.toByte())
        }
        return lst
    }

    override fun createMemento(): Memento {
        return DiceMemento(status.createMemento(), twice, number)
    }

    override fun restore(memento: Memento) {
        (memento as DiceMemento).let {
            number = it.number
            twice = it.twice
            status.restore(it.status)
        }
    }

    override fun equals(other: Any?): Boolean {
        if (other !is DiceImpl) {
            return false
        }
        return status == other.status &&
                twice == other.twice &&
                number == other.number
    }

    private data class DiceMemento(
        val status: Memento,
        val twice: Boolean,
        val number: Byte?
    ) : Memento
}

interface Dice : Originator {
    val random: Random
    val number: Byte?
    val status: DiceStatus
    fun enableWith(number: Byte): Boolean
    fun use(): Boolean
    fun roll(): Byte
    fun isActive(): Boolean
    fun twice()
    fun getActiveNumbers(): List<Byte>
}
