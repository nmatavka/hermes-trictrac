package match

import com.expediagroup.graphql.generator.annotations.GraphQLIgnore
import kotlinx.serialization.Serializable
import utils.Bits
import kotlin.math.pow

interface Match {
    val cubeValue: Int
    val cubeOwner: CubeOwner
    val playerOnRoll: GamePlayer
    val isCrawford: Boolean
    val matchState: MatchState
    val playerOnTurn: GamePlayer
    val doubleOffered: Boolean
    val resignOffered: ResignationOffered?
    val diceRolled: DiceRoll?
    val matchLength: Int
    val playerOneScore: Int
    val playerTwoScore: Int
}

@Serializable
data class MatchObject(
    override val cubeValue: Int,
    override val cubeOwner: CubeOwner,
    override val playerOnRoll: GamePlayer,
    override val isCrawford: Boolean,
    override val matchState: MatchState,
    override val playerOnTurn: GamePlayer,
    override val doubleOffered: Boolean,
    override val resignOffered: ResignationOffered?,
    override val diceRolled: DiceRoll?,
    override val matchLength: Int,
    override val playerOneScore: Int,
    override val playerTwoScore: Int
) : Match

@Serializable @JvmInline
value class GnubgMatchId(val value: String) : Match {
    @GraphQLIgnore
    val bitString get() = Bits.fromBase64String(value)

    override val cubeValue get() = 2.toDouble().pow(bitString.getBits(1..4).asInt).toInt()
    override val cubeOwner get() = CubeOwner.fromTwoBitString(bitString.getBits(5..6).asBinaryString)
    override val playerOnRoll get() = GamePlayer.fromSingleBitString(bitString.getBits(7..7).asBinaryString)
    override val isCrawford get() = bitString.getBoolean(8)
    override val matchState get() = MatchState.fromThreeBitString(bitString.getBits(9..11).asBinaryString)
    override val playerOnTurn get() = GamePlayer.fromSingleBitString(bitString.getBits(12..12).asBinaryString)
    override val doubleOffered get() = bitString.getBoolean(13)
    override val resignOffered get() = ResignationOffered.fromBits(bitString.getBits(14..15))
    override val diceRolled
        get() = DiceRoll
            .fromBitString(bitString.getBits(16..21))
            .takeUnless { it.firstDice == 0 && it.secondDice == 0 }
    override val matchLength get() = bitString.getBits(22..36).asInt
    override val playerOneScore get() = bitString.getBits(37..51).asInt
    override val playerTwoScore get() = bitString.getBits(52..66).asInt

    @GraphQLIgnore
    fun toMatchObject(): MatchObject {
        return MatchObject(
            cubeValue = cubeValue,
            cubeOwner = cubeOwner,
            playerOnRoll = playerOnRoll,
            isCrawford = isCrawford,
            matchState = matchState,
            playerOnTurn = playerOnTurn,
            doubleOffered = doubleOffered,
            resignOffered = resignOffered,
            diceRolled = diceRolled,
            matchLength = matchLength,
            playerOneScore = playerOneScore,
            playerTwoScore = playerTwoScore
        )
    }
}

