package hse.service

import game.backgammon.GammonRestorer
import game.backgammon.dto.ChangeDto
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import game.common.enums.TimePolicy
import hse.dto.GammonRestoreContextDto
import hse.entity.MoveSet
import org.junit.jupiter.api.Test
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.TestConstructor
import kotlin.test.assertEquals


@SpringBootTest
@TestConstructor(autowireMode = TestConstructor.AutowireMode.ALL)
class RegularGammonGameStoreServiceTest(
    private val gammonStoreService: GammonStoreService,
) {

    @Test
    fun restoreBlackTest() {
        val state = GammonRestoreContextDto(
            game = GammonRestorer.GammonRestoreContext(
                deck = mapOf(
                    3 to 10
                ),
                turn = -1,
                zarResult = listOf(),
                bar = mapOf(-1 to -2, 1 to 0),
                endFlag = false
            ),
            firstUserId = 1,
            secondUserId = 2,
            type = BackgammonType.SHORT_BACKGAMMON,
            numberOfMoves = 1,
            blackPoints = 0,
            whitePoints = 0,
            thresholdPoints = 10,
            gameNumber = 1,
            timePolicy = TimePolicy.NO_TIMER
        )
        val moves = listOf(
            MoveSet(
                moves = ChangeDto(
                    changes = listOf(Pair(0, 1), Pair(0, 2))
                ),
                gameId = 1,
                moveId = 1,
                color = Color.BLACK
            )
        )

        val actualGame = gammonStoreService.restoreBackgammon(state, moves, listOf()).getRestoreContext()

        assertEquals(0, actualGame.game.bar[-1])
        assertEquals(-1, actualGame.game.deck[1])
        assertEquals(-1, actualGame.game.deck[2])
        assertEquals(10, actualGame.game.deck[3])
        assertEquals(false, actualGame.game.endFlag)
    }

    @Test
    fun restoreWhiteTest() {
        val state = GammonRestoreContextDto(
            game = GammonRestorer.GammonRestoreContext(
                deck = mapOf(
                    22 to -10
                ),
                turn = 1,
                zarResult = listOf(),
                bar = mapOf(-1 to 0, 1 to 2),
                endFlag = false
            ),
            firstUserId = 1,
            secondUserId = 2,
            type = BackgammonType.SHORT_BACKGAMMON,
            numberOfMoves = 1,
            blackPoints = 0,
            whitePoints = 0,
            thresholdPoints = 10,
            gameNumber = 1,
            timePolicy = TimePolicy.NO_TIMER
        )
        val moves = listOf(
            MoveSet(
                moves = ChangeDto(
                    changes = listOf(Pair(25, 24), Pair(25, 23))
                ),
                gameId = 1,
                moveId = 1,
                color = Color.WHITE
            )
        )

        val actualGame = gammonStoreService.restoreBackgammon(state, moves, listOf(1, 2)).getRestoreContext()

        assertEquals(0, actualGame.game.bar[1])
        assertEquals(1, actualGame.game.deck[24])
        assertEquals(1, actualGame.game.deck[23])
        assertEquals(-10, actualGame.game.deck[22])
        assertEquals(false, actualGame.game.endFlag)
    }

    @Test
    fun restoreWhiteEndFlagTest() {
        val state = GammonRestoreContextDto(
            game = GammonRestorer.GammonRestoreContext(
                deck = mapOf(
                    22 to -10
                ),
                turn = 1,
                zarResult = listOf(),
                bar = mapOf(-1 to 0, 1 to 2),
                endFlag = true
            ),
            firstUserId = 1,
            secondUserId = 2,
            type = BackgammonType.SHORT_BACKGAMMON,
            numberOfMoves = 1,
            blackPoints = 0,
            whitePoints = 0,
            thresholdPoints = 10,
            gameNumber = 1,
            timePolicy = TimePolicy.NO_TIMER
        )
        val moves = listOf(
            MoveSet(
                moves = ChangeDto(
                    changes = listOf(Pair(25, 24), Pair(25, 23))
                ),
                gameId = 1,
                moveId = 1,
                color = Color.WHITE
            )
        )

        val actualGame = gammonStoreService.restoreBackgammon(state, moves, listOf(1, 2)).getRestoreContext()

        assertEquals(0, actualGame.game.bar[1])
        assertEquals(1, actualGame.game.deck[24])
        assertEquals(1, actualGame.game.deck[23])
        assertEquals(-10, actualGame.game.deck[22])
        assertEquals(true, actualGame.game.endFlag)
    }
}