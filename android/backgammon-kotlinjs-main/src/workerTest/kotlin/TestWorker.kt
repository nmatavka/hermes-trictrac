import kotlinx.coroutines.test.runTest
import scorers.*
import kotlin.js.Date
import kotlin.test.*

class TestWorker {
    @Test
    fun testDumbeval() = runTest {
        val dumbevalScorer = Dumbeval()
        for (i in 0..3)
            for (j in 0..dumbevalScorer.MX)
                assertEquals(1.0f, dumbevalScorer.winProb[i][j], 1e6f)

        for ((i, j) in listOf(50 to 13, 220 to 220, 190 to 175, 110 to 126, 50 to 46, 60 to 65, 49 to 65)) {
            println("P[$i, $j] = ${dumbevalScorer.winProb[i][j]}")
        }

    }

    @Test
    fun testPubeval() = runTest {
        val scorer: Pubeval = Pubeval(50f)
        val initState1 = initialGameState(1)
        println("Features: ${initState1.pubevalFeatures(0)}")

        println("Player 1 goes first, player1 score: ${scorer.score(initState1, 1)}")
        println("Player 1 goes first, player2 score: ${scorer.score(initState1, 2)}")

        val initState2 = initialGameState(2)
        println("Player 2 goes first, player1 score: ${scorer.score(initState2, 1)}")
        println("Player 2 goes first, player2 score: ${scorer.score(initState2, 2)}")

    }


    @Test
    fun testMinimax() = runTest {
        val state = initialGameState(1)
        state.setDice(Dice(4, 5))

        val root = MiniMaxNode(true)
        val startDate = Date.now()
        root.expand(state, 1, 1, Date.now() + 500)
        assertNotNull(root.value, "Root value should not be null")
        println("Expansion took ${Date.now() - startDate} ms. Root value: ${root.value}")
        assertNotNull(root.children, "Root children should not be null")
        assertNotNull(root.actionPerChildren, "Root actionsPerChildren should not be null")
        assertEquals(10, root.children!!.size, "Root should have 10 children")
        assertEquals(10, root.actionPerChildren!!.size, "Root should have 10 children")
        for (node in root.children!!) {
            assertFalse(node.isTerminal, "Child of root should not be terminal")
            assertNull(node.children, "Child of root should not have children (depth=1)")
            assertNotNull(node.value, "Child of root should have non-null value")
        }
    }
}