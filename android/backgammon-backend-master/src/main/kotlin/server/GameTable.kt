package server

import gnubg.GameStateHistory
import gnubg.ServerMatchId
import kotlinx.serialization.json.Json
import migrations.Games
import java.util.UUID
import kotlin.time.Clock
import kotlin.time.Instant


fun insertGameToDatabase(game: LoadedGame) {
    Database.gameQueries.insertGame(
        Games(
            id = game.matchData.matchId.serverMatchId,
            playerOneId = "",
            playerTwoId = "",
            matchLength = game.match.matchLength.toLong(),
            history = Json.encodeToString(game.history),
            created_at = Clock.System.now(),
            last_move_at = Clock.System.now(),
            player_one_score = game.match.playerOneScore.toLong(),
            player_two_score = game.match.playerTwoScore.toLong(),
            winner = null,
        )
    )
}

fun getHistory(id: ServerMatchId): List<GameStateHistory> {
    val game = Database.gameQueries.getGame(id.serverMatchId).executeAsOneOrNull()

    return game?.history?.let {
        Json.decodeFromString<List<GameStateHistory>>(it)
    } ?: emptyList()
}

fun updateGameInDatabase(loadedGame: LoadedGame) {
    val historyString = Json.encodeToString(loadedGame.history)

    val match = loadedGame.match

    Database.gameQueries.updateGameHistory(
        history = historyString,
        id = loadedGame.matchData.matchId.serverMatchId,
        matchLength = match.matchLength.toLong(),
        player_one_score = match.playerOneScore.toLong(),
        player_two_score = match.playerTwoScore.toLong(),
        last_move_at = Clock.System.now(),
        winner = when {
            match.playerOneScore >= match.matchLength -> "Player One"
            match.playerTwoScore >= match.matchLength -> "Player Two"
            else -> null
        },
    )
}

