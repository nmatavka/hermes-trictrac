import kotlin.math.abs
import kotlin.test.*

private fun GameState.checkField(field: Int, player: Int, checkers: Int) {
    assertEquals(player, fieldPlayerIdx[field], "Error in fieldPlayerIdx: $field")
    assertEquals(checkers, fields[field], "Error in field counts: $field")
}

private fun GameState.checkGoodMoves(moves: List<Move>) {
    val moveFields = moveableFields().toSet()
    for (move in moves) {
        assertTrue(move.from in moveFields, "$move from value should be in moveableFields")
        val movesFrom = possibleMovesFrom(move.from)
        assertTrue(move in movesFrom, "$move should be in possible moves")
        assertTrue(isMovePossible(move), "$move should be possible")
    }
}

private fun GameState.checkBadMoves(moves: List<Move>) {
    for (move in moves) {
        val movesFrom = possibleMovesFrom(move.from)
        assertFalse(move in movesFrom, "$move should NOT be in possible moves")
        assertFalse(isMovePossible(move), "$move should NOT be possible")
    }
}

/**
 * Create a GameState defined by fields and checker counts on the field for both players.
 */
private fun createGameState(
    player1Fields: Map<Int, Int>,
    player2Fields: Map<Int, Int>,
    turnOf: Int,
    dice: Dice,
): GameState {
    val fields = MutableList(26) {0}
    val fieldPlayerIdx = MutableList(26) {0}
    for ((field, cnt) in player1Fields.entries) {
        fields[field] = cnt
        fieldPlayerIdx[field] = 1
    }
    for ((field, cnt) in player2Fields.entries) {
        fields[field] = cnt
        fieldPlayerIdx[field] = 2
    }
    val gs = GameState(turnOf, fields, fieldPlayerIdx)
    gs.setDice(dice)
    return gs
}

class TestInitialState {

    // all legal initial single moves, if the dice are not considered
    val player1InitialMoves = mapOf(
        Pair(1, listOf(2, 3, 4, 5, 7)),
        Pair(12, listOf(14, 15, 16, 17, 18)),
        Pair(17, listOf(18, 19, 20, 21, 22, 23)),
        Pair(19, listOf(20, 21, 22, 23))
    )
    val player2InitialMoves = mapOf(
        Pair(24, listOf(18, 20, 21, 22, 23)),
        Pair(13, listOf(7, 8, 9, 10, 11)),
        Pair(8, listOf(2, 3, 4, 5, 6, 7)),
        Pair(6, listOf(2, 3, 4, 5))
    )

    private fun testGoodSingleMoves(whoGoesFirst: Int, goodMoves: Map<Int, List<Int>>, dice: Dice) {
        val gameState = initialGameState(whoGoesFirst)
        gameState.setDice(dice)
        for ((field, targets) in goodMoves.entries) {
            val goodTargets = targets.filter {abs(field - it) in listOf(dice.num1, dice.num2)}
            for (target in goodTargets) {
                assertTrue(gameState.isMovePossible(Move(field, target)))
            }
        }
    }

    @Test
    fun testGoodMovesPlayer1() {
        val allDice = listOf(Dice(3, 4), Dice(1, 1), Dice(6, 2), Dice(5, 5))
        for (dice in allDice) {
            testGoodSingleMoves(1, player1InitialMoves, dice)
        }
    }

    @Test
    fun testGoodMovesPlayer2() {
        val allDice = listOf(Dice(3, 4), Dice(1, 1), Dice(6, 2), Dice(5, 5))
        for (dice in allDice) {
            testGoodSingleMoves(2, player2InitialMoves, dice)
        }
    }

    private fun testBadMoves(whoGoesFirst: Int, badMoves: List<Move>, dice: Dice) {
        val gameState = initialGameState(whoGoesFirst)
        gameState.setDice(dice)
        for (move in badMoves)
            assertFalse(gameState.isMovePossible(move))
    }


    @Test
    fun testBadMovesPlayer1() {
        val dice = Dice(1, 4)
        val badMoves = mutableListOf<Move>()

        for (field in 0..25) {
            if (field !in player1InitialMoves) {
                for (target in 0..25) badMoves.add(Move(field, target))
            } else {
                for (target in 0..25)
                    if (target - field > dice.num1 + dice.num2 || target <= field) badMoves.add(Move(field, target))
            }
            badMoves.add(Move(field, -1))
        }
        badMoves.add(Move(1, 6))
        badMoves.add(Move(12, 13))
        badMoves.add(Move(19, 24))
        testBadMoves(1, badMoves, dice)
    }

