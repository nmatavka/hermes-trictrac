package server

import com.expediagroup.graphql.generator.annotations.GraphQLIgnore
import com.expediagroup.graphql.generator.annotations.GraphQLName
import gnubg.GameStateHistory
import gnubg.ParsedMatchData
import gnubg.isSameBoard

data class LoadedGame(
    val matchData: ParsedMatchData,
    @GraphQLIgnore val history: List<GameStateHistory>
) {
    @GraphQLName("history")
    val _history: List<GameStateHistory>
        get() {
            val newItem = GameStateHistory.BoardUpdate(
                matchData.positionId,
                matchData.match,
            ).takeUnless {
                it isSameBoard history.last()
            }

            return history.plus(listOfNotNull(newItem))
        }
}

val LoadedGame.match get() = matchData.match