package gnubg

import gnubg.ParsedMatchData.Companion.parse
import server.LoadedGame
import server.getHistory

fun startMatch(matchLength: Int): LoadedGame {
    val matchId = ServerMatchId.new()

    return listOf(
        GnubgCommand.NewMatch(matchLength),
        GnubgCommand.Hint,
        GnubgCommand.SaveMatch(matchId)
    ).runCommands()
        .also {
            fixStartingMatch(matchId)
        }
        .parse()
        .let { commandResponse ->
            val parsed = commandResponse.parse(matchId)

            val history = parseHistoryItems(commandResponse)

            LoadedGame(parsed, history)
        }
}

fun loadMatchData(matchId: ServerMatchId): ParsedMatchData {
    return listOf(GnubgCommand.LoadMatch(matchId), GnubgCommand.Hint)
        .runCommands()
        .parse()
        .parse(matchId)
}

fun loadMatch(matchId: ServerMatchId): LoadedGame {
    fixStartingMatch(matchId)
    return loadMatchData(matchId)
        .let {
            val history = getHistory(it.matchId)

            LoadedGame(it, history)
        }
}