    @Test
    fun testBadMovesPlayer2() {
        val dice = Dice(1, 4)
        val badMoves = mutableListOf<Move>()

        for (field in 0..25) {
            if (field !in player2InitialMoves) {
                for (target in 0..25) badMoves.add(Move(field, target))
            } else {
                for (target in 0..25)
                    if (field - target > dice.num1 + dice.num2 || target >= field) badMoves.add(Move(field, target))
            }
            badMoves.add(Move(field, -1))
        }
        badMoves.add(Move(24, 19))
        badMoves.add(Move(13, 12))
        badMoves.add(Move(6, 1))
        testBadMoves(2, badMoves, dice)
    }

    @Test
    fun testMakeMoves() {
        val gameState = initialGameState(1)
        gameState.setDice(Dice(3, 4))

        // player1 moves: 1 --> 5, 12 --> 15
        assertTrue(gameState.anyMovesPossible())
        gameState.makeMove(Move(1, 5))
        gameState.makeMove(Move(12, 15))
        gameState.checkField(1, 1, 1)
        gameState.checkField(5, 1, 1)
        gameState.checkField(12, 1, 4)
        gameState.checkField(15, 1, 1)
        assertFalse(gameState.anyMovesPossible(), "No moves should remain")

        // player2 moves: 24 --> 15 (hitting piece on field 15)
        gameState.nextTurn()
        gameState.setDice(Dice(5, 4))
        assertTrue(gameState.anyMovesPossible(), "Moves should be available")
        gameState.makeMove(Move(24, 15))
        gameState.checkField(15, 2, 1)
        gameState.checkField(24, 2, 1)
        // undo move, the hit piece should be restored
        val undoSuccess = gameState.undoLastMove()
        assertTrue(undoSuccess, "Move should be undone")
        gameState.checkField(15, 1, 1)
        gameState.checkField(24, 2, 2)
    }

    @Test
    fun testPossibleMoveSequences() {
        val gameState = initialGameState(1)
        gameState.setDice(Dice(1, 3))
        // if we first move 1 then 3: 3*5
        // if we first move 3 then 1: 4*4
        val numGoodMoves = 3*5 + 4*4
        val possibleMoves = gameState.possibleMoveSequences()
        assertEquals(numGoodMoves, possibleMoves.size, "Number of good moves should be $numGoodMoves")
        assertTrue(possibleMoves.all {it.size == 2}, "All possible sequences should have a length of 2.")
    }

    @Test
    fun testPossibleMovesFrom() {
        val gameState = initialGameState(2)
        gameState.setDice(Dice(1, 6))

        // moves from field 13
        val goodMoves13 = setOf(Move(13, 7), Move(13, 6))
        val movesFrom13 = gameState.possibleMovesFrom(13)
        assertEquals(goodMoves13, movesFrom13.toSet())

        // moves from field 6
        val goodMoves6 = setOf(Move(6, 5))
        val movesFrom6 = gameState.possibleMovesFrom(6)
        assertEquals(goodMoves6, movesFrom6.toSet())
    }

    @Test
    fun testMoveableFields() {
        val gameState1 = initialGameState(1)
        gameState1.setDice(Dice(1, 3))
        assertEquals(player1InitialMoves.keys, gameState1.moveableFields().toSet())
        val gameState2 = initialGameState(2)
        gameState2.setDice((Dice(1, 3)))
        assertEquals(player2InitialMoves.keys, gameState2.moveableFields().toSet())
    }
}

class TestMoves {

    /* Test state 1 (fields 6 to 1):
    |2| | | |1| |
    |2|2|1| |1|2|
     */

    val player1Fields1 = mapOf(4 to 1, 2 to 2)
    val player2Fields1 = mapOf(6 to 2, 5 to 1, 1 to 1)

