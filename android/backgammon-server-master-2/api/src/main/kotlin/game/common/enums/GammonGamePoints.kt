package game.common.enums

enum class GammonGamePoints(val value: Int) {
    ONE(1),
    THREE(3),
    FIVE(5),
    SEVEN(7),
    NINE(9);

    companion object {

        fun of(value: Int): GammonGamePoints? {
            return entries.find { it.value == value }
        }
    }

}