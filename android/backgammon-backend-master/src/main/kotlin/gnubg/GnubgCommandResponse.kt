package gnubg

import match.DiceRoll
import match.GnubgMatchId

val moveRegex = Regex("""(\w*) moves ([^.]*)\.""")

val doubleRegex = Regex("""(\w*) doubles\.""")

val acceptCubeRegex = Regex("""(\w*) accepts the cube at (\d+).""")

sealed interface GnubgCommandResponse {
    data class Move(val playerName: String, val moveString: String) : GnubgCommandResponse

    data class Double(val playerOffering: String) : GnubgCommandResponse

    data class AcceptsCube(val playerAcceptingCube: String, val cubeAmount: Int) :
        GnubgCommandResponse

    data class Roll(val roll: DiceRoll) : GnubgCommandResponse

    data class CannotMove(val playerName: String) : GnubgCommandResponse

    data class PositionId(val positionId: String) : GnubgCommandResponse

    data class MatchID(val matchId: GnubgMatchId) : GnubgCommandResponse

    data class ScoreUpdate(
        val playerOne: String,
        val playerOneScore: Int,
        val playerTwo: String,
        val playerTwoScore: Int,
        val numberOfGames: Int
    ) : GnubgCommandResponse {
        companion object {
            val regex = Regex("The score \\(after (\\d+) games?\\) is: (\\w+) (\\d+), (\\w+) (\\d+)")

            fun fromLine(line: String): ScoreUpdate? {
                return regex.findAll(line).singleOrNull()?.groupValues?.let {
                    val numberOfGames = it[1]
                    val playerOne = it[2]
                    val playerOneScore = it[3]
                    val playerTwo = it[4]
                    val playerTwoScore = it[5]
                    ScoreUpdate(
                        playerOne = playerOne,
                        playerOneScore = playerOneScore.toInt(),
                        playerTwo = playerTwo,
                        playerTwoScore = playerTwoScore.toInt(),
                        numberOfGames = numberOfGames.toInt()
                    )
                }
            }
        }
    }

    data class MatchOver(val winner: String) : GnubgCommandResponse {
        companion object {
            fun fromLine(line: String): MatchOver? {
                val winner =
                    Regex("(\\w+) has won the match.")
                        .findAll(line)
                        .singleOrNull()?.groupValues?.getOrNull(1)
                return winner?.let { MatchOver(it) }
            }
        }
    }

    companion object {
        fun fromLine(line: String): GnubgCommandResponse? {
            val foundRoll = Regex("Rolled (\\d+)").findAll(line).singleOrNull()?.let {
                val (roll1, roll2) = it.groupValues[1].map { x -> x.digitToInt() }

                Roll(roll = DiceRoll(roll1, roll2))
            }

            val foundMove = moveRegex.findAll(line).singleOrNull()?.let {
                val player = it.groupValues[1]
                val move = it.groupValues[2]

                Move(
                    playerName = player,
                    moveString = move
                )
            }

            val foundDouble = doubleRegex.findAll(line).singleOrNull()?.let {
                Double(
                    playerOffering = it.groupValues[1]
                )
            }

            val foundAcceptCube = acceptCubeRegex.findAll(line).singleOrNull()?.let {
                AcceptsCube(
                    playerAcceptingCube = it.groupValues[1],
                    cubeAmount = it.groupValues[2].toInt(),
                )
            }

            val foundCannotMove = Regex("(\\w+) cannot move").findAll(line).singleOrNull()?.let {
                CannotMove(it.groupValues[1])
            }

            val foundPositionId =
                Regex("Position ID: ([a-zA-Z0-9/+=]+)").findAll(line).singleOrNull()?.let {
                    PositionId(it.groupValues[1])
                }

            val foundMatchID = Regex("Match ID\\s*: (\\w+)").findAll(line).singleOrNull()?.let {
                MatchID(GnubgMatchId(it.groupValues[1]))
            }


            return foundMatchID ?: foundPositionId ?: foundCannotMove ?: foundRoll ?: foundMove
            ?: foundDouble ?: foundAcceptCube ?: ScoreUpdate.fromLine(line) ?: MatchOver.fromLine(line)

        }
    }
}