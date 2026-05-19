package view

import Component
import Renderable
import kotlinx.html.TagConsumer
import kotlinx.html.div
import kotlinx.html.id
import org.w3c.dom.HTMLElement
import kotlin.math.max

class ScoreBoard(val maxScore: Int) : Component(), Renderable {
    private var score1 = 0
    private var score2 = 0


    override fun render(tc: TagConsumer<HTMLElement>) {
        root = tc.div {
            id = "scoreboard"
            +"$score1 - (${maxScore}) - $score2"
        }

    }

    fun setPlayerScores(score1: Int, score2: Int) {
        this.score1 = score1
        this.score2 = score2
        root?.innerHTML = "$score1 - (${maxScore}) - $score2"
    }
}