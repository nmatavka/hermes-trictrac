package com.vorobyov.backgammon.view

import com.vorobyov.backgammon.app.Styles
import com.vorobyov.backgammon.models.*
import javafx.event.Event
import javafx.event.EventHandler
import javafx.event.EventType
import javafx.geometry.Pos
import javafx.scene.control.Label
import javafx.scene.input.KeyCode
import javafx.scene.input.KeyEvent
import javafx.scene.layout.Pane
import javafx.scene.paint.Color
import javafx.scene.shape.Circle
import com.vorobyov.backgammon.view.SelectablePolygon
import com.vorobyov.backgammon.view.polygon
import javafx.scene.control.Alert
import javafx.scene.control.Button
import javafx.scene.control.ButtonType
import javafx.scene.input.MouseEvent
import javafx.scene.layout.StackPane
import tornadofx.*
import java.lang.Double.min
import java.util.*
import kotlin.math.abs

class GameView : View("Короткие нарды"), ActionListener, IPlayers {
    companion object {
        val BLACK_BACK_C = c("#0B415A", 0.7)
        val WHITE_BACK_C = c("#89CFF0", 0.7)
        val SELECTED_POINT_C = c("#af89f0", 0.7)
        val ORIGIN_POINT_C = c("#6f569c", 0.7)

        val BLACK_C = c("#0B415A")
        val WHITE_C = c("#a7bfc9")

        val fieldWidth = 600.0
        val fieldHeight = 600.0

        val triangleWidth = fieldWidth / 12
        val triangleHeight = fieldHeight / 2.5

        val checkerRadius = (triangleWidth * 0.8) / 2

        val narrowCoefs = Array(15) { count -> min(1.0, triangleHeight / (count * 2 * checkerRadius)) }

    }

    private val points = Array(24) { pos -> Stack<Circle>() }
    private val pointsPolygons = mutableMapOf<Int, SelectablePolygon>()

    private val backgammon: Backgammon = Backgammon(this)

    private lateinit var board: Pane

    private lateinit var stateLabel: Label

    private lateinit var whiteBarChecker: StackPane
    private lateinit var whiteBarCheckerCount: Label
    private var whitesInBar = 0

    private lateinit var blackBarChecker: StackPane
    private lateinit var blackBarCheckerCount: Label

    private lateinit var firstDie: Label
    private lateinit var secondDie: Label

    private lateinit var dieButton: Button

    private var blacksInBar = 0

