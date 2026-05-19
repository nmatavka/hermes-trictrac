package hse.menu.service

import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import hse.menu.dao.ConnectionDao
import hse.menu.dto.ConnectionDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.Mockito
import org.mockito.Mockito.never
import org.mockito.Mockito.only
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.test.context.TestPropertySource
import kotlin.test.assertFalse
import kotlin.test.assertTrue

@SpringBootTest
@TestPropertySource("classpath:application-test.yaml")
class ConnectionServiceTest {


    @Autowired
    private lateinit var service: ConnectionService

    @Autowired
    @MockBean
    private lateinit var connectionDao: ConnectionDao

    @BeforeEach
    fun setUp() {
        Mockito.reset(connectionDao)
    }


    @Test
    fun `connection happy path`() {
        val userId = 1
        val connectionDto = ConnectionDto(
            userId = userId,
            latch = Mockito.mock(),
            gameType = GameType.REGULAR_GAMMON,
        )

        service.cancelledFilter.add(userId)

        service.connect(
            connectionDto = connectionDto,
            points = GammonGamePoints.THREE
        )

        assertTrue(service.inQueueFilter.contains(userId))
        assertFalse(service.cancelledFilter.contains(userId))
    }

    @Test
    fun `connection repeat`() {
        val userId = 2
        val connectionDto = ConnectionDto(
            userId = userId,
            latch = Mockito.mock(),
            gameType = GameType.REGULAR_GAMMON,
        )

        service.inQueueFilter.add(userId)

        service.connect(
            connectionDto = connectionDto,
            points = GammonGamePoints.THREE
        )

        Mockito.verify(connectionDao, never()).enqueue(any(), eq(GammonGamePoints.THREE))
    }


    @Test
    fun `take happy path`() {
        val userId = 3

        service.inQueueFilter.add(userId)

        val connectionDto = ConnectionDto(
            userId = userId,
            latch = Mockito.mock(),
            gameType = GameType.REGULAR_GAMMON,
        )

        Mockito.`when`(connectionDao.dequeue(eq(GameType.REGULAR_GAMMON), eq(GammonGamePoints.THREE)))
            .thenReturn(connectionDto)

        service.take(
            gameType = GameType.REGULAR_GAMMON,
            points = GammonGamePoints.THREE
        )

        Mockito.verify(connectionDao, only()).dequeue(eq(GameType.REGULAR_GAMMON), eq(GammonGamePoints.THREE))
        assertFalse(service.inQueueFilter.contains(userId))
        assertFalse(service.cancelledFilter.contains(userId))
    }

    @Test
    fun `take first cancelled`() {
        val first = 4
        val second = 5

        service.inQueueFilter.add(first)
        service.inQueueFilter.add(second)
        service.cancelledFilter.add(first)

        val connectionDto = ConnectionDto(
            userId = first,
            latch = Mockito.mock(),
            gameType = GameType.REGULAR_GAMMON,
        )

        Mockito.`when`(connectionDao.dequeue(any(), any()))
            .thenReturn(connectionDto, connectionDto.copy(userId = second))
            .thenReturn(connectionDto)

        val res = service.take(
            gameType = GameType.REGULAR_GAMMON,
            points = GammonGamePoints.THREE
        )

        Mockito.verify(connectionDao, Mockito.times(2)).dequeue(any(), any())
        assertFalse(service.inQueueFilter.contains(first))
        assertFalse(service.inQueueFilter.contains(second))
        assertTrue(service.cancelledFilter.contains(first))
        assertFalse(service.cancelledFilter.contains(second))

        assertEquals(second, res.userId)
    }
}