package gnubg

import analysis.CubeAnalysis
import analysis.RollAnalysis
import kotlinx.serialization.Serializable
import match.DiceRoll


@Serializable
sealed interface MatchStatus {
    @Serializable
    data class RollOrDouble(val cubeAnalysis: CubeAnalysis) : MatchStatus

    @Serializable
    data class MovePieces(val roll: DiceRoll, val rollAnalysis: RollAnalysis) : MatchStatus

    @Serializable
    data class AcceptOrDropCube(val amount: Int) : MatchStatus
}

fun ParsedMatchData.getMatchStatus(): MatchStatus {
    if (rollAnalysis != null) {
        return MatchStatus.MovePieces(match.diceRolled!!, rollAnalysis)
    }

    if (match.doubleOffered) {
        return MatchStatus.AcceptOrDropCube(match.cubeValue)
    }

    if (cubeAnalysis != null) {
        return MatchStatus.RollOrDouble(cubeAnalysis)
    }

    throw Error("Invalid match status.")
}

