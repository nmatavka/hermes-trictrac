package match

enum class GamePlayer {
    PlayerOne, PlayerTwo;

    companion object {
        fun fromSingleBitString(bitString: String) = when (bitString) {
            "0" -> PlayerOne
            "1" -> PlayerTwo
            else -> throw Error("Invalid bitstring passed.")
        }
    }
}