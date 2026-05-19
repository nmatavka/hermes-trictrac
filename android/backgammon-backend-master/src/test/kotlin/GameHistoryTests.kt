import fixtures.loadFixture
import gnubg.GnubgCommandResponseString
import gnubg.ServerMatchId
import gnubg.dedupe
import gnubg.loadMatchData
import io.kotest.core.spec.style.FunSpec

class GameHistoryTests : FunSpec({
    test("load events") {
        val text = loadFixture("event-strings")

        val game = loadMatchData(ServerMatchId("export-game-test"))

        println(game)
    }

    test("dedupe test 1") {
        val text = loadFixture("dedupe-test-1").run(::GnubgCommandResponseString)

        val parsed = text.parse()

        val deduped = parsed.newHistoryItems.dedupe()

        parsed.newHistoryItems.forEach {
            println(it)
        }

        println("\nDeduped\n")

        deduped.forEach {
            println(it)
        }
    }
})
