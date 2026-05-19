import kotlin.js.Date
import kotlin.math.*

/**
 * Returns unique move sequences, eliminating the permutations of the same move seq.
 */
fun GameState.uniqueMoveSequences(): List<List<Move>> {
    val moveSequences = possibleMoveSequences()
    // remove duplicate move sets, i.e. move sequences that are included in multiple orderings
    // e.g Move(1, 6), Move(4, 7) and Move(4, 7), Move(1, 6)
    val moveSet = mutableSetOf<Set<Move>>()
    return moveSequences.filter {
        val s = it.toSet()
        if (s in moveSet) false else {
            moveSet.add(s)
            true
        }
    }.ifEmpty { listOf(emptyList()) }
}

/**
 * Score of a state for `maximizingPlayer` if the state is terminal = the game ended.
 */
fun GameState.terminalValue(maximizingPlayer: Int): Float? {
    val result = roundResult()
    if (result == Result.PLAYER1_WON) return if (maximizingPlayer == 1) 1.0f else 0.0f
    if (result == Result.PLAYER2_WON) return if (maximizingPlayer == 1) 0.0f else 1.0f
    return null
}

abstract class Node(var children: List<Node>?, var isTerminal: Boolean, var value: Float?) {
    /**
     * Expand a node: create its children, and expand them recursively (until the depth limit allows).
     * Some scoring functions are asynchronous, so this has to be a suspend fun too
     */
    abstract suspend fun expand(state: GameState, maximizingPlayer: Int, depth: Int, endTime: Double)
}

/**
 * A node that either calculates the maximum or minimum of its children nodes.
 */
class MiniMaxNode(val maximize: Boolean): Node(null, false, null) {

    var actionPerChildren: List<List<Move>>? = null

    override suspend fun expand(state: GameState, maximizingPlayer: Int, depth: Int, endTime: Double) {
        if (Date.now() >= endTime) {
            value = null
            return
        }

        // depth is 0, so we have to score this state
        if (depth == 0) {
            value = scorer.score(state, maximizingPlayer)
            return
        }
        value = null

        // node not yet expanded: generate children
        if (children == null) {
            actionPerChildren = state.uniqueMoveSequences()
            children = List(actionPerChildren!!.size) { ChanceNode(!maximize) }
        }

        var best = if (maximize) 0.0f else 1.0f
        for (i in children!!.indices) {
            for (move in actionPerChildren!![i]) state.forceMove(move)
            state.nextTurn()

            children!![i].expand(state, maximizingPlayer, depth - 1, endTime)
            if (children!![i].value == null) return
            if (maximize) best = max(best, children!![i].value!!)
            else best = min(best, children!![i].value!!)

            state.undoLastTurn()
            repeat(actionPerChildren!![i].size) {state.undoLastMove()}
        }
        value = best
    }

}

class ChanceNode(val childrenAreMax: Boolean): Node(null, false, null) {

    override suspend fun expand(state: GameState, maximizingPlayer: Int, depth: Int, endTime: Double) {
        if (Date.now() >= endTime) {
            value = null
            return
        }

        value = state.terminalValue(maximizingPlayer)
        // state is terminal state, we can assign the  utility value to this node
        if (value != null) {
            isTerminal = true
            return
        }

        // depth == 0: we evaluate this state
        if (depth == 0) {
            value = scorer.score(state, maximizingPlayer)
            return
        }

        // not expanded yet
        if (children == null) {
            children = List(uniqueDice.size) {MiniMaxNode(childrenAreMax)}
        }

        // expand children
        var sumValues = 0.0f
        for (i in children!!.indices) {
            state.setDice(uniqueDice[i])

            children!![i].expand(state, maximizingPlayer, depth - 1, endTime)
            if (children!![i].value == null) return
            sumValues += children!![i].value!! * diceWeight[uniqueDice[i]]!!.toFloat()
        }
        value = sumValues / totalDiceWeight
    }
}

/**
 * Run an iteratively deepening DFS search on the tree. In each iteration the leaves of the tree are expanded
 * to get a one deeper tree, always maintaining the best move from the previous iteration (in case the time limit expires).
 */
suspend fun iterativeDeepeningSearch(root: MiniMaxNode, state: GameState, timelimitMs: Int, startDepth: Int = 1, maxDepth: Int = 1000): List<Move> {
    val startTime = Date.now()
    val endTime = startTime + timelimitMs
    var bestVal = -10000000.0f
    var bestAction: List<Move>? = null

    for (d in startDepth..maxDepth) {
        root.expand(state, state.turnOf, d, endTime)
        println("Depth $d ready at ${Date.now() - startTime}")
        if (root.value == null) break
        bestVal = -100000000.0f
        for ((child, action) in root.children!!.zip(root.actionPerChildren!!)) {
            if (child.value!! > bestVal) {
                bestVal = child.value!!
                bestAction = action
            }
        }
        println("Depth: $d bestVal: $bestVal bestAction: $bestAction")
    }
    return bestAction ?: emptyList()
}
