package hse.facade

import game.backgammon.Gammon
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import game.backgammon.enums.DoubleCubePositionEnum
import game.common.enums.TimePolicy
import hse.dto.EndGameEvent
import hse.entity.DoubleCube
import hse.factory.GameTimerFactory
import hse.service.DoubleCubeService
import hse.service.EmitterService
import hse.service.GameTimerService
import hse.service.GammonStoreService
import hse.wrapper.BackgammonWrapper
import org.junit.jupiter.api.Test
import org.mockito.Mockito
import org.mockito.kotlin.eq
import kotlin.test.assertEquals

class GammonFacadeTest {
    private var service: GameFacade

    private val emitterService: EmitterService = Mockito.mock(EmitterService::class.java)
    private val gammonStoreService: GammonStoreService = Mockito.mock(GammonStoreService::class.java)
    private val doubleCubeService: DoubleCubeService = Mockito.mock(DoubleCubeService::class.java)
    private val timerService: GameTimerService = Mockito.mock(GameTimerService::class.java)
    private val gameTimerFactory: GameTimerFactory = Mockito.mock(GameTimerFactory::class.java)

    init {
        service = GameFacade(
            emitterService, gammonStoreService, doubleCubeService, timerService, gameTimerFactory
        )
    }

    @Test
    fun `handle game end happy path`() {
        val wrapper = Mockito.spy(
            BackgammonWrapper(
                game = Mockito.mock(Gammon::class.java),
                type = BackgammonType.SHORT_BACKGAMMON,
                gameId = 1,
                blackPoints = 0,
                whitePoints = 0,
                thresholdPoints = 2,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        Mockito.doReturn(mapOf(true to Color.BLACK, false to Color.WHITE)).`when`(wrapper).gameEndStatus()
        Mockito.doReturn(1).`when`(wrapper).getPointsForGame()

        service.handleGameEnd(1, wrapper, null)

        Mockito.verify(wrapper, Mockito.times(1)).restore()
        Mockito.verify(gammonStoreService, Mockito.times(1)).saveGameOnCreation(1, 2, wrapper)
        Mockito.verify(emitterService, Mockito.times(1))
            .sendForAll(eq(1), eq(EndGameEvent(Color.BLACK, 1, 0, false, null, null)))
        assertEquals(1, wrapper.blackPoints)
    }

    @Test
    fun `handle match end happy path`() {
        val wrapper = Mockito.spy(
            BackgammonWrapper(
                game = Mockito.mock(Gammon::class.java),
                type = BackgammonType.SHORT_BACKGAMMON,
                gameId = 1,
                blackPoints = 1,
                whitePoints = 0,
                thresholdPoints = 2,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        Mockito.doReturn(mapOf(true to Color.BLACK, false to Color.WHITE)).`when`(wrapper).gameEndStatus()
        Mockito.doReturn(1).`when`(wrapper).getPointsForGame()

        service.handleGameEnd(1, wrapper, null)

        Mockito.verify(wrapper, Mockito.times(0)).restore()
        Mockito.verify(gammonStoreService, Mockito.times(0)).saveGameOnCreation(1, 2, wrapper)
        Mockito.verify(emitterService, Mockito.times(1))
            .sendForAll(1, EndGameEvent(Color.BLACK, 2, 0, true, null, null))
        assertEquals(2, wrapper.blackPoints)
    }

    @Test
    fun `surrender game match not ended`() {
        val game = Mockito.mock(Gammon::class.java)
        Mockito.`when`(game.turn).thenReturn(1)
        val wrapper = Mockito.spy(
            BackgammonWrapper(
                game = game,
                type = BackgammonType.SHORT_BACKGAMMON,
                gameId = 0,
                blackPoints = 0,
                whitePoints = 0,
                thresholdPoints = 2,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        val playerId = 1
        val matchId = 2
        val doubles = listOf(Mockito.mock(DoubleCube::class.java))
        Mockito.doReturn(wrapper).`when`(gammonStoreService).getMatchById(matchId)
        Mockito.doReturn(Color.BLACK).`when`(wrapper).getPlayerColor(playerId)
        Mockito.doReturn(doubles).`when`(doubleCubeService).getAllDoubles(matchId, 0)
        Mockito.doReturn(true).`when`(wrapper).hasInStore(playerId)
        Mockito.doReturn(DoubleCubePositionEnum.BELONGS_TO_BLACK).`when`(doubleCubeService)
            .getDoubleCubePosition(matchId, wrapper, doubles)
        Mockito.doReturn(1).`when`(wrapper).getPointsForGame()


        service.surrender(playerId, matchId, false)

        Mockito.verify(wrapper).restore()
        Mockito.verify(gammonStoreService).saveGameOnCreation(matchId, 1, wrapper)
        Mockito.verify(emitterService).sendForAll(matchId, EndGameEvent(Color.WHITE, 0, 1, false, null, null))
        assertEquals(1, wrapper.whitePoints)
        assertEquals(0, wrapper.blackPoints)
    }

    @Test
    fun `surrender game end match`() {
        val game = Mockito.mock(Gammon::class.java)
        Mockito.`when`(game.turn).thenReturn(1)
        val wrapper = Mockito.spy(
            BackgammonWrapper(
                game = game,
                type = BackgammonType.SHORT_BACKGAMMON,
                gameId = 0,
                blackPoints = 0,
                whitePoints = 0,
                thresholdPoints = 2,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        val double = Mockito.mock(DoubleCube::class.java)
        Mockito.`when`(double.isAccepted).thenReturn(true)
        Mockito.doReturn(wrapper).`when`(gammonStoreService).getMatchById(1)
        Mockito.doReturn(Color.BLACK).`when`(wrapper).getPlayerColor(1)
        Mockito.doReturn(listOf(double, Mockito.mock())).`when`(doubleCubeService).getAllDoubles(1, 0)
        Mockito.doReturn(1).`when`(wrapper).getPointsForGame()


        service.surrender(1, 1, false)

        Mockito.verify(wrapper, Mockito.never()).restore()
        Mockito.verify(gammonStoreService, Mockito.never()).saveGameOnCreation(1, 1, wrapper)
        Mockito.verify(emitterService).sendForAll(1, EndGameEvent(Color.WHITE, 0, 2, true, null, null))
        assertEquals(2, wrapper.whitePoints)
        assertEquals(0, wrapper.blackPoints)
    }

    @Test
    fun `surrender match`() {
        val game = Mockito.mock(Gammon::class.java)
        Mockito.`when`(game.turn).thenReturn(1)
        val wrapper = Mockito.spy(
            BackgammonWrapper(
                game = game,
                type = BackgammonType.SHORT_BACKGAMMON,
                gameId = 0,
                blackPoints = 4,
                whitePoints = 2,
                thresholdPoints = 5,
                timePolicy = TimePolicy.NO_TIMER
            )
        )
        val double = Mockito.mock(DoubleCube::class.java)
        Mockito.`when`(double.isAccepted).thenReturn(true)
        Mockito.doReturn(wrapper).`when`(gammonStoreService).getMatchById(1)
        Mockito.doReturn(Color.BLACK).`when`(wrapper).getPlayerColor(1)
        Mockito.doReturn(listOf(double, Mockito.mock())).`when`(doubleCubeService).getAllDoubles(1, 0)
        Mockito.doReturn(1).`when`(wrapper).getPointsForGame()


        service.surrender(1, 1, true)

        Mockito.verify(wrapper, Mockito.never()).restore()
        Mockito.verify(gammonStoreService, Mockito.never()).saveGameOnCreation(1, 1, wrapper)
        Mockito.verify(emitterService).sendForAll(1, EndGameEvent(Color.WHITE, 4, 4, true, null, null))
        assertEquals(4, wrapper.whitePoints)
        assertEquals(4, wrapper.blackPoints)
    }
}