package com.vorobyov.backgammon.app

import javafx.geometry.Pos
import javafx.scene.text.FontWeight
import tornadofx.Stylesheet
import tornadofx.box
import tornadofx.cssclass
import tornadofx.px


class Styles : Stylesheet() {
    companion object {
        val heading by cssclass()
        val start by cssclass()
    }

    init {
        label and heading {
            padding = box(10.px)
            alignment = Pos.BASELINE_CENTER
            fontSize = 20.px
            fontWeight = FontWeight.BOLD
        }

        button and start {
            alignment = Pos.BASELINE_CENTER
            fontSize = 20.px
            fontWeight = FontWeight.BOLD

            backgroundColor += tornadofx.c("#75E6DA", 0.5)

            and(hover) {
                backgroundColor += tornadofx.c("#75E6DA")
            }

            and(pressed) {
                backgroundColor += tornadofx.c("#189AB4")
            }
        }
    }

}