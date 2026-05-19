package scorers

import GameState

/**
 * A scorer computes a score for a GameState.
 * Higher scores mean better winning chances for the current player.
 * Scores should be linearly correlated to the predicted chance of winning.
 */
abstract class Scorer {
    abstract suspend fun score(state: GameState, maximizingPlayer: Int): Float
}