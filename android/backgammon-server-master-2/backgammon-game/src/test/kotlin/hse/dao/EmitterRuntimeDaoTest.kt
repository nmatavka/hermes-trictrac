package hse.dao

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNotEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test

class EmitterRuntimeDaoTest {
    private var dao: EmitterRuntimeDao = EmitterRuntimeDao(sseTimeOut = 1)

    @BeforeEach
    fun setup() {
        dao = EmitterRuntimeDao(sseTimeOut = 1)
    }


    @Test
    fun `add new with same id test`() {
        val gameId = 1
        val emitterBefore = dao.add(gameId, 1)

        val emitterAfter = dao.add(gameId, 1)

        val allEmitters = dao.getAllInRoom(gameId)

        assertNotEquals(emitterAfter, emitterBefore)
        assertEquals(allEmitters.size, 1)
        assertEquals(emitterAfter, allEmitters.first().emitter)
    }
}