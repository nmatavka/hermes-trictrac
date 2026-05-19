package scorers

import GameState


/**
 * Create a float array of length 198, encoding the board.
 * The representation is the same as the one used by the original TDGammon.
 */
fun GameState.tdGammonFeatures(): Array<Float> {
    val f = Array(198) {0.0f}

    // encode 'white' features (player 2)
    var player2Total = 0
    for (i in 1..24) {
        if (fieldPlayerIdx[i] != 2) continue
        player2Total += fields[i]

        for (j in 1..3)
            if (fields[i] >= j) f[(i - 1) * 4 + j - 1] = 1.0f
        if (fields[i] >= 4) f[(i - 1) * 4 + 3] = (fields[i] - 3) / 2.0f
    }
    // encode player 2's bar
    f[96] = fields[25] / 2.0f
    // encode player 2's off checkers
    f[97] = (15.0f - player2Total) / 15.0f

    // encode 'black' features (player 1)
    // encode 'white' features (player 2)
    var player1Total = 0
    for (i in 1..24) {
        if (fieldPlayerIdx[i] != 1) continue
        player1Total += fields[i]

        for (j in 1..3)
            if (fields[i] >= j) f[98 + (i - 1) * 4 + j - 1] = 1.0f
        if (fields[i] >= 4) f[98 + (i - 1) * 4 + 3] = (fields[i] - 3) / 2.0f
    }
    // encode player 1's bar
    f[194] = fields[0] / 2.0f
    // encode player 1's off checkers
    f[195] = (15.0f - player1Total) / 15.0f
    // encode who's turn
    if (turnOf == 2) {
        f[196] = 1.0f
        f[197] = 0.0f
    } else {
        f[196] = 0.0f
        f[197] = 1.0f
    }
    return f
}

class TDGammon(val networkPath: String, val numInputs: Int = 198) : Scorer() {

    val onnxSession: OnnxSession = OnnxSession()

    suspend fun initialize() {
        onnxSession.open(networkPath, arrayOf(1, numInputs), arrayOf(2))
    }

    override suspend fun score(state: GameState, maximizingPlayer: Int): Float {
        val features = state.tdGammonFeatures()
        val scores = onnxSession.evaluate(features)
        // the network's output is in the opposite order:
        // scores[0] = player2's score (white)
        // scores[1] = player1's score (black)
        return if (maximizingPlayer == 1) return scores[1] else scores[0]
    }

}