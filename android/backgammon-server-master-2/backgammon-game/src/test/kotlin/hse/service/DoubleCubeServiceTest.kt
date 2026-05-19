package hse.service

import game.backgammon.Gammon
import game.backgammon.GammonRestorer
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import game.common.enums.TimePolicy
import hse.dao.DoubleCubeDao
import hse.dto.GammonRestoreContextDto
import hse.entity.DoubleCube
import hse.wrapper.BackgammonWrapper
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito
import org.mockito.kotlin.any
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.http.HttpStatus
import org.springframework.test.context.TestConstructor
import org.springframework.web.server.ResponseStatusException
import java.time.Instant
import kotlin.test.assertEquals


@SpringBootTest
@TestConstructor(autowireMode = TestConstructor.AutowireMode.ALL)
class DoubleCubeServiceTest {
    @MockBean
    lateinit var doubleCubeDao: DoubleCubeDao

    @MockBean
    lateinit var gammonStoreService: GammonStoreService

    @Autowired
    lateinit var doubleCubeService: DoubleCubeService


    @Test
    fun doubleZarCreateTest() {
        val game = BackgammonWrapper.buildFromContext(
            restoreContextDto = GammonRestoreContextDto(
                game = GammonRestorer.GammonRestoreContext(
                    deck = mapOf(10 to -1),
                    turn = Gammon.BLACK,
                    zarResult = listOf(),
                    bar = mapOf(Gammon.BLACK to 0, Gammon.WHITE to 0),
                    endFlag = false
                ),
                firstUserId = 0,
                secondUserId = 1,
                type = BackgammonType.SHORT_BACKGAMMON,
                numberOfMoves = 0,
                blackPoints = 0,
                whitePoints = 0,
                thresholdPoints = 7,
                gameNumber = 1,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        doubleCubeService.doubleCube(0, 0, game, null)

        Mockito.verify(doubleCubeDao).saveDouble(eq(0), any())
    }

    @Test
    fun doubleZarAlreadyHaveOfferedOneTest() {
        val game = BackgammonWrapper.buildFromContext(
            restoreContextDto = GammonRestoreContextDto(
                game = GammonRestorer.GammonRestoreContext(
                    deck = mapOf(10 to -1),
                    turn = Gammon.BLACK,
                    zarResult = listOf(),
                    bar = mapOf(Gammon.BLACK to 0, Gammon.WHITE to 0),
                    endFlag = false
                ),
                firstUserId = 0,
                secondUserId = 1,
                type = BackgammonType.SHORT_BACKGAMMON,
                numberOfMoves = 0,
                blackPoints = 0,
                whitePoints = 0,
                thresholdPoints = 7,
                gameNumber = 1,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        val doubleCube = DoubleCube(
            gameId = 0,
            moveId = 1,
            by = Color.BLACK,
            isAccepted = false,
            at = Instant.now()
        )
        Mockito.`when`(doubleCubeDao.getAllDoubles(0, 1)).thenReturn(
            mutableListOf(
                doubleCube
            )
        )
        val thrown = assertThrows<ResponseStatusException> { doubleCubeService.doubleCube(0, 0, game, null) }

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, thrown.statusCode)
    }

    @Test
    fun doubleZarOffered2InARowTest() {
        val game = BackgammonWrapper.buildFromContext(
            restoreContextDto = GammonRestoreContextDto(
                game = GammonRestorer.GammonRestoreContext(
                    deck = mapOf(10 to -1),
                    turn = Gammon.BLACK,
                    zarResult = listOf(),
                    bar = mapOf(Gammon.BLACK to 0, Gammon.WHITE to 0),
                    endFlag = false
                ),
                firstUserId = 0,
                secondUserId = 1,
                type = BackgammonType.SHORT_BACKGAMMON,
                numberOfMoves = 0,
                blackPoints = 0,
                whitePoints = 0,
                thresholdPoints = 7,
                gameNumber = 1,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        val doubleCube = DoubleCube(
            gameId = 0,
            moveId = 1,
            by = Color.BLACK,
            isAccepted = true,
            at = Instant.now()
        )
        Mockito.`when`(doubleCubeDao.getAllDoubles(0, 1)).thenReturn(
            mutableListOf(
                doubleCube
            )
        )
        val thrown = assertThrows<ResponseStatusException> { doubleCubeService.doubleCube(0, 0, game, null) }

        assertEquals(HttpStatus.UNPROCESSABLE_ENTITY, thrown.statusCode)
    }
}