package analysis

import kotlinx.serialization.Serializable

@Serializable data class MatchEquities(
    val winOdds: Double,
    val winGammonOdds: Double,
    val winBackgammonOdds: Double,
    val lossOdds: Double,
    val lossGammonOdds: Double,
    val lossBackgammonOdds: Double
) {
    companion object {
        fun fromOddsLine(oddsLine: String) =
            oddsLine.split(" ").mapNotNull { it.toDoubleOrNull() }
                .also {
                    if (it.size != 6) throw Error("$it size should be 6.")
                }.let { odds ->
                    MatchEquities(
                        winOdds = odds[0],
                        winGammonOdds = odds[1],
                        winBackgammonOdds = odds[2],
                        lossOdds = odds[3],
                        lossGammonOdds = odds[4],
                        lossBackgammonOdds = odds[5]
                    )
                }
    }
}