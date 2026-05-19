package game.backgammon.sht

import jdk.jfr.Description
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource
import org.mockito.Mockito
import java.util.*
import kotlin.test.Test
import kotlin.test.assertEquals

class ShortBackgammonGameTossZarTest {

    private var game: ShortGammonGame = ShortGammonGame()

    private var firstUser = -1
    private var secondUser = 1

    @BeforeEach
    fun setUp() {
        val random = Mockito.mock(Random::class.java)
        Mockito.`when`(random.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(2, 1)
        game = ShortGammonGame(random)
        for (i in game.deck.indices) {
            game.deck[i] = 0
        }
    }

    @Test
    fun cantMoveFromBar() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1)
        game.turn = firstUser
        game.zarResults = arrayListOf()
        game.bar[firstUser] = -1
        game.deck[1] = 2
        game.deck[2] = -1

        game.tossBothZar()

        assertEquals(firstUser, game.turn)
        assertEquals(2, game.deck[1])
        assertEquals(-1, game.bar[firstUser])
        assertEquals(0, game.zarResults.size)
    }

    @Test
    fun cantDoRegularMove() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1, 2)
        game.turn = firstUser
        game.zarResults = arrayListOf()
        game.deck[1] = -1
        game.deck[2] = 2
        game.deck[3] = 2

        game.tossBothZar()

        assertEquals(firstUser, game.turn)
        assertEquals(-1, game.deck[1])
        assertEquals(2, game.deck[2])
        assertEquals(2, game.deck[3])
        assertEquals(0, game.zarResults.size)
    }

    @Test
    fun canDoMoveTroughKnockOut() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(2, 1)
        game.turn = firstUser
        game.zarResults = arrayListOf()
        game.deck[1] = -1
        game.deck[2] = 1
        game.deck[3] = 1

        game.tossBothZar()

        assertEquals(firstUser, game.turn)
        assertEquals(-1, game.deck[1])
        assertEquals(1, game.deck[2])
        assertEquals(1, game.deck[3])
        assertEquals(2, game.zarResults.size)
    }

    @Test
    fun canMove3from4ForLuckyZar() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1)
        game.turn = secondUser
        game.zarResults = arrayListOf()
        game.deck[24] = 1
        game.deck[20] = -2
        game.deck[19] = -2

        game.tossBothZar()

        assertEquals(secondUser, game.turn)
        assertEquals(1, game.deck[24])
        assertEquals(-2, game.deck[20])
        assertEquals(-2, game.deck[19])
        assertEquals(3, game.zarResults.size)
    }

    @Test
    fun canMoveHome() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(2)
        game.turn = secondUser
        game.zarResults = arrayListOf()
        game.deck[0] = 0
        game.deck[1] = 1
        game.deck[2] = 3

        game.tossBothZar()

        assertEquals(secondUser, game.turn)
        assertEquals(0, game.deck[0])
        assertEquals(1, game.deck[1])
        assertEquals(3, game.deck[2])
        assertEquals(4, game.zarResults.size)
    }

    @Test
    @Description("Можно два хода: 18 -> 19 и сброс 23")
    fun advancedMoveHome() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(1, 2)
        game.turn = firstUser
        game.zarResults = arrayListOf()
        game.deck[24] = 2
        game.deck[23] = -1
        game.deck[21] = 2
        game.deck[18] = -1

        game.tossBothZar()

        assertEquals(firstUser, game.turn)
        assertEquals(2, game.deck[24])
        assertEquals(2, game.deck[21])
        assertEquals(-1, game.deck[23])
        assertEquals(-1, game.deck[18])
        assertEquals(2, game.zarResults.size)
    }

    @Test
    @Description("Проверка 10 -> 4/5 -> 0")
    fun advancedMoveHomeRuleOfBiggestZar() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(5, 6)
        game.turn = secondUser
        game.zarResults = arrayListOf()
        game.deck[10] = 1
        game.deck[1] = 1

        game.tossBothZar()

        assertEquals(secondUser, game.turn)
        assertEquals(1, game.deck[10])
        assertEquals(1, game.deck[1])
        assertEquals(2, game.zarResults.size)
    }

    @ParameterizedTest
    @CsvSource("1, 2", "2, 1")
    fun canMoveFromBarOnlyOnes(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.turn = firstUser
        game.zarResults = arrayListOf()
        game.bar[firstUser] = -1
        game.deck[1] = 2
        game.deck[3] = 2

        game.tossBothZar()

        assertEquals(-1, game.turn)
        assertEquals(1, game.zarResults.size)
        assertEquals(2, game.zarResults.first())
    }

    @ParameterizedTest
    @CsvSource("1, 2", "2, 1")
    fun canMoveOnlyOne(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.turn = -1
        game.zarResults = arrayListOf()
        game.deck[1] = -1
        game.deck[4] = 2

        game.tossBothZar()

        assertEquals(-1, game.turn)
        assertEquals(1, game.zarResults.size)
        assertEquals(2, game.zarResults.first())
    }

    @Test
    fun moveAllFromBar() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(3)
        game.turn = 1
        game.zarResults = arrayListOf()
        game.bar[1] = 4
        game.deck[24] = -2

        game.tossBothZar()

        assertEquals(1, game.turn)
        assertEquals(4, game.zarResults.size)
    }

    @Test
    // Тест покрывает баг, когда нельзя сходить в стор из дома, из-за чего игнорировались ходы из других секций
    fun moveSeveralTimes() {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(5, 6)
        game.turn = -1
        game.zarResults = arrayListOf()
        game.bar[-1] = -1
        game.deck[1] = 1
        game.deck[4] = -1
        game.deck[5] = -1
        game.deck[6] = 4
        game.deck[8] = 3
        game.deck[12] = -5
        game.deck[13] = 5
        game.deck[18] = 1
        game.deck[19] = -5
        game.deck[21] = -2
        game.deck[24] = 1

        game.tossBothZar()

        assertEquals(-1, game.turn)
        assertEquals(2, game.zarResults.size)
    }


    @ParameterizedTest
    @CsvSource("1, 6", "6, 1")
    fun blockingMoveFromBar(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.bar[-1] = -2
        game.deck[1] = -2
        game.deck[6] = 4
        game.turn = -1

        game.zarResults = arrayListOf()
        game.tossBothZar()

        assertEquals(1, game.zarResults.size)
        assertEquals(1, game.zarResults.first())
    }


    @ParameterizedTest
    @CsvSource("4, 5", "5, 4")
    fun goToStore(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.deck[8] = 1
        game.turn = 1

        game.zarResults = arrayListOf()
        game.tossBothZar()

        assertEquals(2, game.zarResults.size)
    }

    @ParameterizedTest
    @CsvSource("3, 5", "5, 3")
    fun moveToStoreOnlyOneOnDeck(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.deck[0] = 14
        game.deck[1] = 1
        game.turn = 1
        game.zarResults = arrayListOf()
        game.tossBothZar()

        Assertions.assertEquals(1, game.zarResults.size)
    }

    @ParameterizedTest
    @CsvSource("4, 6", "6, 4")
    fun cantMoveBiggestZar(firstZar: Int, secondZar: Int) {
        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(firstZar, secondZar)
        game.deck[10] = -1
        game.deck[16] = 2
        game.deck[19] = -5
        game.deck[20] = 2
        game.deck[21] = 1
        game.deck[22] = -4
        game.deck[23] = -2
        game.deck[24] = -3
        game.turn = -1
        game.zarResults = arrayListOf()
        game.tossBothZar()

        Assertions.assertEquals(1, game.zarResults.size)
        Assertions.assertEquals(4, game.zarResults.first())
    }

    @Test
    fun tossEvent228() {
        /*
        "{\"game\":{\"deck\":{\"3\":4,\"6\":4,\"11\":2,\"12\":-3,\"16\":-2,\"18\":1,\"19\":-6,\"20\":-3,\"21\":3,\"24\":-1},\"turn\":1,\"zarResult\":[5,5,5,5],\"bar\":{\"-1\":0,\"1\":1},\"endFlag\":false},\"firstUserId\":2,\"secondUserId\":1,\"type\":\"SHORT_BACKGAMMON\",\"numberOfMoves\":34}"
         */

        Mockito.`when`(game.zar.nextInt(Mockito.anyInt(), Mockito.anyInt())).thenReturn(5, 5)
        game.deck[3] = 4
        game.deck[6] = 4
        game.deck[11] = 2
        game.deck[12] = -3
        game.deck[16] = -2
        game.deck[18] = 1
        game.deck[19] = -6
        game.deck[20] = -3
        game.deck[21] = 3
        game.deck[24] = -1
        game.bar[1] = 1

        game.turn = 1
        game.zarResults = arrayListOf()
        game.tossBothZar()

        Assertions.assertEquals(0, game.zarResults.size)
    }
}