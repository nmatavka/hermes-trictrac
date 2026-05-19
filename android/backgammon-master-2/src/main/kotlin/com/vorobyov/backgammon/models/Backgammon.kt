package com.vorobyov.backgammon.models

import com.vorobyov.backgammon.models.Backgammon.States.Companion.next
import com.vorobyov.backgammon.models.Checker.Colors.BLACK
import com.vorobyov.backgammon.models.Checker.Colors.WHITE
import kotlin.math.abs

class Backgammon(val players: IPlayers) {

    enum class States {
        SETUP,
        INITIAL_ROLL_DIE_FIRST, INITIAL_ROLL_DIE_SECOND,
        ROLL_DIE_FIRST, CHECK_BAR_FIRST, MOVE_FROM_BAR_FIRST, CHECK_AVAILABLE_MOVES_FIRST, CHECK_BEARING_OFF_FIRST, SELECT_POINT_FIRST, MOVE_FIRST,
        ROLL_DIE_SECOND, CHECK_BAR_SECOND, MOVE_FROM_BAR_SECOND, CHECK_AVAILABLE_MOVES_SECOND, CHECK_BEARING_OFF_SECOND, SELECT_POINT_SECOND, MOVE_SECOND;

        companion object {
            fun States.next(): States =
                if (this == MOVE_SECOND) ROLL_DIE_FIRST else values()[values().indexOf(this) + 1]
        }
    }

    var state: States = States.INITIAL_ROLL_DIE_FIRST
    private set

    private val points = Array(24) { pos -> Point(pos) }
    private val dies = arrayOf(Die(), Die())

    private val bar = mutableListOf<Checker>()

    private var pt = (0..5).random()

    var listener: ActionListener? = null

    private var movesCount = 0

    fun nextAction() {
        when (state) {
            States.SETUP -> {
                setupBoard()
                state = state.next()
            }

            States.INITIAL_ROLL_DIE_FIRST -> {
                players.askInitialRollDie(WHITE)
            }

            States.INITIAL_ROLL_DIE_SECOND -> {
                players.askInitialRollDie(BLACK)
            }


            States.ROLL_DIE_FIRST -> {
                players.askRollDies(WHITE)
            }

            States.CHECK_BAR_FIRST -> {
                checkBar(WHITE)
            }

            States.CHECK_AVAILABLE_MOVES_FIRST -> {
                checkAvailableMovesFor(WHITE)
            }

            States.SELECT_POINT_FIRST -> {
                listener?.onInviteSelectPoint(WHITE)
            }

//            States.CHECK_BEARING_OFF_FIRST -> {
//                checkBearingOff(WHITE)
//            }

//            States.MOVE_FIRST -> {
//            }

            States.ROLL_DIE_SECOND -> {
                players.askRollDies(BLACK)
            }

            States.CHECK_BAR_SECOND -> {
                checkBar(BLACK)
            }

            States.CHECK_AVAILABLE_MOVES_SECOND -> {
                checkAvailableMovesFor(BLACK)
            }

            States.SELECT_POINT_SECOND -> {
                listener?.onInviteSelectPoint(BLACK)
            }

//            States.CHECK_BEARING_OFF_SECOND -> {
//                checkBearingOff(BLACK)
//            }

//            States.MOVE_SECOND -> {
//            }
        }
    }

    fun setupBoard() {
        for (point in points) {
            point.clear()
        }

        // whites home
        for (i in 1..2) {
            Checker(BLACK).addTo(0)
        }
        for (i in 1..5) {
            Checker(WHITE).addTo(5)
        }

        // whites outer
        for (i in 1..3) {
            Checker(WHITE).addTo(7)
        }
        // whites outer
        for (i in 1..5) {
            Checker(BLACK).addTo(11)
        }

        // blacks outer
        for (i in 1..5) {
            Checker(WHITE).addTo(12)
        }
        for (i in 1..3) {
           Checker(BLACK).addTo(16)
        }

        // whites home
        for (i in 1..5) {
            Checker(BLACK).addTo(18)
        }
        for (i in 1..2) {
            Checker(WHITE).addTo(23)
        }

        nextAction()
    }

    private fun hasAvailableMovesFor(player: Checker.Colors): Boolean {
        for (point in points) {
            for (die in dies) {
                if (player.isStepPossible(point.pos, die.amount))
                    return true
            }
        }
        return false
    }

    private fun checkAvailableMovesFor(player: Checker.Colors) {
        if (!hasAvailableMovesFor(player)) {
            listener?.onSkipMove(player)
            when (player) {
                WHITE -> {
                    state = States.ROLL_DIE_SECOND
                }
                BLACK -> {
                    state = States.ROLL_DIE_FIRST
                }
            }
        } else {
            state = state.next()
        }

        nextAction()
    }

