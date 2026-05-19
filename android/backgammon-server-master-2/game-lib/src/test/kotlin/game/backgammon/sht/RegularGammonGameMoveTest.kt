package game.backgammon.sht

import game.backgammon.Gammon.Companion.BLACK
import game.backgammon.Gammon.Companion.WHITE
import game.backgammon.dto.MoveDto
import game.backgammon.exception.CantExitBackgammonException
import game.backgammon.exception.IncorrectPositionForMoveBackgammonException
import game.backgammon.lng.RegularGammonGame
import game.backgammon.lng.RegularGammonGame.Companion.BLACK_HEAD
import game.backgammon.lng.RegularGammonGame.Companion.WHITE_HEAD
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.Mockito
import java.util.*
import kotlin.test.assertEquals

class RegularGammonGameMoveTest {
    private var game: RegularGammonGame = RegularGammonGame()

    @BeforeEach
    fun setUp() {
        val random = Mockito.mock(Random::class.java)
        Mockito.`when`(random.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(2, 1)
        game = RegularGammonGame(random)
        for (i in game.deck.indices) {
            game.deck[i] = 0
        }
    }

    @Test
    fun whiteStartMoveTest() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1, 2)
        game.turn = WHITE
        game.deck[WHITE_HEAD] = 15
        game.zarResults = arrayListOf()
        game.tossBothZar()

        game.move(WHITE, listOf(MoveDto(WHITE_HEAD, WHITE_HEAD + 1), MoveDto(WHITE_HEAD + 1, WHITE_HEAD + 3)))

        assertEquals(14, game.deck[WHITE_HEAD])
        assertEquals(0, game.deck[WHITE_HEAD + 1])
        assertEquals(0, game.deck[WHITE_HEAD + 2])
        assertEquals(1, game.deck[WHITE_HEAD + 3])
    }


    @Test
    fun blackStartMoveTest() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1, 2)
        game.turn = BLACK
        game.deck[BLACK_HEAD] = -15
        game.zarResults = arrayListOf()
        game.tossBothZar()

        game.move(BLACK, listOf(MoveDto(BLACK_HEAD, BLACK_HEAD + 1), MoveDto(BLACK_HEAD + 1, BLACK_HEAD + 3)))

        assertEquals(-14, game.deck[BLACK_HEAD])
        assertEquals(0, game.deck[BLACK_HEAD + 1])
        assertEquals(0, game.deck[BLACK_HEAD + 2])
        assertEquals(-1, game.deck[BLACK_HEAD + 3])
    }


    @Test
    fun blackMoveOverEdgeTest() {
        val zar = 5
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(zar)
        game.turn = BLACK
        game.deck[BLACK_HEAD] = -15
        game.zarResults = arrayListOf()
        game.tossBothZar()

        game.move(
            BLACK,
            listOf(
                MoveDto(BLACK_HEAD, 18),
                MoveDto(18, 23),
                MoveDto(23, 4),
                MoveDto(4, 9),
            )
        )

        assertEquals(-14, game.deck[BLACK_HEAD])
        assertEquals(-1, game.deck[9])
    }


    @Test
    fun cantMoveInBlockTest() {
        game.turn = BLACK
        game.deck[BLACK_HEAD] = -15
        game.deck[BLACK_HEAD + 1] = 1
        game.deck[BLACK_HEAD + 2] = 1

        assertThrows<IncorrectPositionForMoveBackgammonException> {
            game.move(
                BLACK,
                listOf(
                    MoveDto(BLACK_HEAD, BLACK_HEAD + 1),
                    MoveDto(BLACK_HEAD + 1, BLACK_HEAD + 3),
                )
            )
        }
    }


    @Test
    fun blackExitTest() {
        game.turn = BLACK
        game.deck[BLACK_HEAD] = 0
        game.deck[12] = -1

        game.zarResults = arrayListOf(1)

        game.move(
            BLACK,
            listOf(
                MoveDto(12, 0)
            )
        )

        assertEquals(-1, game.deck[0])
    }

    @Test
    fun blackCantExitTest() {
        game.turn = BLACK
        game.deck[BLACK_HEAD] = 0
        game.deck[12] = -1
        game.deck[6] = -1

        game.zarResults = arrayListOf(1)

        assertThrows<CantExitBackgammonException> {
            game.move(
                BLACK,
                listOf(
                    MoveDto(12, 0)
                )
            )
        }
    }

    @Test
    fun whiteExitTest() {
        game.turn = WHITE
        game.deck[WHITE_HEAD] = 0
        game.deck[24] = 1

        game.zarResults = arrayListOf(1)

        game.move(
            WHITE,
            listOf(
                MoveDto(24, 25)
            )
        )

        assertEquals(1, game.deck[25])
    }


    @Test
    fun whiteCantExitTest() {
        game.turn = WHITE
        game.deck[WHITE_HEAD] = 0
        game.deck[24] = 1
        game.deck[18] = 1

        game.zarResults = arrayListOf(1)

        assertThrows<CantExitBackgammonException> {
            game.move(
                WHITE,
                listOf(
                    MoveDto(24, 25)
                )
            )
        }
    }
}