package view

import ANIM_DURATION_DICE
import ANIM_DURATION_MOVE
import ANIM_FREQ_DICE
import ANIM_FREQ_MOVE
import ANIM_WAIT_AFTER_DICE
import Component
import IController
import Renderable
import kotlinx.browser.document
import kotlinx.browser.window
import kotlinx.dom.addClass
import kotlinx.dom.removeClass
import kotlinx.html.TagConsumer
import kotlinx.html.js.svg
import org.w3c.dom.HTMLElement
import org.w3c.dom.svg.SVGElement
import kotlin.math.abs
import kotlin.math.roundToInt
import kotlin.math.sign

class GameBoard(private val app: IController) : Component(), Renderable {

    val svgWidth = 1284
    val svgHeight = 700
    val borderWidth = 30
    val barWidth = 48
    val barAreaHeight = (svgHeight - 2 * borderWidth) * 2 / 3
    val triangleHeight = 280
    val triangleWidth = (svgWidth - 3 * barWidth) / 12
    val checkerBorder = 1
    val checkerRadius = triangleHeight / 10 - checkerBorder
    val dieSize = 56
    val dieGap = 6


    private val triangles: List<Triangle> = initTriangles()
    private val checkersAt = List<MutableList<Checker>>(26) { mutableListOf() }
    var dice: List<Die> = emptyList()
        set (value) {
            for (die in field) die.remove()
            field = value
        }
    private val bars = mutableListOf<SVGElement>()

    private fun initTriangles(): List<Triangle> {
        val l = mutableListOf<Triangle>()

        fun getTriangleX(i: Int): Int {
            var x = triangleWidth / 2 + (12 - i) * triangleWidth + barWidth
            if (i <= 6) x += barWidth
            return x
        }
        for (i in 1..12) {
            val x = getTriangleX(i)
            l.add(Triangle(Pair(x, svgHeight - borderWidth), -triangleHeight, triangleWidth, i % 2 == 0))
        }
        for (i in 13..24) {
            val x = getTriangleX(24 - i + 1)
            l.add(Triangle(Pair(x, borderWidth), triangleHeight, triangleWidth, i % 2 == 0))
        }
        return l
    }

    private fun calcCheckerPosition(field: Int, numCheckers: Int, checkerIdx: Int): Pair<Int, Int> {
        // the place for checkers spans from y1 to y2 along axis x
        var (x, y1, y2) = listOf(0, 0, 0)

        // on player1's bar
        if (field == 0) {
            x = svgWidth / 2
            y1 = svgHeight / 2 + checkerRadius
            y2 = svgHeight / 2 + barAreaHeight
        } else if (field == 25) { // on player2's bar
            x = svgWidth / 2
            y1 = svgHeight / 2 - checkerRadius
            y2 = svgHeight / 2 - barAreaHeight
        } else { // on triangles 1-24
            val t = triangles[field - 1]
            x = t.baseCenter.first
            y1 = t.baseCenter.second
            y2 = y1 + t.height
        }
        val sign = (y2 - y1).sign

        // if the checkers can be drawn completely
        if (abs(y2 - y1) >= numCheckers * checkerRadius * 2) {
            return Pair(x, y1 + sign * checkerRadius * (checkerIdx * 2 - 1))
        }

        // if not, divide them evenly, overlapping
        val step = ((abs(y2 - y1).toDouble() - 2 * checkerRadius) / (numCheckers - 1)).roundToInt()
        return Pair(x, y1 + sign * (checkerRadius + step * (checkerIdx - 1)))
    }

    private fun calcDiePosition(idx: Int, initialRoll: Boolean): Pair<Int, Int> {
        val y = svgHeight / 2
        val x1 = barWidth + (svgWidth - 3 * barWidth) / 4
        val x2 = svgWidth - x1
        if (initialRoll)
            return (if (idx == 1) Pair(x1, y) else Pair(x2, y))
        val x = if (idx <= 2) x1 else x2
        // odd dice are on the left from the center, even ones are on the right
        if (idx % 2 == 1) return Pair(x - (dieSize + dieGap) / 2, y)
        return Pair(x + (dieSize + dieGap) / 2, y)
    }

