package scorers

import kotlin.math.*
import GameState

/**
 * Computes features of the state in the pubeval format.
 * The resulting array has a length of 27. The computer has player2's perspective (i.e. moving from field 24 to 1).
 * The fields have the following meaning:
 *  - index 0: opponent's checkers on the bar (negative int)
 *  - index 1-24: checkers on the board (opponent's are negative, computer's positive)
 *  - index 25: computer's checkers on the bar (positive int)
 *  - index 26: computer's checkers off the board (positive int)
 */
fun GameState.pubevalFeatures(computerPlayer: Int): Array<Int> {
    val a = Array(27) {0}

    var computerTotal = 0
    if (computerPlayer == 2) {
        // computer is player2
        for (i in 0..25) {
            if (fieldPlayerIdx[i] == 1) a[i] = -fields[i]
            else {
                computerTotal += fields[i]
                a[i] = fields[i]
            }
        }
    } else {
        // computer is player1 (who goes in direction 1->24), so the board is flipped
        for (i in 0..25) {
            if (fieldPlayerIdx[i] == 2) a[25 - i] = -fields[i]
            else {
                computerTotal += fields[i]
                a[25 - i] = fields[i]
            }
        }
    }
    a[26] = 15 - computerTotal

    return a
}

/**
 * Convert the 27-long input array to a 122-long input embedding for the pubeval algorithm.
 */
fun embedPubevalInput(board: Array<Int>): Array<Float> {
    val x = Array(122) {0.0f}

    // encode board locations reversed (24-1)
    for (j in 1..24) {
        val jm1 = j - 1
        val n = board[25 - j]

        if (n != 0) {
            if (n == -1) x[5 * jm1 + 0] = 1.0f
            if (n == 1) x[5 * jm1 + 1] = 1.0f
            if (n >= 2) x[5 * jm1 + 2] = 1.0f
            if (n == 3) x[5 * jm1 + 3] = 1.0f
            if (n >= 4) x[5 * jm1 + 4] = (n - 3) / 2.0f
        }
    }

    // encode opponent's bar checkers
    x[120] = -board[0] / 2.0f
    // encode the computer's checkers off
    x[121] = board[26] / 15.0f
    return x
}

/**
 * Checks whether the game is a 'race', i.e. no hits are possible in the game anymore.
 */
fun isRace(board: Array<Int>): Boolean {
    // find the computer's last piece (integer > 0)
    var computerLast = 25
    while (computerLast > 0 && board[computerLast] <= 0) computerLast--

    // find the opponent's first piece (integer < 0)
    var opponentFirst = 0
    while (opponentFirst < 25 && board[opponentFirst] >= 0) opponentFirst++

    return computerLast <= opponentFirst
}


/**
 * reimplementation of the pubeval backgammon evaluation algorithm by Gerald Tesauro.
 * source at: https://www.bkgm.com/rgb/rgb.cgi?view+610
 */
class Pubeval(val maxScore: Float): Scorer() {

