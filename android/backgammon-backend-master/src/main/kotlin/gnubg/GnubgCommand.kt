package gnubg

import com.lordcodes.turtle.shellRun
import kotlinx.coroutines.runBlocking
import utils.HasFilename
import utils.getEnvVar

sealed interface GnubgCommand {
    fun getCommandString(): String


    data class NewMatch(val matchLength: Int) : GnubgCommand {
        override fun getCommandString() = "new match $matchLength"
    }

    data class SetUpBoard(val positionId: String, val matchId: String) : GnubgCommand {
        override fun getCommandString() = listOf(
            "set matchid $matchId",
            "set board $positionId"
        ).joinToString(" \n ")
    }

    data class SaveMatch(val filename: HasFilename) : GnubgCommand {
        override fun getCommandString() = "export match mat ${filename.path}"
    }

    data class LoadMatch(val filename: HasFilename) : GnubgCommand {
        override fun getCommandString() = "import mat ${filename.path}"
    }

    data object RollDice : GnubgCommand {
        override fun getCommandString(): String = "roll"
    }

    data class MoveCheckers(val movePair: MovePair) : GnubgCommand {
        override fun getCommandString() =
            listOfNotNull(
                movePair.firstMove,
                movePair.secondMoveChecker
            ).joinToString(" ") { it.toString() }

    }

    data object Hint : GnubgCommand {
        override fun getCommandString() = "hint"
    }

    data class GetMatchInfo(val matchId: String) : GnubgCommand {
        override fun getCommandString(): String {
            TODO("Not yet implemented")
        }
    }

    data class AcceptOrDecline(val isAccept: Boolean) : GnubgCommand {
        override fun getCommandString() = if (isAccept) "accept" else "drop new"
    }

    data class Literal(val moveString: String) : GnubgCommand {
        override fun getCommandString() = moveString
    }

    data object Double : GnubgCommand {
        override fun getCommandString() = "double"

    }

    data object Board : GnubgCommand {
        override fun getCommandString() = ""
    }
}

fun List<GnubgCommand>.runCommands(): GnubgCommandResponseString {
    val commands = map { it.getCommandString() }.toTypedArray()

    return runBlocking {
        GnubgCommandResponseString(shellProcess.sendCommand(*commands))
    }
}


fun GnubgCommand.runCommand(): GnubgCommandResponseString {
    val command = getCommandString()
    val response = runBlocking {
        GnubgCommandResponseString(shellProcess.sendCommand(command))
    }

    return response
}