    fun setFieldCheckers(fields: List<Int>, fieldPlayerIdx: List<Int>) {
        for (field in checkersAt.indices) {
            val cnt = fields[field]
            checkersAt[field].clear()
            for (i in 1..cnt) {
                val center = calcCheckerPosition(field, cnt, i)
                val checker = Checker(center, checkerRadius, fieldPlayerIdx[field] == 1)
                checker.listener = {app.checkerClicked(field)}
                checkersAt[field].add(checker)
            }
        }
    }

    override fun render(tc: TagConsumer<HTMLElement>) {
        val board = tc.svg("board") {}
        board.setAttribute("style", "width:${svgWidth}px;height:${svgHeight}px")

        // render background first
        val backgr = document.createElementNS(SVG_NS, "rect") as SVGElement
        backgr.setAttribute("x", "0")
        backgr.setAttribute("y", "0")
        backgr.setAttribute("width", "$svgWidth")
        backgr.setAttribute("height", "$svgHeight")
        backgr.classList.add("background")
        backgr.onclick = {app.backgroundClicked()}
        board.appendChild(backgr)

        // inner background (in board)
        val ibackgr = document.createElementNS(SVG_NS, "rect") as SVGElement
        ibackgr.setAttribute("x", "$barWidth")
        ibackgr.setAttribute("y", "$borderWidth")
        ibackgr.setAttribute("width", "${svgWidth - 2 * barWidth}")
        ibackgr.setAttribute("height", "${svgHeight - 2 * borderWidth}")
        ibackgr.classList.add("board-background")
        ibackgr.onclick = {app.backgroundClicked()}
        board.appendChild(ibackgr)

        // render the bars
        val barX = listOf(0, (svgWidth - barWidth) / 2, svgWidth - barWidth)
        val barY = listOf(borderWidth, borderWidth - 1, borderWidth)
        val barWidth = List(3) {barWidth}
        val barHeight = MutableList(3) {svgHeight - 2 * borderWidth}
        barHeight[1] += 2 // white line rendering issue (one pixel overlap needed)

        bars.clear()
        for (i in 0..2) {
            val bar = document.createElementNS(SVG_NS, "rect") as SVGElement
            bar.setAttribute("x", barX[i].toString())
            bar.setAttribute("y", barY[i].toString())
            bar.setAttribute("width", barWidth[i].toString())
            bar.setAttribute("height", barHeight[i].toString())
            bar.classList.add("bar")
            board.appendChild(bar)
            if (i == 2) bar.onclick = {app.bearOffClicked()}
            else bar.onclick = {app.backgroundClicked()}
            bars.add(bar)
        }

        for (t in triangles) t.render(board)
        for ((i, t) in triangles.withIndex()) {
            t.listener = {app.fieldClicked(i + 1)}
        }
        for ((i, checkers) in checkersAt.withIndex()) {
            for (ch in checkers) {
                ch.render(board)
                ch.listener = {app.checkerClicked(i)}
            }
        }

        root = board
    }

    fun initialDiceRoll(result1: Int, result2: Int) {
        dice = listOf(
            Die(result1, calcDiePosition(1, true), dieSize),
            Die(result2, calcDiePosition(2, true), dieSize)
        )
        for (die in dice) {
            die.render(root!!)
            die.animateRolling(ANIM_DURATION_DICE, ANIM_FREQ_DICE)
        }
    }

    fun playerDiceRoll(result1: Int, result2: Int, playerIdx: Int, animated: Boolean = true) {
        val startingDiePos = if (playerIdx == 1) 1 else 3
        dice = listOf(
            Die(result1, calcDiePosition(startingDiePos, false), dieSize),
            Die(result2, calcDiePosition(startingDiePos + 1, false), dieSize)
        )
        for (die in dice) {
            die.render(root!!)
            if (animated) die.animateRolling(ANIM_DURATION_DICE, ANIM_FREQ_DICE)
        }
        window.setTimeout(app::animationFinished, ANIM_DURATION_DICE + ANIM_WAIT_AFTER_DICE)
    }

