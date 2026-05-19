import model.*
import kotlin.js.Date
import kotlin.random.Random
import kotlin.reflect.KClass
import kotlin.test.*

/**
 * A class for receiving and storing GameEvents in a queue.
 */
class EventSink {
    private val sink = ArrayDeque<GameEvent>()

    /**
     * Check whether the next event is of the given type.
     */
    private fun <T : Any> expectType(type: KClass<T>): T {
        assertFalse(sink.isEmpty(), "Sink shouldn't be empty -- expecting ${type.simpleName}")
        val next = sink.removeFirst()
        assertTrue(type.isInstance(next), "Event is of the wrong class: ${next::class.simpleName} instead of ${type.simpleName}")
        return (next as T)
    }

    fun expectNoEvent() {
        if (sink.isNotEmpty())
            assertFalse(true, "No event expected, but got one: ${sink.first()::class.simpleName}")
    }

    fun expectNewRound() {
        expectType(NewRoundEvent::class)
    }

    fun expectInitialDiceRoll() {
        expectType(InitialDiceRollEvent::class)
    }

    fun expectNewTurn() {
        expectType(NewTurnEvent::class)
    }

    fun expectDiceRoll(): Dice {
        return expectType(DiceRollEvent::class).dice
    }

    fun expectMove(): Move {
        return expectType(MoveEvent::class).move
    }

    fun expectRoundEnd(): Int {
        return expectType(RoundEndEvent::class).winner
    }

    fun expectGameEnd(): Int {
        return expectType(GameEndEvent::class).winner
    }

    fun insert(event: GameEvent) {
        sink.addLast(event)
    }
}

class TestGame {

    var sink = EventSink()

    @BeforeTest
    fun init() {
        sink = EventSink()
    }

    @Test
    fun testGameStart() {
        // initialize a game and seed the Dice to make the test reproducible
        val game = Game(1, sink::insert)
        Dice.setSeed(1441)

        sink.expectNoEvent()
        assertEquals(Result.NOT_STARTED, game.currentRoundResult(), "Round should not have started")
        assertEquals(Result.NOT_STARTED, game.finalGameResult(), "Game should not have started")


        // start a new round and a turn
        game.startNewRound()
        sink.expectNewRound()
        sink.expectInitialDiceRoll()
        sink.expectNewTurn()
        sink.expectNoEvent()
        assertNotNull(game.turnOf(), "Game turnOf should NOT be null")
        assertNotNull(game.gameState, "Gamestate should NOT be null")
        assertEquals(1, game.gameIdx, "Game index should be 1")


        var turnOf = game.turnOf()!!
        game.rollDice()
        sink.expectDiceRoll()
        assertNotNull(game.dice, "Dice should not be null")
        val dice = game.dice!!
        println("Dice rolled: $dice")

        // choose one of the available moves (we know they exist in the initial state)
        val moveSequences = game.gameState!!.possibleMoveSequences()
        assertNotEquals(0, moveSequences.size, "Move sequences should exist")
        val moves = moveSequences[0]

        // make the moves one-by-one, we should get a MoveEvent after each
        for (move in moves) {
            assertTrue(game.isMovePossible(move.from, move.to), "Move $move should be possible")
            game.makeMove(move.from, move.to)
            sink.expectMove()
        }
        sink.expectNewTurn()
        sink.expectNoEvent()

        // player2's turn
        game.rollDice()
        sink.expectDiceRoll()
        println(asciiBoard(game.gameState!!))
    }