    fun onInitialRolledDie(player: Checker.Colors) {
        if (player == WHITE && state != States.INITIAL_ROLL_DIE_FIRST || player == BLACK && state != States.INITIAL_ROLL_DIE_SECOND)
            return

        when (player) {
            WHITE -> {
                listener?.onInitialDieRolled(player, dies[0].roll())
                state = state.next()
                nextAction()
            }

            BLACK -> {
                listener?.onInitialDieRolled(player, dies[1].roll())

                state = if (dies[0].amount == dies[1].amount)
                    States.INITIAL_ROLL_DIE_FIRST
                else
                    if (dies[0].amount > dies[1].amount) States.ROLL_DIE_FIRST else States.ROLL_DIE_SECOND

                nextAction()
            }
        }
    }

    fun onRolledDies(player: Checker.Colors) {
        if (player == WHITE && state != States.ROLL_DIE_FIRST || player == BLACK && state != States.ROLL_DIE_SECOND)
            return

        // set count of moves. 4 for equal dias and 2 for other
        listener?.onDiesRolled(player, dies[0].roll() to dies[1].roll())
        movesCount = if (dies[0].amount == dies[1].amount) 4 else 2
        state = state.next()
        nextAction()
    }


    fun Checker.Colors.mayBeBearingOff(point: Int): Boolean {

        fun Checker.Colors.hasCheckersOnThatOrGreater(point: Int): Boolean {
            when (this) {
                WHITE -> for (i in point..5) if (points[i].hasChecker(this)) return true
                BLACK -> for (i in 23 downTo 18) if (points[i].hasChecker(this)) return true
            }
            return false
        }


        fun diesGreaterThan(value: Int): Boolean {
            return dies[0].amount > value && dies[1].amount > value
        }

        return diesGreaterThan(point) && !hasCheckersOnThatOrGreater(point) ||
        !points[point].isFree() && (dies[0].amount - 1 == points[point].boardPosition || dies[1].amount - 1 == points[point].boardPosition) && this == points[point].checkersColor
    }

    var selectedPoint: Point? = null
    fun onPointSelected(point: Int) {

        val player = if (state == States.SELECT_POINT_FIRST || state == States.MOVE_FIRST || state == States.CHECK_BEARING_OFF_FIRST) WHITE else BLACK

        // bearing off request
        if ((state == States.CHECK_BEARING_OFF_FIRST || state == States.CHECK_BEARING_OFF_SECOND) && !points[point].isFree())  {
            if (player.mayBeBearingOff(point) && player.allCheckersInHome()
            ) {
                players.askBearingOff(player, point)

                return

            } else {
                state = when (player) {
                    WHITE -> States.SELECT_POINT_FIRST
                    BLACK -> States.SELECT_POINT_SECOND
                }
            }
        }

        // перевыделить треугольники
        if ((state == States.MOVE_FIRST || state == States.MOVE_SECOND) && selectedPoint != null &&
            !points[point].isFree() && selectedPoint!!.checkersColor == player && points[point].checkersColor == player
        ) {

            val diff = selectedPoint!!.pos - point
            val steps = if (player == WHITE) {
                if (diff < 0) 24 - diff else diff
            } else {
                if (diff < 0) diff else 24 - diff
            }

            if (!(steps == dies[0].amount || steps == dies[1].amount || steps == dies[0].amount + dies[1].amount)) {

                listener?.clearPointsHighlighting()
                selectedPoint = null
                state = if (player == WHITE) States.CHECK_BEARING_OFF_FIRST else States.CHECK_BEARING_OFF_SECOND
            }
        }


        // выделить треугольники
        if (state == States.SELECT_POINT_FIRST || state == States.SELECT_POINT_SECOND) {

            if (points[point].isFree() || points[point].checkersColor != player)
                return


            selectedPoint = points[point]

            val possibleMoves = player.possibleMovesFor(point)

            if (possibleMoves.isNotEmpty()) {

                listener?.onAvailablePointsReceived(player, possibleMoves, point)

                listener?.onInviteSelectedPointClick(player)
                state = state.next()

                nextAction()
            } else if (!player.areTherePossibleMoves()) {
                listener?.onSkipMove(player)

                state = when (player) {
                    WHITE -> States.ROLL_DIE_SECOND
                    BLACK -> States.ROLL_DIE_FIRST
                }

                nextAction()

            }

        }
    }


