package scorers

import kotlin.math.*
import diceWeight
import totalDiceWeight
import GameState


/**
 * Dumb scorer that uses pips to predict win probability.
 * The user's pips is the sum of moves needed for bearing off all checkers.
 * (in the initial position pips are 167 for both players).
 *
 * This class computes `winProb[i, j]` which gives the probability of player 1 winning,
 * if the pips are `(i, j)` for the players, and the game only consists of rolling the dice,
 * and subtracting the numbers (or twice the numbers in the case of double roll) from the user's pips.
 *
 * The scoring is based on `winProb[i, j]`, but some basic heuristics are used to add
 * a penalty to the user's pips if they have a blot (single checker on a field), that can be hit.
 * The penalty increases with the probability of the opponent hitting the furthest blot.
  */
class Dumbeval(): Scorer() {

    // maximum number of pips to compute winProb until (above this pips are cut back to MX)
    val MX: Int = 240

    // winProb[i, j] stores the probability of player1 winning if pips are (i, j)
    val winProb: Array<Array<Float>> = run {
        val P = Array(MX + 1) {Array(MX + 1) {1.0f} }

        // compute values by DP: iterate row and column i simultaneously
        for (i in 0..MX) {
            // start at (i, i)
            for (j in i..MX) {
                // compute P[i][j]
                var total = 0.0f
                for ((dice, weight) in diceWeight.entries) {
                    // recurse to (j - dice.sum(), i)
                    val col = i - dice.numbers().sum()
                    if (col <= 0) total += weight
                    else total += (1 - P[j][col]) * weight
                }
                P[i][j] = total / totalDiceWeight

                // compute P[j][i]
                total = 0.0f
                for ((dice, weight) in diceWeight.entries) {
                    // recurse to (i, j - dice.sum())
                    val col = j - dice.numbers().sum()
                    if (col <= 0) total += weight
                    else total += (1 - P[i][col]) * weight
                }
                P[j][i] = total / totalDiceWeight
            }
        }
        P
    }

    /**
     * Scores a game state. The score is computed from the perspective of `maximizingPlayer` (1 or 2).
     */
    override suspend fun score(state: GameState, maximizingPlayer: Int): Float {
        val movesNeeded = mutableListOf(0, 0, 0)
        val worstHitForNum = MutableList(3) { MutableList(7) {0} }

        // distance of the two farthest checkers from the bear off point for the current player
        val highestDists = mutableListOf(0, 0)

        for (i in 0..25) {
            val (ply, cnt) = state.fieldPlayerIdx[i] to state.fields[i]
            val opponent = 3 - ply
            if (ply == 0 || cnt == 0) continue

            val moves = if (ply == 1) 25 - i else i
            movesNeeded[ply] += moves * cnt


            // if only one checker here, check possible hits by the opponent
            if (cnt == 1) {
                for (dist in 1..6) {
                    val from = if (ply == 1) i + dist else i - dist
                    if (from < 0 || from > 25) break

                    if (state.fieldPlayerIdx[from] == opponent)
                        worstHitForNum[ply][dist] = max(
                            worstHitForNum[ply][dist],
                            if (ply == 1) i else 25 - i
                        )
                }
            }


            if (ply == state.turnOf && highestDists[1] == 0) {
                val dist = if (ply == 1) 25 - i else i

                for (idx in 0 until state.fields[i]) {
                    if (highestDists[0] == 0) highestDists[0] = dist
                    else if (highestDists[1] == 0) highestDists[1] = dist
                    else break
                }
            }
        }

        // for each player, if it has pieces on the bar, add possible wasted numbers
        for (player in 1..2) {
            val opp = 3 - player
            val bar = if (player == 1) 0 else 25
            if (state.fields[bar] == 0) continue
            val badFields = mutableListOf<Int>()
            for (i in 1..6) {
                val target = if (player == 1) bar + i else bar - i
                // opponent has more than one checkers on target field: add to bad fields
                if (state.fieldPlayerIdx[target] == opp && state.fields[target] > 1) badFields.add(i)
            }

            var totalPenalty = 0
            for ((dice, weight) in diceWeight.entries) {
                if (state.fields[bar] == 1) {
                    if (dice.numbers().all {it in badFields}) totalPenalty += dice.numbers().sum() * weight
                } else if (dice.numbers().any {it in badFields}) totalPenalty += dice.numbers().sum() * weight
            }

            movesNeeded[player] += totalPenalty / totalDiceWeight
        }

        // for each player consider the single worst piece that can be hit by the opponent for each die number
        // add the average of the position lost when that checker gets hit to movesNeeded
        for (player in 1..2) {
            // if the dice are known for the opponent -- use those for calculation
            if (state.turnOf != player && state.numbersLeft.isNotEmpty()) {
                for (num in state.numbersLeft.take(2))
                    movesNeeded[player] += worstHitForNum[player][num] / 2
            } else {
                // player is on turn or opponent's numbers are unknown
                for (num in 1..6)
                    movesNeeded[player] += worstHitForNum[player][num] / 6
            }
        }

        // subtract dice values from current player's movesNeeded, as the player will
        // use them to move, and reduce his/her count (if possible)
        if (state.numbersLeft.size >= 2) {
            if (highestDists.max() > 6) movesNeeded[state.turnOf] -= min(movesNeeded[state.turnOf], state.numbersLeft.sum())
            else {
                // player is bearing off -> cap the numbers subtracted by the highest distances

                // only check the first two dice
                var (n1, n2) = state.numbersLeft
                if (n1 < n2) n1 = n2.also { n2 = n1 }

                val sub = min(highestDists[0], n1) + min(highestDists[1], n2)
                movesNeeded[state.turnOf] -= sub
            }
        }

        val opponent = 3 - state.turnOf

        // maximize movesNeeded values in MX
        for (i in 1..2) movesNeeded[i] = min(MX, movesNeeded[i])

        // probability that opponent wins
        val pOpponent = if (state.numbersLeft.size == 0) {
            // player has not rolled the dice yet, compute prob for current player going first
            1.0f - winProb[movesNeeded[state.turnOf]][movesNeeded[opponent]]
        } else winProb[movesNeeded[opponent]][movesNeeded[state.turnOf]]

        return if (maximizingPlayer == opponent) pOpponent else 1 - pOpponent
    }

}