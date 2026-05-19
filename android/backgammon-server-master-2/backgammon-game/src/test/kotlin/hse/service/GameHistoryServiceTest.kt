package hse.service

import game.backgammon.Gammon
import game.backgammon.GammonRestorer
import game.backgammon.dto.ChangeDto
import game.backgammon.enums.Color
import hse.dto.GameEndHistoryResponseItem
import hse.dto.GammonRestoreContextDto
import hse.dto.MoveHistoryResponseItem
import hse.dto.OfferDoubleHistoryResponseItem
import hse.entity.*
import org.junit.jupiter.api.Test
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.mock.mockito.MockBean
import org.springframework.test.context.TestConstructor
import java.time.Instant
import kotlin.test.assertEquals

@SpringBootTest
@TestConstructor(autowireMode = TestConstructor.AutowireMode.ALL)
class GameHistoryServiceTest {

    @Autowired
    private lateinit var gameHistoryService: GameHistoryService

    @MockBean
    private lateinit var gammonStoreService: GammonStoreService

    @Test
    fun `happy path test`() {
        val matchId = 1
        val gameId = 1
        val restoreContextDto = mock(GammonRestoreContextDto::class.java)
        val restoreContext = mock(GammonRestorer.GammonRestoreContext::class.java)
        `when`(restoreContextDto.game).thenReturn(restoreContext)
        `when`(restoreContext.turn).thenReturn(Gammon.BLACK)
        val gameHistoryFromDb = listOf(
            GameWithId(
                matchId = matchId,
                gameId = gameId,
                restoreContextDto = restoreContextDto,
                at = Instant.now()
            ),
            Zar(
                gameId = gameId,
                moveId = 0,
                z = listOf(1, 2),
                at = Instant.now()
            ),
            MoveWithId(
                matchId = matchId,
                gameId = gameId,
                moveSet = MoveSet(
                    moves = ChangeDto(listOf(0 to 1, 0 to 2)),
                    gameId = gameId,
                    moveId = 0,
                    color = Color.BLACK,
                ),
                at = Instant.now()
            ),
            DoubleCube(
                gameId = gameId,
                moveId = 1,
                by = Color.WHITE,
                isAccepted = false,
                at = Instant.now()
            ),
            GameWinner(
                matchId = matchId,
                gameId = gameId,
                winner = Gammon.WHITE,
                points = 1,
                surrender = false,
                endMatch = false,
                at = Instant.now()
            )
        )
        `when`(gammonStoreService.getAllInGameInOrderByInsertionTime(matchId, gameId)).thenReturn(gameHistoryFromDb)


        val result = gameHistoryService.getHistory(matchId, gameId)

        assertEquals(Color.BLACK, result.firstToMove)
        assertEquals(3, result.items.size)
        assertEquals(
            MoveHistoryResponseItem(
                listOf(1, 2),
                listOf(MoveHistoryResponseItem.MoveItem(0, 1), MoveHistoryResponseItem.MoveItem(0, 2))
            ), result.items[0]
        )
        assertEquals(OfferDoubleHistoryResponseItem(Color.WHITE, 2), result.items[1])
        assertEquals(GameEndHistoryResponseItem(1, 0, Color.WHITE, false), result.items[2])
    }
}