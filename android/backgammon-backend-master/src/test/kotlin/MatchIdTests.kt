import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import match.CubeOwner
import match.DiceRoll
import match.GamePlayer
import match.GnubgMatchId
import match.MatchObject
import match.MatchState


fun FunSpec.testMatchId(matchId: String, expected: MatchObject) {
    val actual = GnubgMatchId(matchId).toMatchObject()

    test("cube value") {
        actual.cubeValue shouldBe expected.cubeValue
    }

    test("cube owner") {
        actual.cubeOwner shouldBe expected.cubeOwner
    }

    test("player on roll") {
        actual.playerOnRoll shouldBe expected.playerOnRoll
    }

    test("is crawford") {
        actual.isCrawford shouldBe expected.isCrawford
    }

    test("match state") {
        actual.matchState shouldBe expected.matchState
    }

    test("player on turn") {
        actual.playerOnTurn shouldBe expected.playerOnTurn
    }

    test("double offered") {
        actual.doubleOffered shouldBe expected.doubleOffered
    }

    test("resign offered") {
        actual.resignOffered shouldBe expected.resignOffered
    }

    test("dice rolled") {
        actual.diceRolled shouldBe expected.diceRolled
    }

    test("match length") {
        actual.matchLength shouldBe expected.matchLength
    }

    test("player one score") {
        actual.playerOneScore shouldBe expected.playerOneScore
    }

    test("player two score") {
        actual.playerTwoScore shouldBe expected.playerTwoScore
    }
}

class MatchIdTestOne : FunSpec({
    testMatchId(
        "QYkqASAAIAAA", MatchObject(
            cubeValue = 2,
            cubeOwner = CubeOwner.PlayerOne,
            playerOnRoll = GamePlayer.PlayerTwo,
            isCrawford = false,
            matchState = MatchState.PlayingGame,
            playerOnTurn = GamePlayer.PlayerTwo,
            doubleOffered = false,
            resignOffered = null,
            diceRolled = DiceRoll(5, 2),
            matchLength = 9,
            playerOneScore = 2,
            playerTwoScore = 4
        )
    )
})

class MatchIdTestTwo : FunSpec({
    testMatchId(
        "cImSAAAAAAAE", MatchObject(
            cubeValue = 1,
            cubeOwner = CubeOwner.Centered,
            playerOnRoll = GamePlayer.PlayerTwo,
            isCrawford = false,
            matchState = MatchState.PlayingGame,
            playerOnTurn = GamePlayer.PlayerTwo,
            doubleOffered = false,
            resignOffered = null,
            diceRolled = DiceRoll(5, 4),
            matchLength = 4,
            playerOneScore = 0,
            playerTwoScore = 0
        )
    )

})

class MatchIdTests : FunSpec({
    test("testMatches") {
        GnubgMatchId("cAmvAEAAIAAE").toMatchObject().run(::println)
        GnubgMatchId("MAGgAEAAIAAE").toMatchObject().run(::println)
    }
})
