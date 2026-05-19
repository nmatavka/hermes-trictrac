package analysis

import kotlinx.serialization.Serializable

@Serializable data class CubelessEquity(
    val equity: Double,
    val odds: MatchEquities,
    val noDoubleEquity: Double,
    val doublePassEquity: Double,
    val doubleTakeEquity: Double,
) {
    constructor(equity: Double, odds: MatchEquities, decisions: List<CubeDecisionItem>) :
            this(
                equity = equity,
                odds = odds,
                noDoubleEquity = decisions.first { it.decision == CubeDecision.NoDouble }.newEquity,
                doublePassEquity = decisions.first { it.decision == CubeDecision.DoublePass }.newEquity,
                doubleTakeEquity = decisions.first { it.decision == CubeDecision.DoubleTake }.newEquity,
            )
}

enum class CubeDecision {
    NoDouble, DoublePass, DoubleTake;
}

@Serializable data class CubeDecisionItem(
    val decision: CubeDecision, val newEquity: Double
) {
    companion object {
        fun fromLine(line: String) = CubeDecisionItem(
            decision = when {
                "No double" in line -> CubeDecision.NoDouble
                "Double, pass" in line -> CubeDecision.DoublePass
                "Double, take" in line -> CubeDecision.DoubleTake
                else -> throw Error("Line $line does not have valid cube")
            },
            newEquity = line.split(" ").drop(1).firstNotNullOf { it.toDoubleOrNull() }
        )
    }
}

fun CubelessEquity.Companion.fromAnalysisString(analysisString: String): CubelessEquity {
    val analysisStringLines = analysisString.lines()

    val cubelessEquityLineNumber = analysisStringLines.indexOfFirst { "cubeless equity" in it }

    val cubelessEquityLine = analysisStringLines[cubelessEquityLineNumber]
    val oddsLine = analysisStringLines[cubelessEquityLineNumber + 1]

    val cubelessEquity = cubelessEquityLine.split(" ").firstNotNullOf { it.toDoubleOrNull() }

    val (winOdds, loseOdds) = oddsLine
        .split(" - ")
        .map(String::trim)
        .map { it.split(" ").map { s -> s.toDouble() } }

    return CubelessEquity(
        equity = cubelessEquity,
        odds = MatchEquities.fromOddsLine(oddsLine),
        decisions = listOf(
            analysisStringLines[cubelessEquityLineNumber + 3],
            analysisStringLines[cubelessEquityLineNumber + 4],
            analysisStringLines[cubelessEquityLineNumber + 5],
        ).map { CubeDecisionItem.fromLine(it) }
    )

}