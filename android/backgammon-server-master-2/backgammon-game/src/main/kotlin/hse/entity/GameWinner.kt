package hse.entity

import game.backgammon.enums.Color
import hse.enums.GameEntityType
import java.time.Instant
import java.time.ZonedDateTime

class GameWinner(
    val matchId: Int,
    val gameId: Int,
    val winner: Int,
    val points: Int,
    val surrender: Boolean,
    val endMatch: Boolean,
    at: Instant
) : TypedMongoEntity(GameEntityType.WINNER_INFO, at) {

    val color: Color
        get() = if (winner == BLACK) Color.BLACK else Color.WHITE

    companion object {

        private const val BLACK = -1
        private const val WHITE = 1

        fun of(
            matchId: Int,
            gameId: Int,
            color: Color,
            points: Int,
            surrender: Boolean,
            endMatch: Boolean,
            at: Instant
        ): GameWinner {
            val intColor = if (color == Color.BLACK) BLACK else WHITE
            return GameWinner(matchId, gameId, intColor, points, surrender, endMatch, at)
        }
    }
}