    val raceWeights = arrayOf<Float>(0.00000f,-0.17160f,0.27010f,0.29906f,-0.08471f,0.00000f,-1.40375f,-1.05121f,0.07217f,-0.01351f,0.00000f,-1.29506f,-2.16183f,0.13246f,-1.03508f,0.00000f,-2.29847f,-2.34631f,0.17253f,0.08302f,0.00000f,-1.27266f,-2.87401f,-0.07456f,-0.34240f,0.00000f,-1.34640f,-2.46556f,-0.13022f,-0.01591f,0.00000f,0.27448f,0.60015f,0.48302f,0.25236f,0.00000f,0.39521f,0.68178f,0.05281f,0.09266f,0.00000f,0.24855f,-0.06844f,-0.37646f,0.05685f,0.00000f,0.17405f,0.00430f,0.74427f,0.00576f,0.00000f,0.12392f,0.31202f,-0.91035f,-0.16270f,0.00000f,0.01418f,-0.10839f,-0.02781f,-0.88035f,0.00000f,1.07274f,2.00366f,1.16242f,0.22520f,0.00000f,0.85631f,1.06349f,1.49549f,0.18966f,0.00000f,0.37183f,-0.50352f,-0.14818f,0.12039f,0.00000f,0.13681f,0.13978f,1.11245f,-0.12707f,0.00000f,-0.22082f,0.20178f,-0.06285f,-0.52728f,0.00000f,-0.13597f,-0.19412f,-0.09308f,-1.26062f,0.00000f,3.05454f,5.16874f,1.50680f,5.35000f,0.00000f,2.19605f,3.85390f,0.88296f,2.30052f,0.00000f,0.92321f,1.08744f,-0.11696f,-0.78560f,0.00000f,-0.09795f,-0.83050f,-1.09167f,-4.94251f,0.00000f,-1.00316f,-3.66465f,-2.56906f,-9.67677f,0.00000f,-2.77982f,-7.26713f,-3.40177f,-12.32252f,0.00000f,3.42040f)
    val contactWeights = arrayOf<Float>(0.25696f,-0.66937f,-1.66135f,-2.02487f,-2.53398f,-0.16092f,-1.11725f,-1.06654f,-0.92830f,-1.99558f,-1.10388f,-0.80802f,0.09856f,-0.62086f,-1.27999f,-0.59220f,-0.73667f,0.89032f,-0.38933f,-1.59847f,-1.50197f,-0.60966f,1.56166f,-0.47389f,-1.80390f,-0.83425f,-0.97741f,-1.41371f,0.24500f,0.10970f,-1.36476f,-1.05572f,1.15420f,0.11069f,-0.38319f,-0.74816f,-0.59244f,0.81116f,-0.39511f,0.11424f,-0.73169f,-0.56074f,1.09792f,0.15977f,0.13786f,-1.18435f,-0.43363f,1.06169f,-0.21329f,0.04798f,-0.94373f,-0.22982f,1.22737f,-0.13099f,-0.06295f,-0.75882f,-0.13658f,1.78389f,0.30416f,0.36797f,-0.69851f,0.13003f,1.23070f,0.40868f,-0.21081f,-0.64073f,0.31061f,1.59554f,0.65718f,0.25429f,-0.80789f,0.08240f,1.78964f,0.54304f,0.41174f,-1.06161f,0.07851f,2.01451f,0.49786f,0.91936f,-0.90750f,0.05941f,1.83120f,0.58722f,1.28777f,-0.83711f,-0.33248f,2.64983f,0.52698f,0.82132f,-0.58897f,-1.18223f,3.35809f,0.62017f,0.57353f,-0.07276f,-0.36214f,4.37655f,0.45481f,0.21746f,0.10504f,-0.61977f,3.54001f,0.04612f,-0.18108f,0.63211f,-0.87046f,2.47673f,-0.48016f,-1.27157f,0.86505f,-1.11342f,1.24612f,-0.82385f,-2.77082f,1.23606f,-1.59529f,0.10438f,-1.30206f,-4.11520f,5.62596f,-2.75800f)

    /**
     * Computes the score for a state. The current player shouldn't have made moves in this turn.
     */
    override suspend fun score(state: GameState, maximizingPlayer: Int): Float {
        val board = state.pubevalFeatures(maximizingPlayer)
        val x = embedPubevalInput(board)

        var score = 0.0f
        // all checkers off: 'infinite' score
        if (board[26] == 15) score = 999999.0f
        else {
            if (isRace(board)) for (i in x.indices) {
                score += raceWeights[i] * x[i]
            } else for (i in x.indices) {
                score += contactWeights[i] * x[i]
            }
        }

        // force the score into [-maxScore, maxScore]
        score = min(maxScore, score)
        score = max(-maxScore, score)

        return score / maxScore
    }

}