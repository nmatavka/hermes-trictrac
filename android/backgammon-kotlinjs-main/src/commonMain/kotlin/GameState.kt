import kotlinx.serialization.Serializable
import kotlin.math.abs

/**
 * A move of a checker from a field to another field.
 */
@Serializable
open class Move(val from: Int, val to: Int) {
    override fun toString(): String {
        return "Move($from, $to)"
    }

    override fun equals(other: Any?): Boolean {
        if (other !is Move) return false
        return from == other.from && to == other.to
    }

    override fun hashCode(): Int {
        return Pair(from, to).hashCode()
    }
}

/**
 * A move performed in the game.
 */
@Serializable
class MoveMade(
    val from: Int, val to: Int, val hitPiece: Boolean, val numberUsed: Int, val withPrevious: Boolean = false
)

/**
 * ## State of the backgammon game.
 * Normal fields are numbered from 1 to 24, starting from bottom right.
 * Player1's home row is 18-24, player2's is 1-6.
 * Fields 0 and 25 are the bars of player1 and player2 respectively (which makes sense as a continuation of the board)
 * Field -1 is the exit point for both players.
 *
 * @param turnOf index of the player on turn (1 or 2)
 * @param fields Number of checkers on each field
 * @param fieldPlayerIdx Index of player controlling the field. 0 is empty
 * @param numbersLeft Numbers from the dice that have not been used yet. (double rolls like 6-6 are inserted 4 times into the list)
 */
