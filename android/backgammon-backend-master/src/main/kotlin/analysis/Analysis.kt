package analysis

import gnubg.parseMoveString
import kotlinx.serialization.Serializable
import utils.trimLines


@Serializable sealed interface GameAnalysis {
    companion object {
        fun fromString(analysisString: String): GameAnalysis? {
            val cube = runCatching {
                CubeAnalysis(CubelessEquity.fromAnalysisString(analysisString))
            }.getOrNull()

            val roll = runCatching { RollCandidate.fromAnalysisString(analysisString) }.getOrNull()

            return cube ?: roll
        }
    }

}

fun <T> List<T>.chunkedEqualSize(size: Int) = chunked(size).filter {it.size == size}


@Serializable @JvmInline value class RollAnalysis(val value: List<RollCandidate>) : GameAnalysis

@Serializable data class RollCandidate(
    val moveString: String,
    val newMatchEquity: Double,
    val odds: MatchEquities,
    val analysisUsed: String
) : GameAnalysis {
    companion object {
        fun fromGroupOfThreeLines(lines: List<String>): RollCandidate {
            val moveString = parseMoveString(lines[0])!!

            return RollCandidate(
                moveString = moveString,
                newMatchEquity = lines[0].split("Eq.: ")[1].split(" ").first().toDouble(),
                odds = MatchEquities.fromOddsLine(lines[1]),
                analysisUsed = lines[2].trim()
            )
        }

        fun fromAnalysisString(analysisString: String): RollAnalysis = RollAnalysis(
            analysisString.trimLines().let {
                val index = it.indexOfFirst { line -> "1. C" in line }
                it.drop(index)
            }
                .chunkedEqualSize(3)
                .mapNotNull { runCatching { RollCandidate.fromGroupOfThreeLines(it) }.getOrNull() }
        )
    }
}


@Serializable data class CubeAnalysis(
    val cubelessEquity: CubelessEquity,
) : GameAnalysis