    @Test
    fun testBasicMoves() {
        val dice = Dice(1, 4)
        val gameState = createGameState(player1Fields1, player2Fields1, 1, dice)
        // player1 move sequences:
        val goodMoveSeq = listOf(
            listOf(Move(4, 5), Move(5, 9)),
            listOf(Move(2, 3), Move(3, 7)),
            listOf(Move(2, 3), Move(4, 8)),
            listOf(Move(4, 8), Move(8, 9)),
            listOf(Move(4, 8), Move(2, 3)),
        )
        val sequences = gameState.possibleMoveSequences()
        assertEquals(goodMoveSeq.size, sequences.size, "Number of move sequences should be ${goodMoveSeq.size}")
        assertEquals(goodMoveSeq.toSet(), sequences.toSet(), "Move sequences should be equal")
        assertEquals(setOf(2, 4), gameState.moveableFields().toSet(), "Moveable fields")
        assertEquals(createGameState(player1Fields1, player2Fields1, 1, dice), gameState, "GameState should be the same")

        // player1 hits field 5
        // |2| | | |1| |
        // |2|1| | |1|2|
        //gameState.checkField(25, 0, 0)
        gameState.makeMove(Move(4, 5))
        assertEquals(listOf(4), gameState.numbersLeft, "Remaining numbers")
        val goodMoveSeq2 = listOf(listOf(Move(5, 9)))
        val sequences2 = gameState.possibleMoveSequences()
        assertEquals(goodMoveSeq2.size, sequences2.size, "Number of move sequences should be ${goodMoveSeq2.size}")
        assertEquals(goodMoveSeq2.toSet(), sequences2.toSet(), "Move sequences should be equal")
        assertEquals(setOf(5), gameState.moveableFields().toSet(), "Moveable fields")
        gameState.checkField(25, 2, 1)

        // final move: 5-->9
        gameState.makeMove(Move(5, 9))
        val sequences3 = gameState.possibleMoveSequences()
        assertEquals(0, sequences3.size, "No sequences should be left")
        assertFalse(gameState.anyMovesPossible(), "No moves should be possible")
    }


    @Test
    fun testHitPiece() {
        val dice = Dice(1, 2)
        val gameState = createGameState(player1Fields1, player2Fields1, 2, dice)

        // player2 moves 5-->4 hitting on field 4
        gameState.makeMove(Move(5, 4))
        gameState.checkField(0, 1, 1)

        // player1 rolls 6, no moves should be legal
        gameState.nextTurn()
        gameState.setDice(Dice(6, 6))
        gameState.checkBadMoves(listOf(Move(0, 6), Move(0, 4), Move(1, 7), Move(2, 8)))
        assertFalse(gameState.anyMovesPossible(), "No moves should exist")

        // set different dice, moves should exist, but only from the bar first
        gameState.setDice(Dice(1, 3))
        gameState.checkBadMoves(listOf(Move(2, 3), Move(4, 5), Move(4, 7), Move(0, 5)))
        gameState.checkGoodMoves(listOf(Move(0, 1), Move(0, 4), Move(0, 3)))

        // player1 moves 0-->1-->4, hitting two pieces
        gameState.makeMove(Move(0, 4))
        gameState.checkField(0, 0,0)
        gameState.checkField(4, 1, 1)
        gameState.checkField(25, 2, 2)

        // player2 has to move the 2 checkers off the bar
        gameState.nextTurn()
        gameState.setDice(Dice(5, 6))
        val goodMoveSeq = listOf(
            listOf(Move(25, 20), Move(25, 19)),
            listOf(Move(25, 19), Move(25, 20))
        )
        val sequences = gameState.possibleMoveSequences()
        assertEquals(goodMoveSeq.toSet(), sequences.toSet(), "Move sequences should be equal")
        gameState.makeMove(Move(25, 20))
        assertEquals(setOf(25), gameState.moveableFields().toSet(), "Only the bar should be playable")
        gameState.checkGoodMoves(listOf(Move(25, 19)))
        gameState.checkBadMoves(listOf(Move(20, 14), Move(25, 20)))
        gameState.makeMove(Move(25, 19))
        assertFalse(gameState.anyMovesPossible(), "No moves left")
    }

    /* fields 19-24:
    |1| | | |1| |
    |1|1|1| |1|2|
       fields 6-1:
    | | | | |2| |
    | |2| | |2|2|
     */
    val player1fields2 = mapOf(19 to 2, 20 to 1, 21 to 1, 23 to 2)
    val player2fields2 = mapOf(24 to 1, 5 to 1, 2 to 2, 1 to 1)

