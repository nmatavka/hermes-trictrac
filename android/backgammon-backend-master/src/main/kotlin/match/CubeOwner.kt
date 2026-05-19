package match

enum class CubeOwner {
    PlayerOne, PlayerTwo, Centered;

    companion object {
        fun fromTwoBitString(bitString: String) = when (bitString) {
            "00" -> PlayerOne
            "01" -> PlayerTwo
            "11" -> Centered
            else -> throw Error("Could not parse cube owner from bitstring.")
        }
    }
}