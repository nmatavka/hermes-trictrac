package server

import com.expediagroup.graphql.server.operations.Mutation
import gnubg.GnubgCommand
import gnubg.ServerMatchId


object GameMutations : Mutation {
    @Suppress("unused")
    fun moveCheckers(serverMatchId: String, moveString: String): Boolean {
        // TODO need to validate moveString is just a move
        runCatching {
            GameState.sendStringLiteralMove(ServerMatchId(serverMatchId), moveString)
        }.onFailure { exception -> exception.printStackTrace() }

        return true
    }

    @Suppress("unused")
    fun acceptOrDecline(serverMatchId: String, isAccept: Boolean): Boolean {
        GameState.acceptOrDeclineCube(ServerMatchId(serverMatchId), isAccept)
        return true
    }

    @Suppress("unused")
    fun double(serverMatchId: String): Boolean {
        GameState.offerCube(ServerMatchId(serverMatchId))
        return true
    }

    @Suppress("unused")
    fun rollDice(serverMatchId: String): Boolean {
        GameState.rollDice(ServerMatchId(serverMatchId))
        return true
    }

    fun newGame(matchLength: Int?): String {
        val newMatch = GameState.newMatch(matchLength ?: 5)
        return newMatch.serverMatchId
    }
}