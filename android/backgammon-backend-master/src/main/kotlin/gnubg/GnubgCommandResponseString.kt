package gnubg

import analysis.CubeAnalysis
import analysis.GameAnalysis
import analysis.RollCandidate
import match.GnubgMatchId

@JvmInline
value class GnubgCommandResponseString(val value: String) {
    fun parse(): ParsedCommandResponse {
        val analysisString =
            value
                .split("\n\n")
                .find { paragraph -> "analysis" in paragraph || "prune" in paragraph }


        val rawHistoryItems = value.lines().mapNotNull { line ->
            GnubgCommandResponse.fromLine(line)
        }


        val cleanedHistoryItems = rawHistoryItems.dedupe()



        return ParsedCommandResponse(
            analysisString = analysisString?.trim(),
            newHistoryItems = cleanedHistoryItems
        )
    }
}

fun List<GnubgCommandResponse>.dedupe(): List<GnubgCommandResponse> {
    var positionId: String? = null
    var gnubgMatchId: GnubgMatchId? = null
    var roll: GnubgCommandResponse.Roll? = null

    return filter { commandResponse ->
        when (commandResponse) {
            is GnubgCommandResponse.MatchID -> {
                if (gnubgMatchId == commandResponse.matchId) {
                    false
                } else {
                    gnubgMatchId = commandResponse.matchId
                    roll = null
                    true
                }
            }

            is GnubgCommandResponse.PositionId -> {
                if (positionId == commandResponse.positionId) {
                    false
                } else {
                    positionId = commandResponse.positionId
                    roll = null
                    true
                }
            }

            is GnubgCommandResponse.Roll -> {
                if (roll == null) {
                    roll = commandResponse
                    true
                } else false
            }

            else -> true
        }
    }
}

val List<GnubgCommandResponse>.matchId: GnubgMatchId?
    get() = filterIsInstance<GnubgCommandResponse.MatchID>().lastOrNull()?.matchId

val List<GnubgCommandResponse>.positionId: String?
    get() = filterIsInstance<GnubgCommandResponse.PositionId>().lastOrNull()?.positionId

data class ParsedCommandResponse(
    val analysisString: String?,
    val newHistoryItems: List<GnubgCommandResponse>
) {
    val positionId get() = newHistoryItems.positionId!!
    val gnubgMatchId get() = newHistoryItems.matchId!!
    val gameAnalysis get() = analysisString?.run(GameAnalysis::fromString)
    val cubeAnalysis get() = gameAnalysis as? CubeAnalysis
    val rollAnalysis get() = analysisString?.run(RollCandidate::fromAnalysisString)
}