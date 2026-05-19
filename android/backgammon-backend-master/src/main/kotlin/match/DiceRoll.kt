package match

import com.expediagroup.graphql.generator.annotations.GraphQLIgnore
import kotlinx.serialization.Serializable
import utils.Bits

@Serializable
data class DiceRoll(val firstDice: Int, val secondDice: Int) {
    @GraphQLIgnore
    fun asList() = listOf(firstDice, secondDice)

    override fun hashCode(): Int {
        return asList().sorted().hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as DiceRoll

        if (firstDice != other.firstDice) return false
        if (secondDice != other.secondDice) return false

        return true
    }

    companion object {
        fun fromBitString(bitString: Bits) = DiceRoll(
            bitString.getBits(1..3).asInt,
            bitString.getBits(4..6).asInt
        )
    }
}