@Serializable
data class GameState(
    var turnOf: Int, val fields: MutableList<Int>, val fieldPlayerIdx: MutableList<Int>,
    val numbersLeft: MutableList<Int> = mutableListOf(),
) {

    /**
     * Stores the moves made in each turn. The last element is the most recent turn.
     */
    private val lastMovesByTurn: MutableList<MutableList<MoveMade>> = mutableListOf(
        mutableListOf()
    )

    /**
     * Stores already computed legal move sequences in this position.
     */
    private var possibleMoveSeqCache: List<List<Move>>? = null

    /**
     * Player index of the opponent.
     */
    inline fun opponent() = 3 - turnOf

    override fun equals(other: Any?): Boolean {
        if (other !is GameState) return false
        return turnOf == other.turnOf && fields == other.fields &&
                fieldPlayerIdx == other.fieldPlayerIdx && numbersLeft.sorted() == other.numbersLeft.sorted()
    }

    override fun hashCode(): Int {
        return turnOf.hashCode() * fields.hashCode() * fieldPlayerIdx.hashCode() * numbersLeft.hashCode()
    }

    /**
     * Start the next turn. The current player is set to be the opponent.
     */
    fun nextTurn() {
        turnOf = opponent()
        lastMovesByTurn.add(mutableListOf())
        possibleMoveSeqCache = null
    }

    /**
     * Set the numbers from the dice rolled this turn.
     */
    fun setDice(dice: Dice) {
        numbersLeft.clear()
        numbersLeft.addAll(dice.numbers())
        possibleMoveSeqCache = null
    }

    /**
     * Create a deep copy of the state. The last moves are not copied.
     */
    fun deepcopy(): GameState {
        return copy(
            fields = fields.toMutableList(),
            fieldPlayerIdx = fieldPlayerIdx.toMutableList(),
            numbersLeft = numbersLeft.toMutableList()
        )
    }

    /**
     *  Check whether the current player meets the criteria for bearing off.
     */
    private fun bearOffPossible(): Boolean {
        val badFields = if (turnOf == 1) 0..18 else 7..25
        for (i in badFields)
            if (fieldPlayerIdx[i] == turnOf && fields[i] > 0) return false
        return true
    }

    /**
     * Check whether a move can be performed in a single move, regardless of the dice.
     */
    private fun isMoveLegalWithoutDice(move: Move): Boolean {
        // the source field is not the current player's
        if (fieldPlayerIdx[move.from] != turnOf || fields[move.from] == 0) return false

        // bearing off
        if (move.to == -1) {
            if (!bearOffPossible()) return false
            return if (turnOf == 1) move.from > 18 else move.from < 7
        }

        val stepsize = if (turnOf == 1) move.to - move.from else move.from - move.to
        // too big or non-positive step
        if (stepsize <= 0 || stepsize > 6) return false

        // the opponent has multiple pieces on the target field
        if (fieldPlayerIdx[move.to] != turnOf && fields[move.to] > 1) return false
        // the target is the bar ...
        if (move.to < 1 || move.to > 24) return false

        // the source is the bar but not the current player's
        if ((move.from == 0 && turnOf == 2) || (move.from == 25 && turnOf == 1)) return false

        val playerBar = if (turnOf == 1) 0 else 25
        // the source is not the bar, but the player has pieces on the bar
        if (move.from != playerBar && fields[playerBar] > 0) return false
        return true
    }

    /**
     * Check whether the move can be performed using `number` from the die.
     */
    private fun isMoveLegalUsingNumber(move: Move, number: Int): Boolean {
        // illegal move on the board
        if (!isMoveLegalWithoutDice(move)) return false

        // if it is not a bearing off move, the number has to equal the field diff
        if (move.to >= 0) return number == abs(move.from - move.to)

        // the move is a bearing off move at this point (move.to == -1)
        // the checker would be moved to field `target`
        val target = move.from + (if (turnOf == 1) number else -number)
        val bearOffDiff = if (turnOf == 1) 25 - target else target
        if (bearOffDiff == 0) return true
        if (bearOffDiff > 0) return false
        // `number` is more than what is needed. No non-bear off moves should exist.

        val higherRange = if (turnOf == 1) 19 until move.from else 6 downTo (move.from + 1)
        // go through the higher home row fields, where shouldn't be player's checkers
        for (i in higherRange) {
            if (fields[i] > 0 && fieldPlayerIdx[i] == turnOf) return false
        }
        return true
    }

    /**
     * Candidate moves that can be made currently if dice rules allow. Non-exact bear off moves excluded.
     */
    private fun moveCandidates(dieNum: Int): List<Move> {
        val range = if (turnOf == 1) 0..(24 - dieNum) else (dieNum + 1)..25
        val diff = if (turnOf == 1) dieNum else -dieNum
        val moves = mutableListOf<Move>()
        // check normal moves
        for (i in range) {
            val move = Move(i, i + diff)
            if (isMoveLegalUsingNumber(move, dieNum)) moves.add(move)
        }

        // check exact bearing off too
        val field = if (turnOf == 1) 25 - dieNum else dieNum
        if (isMoveLegalUsingNumber(Move(field, -1), dieNum)) moves.add(Move(field, -1))

        return moves
    }

    /**
     * Returns the only possible bear off move that uses a higher number than needed, if such a move exists.
     */
    private fun nonExactBearOffCandidate(): Move? {
        val maxNum = numbersLeft.maxOrNull() ?: return null
        // go through the available bear off fields and get the farthest one
        val bearOffRange = if (turnOf == 1) (26 - maxNum)..24 else (maxNum - 1) downTo 1
        for (i in bearOffRange) {
            if (fields[i] > 0 && fieldPlayerIdx[i] == turnOf) {
                val move = Move(i, -1)
                return if (isMoveLegalUsingNumber(move, maxNum)) move else null
            }
        }
        return null
    }

    /**
     * Returns the possible sequences of moves that can be played currently.
     */
    fun possibleMoveSequences(): List<List<Move>> {
        if (numbersLeft.isEmpty()) return emptyList()

        // the results are cached already
        if (possibleMoveSeqCache != null) return possibleMoveSeqCache!!

        // data structures for storing state during dfs
        val path = mutableListOf<Move>()
        val acc = mutableListOf<List<Move>>()

        // stores edges of the tree to be explored, in (move, number used) pairs. Null moves mean return to the parent node.
        val moveStack = mutableListOf<Pair<Move, Int>?>()

        // expand the current node we are at: add its children to
        inline fun expandNode() {
            // insert edge back to parent
            moveStack.add(null)
            // for each unique number left, add possible moves
            for (num in numbersLeft.toSet())
                for (move in moveCandidates(num)) moveStack.add(move to num)

            // if no moves found, try the non-exact bear off move too
            if (moveStack.last() == null)
                nonExactBearOffCandidate()?.let {
                    moveStack.add(it to numbersLeft.max())
                }

            // if no children node found (= top of the stack is null), add the current path to the results
            if (moveStack.last() == null && path.isNotEmpty()) acc.add(path.toList())
        }

        // start by expanding the root
        expandNode()
        // walk the nodes of the tree by dfs
        while (moveStack.isNotEmpty()) {
            val top = moveStack.removeLast()
            // back to parent node
            if (top == null) {
                if (moveStack.isNotEmpty()) {
                    doUndoLastMove()
                    path.removeLast()
                }
                continue
            }

            // make the move and expand the new node
            doMakeMove(top.first, top.second)
            path.add(top.first)
            expandNode()
        }

        if (acc.isEmpty()) return acc.also {possibleMoveSeqCache = it}
        val maxCandidateLen = acc.maxOf { it.size }

        // only the longest move sequences are valid (player has to use the most possible dice numbers)
        val longestCandidates = acc.filter { it.size == maxCandidateLen }

        // if only one move can be done, we have to use the bigger number if we can
        if (maxCandidateLen == 1 && numbersLeft.size > 1) {
            val maxNum = numbersLeft.max()
            val maxNumCandidates = longestCandidates.filter {
                it[0].to == -1 || abs(it[0].to - it[0].from) == maxNum
            }
            if (maxNumCandidates.isNotEmpty()) return maxNumCandidates.also {possibleMoveSeqCache = it}
        }
        return longestCandidates.also {possibleMoveSeqCache = it}
    }

    /**
     * If the move is a compound move, split it to single moves. If it is invalid, return null.
     * If the move can be split in multiple ways, this finds the shortest one that hits the most opponent pieces.
     * E.g.: when bearing off, and player1 has numbers 1 and 2 left, it is valid for him to perform
     * Move(23, -1) using number 2, but the sequence of Move(23, 24), Move(24, -1) could be valid too using both numbers.
     * We decompose the move so that it is the most favorable to the current player.
     */
    fun decomposeMove(move: Move): List<Move>? {
        val moveSequences = possibleMoveSequences()
        // we search for the shortest good move sequence that equals to this move
        // The number of hits only matters in move sequences of length 2: we take the one with the intermediate hit if possible
        var shortestSeq: List<Move>? = null

        for (moveSeq in moveSequences) {
            var from = move.from
            for ((i, m) in moveSeq.withIndex()) {
                if (m.from != from) break
                if (m.to == move.to) {
                    val seq = moveSeq.subList(0, i + 1)
                    if (seq.size == 1) return seq

                    // if no correct seq found yet, or this is the shortest so far, we store it
                    // if the length is the same as the best, but this hits on the first move, also favor this one
                    if (shortestSeq == null || shortestSeq.size > seq.size ||
                        (shortestSeq.size == seq.size && fieldPlayerIdx[seq[0].to] == opponent()))
                        shortestSeq = seq

                }
                from = m.to
            }
        }
        return shortestSeq
    }

    /**
     * Check whether a move is legal in the game.
     *  The move can be a `compound move` too (multiple moves with the same piece, e.g. field 1 -> field 4 -> field 8)
     */
    fun isMovePossible(move: Move): Boolean {
        return decomposeMove(move) != null
    }

    /**
     * Return fields from which the player has available moves.
     */
    fun moveableFields(): List<Int> {
        val moveSequences = possibleMoveSequences()
        val fields = mutableSetOf<Int>()
        for (moveSeq in moveSequences) {
            fields.add(moveSeq[0].from)
        }
        return fields.toList()
    }

    /**
     * Check whether any moves are available for the current player
     */
    fun anyMovesPossible(): Boolean {
        return possibleMoveSequences().isNotEmpty()
    }

    /**
     * Possible moves from a given field.
     */
    fun possibleMovesFrom(field: Int): List<Move> {
        val moveSequences = possibleMoveSequences()
        val moves = mutableSetOf<Move>()
        for (moveSeq in moveSequences) {
            var from = field
            for (move in moveSeq) {
                if (move.from != from) break
                moves.add(Move(field, move.to))
                from = move.to
            }
        }
        return moves.toList()
    }

    /**
     * Make a move using `dieNum` from numbersLeft. If `withPrevious`, the move is considered a compound move with the previous one.
     */
    private fun doMakeMove(move: Move, dieNum: Int, withPrevious: Boolean = false) {
        // clear move seq cache
        possibleMoveSeqCache = null

        fields[move.from] -= 1
        if (fields[move.from] == 0) fieldPlayerIdx[move.from] = 0
        var hitPiece = false
        if (move.to >= 0) {
            hitPiece = (fields[move.to] == 1 && fieldPlayerIdx[move.to] != turnOf)
            if (hitPiece) {
                val barField = if (turnOf == 1) 25 else 0
                fields[barField] += 1
                fieldPlayerIdx[barField] = opponent()
            } else fields[move.to] += 1
            fieldPlayerIdx[move.to] = turnOf
        }
        lastMovesByTurn.last().add(MoveMade(move.from, move.to, hitPiece, dieNum, withPrevious))
        numbersLeft.remove(dieNum)
    }

    /**
     * Perform a move. The move can be a single move (e.g Move(1, 5) using 4, or a compound move like Move(1, 10) using nums 4 and 5.
     * Checking whether the move is a compound move and it is valid, causes an overhead. For forcing single moves without checking use `forceMove`.
     */
    fun makeMove(move: Move) {
        check(numbersLeft.size > 0)
        val singleMoves = decomposeMove(move)
        singleMoves ?: throw IllegalArgumentException("Move $move is invalid.")

        for ((i, sMove) in singleMoves.withIndex()) {
            val (highNum, lowNum) = Pair(numbersLeft.max(), numbersLeft.min())
            // try to make the move with the highest number first
            if (isMoveLegalUsingNumber(sMove, highNum)) {
                doMakeMove(sMove, highNum, i > 0)
            } else {
                doMakeMove(sMove, lowNum, i > 0)
            }
        }
    }

    /**
     * Force to make a move without checking whether it is valid.
     */
    fun forceMove(move: Move) {
        // non-bear-off move
        if (move.to != -1) doMakeMove(move, abs(move.to - move.from))
        else {
            val diff = if (turnOf == 1) 25 - move.from else move.from
            // exact bear off
            if (diff in numbersLeft) doMakeMove(move, diff)
            // non-exact bear off: only highest number can be used
            else doMakeMove(move, numbersLeft.max())
        }
    }

    /**
     * Perform the undo procedure of the last move.
     */
    private fun doUndoLastMove(): Boolean {
        val move = lastMovesByTurn.lastOrNull()?.removeLastOrNull() ?: return false

        // clear move seq cache
        possibleMoveSeqCache = null

        if (move.hitPiece) { // hit a piece ==> we have to restore that piece
            fieldPlayerIdx[move.to] = opponent()
            val bar = if (turnOf == 1) 25 else 0
            fields[bar] -= 1
            if (fields[bar] == 0) fieldPlayerIdx[bar] = 0
        } else if (move.to >= 0) {
            // not a bear-off move, and didn't hit a checker either ==> remove a checker from field `to`
            fields[move.to] -= 1
            if (fields[move.to] == 0) fieldPlayerIdx[move.to] = 0
        }
        fieldPlayerIdx[move.from] = turnOf
        fields[move.from] += 1
        numbersLeft.add(move.numberUsed)
        return true
    }

    /**
     * Undo the last move (compound or single).
     */
    fun undoLastMove(): Boolean {
        val lastMoves = lastMovesByTurn.lastOrNull()
        lastMoves ?: return false
        if (lastMoves.size == 0) return false
        do {
            val lastMove = lastMoves.last()
            doUndoLastMove()
        } while (lastMove.withPrevious)
        return true
    }

    /**
     * Undo the complete turn. The board will be in the position left at the end of the last turn.
     */
    fun undoLastTurn(): Boolean {
        val lastMoves = lastMovesByTurn.lastOrNull()
        lastMoves ?: return false

        // clear move seq cache
        possibleMoveSeqCache = null

        while (doUndoLastMove()) {}
        lastMovesByTurn.removeLast()
        numbersLeft.clear()
        turnOf = opponent()
        return true
    }

    /**
     * Return who won if the round has ended or `Result.RUNNING` if it is in progress.
     */
    fun roundResult(): Result {
        if ((0..24).all { fieldPlayerIdx[it] != 1 || fields[it] == 0 }) return Result.PLAYER1_WON
        if ((1..25).all { fieldPlayerIdx[it] != 2 || fields[it] == 0 }) return Result.PLAYER2_WON
        return Result.RUNNING
    }

}


