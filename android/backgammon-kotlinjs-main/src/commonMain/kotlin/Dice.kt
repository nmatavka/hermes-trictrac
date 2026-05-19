import kotlinx.html.currentTimeMillis
import kotlinx.serialization.Serializable
import kotlin.math.max
import kotlin.math.min
import kotlin.random.Random

@Serializable
data class Dice(val num1: Int, val num2: Int) {
    companion object {
        private var random: Random = Random(currentTimeMillis())

        fun setSeed(seed: Int) {
            random = Random(seed)
        }

        fun roll(): Dice {
            return Dice(random.nextInt(1, 7), random.nextInt(1, 7))
        }

        fun allDice(): List<Dice> {
            val dice = mutableListOf<Dice>()
            for (i in 1..6) for (j in 1..6) dice.add(Dice(i, j))
            return dice
        }
    }

    fun numbers(): List<Int> {
        if (num1 == num2) return List(4) {num1}
        return listOf(min(num1, num2), max(num1, num2))
    }
}