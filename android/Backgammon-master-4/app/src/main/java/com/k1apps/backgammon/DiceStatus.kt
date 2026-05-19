package com.k1apps.backgammon

import com.k1apps.backgammon.gamelogic.memento.Memento
import com.k1apps.backgammon.gamelogic.memento.Originator
import javax.inject.Inject

class DiceStatus @Inject constructor() : Originator {
    private var enable1 = false
    private var enable2 = false
    private var twice = false
    var enable: Boolean
        get() {
            return enable1 || enable2
        }
        set(value) {
            if (value) {
                enable()
            } else {
                disable()
            }
        }

    private fun enable() {
        if (enable1.not()) {
            enable1 = true
        } else if (twice) {
            enable2 = true
        }
    }

    private fun disable() {
        if (enable1) {
            enable1 = false
        } else if (twice) {
            enable2 = false
        }
    }

    internal fun isFullEnabled(): Boolean {
        if (enable1 && enable2) {
            return true
        }
        if (enable1 && twice.not()) {
            return true
        }
        return false
    }

    fun setTwice(twice: Boolean) {
        this.twice = twice
    }

    fun enableCount(): Byte {
        var count = 0.toByte()
        if (enable1) {
            count++
        }
        if (enable2) {
            count++
        }
        return count
    }

    override fun equals(other: Any?): Boolean {
        if (other !is DiceStatus) {
            return false
        }
        return enable2 == other.enable2 &&
                enable1 == other.enable1 &&
                twice == other.twice
    }

    override fun createMemento(): Memento {
        return StatusMemento(enable1, enable2, twice)
    }

    override fun restore(memento: Memento) {
        (memento as StatusMemento).let {
            enable1 = it.enable1
            enable2 = it.enable2
            twice = it.twice
        }
    }

    override fun hashCode(): Int {
        var result = enable1.hashCode()
        result = 31 * result + enable2.hashCode()
        result = 31 * result + twice.hashCode()
        return result
    }

    private data class StatusMemento(
        val enable1: Boolean,
        val enable2: Boolean,
        val twice: Boolean
    ) : Memento
}
