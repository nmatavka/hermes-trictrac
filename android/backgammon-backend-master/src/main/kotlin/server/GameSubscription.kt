package server

import com.expediagroup.graphql.server.operations.Subscription
import gnubg.ServerMatchId
import kotlinx.coroutines.flow.Flow


object GameSubscription : Subscription {
    fun getGame(serverMatchId: String): Flow<LoadedGame> =
        runCatching {
            GameState.subscribeToGame(ServerMatchId(serverMatchId))
        }
            .onFailure { exception -> exception.printStackTrace() }
            .getOrThrow()


}