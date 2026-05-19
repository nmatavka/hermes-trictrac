package com.emredogan.tavlazari

import com.emredogan.tavlazari.Utils.Util
import org.junit.Assert.*
import org.junit.Test
import kotlin.math.max

class MainActivityTest {
    val maxDiceNumber = 6

    @Test
    fun createRandomNumbersForDice() {
        val randomNumber = Util.createRandomNumbersForDice(maxDiceNumber)
        assertTrue("Random number is between 1 and $maxDiceNumber", randomNumber in 1..6)
    }
}