    fun moveChecker(fieldFrom: Int, fieldTo: Int) {
        val checker = checkersAt[fieldFrom].removeLast()
        checker.listener = {app.checkerClicked(fieldTo)}
        // if checker on target field was hit, move it to the bar
        val hitChecker = if (checkersAt[fieldTo].size == 1 && checkersAt[fieldTo].last().isDark != checker.isDark) {
            checkersAt[fieldTo].removeLast()
        } else null
        if (hitChecker != null) {
            val barIdx = if (hitChecker.isDark) 0 else 25
            checkersAt[barIdx].add(hitChecker)
            hitChecker.listener = { app.checkerClicked(barIdx) }
        }
        checkersAt[fieldTo].add(checker)
        for ((i, ch) in checkersAt[fieldFrom].withIndex()) {
            val pos = calcCheckerPosition(fieldFrom, checkersAt[fieldFrom].size, i + 1)
            ch.moveTo(pos, ANIM_DURATION_MOVE, ANIM_FREQ_MOVE)
        }
        for ((i, ch) in checkersAt[fieldTo].withIndex()) {
            val pos = calcCheckerPosition(fieldTo, checkersAt[fieldTo].size, i + 1)
            ch.moveTo(pos, ANIM_DURATION_MOVE, ANIM_FREQ_MOVE)
        }
        // if a checker was hit, animate the bar at the end, or else just call animationFinished()
        if (hitChecker == null) window.setTimeout(app::animationFinished, ANIM_DURATION_MOVE)
        else window.setTimeout({
            val barIdx = if (hitChecker.isDark) 0 else 25
            for ((i, ch) in checkersAt[barIdx].withIndex()) {
                val pos = calcCheckerPosition(barIdx, checkersAt[barIdx].size, i + 1)
                ch.moveTo(pos, ANIM_DURATION_MOVE, ANIM_FREQ_MOVE)
            }
            window.setTimeout(app::animationFinished, ANIM_DURATION_MOVE)
        }, ANIM_DURATION_MOVE)
    }

    fun bearOffChecker(fieldFrom: Int) {
        val checker = checkersAt[fieldFrom].removeLast()
        checker.isFocused = false // clear focus from this checker, as it is removed from the fields
        val bar = bars[2]
        val posX = bar.getAttribute("x")!!.toInt() + bar.getAttribute("width")!!.toInt() / 2
        val posY = bar.getAttribute("y")!!.toInt() + bar.getAttribute("height")!!.toInt() / 2
        checker.moveTo(posX to posY, ANIM_DURATION_MOVE, ANIM_FREQ_MOVE)
        for ((i, ch) in checkersAt[fieldFrom].withIndex()) {
            val pos = calcCheckerPosition(fieldFrom, checkersAt[fieldFrom].size, i + 1)
            ch.moveTo(pos, ANIM_DURATION_MOVE, ANIM_FREQ_MOVE)
        }
        window.setTimeout({
            // remove the checker that was born off
            checker.remove()
            app.animationFinished()
        }, ANIM_DURATION_MOVE)
    }

    fun highlightFields(fields: Set<Int>) {
        for (i in 1..24) {
            triangles[i-1].isActive = i in fields
        }
        // set the bar active too if -1 in fields
        if (-1 in fields) bars[2].classList.add("active")
        else bars[2].classList.remove("active")
    }

    fun highlightCheckersAt(fields: Set<Int>) {
        for (i in 0..25) {
            for (checker in checkersAt[i]) {
                checker.isActive = false
            }
            if (i in fields && checkersAt[i].isNotEmpty()) checkersAt[i].last().isActive = true
        }
    }

    fun focusField(field: Int?) {
        // unfocus triangles and checkers
        for (i in 0..23) triangles[i].isFocused = field == i
        for (i in 0..25)
            for (checker in checkersAt[i]) checker.isFocused = false
        // if a field is selected, highlight the last checker there
        if (field != null && checkersAt[field].isNotEmpty())
            checkersAt[field].last().isFocused = true
    }
}