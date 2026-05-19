package com.vorobyov.backgammon.view

import com.vorobyov.backgammon.models.Checker
import com.vorobyov.backgammon.view.GameView.Companion.WHITE_C
import com.vorobyov.backgammon.view.GameView.Companion.fieldHeight
import javafx.scene.Parent
import javafx.scene.paint.Color
import javafx.scene.paint.Paint
import javafx.scene.shape.Circle
import javafx.scene.shape.Polygon
import tornadofx.addChildIfPossible
import tornadofx.c
import tornadofx.getChildList
import java.util.*

class SelectablePolygon : Polygon {

    enum class Sides {
        TOP, BOTTOM
    }

    var background: Paint = c("#FFFFFF")
    set(value) {
        field = value
        fill = value
    }

    var selectedBackground: Paint = c("#FFFFFF")

    var side: Sides = Sides.TOP

    val checkers: Stack<Circle> = Stack()

    val checkerCenterX: Double
    get() {
        return layoutBounds.minX + GameView.triangleWidth / 2
    }


    constructor(vararg points: Number) : super(*points.map { it.toDouble() }.toDoubleArray())
    constructor() : super()

    var selected: Boolean = false
    private set

    fun select() {
        selected = true
        fill = selectedBackground
    }

    fun clearSelection() {
        selected = false
        fill = background
    }

    fun addChecker(checker: Checker) {
        var y: Double
        val action: Int

        when (side) {
            Sides.BOTTOM -> {
                y = fieldHeight
                action = -1
            }
            Sides.TOP -> {
                y = 0.0
                action = 1
            }
        }

        calculateCheckersPositions()

        y = (checkers.lastOrNull()?.centerY ?: y)
        y += action * (if (checkers.isNotEmpty()) 2 * GameView.checkerRadius * GameView.narrowCoefs[checkers.size] else GameView.checkerRadius)

        val checkerImg = Circle(
            checkerCenterX,
            y,
            GameView.checkerRadius,
            if (checker.color == Checker.Colors.WHITE) GameView.WHITE_C else GameView.BLACK_C
        )

        checkerImg.isMouseTransparent = true

        checkerImg.strokeWidth = 2.0
        checkerImg.stroke = Color.BLACK

        checkers.push(checkerImg)

        parent.addChildIfPossible(checkerImg)

    }

    fun popChecker() : Circle {
        val poppedCheckerImage = checkers.pop()
        parent.getChildList()?.remove(poppedCheckerImage)

        calculateCheckersPositions()
        return poppedCheckerImage
    }

    fun popFirstChecker() : Circle {
        val first = checkers.first()
        checkers.removeFirst()

        parent.getChildList()?.remove(first)

        calculateCheckersPositions()
        return first
    }

    private fun calculateCheckersPositions() {
        val action = if (side == Sides.TOP) 1 else -1
        for (i in 1 until checkers.size) {
            checkers[i].centerY =
                checkers[i - 1].centerY + action * GameView.checkerRadius * 2 * GameView.narrowCoefs[checkers.size]
        }
    }
}


fun Parent.polygon(vararg points: Number, op: SelectablePolygon.() -> Unit): SelectablePolygon {
    val polygon = SelectablePolygon(*points)
    op(polygon)
    addChildIfPossible(polygon)
    return polygon
}