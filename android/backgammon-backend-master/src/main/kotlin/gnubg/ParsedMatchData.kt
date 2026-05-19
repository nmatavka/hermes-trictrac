package gnubg

import analysis.CubeAnalysis
import analysis.GameAnalysis
import analysis.RollAnalysis
import analysis.RollCandidate
import com.expediagroup.graphql.generator.annotations.GraphQLIgnore
import kotlinx.serialization.Serializable
import match.GnubgMatchId
import match.MatchObject


@Serializable
data class ParsedMatchData(
    val positionId: String,
    val match: GnubgMatchId,
    val cubeAnalysis: CubeAnalysis?,
    val rollAnalysis: RollAnalysis?,
    @param:GraphQLIgnore val matchId: ServerMatchId,
) {
    companion object {
        fun ParsedCommandResponse.parse(matchId: ServerMatchId): ParsedMatchData {
            val cubeAnalysis = analysisString?.let(GameAnalysis.Companion::fromString) as? CubeAnalysis

            return ParsedMatchData(
                positionId = positionId,
                match = gnubgMatchId,
                cubeAnalysis = cubeAnalysis,
                rollAnalysis = runCatching {
                    if (analysisString == null) throw Error("Can't analyze empty string.")

                    RollCandidate.fromAnalysisString(analysisString)
                }.getOrNull(),
                matchId = matchId,
            )
        }
    }
}