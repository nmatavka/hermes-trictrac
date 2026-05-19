package gnubg

import kotlinx.serialization.Serializable
import kotlin.math.sin

@Serializable data class MoveChecker(val from: Int, val to: Int) {
    override fun toString() = "$from/$to"

    companion object {
        fun fromStringToken(token: String): MoveChecker? = token.split("/").let {
            val from = it.getOrNull(0)?.removeSuffix("*")?.toIntOrNull()
            val to = it.getOrNull(1)?.removeSuffix("*")?.toIntOrNull()
            if (from != null && to != null) MoveChecker(from, to) else null
        }
    }
}

@Serializable data class MovePair(val firstMove: MoveChecker, val secondMoveChecker: MoveChecker?) {
    companion object {
        fun fromStrings(moveOne: String, moveTwo: String?) = MovePair(
            MoveChecker.fromStringToken(moveOne)!!,
            moveTwo?.let(MoveChecker::fromStringToken)
        )
    }
}


fun parseMoveString(moveString: String): String? {
    return moveString.split(" ").mapNotNull {
        (doubleMove.findAll(it).singleOrNull() ?: singleMove.findAll(it).singleOrNull())?.value
    }.joinToString(" ").takeUnless { it.isBlank() }
}

val optionalStar = Regex("(?>\\*?)")

val optionalMoveRepeater = Regex("(\\(\\d\\))?")

val requiredDigit = Regex("(\\d+)")

val barOrNumber = Regex("bar|$requiredDigit")

val numberWithStar = Regex("$requiredDigit$optionalStar")

val destination = Regex("($numberWithStar|off)")

val singleMove = Regex("($barOrNumber)/($destination)$optionalMoveRepeater")

val doubleMove = Regex("($barOrNumber)/($numberWithStar)/($numberWithStar)")