    private fun Checker.Colors.possibleMovesFor(point: Int): List<Int> {
        val possibleMoves = mutableListOf<Int>()

        if (!dies[0].hidden && !dies[1].hidden &&
            dies[0].amount == dies[1].amount
        ) {
            for (i in 1..movesCount) {
                val steps = dies[0].amount * i
                // каждый более дальний ход можно сделать, если можно ходить на более ближние позиции
                if (!isStepPossible(point, steps))
                    break

                possibleMoves.add(posBySteps(point, steps))
            }
        } else {

            for (die in dies) {
                if (die.hidden)
                    continue

                if (isStepPossible(point, die.amount))
                    possibleMoves.add(posBySteps(point, die.amount))
            }

            val sumStep = dies.sumOf { die -> die.amount }
            // каждый более дальний ход можно сделать, если можно ходить на более ближние позиции
            if (possibleMoves.isNotEmpty() && isStepPossible(point, sumStep))
                possibleMoves.add(posBySteps(point, sumStep))
        }

        return possibleMoves
    }

    fun primitiveSteps(stepsSum: Int): List<Int> {
        val primitiveSteps = mutableListOf<Int>()
        var steps = stepsSum

        if (stepsSum !in dies.map { it.amount }) {
            while (steps > 0) {
                for (die in dies) {
                    if (steps >= die.amount) {
                        steps -= die.amount
                        primitiveSteps.add(die.amount)
                    }
                }
            }
        } else {
            primitiveSteps.add(stepsSum)
        }
        return primitiveSteps
    }

    /*
                    BLACKS
                    5 -> 10  (10 - 5) 5    | 5
                    20 -> 3  (3 - 20) -17  | 7

                    ------
                    WHITES
                    10 -> 5 (5 - 10) -5    | 5
                    3 -> 20 (20 - 3) 17    | 7

             */
    fun onSelectedPointClicked(point: Int) {
        fun firstMove(): Boolean = (dies.filter { it.amount != 0 }.size == 2)

        println("State: ${state}")
        // move from bar
        if (state == States.MOVE_FROM_BAR_FIRST || state == States.MOVE_FROM_BAR_SECOND) {
            val player = if (state == States.MOVE_FROM_BAR_FIRST) WHITE else BLACK

            val possibleMoves = player.possibleMovesForBar()

            if (point !in possibleMoves)
                return


            if (points[point].isBlotFor(player)) {
                bar.add(points[point].popFirst())
                listener?.onBarPut(point, bar.last().color)
            }

            movesCount -= 1
            moveCheckerFromBar(points[point], player)

            listener?.clearPointsHighlighting()

            if (firstMove()) {
                val dieAmount = player.dieAmountByPoint(point)
                dies.find { it.amount == dieAmount }!!.hide()

                when (player) {
                    WHITE -> state = States.CHECK_BAR_FIRST
                    BLACK -> state = States.CHECK_BAR_SECOND
                }
            } else {
                when (player) {
                    WHITE -> state = States.ROLL_DIE_SECOND
                    BLACK -> state = States.ROLL_DIE_FIRST
                }
            }

            nextAction()
            return
        }


        // just move

        require(selectedPoint != null)

        val player = when (state) {
            States.MOVE_FIRST -> WHITE
            States.MOVE_SECOND -> BLACK
            else -> return
        }

        val possibleMoves = player.possibleMovesFor(selectedPoint!!.pos)

        if (point !in possibleMoves)
            return


        val primitiveSteps = primitiveSteps(player.steps(selectedPoint!!.pos, point))


        if (points[point].isBlotFor(player)) {
            bar.add(points[point].popFirst())
            listener?.onBarPut(point, bar.last().color)
        }


        selectedPoint!!.moveChecker(points[point])
        movesCount -= primitiveSteps.size
        listener?.clearPointsHighlighting()


        when (movesCount) {
            3, 2 -> {
                when (player) {
                    WHITE -> state = States.CHECK_AVAILABLE_MOVES_FIRST
                    BLACK -> state = States.CHECK_AVAILABLE_MOVES_SECOND
                }
            }
            1 -> {

                for (step in primitiveSteps.toSet()) {
                    dies.find { it.amount == step }?.hide()
                }

                when (player) {
                    WHITE -> state = States.CHECK_AVAILABLE_MOVES_FIRST
                    BLACK -> state = States.CHECK_AVAILABLE_MOVES_SECOND
                }
            }
            0 -> {
                for (step in primitiveSteps.toSet()) {
                    dies.find { it.amount == step }?.hide()
                }

                when (player) {
                    WHITE -> state = States.ROLL_DIE_SECOND
                    BLACK -> state = States.ROLL_DIE_FIRST
                }
            }
        }

        selectedPoint = null

        nextAction()
    }

    private fun moveCheckerFromBar(to: Point, color: Checker.Colors) {
        val checker = bar.find { it.color == color }!!
        points[to.pos].addChecker(checker)
        bar.remove(checker)

        listener?.onCheckerMovedFromBar(color, to.pos)

    }

    private fun Point.moveChecker(to: Point) {
        points[to.pos].addChecker(points[pos].popChecker())

        listener?.onCheckerMoved(pos, to.pos, to.getLastChecker())

    }


