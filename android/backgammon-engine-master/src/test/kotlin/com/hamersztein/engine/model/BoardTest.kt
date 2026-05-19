package com.hamersztein.engine.model

import com.hamersztein.engine.model.Colour.DARK
import com.hamersztein.engine.model.Colour.LIGHT
import org.junit.jupiter.api.BeforeEach
import kotlin.test.Test
import kotlin.test.assertEquals

class BoardTest {

    private val bar = Bar()
    private val spaces = Array(24) { Space() }

    private val board = Board(bar, spaces)

    @BeforeEach
    fun beforeEach() {
        board.setup()
    }

    @Test
    fun `should set up the board correctly`() {
        assertEquals(spaces[5].count, 5)
        assertEquals(spaces[5].colour, DARK)
        assertEquals(spaces[7].count, 3)
        assertEquals(spaces[7].colour, DARK)
        assertEquals(spaces[12].count, 5)
        assertEquals(spaces[12].colour, DARK)
        assertEquals(spaces[23].count, 2)
        assertEquals(spaces[23].colour, DARK)

        assertEquals(spaces[18].count, 5)
        assertEquals(spaces[18].colour, LIGHT)
        assertEquals(spaces[16].count, 3)
        assertEquals(spaces[16].colour, LIGHT)
        assertEquals(spaces[11].count, 5)
        assertEquals(spaces[11].colour, LIGHT)
        assertEquals(spaces[0].count, 2)
        assertEquals(spaces[0].colour, LIGHT)
    }

    @Test
    fun `should move a light piece from its perspective`() {
        board.movePiece(LIGHT, 23, 12)

        assertEquals(1, spaces[0].count)
        assertEquals(6, spaces[11].count)
    }

    @Test
    fun `should move a dark piece from its perspective`() {
        board.movePiece(DARK, 23, 12)

        assertEquals(1, spaces[23].count)
        assertEquals(6, spaces[12].count)
    }
}