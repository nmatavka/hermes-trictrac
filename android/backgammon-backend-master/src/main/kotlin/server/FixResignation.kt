package server

import gnubg.GnubgCommandResponseString
import gnubg.resignRegex
import utils.Filename

fun processAfterCommands(gnubgStringResult: GnubgCommandResponseString): Unit {

}

enum class GameOutcome {
    SingleGame,
    Gammon,
    Backgammon;

    val pointValue
        get() = when (this) {
            GameOutcome.SingleGame -> 1
            GameOutcome.Gammon -> 2
            GameOutcome.Backgammon -> 3
        }

    companion object {
        fun fromString(resignationString: String) = when (resignationString) {
            "single game" -> SingleGame
            "gammon" -> Gammon
            "backgammon" -> Backgammon
            else -> throw Error("Invalid type of resignation: \"$resignationString\"")
        }
    }
}

fun GnubgCommandResponseString.findResignation(): GameOutcome? =
    resignRegex.findAll(value).singleOrNull()?.let { regexResult ->
        GameOutcome.fromString(regexResult.groupValues[1])
    }

fun GnubgCommandResponseString.findCubeValue(): Int {
    val cubeString = Regex("Cube: (\\d+)").findAll(value).lastOrNull()

    val amount = cubeString?.groupValues?.getOrNull(1)?.toIntOrNull()

    return amount ?: 1
}


fun fixResignation(it: GnubgCommandResponseString, filename: Filename) {
    val resignation = it.findResignation()?.let { typeOfResignation ->
        val cubeValue = it.findCubeValue()

        val gameValue = typeOfResignation.pointValue * cubeValue

        val winString = "\n                                  Wins $gameValue points"
        filename.load().appendText(winString)
    }
}