    @Test
    fun testBearOff() {
        val dice = Dice(3, 4)
        val gameState = createGameState(player1fields2, player2fields2, 1, dice)
        gameState.checkGoodMoves(listOf(Move(19, 22), Move(20, 24), Move(20, 23), Move(21, -1), Move(21, 24)))
        gameState.checkBadMoves(listOf(Move(19, 24), Move(19, -1), Move(20, -1), Move(23, -1), Move(21, 25)))
        gameState.makeMove(Move(21, -1))
        /* fields 19-24:
        |1| | | |1| |
        |1|1| | |1|2|
        */
        // player1 cannot bear off with number 3 yet, as no checkers are on field 22
        gameState.checkGoodMoves(listOf(Move(19, 22), Move(20, 23)))
        gameState.checkBadMoves(listOf(Move(23, -1), Move(20, -1)))
        gameState.makeMove(Move(20, 23))
        assertFalse(gameState.anyMovesPossible(), "No moves should be possible")

        // player 2 cannot bear off before moving from field 24 to the home row
        // but rolling (6, 6) allows to bear off from 24 in 4 moves (the only move sequence possible)
        gameState.nextTurn()
        gameState.setDice(Dice(6, 6))
        gameState.checkBadMoves(listOf(Move(5, -1), Move(1, -1)))
        gameState.checkGoodMoves(listOf(Move(24, 18), Move(24, 12), Move(24, 6), Move(24, -1)))
        assertEquals(1, gameState.possibleMoveSequences().size, "Only one move sequence should exist")
        gameState.makeMove(Move(24, -1))

        /* fields 19-24:
        | | | | |1| |
        |1| | | |1| |
        |1| | | |1| |
           fields 6-1:
        | | | | |2| |
        | |2| | |2|2|
         */
        // player1 can bear off and move 5 with the other checker on field 19
        gameState.nextTurn()
        gameState.setDice(Dice(6, 5))
        gameState.checkGoodMoves(listOf(Move(19, -1), Move(19, 24)))
        gameState.makeMove(Move(19, -1))
        gameState.checkGoodMoves(listOf(Move(19, 24)))
        gameState.checkBadMoves(listOf(Move(23, -1)))

        // player2 rolls (6,6) again, and can bear off everything
        gameState.nextTurn()
        gameState.setDice(Dice(6, 6))
        // there is only one move sequence
        val sequence = listOf(Move(5, -1), Move(2, -1), Move(2, -1), Move(1, -1))
        val sequences = gameState.possibleMoveSequences()
        assertEquals(listOf(sequence), sequences, "Only one move sequence should be possible")
        for (move in sequence) {
            assertTrue(gameState.isMovePossible(move))
            assertEquals(Result.RUNNING, gameState.roundResult(), "Game should be running")
            gameState.makeMove(move)
        }
        assertEquals(Result.PLAYER2_WON, gameState.roundResult(), "Player2 should have won")
    }

    /* fields 19-24:
    |1|1|1|1|1|1|
    |1|1|1|1|1|1|
       fields 6-1:
    | | | | |2| |
    | |2| | |2|2|
    + 1 checker on the bar for player2
    */
    val player1Fields3 = (19..24).associateWith { 2 }
    val player2Fields3 = mapOf(5 to 1, 2 to 2, 1 to 1, 25 to 1)

    @Test
    fun testBar() {
        val dice = Dice(1, 6)
        val gameState = createGameState(player1Fields3, player2Fields3, 2, dice)
        // player2 cannot move from the bar ==> no moves
        assertFalse(gameState.anyMovesPossible(), "Moves should NOT exist")

        // player1 rolls (3, 3)
        gameState.nextTurn()
        gameState.setDice(Dice(3, 3))
        val moves = listOf(Move(19, 22), Move(22, -1), Move(22, -1), Move(21, 24))
        for (move in moves) {
            assertTrue(gameState.isMovePossible(move), "Move $move should be possible")
            gameState.makeMove(move)
        }

        /* fields 19-24:
        | | | | | |1|
        | |1| | |1|1|
        |1|1|1|1|1|1|
         */

        // player2 rolls (4, 4) and comes off the bar
        gameState.nextTurn()
        gameState.setDice(Dice(4, 4))
        gameState.checkBadMoves(listOf(Move(5, 1), Move(2, -1)))
        gameState.checkGoodMoves(listOf(Move(25, 21), Move(25, 9)))
        // quadruple move
        gameState.makeMove(Move(25, 9))
        assertFalse(gameState.anyMovesPossible(), "Moves should not exist")


        // field 21 was hit on, player1 has to move from the bar
        gameState.nextTurn()
        gameState.setDice(Dice(1, 2))
        gameState.checkBadMoves(listOf(Move(0, 2), Move(24, -1), Move(23, -1), Move(22, 24)))
        gameState.checkGoodMoves(listOf(Move(0, 1), Move(0, 3)))
        gameState.makeMove(Move(0, 3))

        /* fields 19-24:
        | | | | | |1|
        | |1| | |1|1|
        |1|1| |1|1|1|
           fields 6-1:
        | | | | |2| |
        | |2| |1|2| |
        */

        // now player2 has a checker on the bar
        gameState.nextTurn()
        gameState.setDice(Dice(5, 5))
        assertFalse(gameState.anyMovesPossible(), "No moves should exist")

        // player1 cannot bear off yet because of the checker on field 3
        gameState.nextTurn()
        gameState.setDice(Dice(1, 2))
        gameState.checkGoodMoves(listOf(Move(3, 4), Move(3, 5), Move(3, 6), Move(22, 23)))
        gameState.checkBadMoves(listOf(Move(24, -1), Move(23, -1), Move(22, -1)))
    }

