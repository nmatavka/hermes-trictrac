package model


import Dice
import GameState
import Move
import Result
import initialGameState
import kotlinx.serialization.Transient
import kotlinx.serialization.Serializable

/**
 * A backgammon game, which consists of multiple rounds. In each round the winning player
 * gains a score. The game runs until either player reaches `maxScore`. In summary:
 * - A **game** consists of multiple individual rounds until one player reaches `maxScore`.
 * - A **round** consists of multiple **turns**. A round starts with an initial roll that decides who goes first.
 *   Then the players take turns in alteration until one wins the round.
 */
@Serializable
class Game(
    val maxScore: Int,
    @Transient var gameEventListener: ((GameEvent) -> Unit)? = null,
) {
    var gameState: GameState? = null
        private set
    var dice: Dice? = null
        private set
    var playerScore1: Int = 0
        private set
    var playerScore2: Int = 0
        private set
    var gameIdx: Int = 0
        private set

    fun turnOf(): Int? {
        return gameState?.turnOf
    }

    private fun raiseEvent(event: GameEvent) {
        gameEventListener?.invoke(event)
    }

    fun currentRoundResult(): Result {
        return gameState?.roundResult() ?: Result.NOT_STARTED
    }

    fun finalGameResult(): Result {
        if (gameIdx <= 0) return Result.NOT_STARTED
        val currentResult = currentRoundResult()
        if (currentResult in listOf(Result.PLAYER1_WON, Result.PLAYER2_WON)) {
            if (playerScore1 >= maxScore) return Result.PLAYER1_WON
            if (playerScore2 >= maxScore) return Result.PLAYER2_WON
        }
        return Result.RUNNING
    }

    /**
     * Start a new round of the game. The round starts from the initial position.
     * The intial rolls are also performed, and the first turn starts.
     */
    fun startNewRound() {
        if (currentRoundResult() == Result.RUNNING) throw IllegalStateException("A round is already running.")
        if (finalGameResult() !in listOf(Result.NOT_STARTED, Result.RUNNING))
            throw IllegalStateException("Game finished, cannot start a new round.")
        gameIdx += 1
        val rolls = mutableListOf<Dice>()
        while (rolls.isEmpty() || rolls.last().num1 == rolls.last().num2)
            rolls.add(Dice.roll())
        val finalRoll = rolls.last()
        gameState = initialGameState(if (finalRoll.num1 > finalRoll.num2) 1 else 2)
        raiseEvent(NewRoundEvent())
        raiseEvent(InitialDiceRollEvent(rolls))
        raiseEvent(NewTurnEvent(gameState!!.turnOf))
        dice = null
    }

    fun rollDice() {
        if (currentRoundResult() != Result.RUNNING) throw IllegalStateException("Game not running, cannot roll dice.")
        dice = Dice.roll()
        gameState?.setDice(dice!!)
        raiseEvent(DiceRollEvent(dice!!))

        // if no moves are possible after the roll, next turn is performed
        if (gameState!!.anyMovesPossible()) return
        nextTurn()
    }

    private fun nextTurn() {
        checkNotNull(gameState) {"gameState is null, nextTurn() call invalid"}
        dice = null
        gameState!!.nextTurn()
        raiseEvent(NewTurnEvent(gameState!!.turnOf))
    }

    fun isMovePossible(fieldFrom: Int, fieldTo: Int): Boolean {
        checkNotNull(gameState) {"GameState is null, isMovePossible called"}
        return gameState!!.isMovePossible(Move(fieldFrom, fieldTo))
    }

    fun moveableFields(): List<Int> {
        checkNotNull(gameState) {"GameState is null, isMovePossible called"}
        return gameState!!.moveableFields()
    }

    fun possibleFieldsFrom(field: Int) : List<Int> {
        checkNotNull(gameState) {"GameState is null, possibleFieldsFrom called"}
        val moves = gameState!!.possibleMovesFrom(field)
        return moves.map {it.to}
    }

    fun makeMove(fieldFrom: Int, fieldTo: Int) {
        if (!isMovePossible(fieldFrom, fieldTo)) {
            throw IllegalArgumentException("Move impossible from $fieldFrom to $fieldTo")
        }
        val move = Move(fieldFrom, fieldTo)
        val singleMoves = gameState!!.decomposeMove(move)
        gameState!!.makeMove(move)
        for (m in singleMoves!!) raiseEvent(MoveEvent(m))

        // if no moves left, check game end and go to next turn
        if (gameState!!.anyMovesPossible()) return
        val roundResult = currentRoundResult()
        if (roundResult != Result.RUNNING) {
            val winner = if (roundResult == Result.PLAYER1_WON) 1 else 2
            val loserStartArea = if (winner == 1) 19..25 else 0..6
            val score = gameState!!.let {state ->
                when {
                    // backgammon
                    loserStartArea.map {state.fields[it] }.sum() > 0 -> 3
                    // gammon
                    state.fields.sum() == 15 -> 2
                    // normal win
                    else -> 1
                }
            }
            if (winner == 1) playerScore1 += score
            else playerScore2 += score
            raiseEvent(RoundEndEvent(winner, score))

            // check if game ended
            val gameResult = finalGameResult()
            if (gameResult != Result.RUNNING) {
                val gameWinner = if (gameResult == Result.PLAYER1_WON) 1 else 2
                raiseEvent(GameEndEvent(gameWinner))
            }

            return
        }
        // round has not ended, go to next turn
        nextTurn()
    }
}
