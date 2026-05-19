package game.backgammon.sht

import game.backgammon.dto.MoveDto
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource
import org.mockito.Mockito
import java.util.*
import kotlin.math.absoluteValue

class ShortGammonGameMoveTest {


    private var game: ShortGammonGame = ShortGammonGame()

    @BeforeEach
    fun setUp() {
        val random = Mockito.mock(Random::class.java)
        Mockito.`when`(random.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(2, 1)
        game = ShortGammonGame(random)
        for (i in game.deck.indices) {
            game.deck[i] = 0
        }
    }

    @ParameterizedTest
    @CsvSource("1, 2", "2, 1")
    fun moveFromBarTest(first: Int, second: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1, 2)
        game.bar[-1] = -2
        game.deck[1] = 0
        game.deck[2] = 0
        game.turn = -1

        game.move(-1, listOf(MoveDto(0, first), MoveDto(0, second)))

        assertEquals(0, game.bar[-1])
        assertEquals(-1, game.deck[1])
        assertEquals(-1, game.deck[2])
    }

    @ParameterizedTest
    @CsvSource("1, 2", "2, 1")
    fun moveFromBarWithKnockOut(first: Int, second: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1, 2)
        game.bar[-1] = -2
        game.deck[1] = 1
        game.deck[2] = 1
        game.turn = -1

        val actualRes = game.move(-1, listOf(MoveDto(0, first), MoveDto(0, second)))

        println(actualRes)

        assertEquals(0, game.bar[-1])
        assertEquals(-1, game.deck[1])
        assertEquals(-1, game.deck[2])
        assertEquals(2, game.bar[1])
    }

    @Test
    fun moveHome() {
        game.zarResults = arrayListOf(4, 5)
        game.deck = ArrayList(MutableList(game.deck.size) { 0 })
        game.deck[4] = 3
        game.deck[5] = 4
        game.turn = 1

        game.move(1, listOf(MoveDto(4, 0), MoveDto(5, 0)))

        assertEquals(2, game.deck[0])
        assertEquals(2, game.deck[4])
        assertEquals(3, game.deck[5])
    }

    @Test
    fun cantMoveHome() {
        game.zarResults = arrayListOf(4)
        game.deck = ArrayList(MutableList(game.deck.size) { 0 })
        game.deck[4] = 3
        game.deck[7] = 1
        game.turn = 1

        assertThrows<RuntimeException> { game.move(1, listOf(MoveDto(4, 0))) }

        assertEquals(0, game.deck[0])
        assertEquals(3, game.deck[4])
        assertEquals(1, game.deck[7])
    }


    @ParameterizedTest
    @CsvSource("4, 5", "5, 4")
    fun moveHomeFromFor2MovesBiggerZar(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.deck[8] = 1
        game.turn = 1
        game.zarResults = arrayListOf()
        game.tossBothZar()

        game.move(game.turn, listOf(MoveDto(8, 8 - firstZar), MoveDto(8 - firstZar, 0)))

        assertEquals(1, game.deck[0])
    }


    @Test
    fun moveToStoreOnlyOneOnDeck() {
        game.deck[23] = -1
        game.turn = -1
        game.zarResults = arrayListOf(3)

        game.move(game.turn, listOf(MoveDto(23, 25)))

        assertEquals(1, game.deck[25].absoluteValue)
    }
}