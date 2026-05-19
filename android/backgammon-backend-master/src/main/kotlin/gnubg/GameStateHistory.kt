package gnubg

import analysis.CubeAnalysis
import analysis.RollAnalysis
import gnubg.GameStateHistory.*
import kotlinx.serialization.Serializable
import match.DiceRoll
import match.GnubgMatchId
import match.MatchObject


@Serializable
sealed interface GameStateHistory {
    val positionId: String

    val gnubgMatchId: GnubgMatchId

    @Serializable
    data class BoardUpdate(
        override val positionId: String,
        override val gnubgMatchId: GnubgMatchId
    ) : GameStateHistory

    @Serializable
    data class Roll(
        val roll: DiceRoll,
        val moveString: String?,
        val rollAnalysis: RollAnalysis?,
        override val positionId: String,
        val matchDataBeforeRoll: MatchObject,
        val playerOnRoll: String,
        val wasBrick: Boolean = false,
        override val gnubgMatchId: GnubgMatchId
    ) : GameStateHistory

    @Serializable
    data class OfferedDouble(
        val cubeAnalysis: CubeAnalysis?,
        val amountDoubledTo: Int,
        override val positionId: String,
        override val gnubgMatchId: GnubgMatchId
    ) : GameStateHistory

    @Serializable
    data class AcceptCube(
        val amount: Int,
        val playerAcceptingCube: String,
        override val positionId: String,
        override val gnubgMatchId: GnubgMatchId
    ) : GameStateHistory

    @Serializable
    data class GameOver(
        override val positionId: String,
        override val gnubgMatchId: GnubgMatchId,
    ) : GameStateHistory

    @Serializable
    data class MatchOver(
        override val positionId: String,
        override val gnubgMatchId: GnubgMatchId,
        val winner: String
    ) : GameStateHistory
}

fun parseHistoryItems(
    commandResponse: ParsedCommandResponse
): List<GameStateHistory> {
    var positionId = commandResponse.positionId
    var matchId = commandResponse.gnubgMatchId


    val newHistoryItems: List<GameStateHistory> =
        commandResponse.newHistoryItems.mapIndexedNotNull { index, it ->
            when (it) {
                is GnubgCommandResponse.AcceptsCube -> AcceptCube(
                    amount = it.cubeAmount,
                    playerAcceptingCube = it.playerAcceptingCube,
                    positionId = positionId,
                    gnubgMatchId = matchId
                )
//
                is GnubgCommandResponse.Double -> OfferedDouble(
                    cubeAnalysis = commandResponse.cubeAnalysis,
                    amountDoubledTo = matchId.cubeValue * 2,
                    positionId = positionId,
                    gnubgMatchId = matchId
                )

                is GnubgCommandResponse.Move ->
                    Roll(
                        commandResponse.newHistoryItems
                            .subList(0, index)
                            .filterIsInstance<GnubgCommandResponse.Roll>()
                            .last().roll,
                        it.moveString,
                        rollAnalysis = null,
                        positionId = positionId,
                        matchDataBeforeRoll = matchId.toMatchObject(),
                        playerOnRoll = it.playerName,
                        gnubgMatchId = matchId
                    )

                is GnubgCommandResponse.Roll -> {
                    val nextItem = commandResponse.newHistoryItems.getOrNull(index + 1)
                    val shouldIgnore = nextItem is GnubgCommandResponse.Move
                    val cannotMove = nextItem as? GnubgCommandResponse.CannotMove
                    val wasBrick = nextItem is GnubgCommandResponse.CannotMove

                    Roll(
                        it.roll,
                        null,
                        null,
                        positionId = positionId,
                        matchDataBeforeRoll = matchId.toMatchObject(),
                        playerOnRoll = cannotMove?.playerName ?: matchId.playerOnRoll.name,
                        wasBrick = wasBrick,
                        gnubgMatchId = matchId
                    ).takeUnless {
                        shouldIgnore
                    }
                }

                is GnubgCommandResponse.CannotMove -> null

                is GnubgCommandResponse.MatchID -> {
                    matchId = it.matchId
                    null
                }

                is GnubgCommandResponse.PositionId -> {
                    positionId = it.positionId
                    null
                }

                is GnubgCommandResponse.ScoreUpdate -> GameOver(
                    positionId = positionId,
                    gnubgMatchId = matchId,
                )

                is GnubgCommandResponse.MatchOver -> MatchOver(
                    positionId = positionId,
                    gnubgMatchId = matchId,
                    winner = it.winner
                )
            }
        }

    return newHistoryItems
}

fun List<GameStateHistory>.mergeHistoryItems(
    newItems: List<GameStateHistory>
): List<GameStateHistory> {
    val toReturn = toMutableList()




    return this + newItems
}

infix fun GameStateHistory.isSameBoard(other: GameStateHistory): Boolean {
    return positionId == other.positionId && gnubgMatchId == other.gnubgMatchId
}