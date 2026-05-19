package server

import gnubg.*
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.update

object GameState {
    val loadedGames = mutableMapOf<ServerMatchId, MutableStateFlow<LoadedGame>>()

    fun acceptOrDeclineCube(serverMatchId: ServerMatchId, isAccept: Boolean) {
        loadedGames[serverMatchId]!!.value
            .processCommandsAndSaveMatch(GnubgCommand.AcceptOrDecline(isAccept))
    }

    fun rollDice(serverMatchId: ServerMatchId) {
        loadedGames[serverMatchId]!!.value.processCommandsAndSaveMatch(GnubgCommand.RollDice)
    }

    fun offerCube(serverMatchId: ServerMatchId) {
        loadedGames[serverMatchId]!!.value.processCommandsAndSaveMatch(GnubgCommand.Double)
    }

    fun subscribeToGame(serverMatchId: ServerMatchId): Flow<LoadedGame> {
        return loadedGames.getOrPut(serverMatchId) {
            MutableStateFlow(loadMatch(serverMatchId))
        }
    }

    fun newMatch(matchLength: Int): ServerMatchId {
        val match = startMatch(matchLength)

        loadedGames[match.matchData.matchId] = MutableStateFlow(match)

        insertGameToDatabase(match)

        return match.matchData.matchId
    }

    fun updateMatch(loadedGame: LoadedGame) {
        loadedGames[loadedGame.matchData.matchId]!!.update {
            loadedGame
        }

        updateGameInDatabase(loadedGame)
    }

    fun sendStringLiteralMove(matchId: ServerMatchId, stringLiteralMove: String) {
        val loadedGame = loadedGames[matchId]!!.value


        loadedGame.processCommandsAndSaveMatch(GnubgCommand.Literal(stringLiteralMove))
    }
}