    @Test
    fun testOneRound() {
        // initialize a game and seed the Dice to make the test reproducible
        val game = Game(4, sink::insert)
        Dice.setSeed(42)

        game.startNewRound()
        sink.expectNewRound()
        sink.expectInitialDiceRoll()
        sink.expectNewTurn()

        assertEquals(Result.RUNNING, game.currentRoundResult(), "Game should be running")
        while (game.currentRoundResult() == Result.RUNNING) {
            val prevState = game.gameState!!.deepcopy()
            game.rollDice()
            val dice = sink.expectDiceRoll()

            // check possible moves (using the saved state, because game.gameState could have changed)
            prevState.setDice(dice)
            val moveSeq = prevState.possibleMoveSequences()
            if (moveSeq.isEmpty()) {
                sink.expectNewTurn()
                continue
            }

            // choose moves and make them
            val moves = moveSeq[0]
            println(asciiBoard(game.gameState!!))
            for (move in moves) {
                game.makeMove(move.from, move.to)
                sink.expectMove()
            }
            // if the current player won, round end is expected
            if (game.currentRoundResult() in listOf(Result.PLAYER1_WON, Result.PLAYER2_WON)) {
                sink.expectRoundEnd()
                break
            } else {
                sink.expectNewTurn()
            }
        }
        sink.expectNoEvent()
    }

    fun runMultipleRounds(N: Int, seed: Int = 1900) {
        // initialize a game and seed the Dice to make the test reproducible
        val game = Game(N, sink::insert)
        Dice.setSeed(seed)
        // random generator for choosing moves
        val random = Random(2*seed)

        // run N rounds (or less if one player wins more than half earlier)
        for (round in 1..N) {
            game.startNewRound()
            sink.expectNewRound()
            sink.expectInitialDiceRoll()
            sink.expectNewTurn()

            assertEquals(Result.RUNNING, game.currentRoundResult(), "Game should be running")
            val nCheckers = mutableMapOf(1 to 15, 2 to 15)
            while (game.currentRoundResult() == Result.RUNNING) {
                val prevState = game.gameState!!.deepcopy()
                game.rollDice()
                val dice = sink.expectDiceRoll()

                // check possible moves (using the saved state, because game.gameState could have changed)
                prevState.setDice(dice)
                val moveSeq = prevState.possibleMoveSequences()
                if (moveSeq.isEmpty()) {
                    sink.expectNewTurn()
                    continue
                }

                //println(asciiBoard(game.gameState!!))

                // choose moves and make them
                val moves = moveSeq[random.nextInt(0, moveSeq.size)]
                for (move in moves) {
                    if (move.to == -1) nCheckers[game.turnOf()!!] = nCheckers[game.turnOf()!!]!! - 1
                    game.makeMove(move.from, move.to)
                    val movemade = sink.expectMove()
                    assertEquals(move, movemade, "Move requested and move made are not equal")
                }

                // check whether the number of checkers on the board is correct
                for (i in 1..2) {
                    val checkers = game.gameState!!.fields.zip(game.gameState!!.fieldPlayerIdx).sumOf {
                        if (it.second == i) it.first else 0
                    }
                    assertEquals(nCheckers[i]!!, checkers, "Number of checkers on the board for player $i is incorrect")
                }


                // if the current player won, round end is expected
                if (game.currentRoundResult() in listOf(Result.PLAYER1_WON, Result.PLAYER2_WON)) {
                    sink.expectRoundEnd()
                    break
                } else {
                    sink.expectNewTurn()
                }
            }
            val winner = if (game.currentRoundResult() == Result.PLAYER1_WON) 1 else 2
            println("Round $round won by Player${winner} (${game.playerScore1} - ${game.playerScore2}), final board: ")
            println(asciiBoard(game.gameState!!))
            if (game.playerScore1 >= N || game.playerScore2 >= N) {
                val gameWinner = sink.expectGameEnd()
                println("Final winner: Player$winner.")
                break
            }
            sink.expectNoEvent()
        }
        sink.expectNoEvent()
    }

    @Test
    fun testGameFewRounds() {
        runMultipleRounds(5, 55)
    }

    @Test
    fun testGameLotsOfRounds() {
        val start = Date.now()
        runMultipleRounds(50, 565)
        val total = Date.now() - start
        println("50 games took: $total s")
    }


}