    /*
    fields 6-1:
    |2| | | |1| |
    |2|2| | |1|1|
    + 3 checkers on the bar for player1
    */
    val player1Fields4 = mapOf(0 to 3, 1 to 1, 2 to 2)
    val player2Fields4 = mapOf(6 to 2, 5 to 1)
    @Test
    fun testBar2() {
        val dice = Dice(5, 6)
        val gameState = createGameState(player1Fields4, player2Fields4, 1, dice)
        // there should be one move, moving a piece from the bar to field 5
        val moveSeq = gameState.possibleMoveSequences()
        assertEquals(listOf(listOf(Move(0, 5))), moveSeq, "Only one move should exist")
    }

}

class TestUndo {

    @Test
    fun testUndoMove() {
        val gameState = initialGameState(1)
        gameState.setDice(Dice(1, 2))
        val savedState = gameState.deepcopy()
        gameState.makeMove(Move(1, 2))
        val savedState2 = gameState.deepcopy()
        gameState.makeMove(Move(1, 3))
        gameState.undoLastMove()
        gameState.undoLastMove()
        assertEquals(savedState, gameState, "States should be equal")

        gameState.setDice(Dice(1, 3))
        gameState.makeMove(Move(1, 2))
        assertNotEquals(savedState2, gameState, "States should not be equal")
        gameState.makeMove(Move(1, 4))
        val stateAfterFirstRound = gameState.deepcopy()


        // player2 moves too
        gameState.nextTurn()
        gameState.setDice(Dice(5, 6))
        val stateAtSecondRound = gameState.deepcopy()
        gameState.makeMove(Move(24, 13))
        // undo the compound move
        gameState.undoLastMove()
        assertEquals(stateAtSecondRound, gameState, "States should be equal #2")
        gameState.makeMove(Move(24, 18))
        gameState.makeMove(Move(18, 13))
        // undo the turn
        gameState.undoLastTurn()
        assertEquals(stateAfterFirstRound, gameState, "States should be equal #3")

    }

    @Test
    fun testUndoTurns() {
        val gameState = initialGameState(1)
        val allDice = listOf(
            Dice(1, 2),
            Dice(4, 5),
            Dice(6, 6),
            Dice(4, 5),
            Dice(1, 1),
        )
        val allMoves = listOf(
            listOf(Move(1, 2), Move(1, 3)),
            listOf(Move(6, 1), Move(6, 2)),
            listOf(),
            listOf(Move(13, 9), Move(13, 8)),
            listOf(Move(0, 3), Move(3, 4)),
        )

        val states = mutableListOf<GameState>()

        for ((dice, moves) in allDice.zip(allMoves)) {
            gameState.setDice(dice)
            for (move in moves) {
                assertTrue(gameState.isMovePossible(move), "Move $move should be possible")
                gameState.makeMove(move)
            }
            assertFalse(gameState.anyMovesPossible(), "No moves should exist")
            // clear unusable numbers, as these aren't saved when we go to the next turn
            gameState.numbersLeft.clear()
            states.add(gameState.deepcopy())
            gameState.nextTurn()
        }

        for (state in states.reversed()) {
            gameState.undoLastTurn()
            assertEquals(state, gameState)
        }

    }
}