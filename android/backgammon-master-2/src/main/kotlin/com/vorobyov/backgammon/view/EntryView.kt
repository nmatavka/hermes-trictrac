package com.vorobyov.backgammon.view

import com.vorobyov.backgammon.app.Styles
import javafx.geometry.Pos
import javafx.stage.Modality
import tornadofx.*

class EntryView : View("Короткие нарды") {
    override val root = vbox {
        alignment = Pos.CENTER
        style {
            padding = box(50.px)
            backgroundColor += tornadofx.c("#D4F1F4")
        }

        label("Короткие нарды") {
            addClass(Styles.heading)
        }

        button("Начать") {
            addClass(Styles.start)

            setOnMouseClicked {
                GameView().openWindow(owner = null, escapeClosesWindow = false)
//                find<GameView>().openWindow(owner = null)
                currentStage?.close()
            }
        }
    }
}