    fun clearPointSelection() {
        listener?.clearPointsHighlighting()
        selectedPoint = null
        when (state) {
            States.MOVE_FIRST -> state = States.CHECK_BEARING_OFF_FIRST
            States.MOVE_SECOND -> state = States.CHECK_BEARING_OFF_SECOND
        }

        nextAction()
    }


    private fun Checker.Colors.pointByDieAmount(amount: Int): Int = if (this == WHITE) 24 - amount else amount - 1

    private fun Checker.Colors.dieAmountByPoint(point: Int): Int = if (this == WHITE) 24 - point else point + 1


    // whites -> (18 - 23)  | 23 - x
    // blacks -> 0 - 5  | x - 1
    private fun Checker.Colors.possibleMovesForBar(): List<Int> {
        val possibleMoves = mutableListOf<Int>()

        for (die in dies) {
            if (die.hidden)
                continue

            val point = pointByDieAmount(die.amount)

            if (points[point].isFreeFor(this)) {
                possibleMoves.add(point)
            }
        }
        return possibleMoves
    }

    private fun checkBar(whose: Checker.Colors) {
        if (bar.count { it.color == whose } == 0) {
            state = when (whose) {
                WHITE -> States.CHECK_AVAILABLE_MOVES_FIRST
                BLACK -> States.CHECK_AVAILABLE_MOVES_SECOND
            }
            nextAction()
        } else {
            if (bar.filter { it.color == whose }.isNotEmpty()) {
                val possibleMoves = whose.possibleMovesForBar()
                if (possibleMoves.isEmpty()) {
                    listener?.onSkipMove(whose)

                    state = when (whose) {
                        WHITE -> States.ROLL_DIE_SECOND
                        BLACK -> States.ROLL_DIE_FIRST
                    }

                    nextAction()
                } else {
                    listener?.onMoveFromBar(whose)
                    listener?.onAvailablePointsForBarReceived(whose, possibleMoves)

                    state = when (whose) {
                        WHITE -> States.MOVE_FROM_BAR_FIRST
                        BLACK -> States.MOVE_FROM_BAR_SECOND
                    }
                }
            }
        }
    }


    fun onBearingOffAccepted(player: Checker.Colors, point: Int) {

        listener?.onCheckerBearingOff(player, point)

        dies.find { it.amount - 1 == points[point].boardPosition }?.hide()
        points[point].popChecker()
        movesCount--

        if (movesCount > 0) {
            state = when (player) {
                WHITE -> States.CHECK_BEARING_OFF_FIRST
                BLACK -> States.CHECK_BEARING_OFF_SECOND
            }
        } else {
            state = when (player) {
                WHITE -> States.ROLL_DIE_SECOND
                BLACK -> States.ROLL_DIE_FIRST
            }
            nextAction()
        }

        if (!player.hasCheckers())
            listener?.onWin(player)

    }

    fun onBearingOffReject(player: Checker.Colors, point: Int) {
        state = when (points[point].checkersColor) {
            WHITE -> States.SELECT_POINT_FIRST
            BLACK -> States.SELECT_POINT_SECOND
        }

        onPointSelected(point)
    }

    private fun Checker.Colors.allCheckersInHome() : Boolean {
        for (point in points) {
            if (!point.allInHome(this))
                return false
        }
        return true
    }


    private fun Checker.Colors.isStepPossible(fromPoint: Int, steps: Int): Boolean {
        return when (this) {
            WHITE -> points[(fromPoint - steps + 24) % 24].isFreeFor(this)
            BLACK -> points[(fromPoint + steps) % 24].isFreeFor(this)
        }
    }

    private fun Checker.Colors.steps(from: Int, to: Int): Int {
        val diff = to - from
        return if (this == WHITE) {
            if (diff > 0) 24 - diff else abs(diff)
        } else {
            if (diff < 0) 24 + diff else diff
        }
    }

    private fun Checker.Colors.posBySteps(from: Int, steps: Int): Int {
        val dif = from - steps
        val sum = from + steps

        return when (this) {
            WHITE -> if (dif < 0) 24 + dif else dif
            BLACK -> sum % 24
        }
    }


    private fun Checker.addTo(point: Int) {
        points[point].addChecker(this)

        listener?.onCheckerAdded(point, this, points[point].checkersCount)
    }

    private fun Checker.Colors.areTherePossibleMoves(): Boolean {
        for (point in points) {
            if (point.isFree() || point.checkersColor != this)
                continue

            if (possibleMovesFor(point.pos).isNotEmpty())
                return true;
        }
        return false
    }

    private fun Checker.Colors.hasCheckers(): Boolean {
        for (point in points)
            if (point.hasChecker(this))
                return true

        return false
    }




    // game field indices
    /*
                   blacks
        outer board     whites home
     13 14 15 16 17 18 19 20 21 22 23 24
                      |
     12 11 10  9  8  7  6  5  4  3  2  1
         outer board     whites home
                   whites
     */


}