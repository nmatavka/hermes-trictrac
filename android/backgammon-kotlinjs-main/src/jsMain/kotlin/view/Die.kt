package view

import Component
import RenderableInto
import kotlinx.browser.document
import kotlinx.browser.window
import org.w3c.dom.Element
import kotlin.random.Random

class Die (
    private val number: Int, private val center: Pair<Int, Int>, private val size: Int
): Component(), RenderableInto {
    override fun render(parent: Element) {
        val elem = document.createElementNS(SVG_NS, "image")
        elem.setAttribute("x", "${center.first - size/2}")
        elem.setAttribute("y", "${center.second - size/2}")
        elem.setAttribute("width", "$size")
        elem.setAttribute("height", "$size")
        elem.setAttribute("href", "assets/die_${number}.svg")
        parent.append(elem)
        root = elem
    }

    fun animateRolling(durationMs: Int, frequencyMs: Int) {
        val nextDuration = durationMs - frequencyMs
        val roll = if (nextDuration < 0) number else Random.nextInt(1, 7)
        root?.setAttribute("href", "assets/die_${roll}.svg")
        if (nextDuration >= 0)
            window.setTimeout({animateRolling(nextDuration, frequencyMs)}, frequencyMs)
    }
}