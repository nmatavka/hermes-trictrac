import gnubg.GnubgCommandResponseString
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import server.findCubeValue
import server.findResignation

val sampleResponse = GnubgCommandResponseString(
    """
gnubg offers to resign a single game.
GNU Backgammon  Position ID: AgAAPBcAAAAAAA
Match ID   : USGgACAAIAAE
+13-14-15-16-17-18------19-20-21-22-23-24-+     O: kyleth95
|                  |   |             O    | OOO 2 points
|                  |   |                  | OOO
|                  |   |                  | OOO
|                  |   |                  | OOO
|                  |   |                  | OO
v|                  |BAR|                  |     5 points match
|                  |   |                  | X
|                  |   |                X | X
|                  |   |          X     X | X
|                  |   |          X     X | XX  On roll, resigns single game
|                  |   |       X  X     X | XX  4 points
+12-11-10--9--8--7-------6--5--4--3--2--1-+     X: gnubg (Cube: 2)
"""
)

class FixResignationTests : FunSpec({
    test("find cube value") {
        sampleResponse.findResignation().run(::println)
        sampleResponse.findCubeValue() shouldBe 2
    }
})