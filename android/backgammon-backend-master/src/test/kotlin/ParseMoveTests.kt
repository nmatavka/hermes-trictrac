import gnubg.doubleMove
import gnubg.optionalStar
import gnubg.parseMoveString
import gnubg.singleMove
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.equals.shouldBeEqual
import io.kotest.matchers.shouldBe

val sampleOne = "bar/21 8/2*"

class ParseMoveTests : FunSpec({
    listOf(
        "bar/21 24/18",
        "bar/15",
        "6/1*",
        "13/7* 6/1*",
        "24/18 6/1*",
        "24/21* 6/2",
        "13/7*/2",
        "24/21*/19*",
        "8/3(2) 6/1*(2)",
        "8/3*(3) 6/1*",
        "bar/17* bar/21 6/2",
        "bar/21(2) 8/4 6/2",
        "bar/21(2) 8/4(2)",
        "bar/17*(2)",
        "13/7*/1 13/7(2)",
        "24/18(2) 13/7*/1"
    ).forEach { text ->
        test(text) {
            val parsedMove = parseMoveString(text)!!
            parsedMove shouldBeEqual text
        }
    }

    test("double move") {
        doubleMove.findAll("13/7*/19*").toList().forEach {
            println(it.value)
        }
    }

    test("from complex string") {
        val parsedMove = parseMoveString(
            "1. Cubeful 2-ply    bar/17*(2)                   Eq.: +0.324"
        )!!

        parsedMove shouldBe "bar/17*(2)"
    }
})

