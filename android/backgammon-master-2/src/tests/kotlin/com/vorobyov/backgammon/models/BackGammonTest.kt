package com.vorobyov.backgammon.models

import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.RepeatedTest
import org.junit.jupiter.api.Test
import kotlin.math.abs
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class BackGammonTest {

    lateinit var backgammon: Backgammon


    @Test
    fun testSetup() {
        val backgammon = Backgammon(object : IPlayersTest {})
        backgammon.listener = object : ActionListenerTest {}

        val privatePointsField = Backgammon::class.java.getDeclaredField("points")
        privatePointsField.isAccessible = true

        val points: Array<Point> = privatePointsField.get(backgammon) as Array<Point>

        backgammon.setupBoard()

        for (point in points) {
            when (point.pos) {
                0 -> {
                    assertEquals(Checker.Colors.BLACK, point.checkersColor)
                    assertEquals(2, point.checkersCount)
                }
                5 -> {
                    assertEquals(Checker.Colors.WHITE, point.checkersColor)
                    assertEquals(5, point.checkersCount)
                }
                7 -> {
                    assertEquals(Checker.Colors.WHITE, point.checkersColor)
                    assertEquals(3, point.checkersCount)
                }
                11 -> {
                    assertEquals(Checker.Colors.BLACK, point.checkersColor)
                    assertEquals(5, point.checkersCount)
                }

                12 -> {
                    assertEquals(Checker.Colors.WHITE, point.checkersColor)
                    assertEquals(5, point.checkersCount)
                }
                16 -> {
                    assertEquals(Checker.Colors.BLACK, point.checkersColor)
                    assertEquals(3, point.checkersCount)
                }
                18 -> {
                    assertEquals(Checker.Colors.BLACK, point.checkersColor)
                    assertEquals(5, point.checkersCount)
                }
                23 -> {
                    assertEquals(Checker.Colors.WHITE, point.checkersColor)
                    assertEquals(2, point.checkersCount)
                }
            }
        }
    }

    @RepeatedTest(100)
    fun testInitial() {

        var first = 0
        var second = 0

        var askReRoll = true

        backgammon = Backgammon(object : IPlayers {
            override fun askInitialRollDie(player: Checker.Colors) {
                if (player == Checker.Colors.WHITE) assertTrue(askReRoll)
                backgammon.onInitialRolledDie(player)
            }

            override fun askRollDies(player: Checker.Colors) {
                assertFalse(askReRoll)
                backgammon.onRolledDies(player)
            }

            override fun askBearingOff(player: Checker.Colors, point: Int) = Unit
        })

        backgammon.listener = object : ActionListenerTest {
            override fun onInitialDieRolled(player: Checker.Colors, amount: Int) {
                if (player == Checker.Colors.WHITE) first = amount else {
                    second = amount

                    askReRoll = first == second
                }
            }

            override fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>) {
                assertEquals(if (first > second) Checker.Colors.WHITE else Checker.Colors.BLACK, player)
            }
        }

        backgammon.setupBoard()

    }

    @RepeatedTest(100)
    fun testFinish() {
        var won = false

        val point = (0..5).random()

        backgammon = Backgammon(object : IPlayers {
            override fun askInitialRollDie(player: Checker.Colors) {
                backgammon.onInitialRolledDie(player)
            }

            override fun askRollDies(player: Checker.Colors) {
                backgammon.onRolledDies(player)
            }

            override fun askBearingOff(player: Checker.Colors, point: Int) {
                backgammon.onBearingOffAccepted(player, point)
            }
        })

        backgammon.listener = object : ActionListenerTest {
            override fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>) {
                assumeTrue(dies.first == point + 1 || dies.second == point + 1)
                assumeTrue(player == Checker.Colors.WHITE)
            }

            override fun onWin(player: Checker.Colors) {
                won = true
            }
        }

        backgammon.setupBoard()

        val privatePointsField = Backgammon::class.java.getDeclaredField("points")
        privatePointsField.isAccessible = true

        val points: Array<Point> = privatePointsField.get(backgammon) as Array<Point>

        for (point in points) {
            point.clear()
        }

        points[point].addChecker(Checker(Checker.Colors.WHITE))

        backgammon.onPointSelected(point)

        assertTrue(won)
    }

    @RepeatedTest(100)
    fun testBar() {

        val white = (0..23).random()
        val black: Int
        var random: Int
        do {
            random = (0..23).random()
        } while (random == white)

        black = random

        assumeTrue(Checker.Colors.WHITE.steps(white, black) <= 12)

        backgammon = Backgammon(object : IPlayersTest {
            override fun askInitialRollDie(player: Checker.Colors) {
                backgammon.onInitialRolledDie(player)
            }

            override fun askRollDies(player: Checker.Colors) {
                backgammon.onRolledDies(player)
            }

        })

        backgammon.listener = object : ActionListenerTest {
//            override fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>) {
//                assumeTrue(dies.first == point + 1 || dies.second == point + 1)
//                assumeTrue(player == Checker.Colors.WHITE)
//            }

            override fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>) {
                assumeTrue(player == Checker.Colors.WHITE)
                println("rolled")
            }

            override fun onAvailablePointsReceived(player: Checker.Colors, points: List<Int>, forPoint: Int) {
                println("received")
                backgammon.onSelectedPointClicked(black)
            }

            override fun onCheckerMoved(from: Int, to: Int, checker: Checker) {
                println("moved: ${from} - ${to}")
            }
        }

        backgammon.setupBoard()

        val privatePointsField = Backgammon::class.java.getDeclaredField("points")
        privatePointsField.isAccessible = true

        val points: Array<Point> = privatePointsField.get(backgammon) as Array<Point>

        val privateBarField = Backgammon::class.java.getDeclaredField("bar")
        privateBarField.isAccessible = true

        val bar: List<Checker> = privateBarField.get(backgammon) as List<Checker>

        for (point in points) {
            point.clear()
        }

        points[white].addChecker(Checker(Checker.Colors.WHITE))
        points[black].addChecker(Checker(Checker.Colors.BLACK))

        backgammon.onPointSelected(white)

        assertEquals(1, bar.size)
        assertTrue(bar.contains(Checker(Checker.Colors.WHITE)))
    }


    interface IPlayersTest : IPlayers {
        override fun askInitialRollDie(player: Checker.Colors) = Unit

        override fun askRollDies(player: Checker.Colors) = Unit

        override fun askBearingOff(player: Checker.Colors, point: Int) = Unit
    }

    interface ActionListenerTest : ActionListener {
        override fun onCheckerAdded(point: Int, checker: Checker, checkersAtPoint: Int) = Unit

        override fun onCheckerMoved(from: Int, to: Int, checker: Checker) = Unit

        override fun onInitialDieRolled(player: Checker.Colors, amount: Int) = Unit

        override fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>) = Unit

        override fun onInviteSelectPoint(player: Checker.Colors) = Unit

        override fun onAvailablePointsReceived(player: Checker.Colors, points: List<Int>, forPoint: Int) = Unit

        override fun clearPointsHighlighting() = Unit

        override fun onInviteSelectedPointClick(player: Checker.Colors) = Unit

        override fun onSkipMove(player: Checker.Colors) = Unit

        override fun onBarPut(point: Int, color: Checker.Colors) = Unit

        override fun onMoveFromBar(player: Checker.Colors) = Unit

        override fun onAvailablePointsForBarReceived(player: Checker.Colors, points: List<Int>) = Unit

        override fun onCheckerMovedFromBar(player: Checker.Colors, point: Int) = Unit

        override fun onCheckerBearingOff(player: Checker.Colors, point: Int) = Unit

        override fun onWin(player: Checker.Colors) = Unit
    }

    private fun Checker.Colors.steps(from: Int, to: Int): Int {
        val diff = to - from
        return if (this == Checker.Colors.WHITE) {
            if (diff > 0) 24 - diff else abs(diff)
        } else {
            if (diff < 0) 24 + diff else diff
        }
    }
}