    override val root = vbox {
        prefWidth = 800.0
        prefHeight = 800.0

        addEventFilter(KeyEvent.KEY_PRESSED) {
            if (it.code == KeyCode.ESCAPE) {
                backgammon.clearPointSelection()
            }
        }

        alignment = Pos.TOP_CENTER
        style {
            backgroundColor += tornadofx.c("#D4F1F4")
        }

        label("Короткие нарды") {
            addClass(Styles.heading)
            alignment = Pos.TOP_CENTER
        }

        stateLabel = label {
            alignment = Pos.BASELINE_CENTER
        }

        board = pane {
            style {
                backgroundColor += tornadofx.c("#189AB4", 0.5)
            }

            prefWidth = fieldWidth
            minWidth = fieldWidth
            maxWidth = fieldWidth

            prefHeight = fieldHeight
            minHeight = fieldHeight
            maxHeight = fieldHeight

            line(fieldWidth / 2, 0, fieldWidth / 2, fieldHeight) {
                fill = BLACK_C
            }


            for (i in 0 until 12) {

                val x = i * triangleWidth

                var pos = 12 + i

                pointsPolygons[pos] = polygon(x, 0, x + triangleWidth / 2, triangleHeight, x + triangleWidth, 0) {
                    background = if (i % 2 == 0) WHITE_BACK_C else BLACK_BACK_C
                    selectedBackground = SELECTED_POINT_C
                    side = SelectablePolygon.Sides.TOP
                }
                pos.apply { pointsPolygons[this]!!.setOnMouseClicked { onPointClicked(this) } }

                pos = 11 - i

                pointsPolygons[pos] = this.polygon(
                    x,
                    fieldHeight,
                    x + triangleWidth / 2,
                    fieldHeight - triangleHeight,
                    x + triangleWidth,
                    fieldHeight
                ) {
                    style {
                        borderColor += box(c("#222222"))
                        borderWidth += box(50.0.px)
                    }
                    background = if (i % 2 == 0) BLACK_BACK_C else WHITE_BACK_C
                    selectedBackground = SELECTED_POINT_C
                    side = SelectablePolygon.Sides.BOTTOM
                }
                pos.apply { pointsPolygons[this]!!.setOnMouseClicked { onPointClicked(this) };
                }

            }

            stackpane {

                isMouseTransparent = true

                prefWidth = fieldWidth
                minWidth = fieldWidth
                maxWidth = fieldWidth

                prefHeight = fieldHeight
                minHeight = fieldHeight
                maxHeight = fieldHeight


                vbox {
                    alignment = Pos.CENTER

                    hbox {
                        alignment = Pos.CENTER

                        whiteBarChecker = stackpane {
                            alignment = Pos.BASELINE_LEFT
                        }

                        whiteBarCheckerCount = label() {
                            alignment = Pos.CENTER_RIGHT
                            style {
                                fontSize = 20.0.pt
                                padding = box(5.0.px)
                            }
                        }
                    }

                    hbox {
                        alignment = Pos.CENTER

                        blackBarChecker = stackpane {
                            alignment = Pos.BASELINE_LEFT
                        }

                        blackBarCheckerCount = label() {
                            alignment = Pos.CENTER_RIGHT
                            style {
                                fontSize = 20.0.pt
                                padding = box(5.0.px)
                            }
                        }
                    }
                }
            }
        }

        hbox {
            alignment = Pos.BASELINE_CENTER
            style {
                padding = box(5.0.px)
                fontSize = 16.pt
            }
            firstDie = label {
                style {
                    padding = box(5.0.px)
                }
            }
            secondDie = label {
                style {
                    padding = box(5.0.px)
                }
            }
        }

        hbox {
            alignment = Pos.BASELINE_CENTER

            style {
                padding = box(5.0.px)
            }
            dieButton = button("Бросить кубик") {  }
        }
    }


    override fun onCheckerMoved(from: Int, to: Int, checker: Checker) {
        pointsPolygons[from]?.popChecker()
        pointsPolygons[to]?.addChecker(checker)
    }


    override fun onCheckerAdded(point: Int, checker: Checker, checkersAtPoint: Int) {
        pointsPolygons[point]?.addChecker(checker)
    }

    private fun player(color: Checker.Colors): String = when (color) {
        Checker.Colors.WHITE -> "1"
        Checker.Colors.BLACK -> "2"
    }

    override fun onInitialDieRolled(player: Checker.Colors, amount: Int) {
        when (player) {
            Checker.Colors.WHITE -> firstDie.text = amount.toString()
            Checker.Colors.BLACK -> secondDie.text = amount.toString()
        }
    }

