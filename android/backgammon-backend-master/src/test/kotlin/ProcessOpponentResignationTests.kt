import fixtures.getFixtureFilename
import match.GameResult
import gnubg.GnubgCommand
import gnubg.GnubgCommandResponseString
import match.ResignationOffered
import gnubg.runCommands
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import server.fixResignation

val testString = GnubgCommandResponseString(
    """
    gnubg offers to resign a gammon.
     GNU Backgammon  Position ID: AQAAcO6bgAAAAA
                     Match ID   : sEmgAEAAGAAE
     +12-11-10--9--8--7-------6--5--4--3--2--1-+     O: gnubg
     |          O     O |   | O  O     O       |     4 points
     |                O |   | O  O     O       |     On roll, resigns gammon
     |                  |   | O  O     O       |     
     |                  |   | O                |     
     |                  |   | O                |    
    ^|                  |BAR|                  |     5 points match (Crawford game)
     |                  |   |                  | XX 
     |                  |   |                  | XXX 
     |                  |   |                  | XXX 
     |                  |   |                  | XXX 
     |          O       |   |                X | XXX 3 points
     +13-14-15-16-17-18------19-20-21-22-23-24-+     X: kyle

    (kyle) 
""".trimIndent()
)

class ProcessOpponentResignationTests : FunSpec({
    test("fixes resignation") {
        val match = listOf(
            GnubgCommand.LoadMatch(getFixtureFilename("test-resign-before-move.mat")),
            GnubgCommand.Literal("move 3/0 2/0")
        )
            .runCommands().parse().gnubgMatchId.toMatchObject()

        match.resignOffered shouldBe ResignationOffered(GameResult.Gammon)

//        loadFixture("test-resign-before-move.mat") shouldBe loadFixture("test-resign-after-resignation.mat")
    }

    test("fixes resignation of gammon") {
        val file = getFixtureFilename("opponent-offers-to-resign-gammon.mat")

        val outfile = getFixtureFilename("opponent-offers-to-resign-gammon-fixed.mat")


        outfile.load().writeText(file.load().readText())


//        val response = listOf(
//            GnubgCommand.LoadMatch(file),
//            GnubgCommand.Literal("move 3/0 3/0 2/0 1/0"),
//            GnubgCommand.SaveMatch(outfile)
//        ).runCommands()


//        println(response)

        fixResignation(testString, outfile)

//        val match = listOf(
//            GnubgCommand.LoadMatch(outfile),
//        ).runCommands().parse().gnubgMatchId.parse()

//        match.resignOffered shouldBe ResignationOffered(GameResult.Gammon)

//        loadFixture("test-resign-before-move.mat") shouldBe loadFixture("test-resign-after-resignation.mat")
    }
})