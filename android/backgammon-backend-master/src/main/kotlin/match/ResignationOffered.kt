package match

import kotlinx.serialization.Serializable
import utils.Bits

@Serializable
data class ResignationOffered(val result: GameResult) {
    companion object {
        fun fromBits(bits: Bits): ResignationOffered? = when (bits.asBinaryString) {
            "00" -> null
            "01" -> ResignationOffered(GameResult.SingleGame)
            "10" -> ResignationOffered(GameResult.Gammon)
            "11" -> ResignationOffered(GameResult.Backgammon)
            else -> throw Error("Invalid bit string.")
        }
    }
}