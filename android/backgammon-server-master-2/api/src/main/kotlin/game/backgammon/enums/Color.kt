package game.backgammon.enums

import java.io.Serializable

enum class Color : Serializable {
    BLACK,
    WHITE;

    fun getOpponent(): Color {
        return when (this) {
            WHITE -> BLACK
            BLACK -> WHITE
        }
    }
}