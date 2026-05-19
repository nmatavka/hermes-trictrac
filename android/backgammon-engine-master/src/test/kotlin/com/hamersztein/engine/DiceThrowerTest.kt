package com.hamersztein.engine

import kotlin.test.Test
import kotlin.test.assertEquals


class DiceThrowerTest {

    private val diceThrower = DiceThrower()

    @Test
    fun `should throw two valid dice and increase the throw count`() {
        val (left, right) = diceThrower()

        assert(left >= 1)
        assert(left <= 6)

        assert(right >= 1)
        assert(right <= 6)

        assertEquals(1, diceThrower.throwCount)
    }
}