/**
 * Get an initial game state if the specified player goes first.
 */
fun initialGameState(whoGoesFirst: Int): GameState {
    val fields = MutableList(26) { 0 }
    val fieldPlayerIdx = MutableList(26) { 0 }
    val initialPlayer1 = listOf(Pair(1, 2), Pair(12, 5), Pair(17, 3), Pair(19, 5))
    for ((field, cnt) in initialPlayer1) {
        fields[field] = cnt
        fieldPlayerIdx[field] = 1
        fields[25 - field] = cnt
        fieldPlayerIdx[25 - field] = 2
    }
    return GameState(whoGoesFirst, fields, fieldPlayerIdx)
}

/**
 * Basic board display using ASCII characters for debugging.
 */
fun asciiBoard(gameState: GameState): String {
    val rows = mutableListOf<String>()
    for (i in 1..3) {
        val items = mutableListOf<String>()
        for (x in 13..24) {
            var item = if (gameState.fields[x] >= i) " ${gameState.fieldPlayerIdx[x]} " else "   "
            if (i == 3 && gameState.fields[x] > 3) item = "(${gameState.fields[x] - 2})"
            items.add(item)
            if (x == 18) items.add("|   |")
        }
        rows.add("|${items.joinToString("|")}|\n")
    }
    val padding = 4*6 + 1
    rows.add("|   |".padEnd(5 + padding).padStart(5 + 2*padding) + "\n")

    val diceNums = "${gameState.numbersLeft}"
    var center = "|(${gameState.fields[25]})|".padEnd(5 + padding).padStart(5 + 2*padding) + "\n"
    if (gameState.turnOf == 1) {
        center = center.replaceRange(0, diceNums.length, diceNums)
    } else center = center.replaceRange(center.length - 1 - diceNums.length, center.length -1, diceNums)
    rows.add(center)
    rows.add("|(${gameState.fields[0]})|".padEnd(5 + padding).padStart(5 + 2*padding) + "\n")
    rows.add("|   |".padEnd(5 + padding).padStart(5 + 2*padding) + "\n")

    for (i in 3 downTo 1) {
        val items = mutableListOf<String>()
        for (x in 12 downTo 1) {
            var item = if (gameState.fields[x] >= i) " ${gameState.fieldPlayerIdx[x]} " else "   "
            if (i == 3 && gameState.fields[x] > 3) item = "(${gameState.fields[x] - 2})"
            items.add(item)
            if (x == 7) items.add("|   |")
        }
        rows.add("|${items.joinToString("|")}|\n")
    }
    rows.add(0, "".padEnd(rows[0].length - 1, '-') + "\n")
    rows.add(rows.size, "".padEnd(rows[0].length - 1, '-') + "\n")
    return rows.joinToString("")
}