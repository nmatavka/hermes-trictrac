package server

import gnubg.*
import gnubg.ParsedMatchData.Companion.parse
import match.MatchState
import utils.Filename
import utils.bothExist
import java.io.File


fun LoadedGame.logResponse(
    command: GnubgCommand, response: GnubgCommandResponseString, rawMatchData: ParsedCommandResponse
) {
    val debugFile = File("gnubg-logs/${this.matchData.matchId.serverMatchId}").also {
        it.createNewFile()
    }

    debugFile.appendText("-----------------------------------\n")
    debugFile.appendText("Command: ${command.getCommandString()}\n")
    debugFile.appendText("GNUBG Response:\n")
    debugFile.appendText(response.value)
    debugFile.appendText("\nGnubgCommandResponse[]:\n")
    debugFile.appendText(rawMatchData.newHistoryItems.joinToString("\n"))
    debugFile.appendText("\n-----------------------------------\n")
}

fun LoadedGame.getNewHistory(
    command: GnubgCommand,
    commandResponse: ParsedCommandResponse
): List<GameStateHistory> {
    val moveString = (command as? GnubgCommand.Literal)

    val oldHistory = history.let {
        val last = it.last() as? GameStateHistory.Roll

        if (moveString != null && last != null) {
            it.dropLast(1) + last.copy(moveString = moveString.moveString)
        } else it
    }

    val newHistoryItems =
        parseHistoryItems(commandResponse)
            .let {
                when (moveString) {
                    null -> it
                    else -> it.drop(1)
                }
            }


    val newHistory = oldHistory.mergeHistoryItems(newHistoryItems)

    return newHistory
}

/**
 * Responsible for every move a player makes.
 */
fun LoadedGame.processCommandsAndSaveMatch(
    command: GnubgCommand,
    overrideInputFile: Filename? = null,
    overrideOutputFile: Filename? = null,
    dontSave: Boolean = false
): LoadedGame? = runCatching {
    val filename = matchData.matchId.filename
    val inputFileName = overrideInputFile ?: filename
    val outputFileName = overrideOutputFile ?: filename

    val originalResponse = listOf(
        GnubgCommand.LoadMatch(inputFileName),
        command,
        GnubgCommand.Hint,
        GnubgCommand.Literal("show board")
    ).runCommands()


    fixStartingMatch(inputFileName, outputFileName)

//    fixResignation(response, filename)

    val resignationResponse =
        if (originalResponse.findResignation() != null)
            listOf(
                GnubgCommand.AcceptOrDecline(true),
                GnubgCommand.Hint,
                GnubgCommand.Literal("show board")
            ).runCommands()
        else
            null

    val response = resignationResponse ?: originalResponse

    if (resignationResponse != null) {
        logResponse(command, resignationResponse, resignationResponse.parse())
    }

    val parsedCommandResponse = response.parse()

    logResponse(command, response, parsedCommandResponse)


    val parsedMatch = parsedCommandResponse.parse(matchData.matchId)

    val newHistory = getNewHistory(
        command, parsedCommandResponse
    )

    val matchOver = bothExist(
        parsedCommandResponse.newHistoryItems
            .filterIsInstance<GnubgCommandResponse.MatchOver>()
            .firstOrNull(),
        parsedCommandResponse.newHistoryItems
            .filterIsInstance<GnubgCommandResponse.ScoreUpdate>()
            .firstOrNull()
    )


    val newLoadedGame = LoadedGame(
        parsedMatch
//        .let {
//        if (matchOver != null) it.copy(
//            match = it.match.copy(
//                matchState = MatchState.GameOver,
//                playerOneScore = matchOver.second.playerOneScore,
//                playerTwoScore = matchOver.second.playerTwoScore
//            )
//        ) else it
//    }
        , newHistory
    )

    if (!dontSave) {
        GameState.updateMatch(newLoadedGame)
    }

    GnubgCommand.SaveMatch(outputFileName).runCommand()

    fixStartingMatch(newLoadedGame.matchData.matchId)

    newLoadedGame
}.onFailure { it.printStackTrace() }.getOrNull()