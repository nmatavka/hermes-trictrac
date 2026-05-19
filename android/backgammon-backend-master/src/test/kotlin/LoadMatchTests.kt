import gnubg.GnubgCommand
import gnubg.ServerMatchId
import gnubg.runCommands
import io.kotest.core.spec.style.FunSpec
import server.GameState

class LoadMatchTests : FunSpec({
    test("load match") {
//        Position ID: yOvgATDgc/ABRA
//                Match ID   : cAmgAAAAAAAE


        listOf(GnubgCommand.RollDice).runCommands()
//        listOf(
//            GnubgCommand.LoadMatch("import-game-test"),
//            GnubgCommand.RollDice,
//            GnubgCommand.SaveMatch("export-game-test")
//        ).runCommands().run(::println)
    }

    test("load flow") {
        GameState.subscribeToGame(ServerMatchId("a14e859e-6749-4784-b96d-a22c3593932b")).collect {
            println(it.history)
            println(it._history)

        }
    }
})