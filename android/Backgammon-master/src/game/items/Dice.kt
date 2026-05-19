package game.items

import kotlin.random.Random

class Dice {
    fun roll(): Array<Int> {
        return arrayOf(rollDice(), rollDice())
    }

    private fun rollDice(): Int {
        return Random.nextInt(1, 6)
    }
}