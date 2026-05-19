import gnubg.GnubgCommandResponseString
import gnubg.startMatch
import io.kotest.core.spec.style.FunSpec


class GnubgShellTests : FunSpec({
    test("create game") {
        val newGame = startMatch(7)
        println(newGame)
    }
})