    override fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>) {
        firstDie.text = dies.first.toString()
        secondDie.text = dies.second.toString()

    }

    override fun onInviteSelectPoint(player: Checker.Colors) {
        stateLabel.text = "Игрок ${player(player)}. Выбор шашки"
    }

    override fun onAvailablePointsReceived(player: Checker.Colors, points: List<Int>, forPoint: Int) {
        pointsPolygons[forPoint]?.fill = ORIGIN_POINT_C

        for (point in points) {
            pointsPolygons[point]?.select()
        }
    }

    override fun onAvailablePointsForBarReceived(player: Checker.Colors, points: List<Int>) {
        for (point in points) {
            pointsPolygons[point]?.select()
        }
    }

    override fun clearPointsHighlighting() {
        for ((_, point) in pointsPolygons) {
            point.clearSelection()
        }
    }

    override fun onSkipMove(player: Checker.Colors) {
        alert(Alert.AlertType.INFORMATION, "Нет возможных ходов", "Игрок ${player(player)} пропускает ход", owner = currentWindow)
    }

    override fun onBarPut(point: Int, color: Checker.Colors) {
        val firstChecker = pointsPolygons[point]?.popFirstChecker() ?: return

        when (color) {
            Checker.Colors.WHITE -> {
                val was = if (whiteBarCheckerCount.text.isNullOrEmpty()) 0 else whiteBarCheckerCount.text.toInt()
                whiteBarCheckerCount.text = (was + 1).toString()
                if (was == 0) {
                    whiteBarChecker.add(firstChecker)
                }
            }
            Checker.Colors.BLACK -> {
                val was = if (blackBarCheckerCount.text.isNullOrEmpty()) 0 else blackBarCheckerCount.text.toInt()
                blackBarCheckerCount.text = (was + 1).toString()
                if (was == 0) {
                    blackBarChecker.add(firstChecker)
                }
            }
        }
    }


    override fun onCheckerMovedFromBar(player: Checker.Colors, point: Int) {
        when (player) {
            Checker.Colors.WHITE -> {
                val was = whiteBarCheckerCount.text.toInt()
                whiteBarCheckerCount.text = if (was == 1) "" else (was - 1).toString()
                if (was == 1) {
                    whiteBarChecker.getChildList()?.clear()
                }

                pointsPolygons[point]?.addChecker(Checker(Checker.Colors.WHITE))
            }
            Checker.Colors.BLACK -> {
                val was = blackBarCheckerCount.text.toInt()
                blackBarCheckerCount.text = if (was == 1) "" else (was - 1).toString()
                if (was == 1) {
                    blackBarChecker.getChildList()?.clear()
                }
                pointsPolygons[point]?.addChecker(Checker(Checker.Colors.BLACK))
            }
        }
    }

    override fun onCheckerBearingOff(player: Checker.Colors, point: Int) {
        pointsPolygons[point]?.popChecker()
    }

    override fun onWin(player: Checker.Colors) {
        alert(Alert.AlertType.INFORMATION, "Поздравляем!", "Игрок ${player(player)} победил!", ButtonType.OK, owner = currentWindow) {
            if (result == ButtonType.OK) {
                backgammon.setupBoard()
            }
        }
    }

    override fun onMoveFromBar(player: Checker.Colors) {
        stateLabel.text = "Игрок ${player(player)}. Вывод шашки из бара"

    }

    init {
        backgammon.listener = this
        backgammon.setupBoard()
    }

    override fun askInitialRollDie(player: Checker.Colors) {
        stateLabel.text = "Игрок ${player(player)}. Стартовый бросок кубика"

        dieButton.setOnMouseClicked { dieButton.onMouseClicked = null; backgammon.onInitialRolledDie(player)  }

    }

    override fun askRollDies(player: Checker.Colors) {
        stateLabel.text = "Игрок ${player(player)}. Бросок кубиков"

        dieButton.setOnMouseClicked { dieButton.onMouseClicked = null; backgammon.onRolledDies(player) }
    }

    override fun onInviteSelectedPointClick(player: Checker.Colors) {
        stateLabel.text = "Игрок ${player(player)}. Выбор хода"
    }

    override fun onDock() {
        root.requestFocus()
    }

    private fun onPointClicked(pos: Int) {
        if (pointsPolygons[pos]?.selected != true) {
            backgammon.onPointSelected(pos)
        }
        else {
            backgammon.onSelectedPointClicked(pos)
        }
    }

    override fun askBearingOff(player: Checker.Colors, point: Int) {
        alert(
            Alert.AlertType.CONFIRMATION,
            "Выбрасывание с поля",
            "Выбросить шашку ${point + 1} с поля?",
            ButtonType.YES, ButtonType.NO,
            owner = currentWindow
        ) { buttonType ->
            if (result == ButtonType.YES) {
                backgammon.onBearingOffAccepted(player, point)
            } else {
                backgammon.onBearingOffReject(player, point)
//                close()
            }
        }
    }

}
