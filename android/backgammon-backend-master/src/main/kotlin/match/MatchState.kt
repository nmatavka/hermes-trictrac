package match

enum class MatchState {
    NoGameStarted, PlayingGame, GameOver, GameResigned, GameEndedViaDroppedCube;

    companion object {
        fun fromThreeBitString(bitString: String) = when (bitString) {
            "000" -> NoGameStarted
            "001" -> PlayingGame
            "010" -> GameOver
            "011" -> GameResigned
            "100" -> GameEndedViaDroppedCube
            else -> throw Error("Could not parse match state from bitstring.")
        }
    }
}