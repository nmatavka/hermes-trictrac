import fixtures.loadFixture
import gnubg.GnubgCommandResponse
import gnubg.GnubgCommandResponseString
import gnubg.dedupe
import io.kotest.core.spec.style.FunSpec


val matchOverString =
    """
        The score (after 4 games) is: gnubg 5, kyleth95 4 (match to 5 points, post-Crawford play)
        gnubg has won the match.
    """.trimIndent()

class TestMatchOver : FunSpec({
    test("test parse") {

        matchOverString.lines().map {
            GnubgCommandResponse.fromLine(it)
        }.run(::println)
    }

    test("game over") {
        val response = GnubgCommandResponseString(loadFixture("gnubg-response-game-over"))

        val loaded = response.parse()

        loaded.newHistoryItems.forEach(::println)

        println("Deduped")
        loaded.newHistoryItems.dedupe().forEach(::println)
    }
})