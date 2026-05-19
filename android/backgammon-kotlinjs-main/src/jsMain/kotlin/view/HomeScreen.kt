package view

import AppScreen
import IController
import Player
import PlayerSide
import kotlinx.browser.document
import kotlinx.dom.clear
import kotlinx.html.dom.append
import kotlinx.html.dom.create
import kotlinx.html.js.*
import Settings
import kotlinx.browser.window
import kotlinx.html.*
import org.w3c.dom.Element
import org.w3c.dom.HTMLElement
import org.w3c.dom.HTMLInputElement
import org.w3c.dom.events.Event
import org.w3c.dom.get
import org.w3c.dom.svg.SVGElement

/**
 * Create a callback for updating an element when an input changes.
 */
private fun inputFeedbackCallback(inputId: String, feedbackId: String): (Event) -> Unit {

    fun update(event: Event) {
        val numFeedback = document.getElementById(feedbackId)
        val newval = (document.getElementById(inputId) as HTMLInputElement?)?.value
        if (newval != null) numFeedback?.innerHTML = newval
    }
    return ::update
}

private fun HTMLElement.inputSlider(
    id_: String, label_: String, min_: String, max_: String, step_: String,
    value_: String
) {
    append.div ("home-block row"){
        div {
            label("form-label") {
                htmlFor = id_
                +label_
            }
            span {
                id = id_ + "Feedback"
                +value_
            }
            input(InputType.range, classes = "form-range") {
                min = min_
                max = max_
                step = step_
                value = value_
                id = id_
                onChangeFunction = inputFeedbackCallback(id_, id_ + "Feedback")
            }
        }
    }
}

private fun TagConsumer<HTMLElement>.checkerChoice(color: String, size: Int, callback: (Event) -> Unit) {
    val svgBox = svg("color-choice $color") {}
    svgBox.setAttribute("style", "width:${size + 12}px;height:${size + 12}px;padding:6px;")

    val mid = size / 2
    if (color == "mixed") {
        val path1 = document.createElementNS(SVG_NS, "path") as SVGElement
        path1.setAttribute("d", "M$mid,0 L$mid,$size A$mid,$mid 0 0,1 $mid,0")
        path1.classList.add("light")
        path1.onclick = callback
        svgBox.append(path1)

        val path2 = document.createElementNS(SVG_NS, "path") as SVGElement
        path2.setAttribute("d", "M$mid,0 L$mid,$size A$mid,$mid 0 0,0 $mid,0")
        path2.classList.add("dark")
        path2.onclick = callback
        svgBox.append(path2)
    } else {
        val path1 = document.createElementNS(SVG_NS, "path") as SVGElement
        path1.setAttribute("d", "M$mid,0 A$mid,$mid,0,0,0,$mid,$size M$mid,0 A$mid,$mid,0,0,1,$mid,$size")
        path1.classList.add(color)
        path1.onclick = callback
        svgBox.append(path1)
    }
    svgBox.onclick = callback
}

private fun TagConsumer<HTMLElement>.sideChooser(settings: Settings) {

    // set a choice active, and remove the active tag from all the others (radio button behaviour)
    val setActive = { color: String ->
        val boxes = document.getElementsByClassName("color-choice")
        for (i in 0 until boxes.length) {
            if (boxes[i]!!.classList.contains(color)) boxes[i]!!.classList.add("active")
            else boxes[i]!!.classList.remove("active")
        }
    }

    div ("home-block row color-choices"){
        checkerChoice("light", 36) {
            settings.color = PlayerSide.PLAYER2
            setActive("light")
        }
        checkerChoice("mixed", 36) {
            settings.color = PlayerSide.RANDOM
            setActive("mixed")
        }
        checkerChoice("dark", 36) {
            settings.color = PlayerSide.PLAYER1
            setActive("dark")
        }
    }
    val initChoice = when (settings.color) {
        PlayerSide.PLAYER1 -> "dark"
        PlayerSide.PLAYER2 -> "light"
        else -> "mixed"
    }
    setActive(initChoice)
}

/**
 * A group of elements containing game settings
 */
private fun HTMLElement.settingsForm(settings: Settings) {
    append {
        inputSlider("numGamesInput", "Play until score:", "1", "21", "1", "${settings.maxScore}")
        inputSlider("levelInput", "Level:", "1", "5", "1", "${settings.level}")
        sideChooser(settings)
    }
}


class HomeScreen(app: IController, root: HTMLElement, private val settings: Settings): AppScreen(app, root) {

    private val container: HTMLElement

    init {
        root.clear()
        container = document.create.div("home-container") {}
        root.appendChild(container)
        container.append {
            h1 {
                +"Backgammon"
            }
            container.settingsForm(settings)
            button(classes = "btn btn-primary") {
                onClickFunction = {
                    settings.maxScore = (document.getElementById("numGamesInput") as HTMLInputElement).value.toInt()
                    settings.level = (document.getElementById("levelInput") as HTMLInputElement).value.toInt()
                    app.newGame()
                }
                +"Start"
            }
            button(classes = "btn btn-primary") {
                disabled = !app.savedGameExists()
                onClickFunction = {
                    app.loadSavedGame()
                }
                +"Load previous game"
            }
        }
        // remove event handlers possibly set by a previous GameScreen
        window.onresize = null
        window.onbeforeunload = null
    }
}

