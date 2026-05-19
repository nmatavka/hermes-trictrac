package server

import app.cash.sqldelight.coroutines.asFlow
import app.cash.sqldelight.coroutines.mapToList
import com.backgammon.GetGames
import com.expediagroup.graphql.server.operations.Subscription
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

data class AvailableGame(
    val serverMatchId: String,
    val playerOneScore: Int,
    val playerTwoScore: Int,
    val matchLength: Int,
    val lastAction: Int
)


object LobbySubscription : Subscription {
    fun getAvailableGames(): Flow<List<AvailableGame>> {
        return Database.gameQueries.getGames().asFlow().mapToList(Dispatchers.IO).map { list ->
            list.map { game ->
                AvailableGame(
                    serverMatchId = game.id,
                    playerOneScore = game.player_one_score?.toInt() ?: 0,
                    playerTwoScore = game.player_two_score?.toInt() ?: 0,
                    matchLength = game.matchLength?.toInt()!!,
                    lastAction = game.last_move_at!!.epochSeconds.toInt()
                )
            }
        }
    }
}