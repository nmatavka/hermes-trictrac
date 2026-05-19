package view

import ActivateableComponent
import CSSClassDelegate
import RenderableInto
import kotlinx.browser.document
import kotlinx.browser.window
import org.w3c.dom.Element
import org.w3c.dom.events.Event
import org.w3c.dom.svg.SVGElement
import kotlin.js.Date

class Checker(
    private var center: Pair<Int, Int>, private val radius: Int, val isDark: Boolean
): ActivateableComponent(), RenderableInto {
    var listener: (Event) -> Unit = {}
        set (value) {
            field = value
            if (root != null) (root as SVGElement).onclick = value
        }
    var isFocused: Boolean by CSSClassDelegate("focused")
    private var intervalId: Int? = null

    override fun render(parent: Element) {
        val elem = document.createElementNS(SVG_NS, "circle") as SVGElement
        elem.classList.add(if (isDark) "dark" else "light")
        elem.setAttribute("cx", "${center.first}")
        elem.setAttribute("cy", "${center.second}")
        elem.setAttribute("r", "$radius")
        parent.append(elem)
        elem.onclick = listener
        root = elem
    }

    fun moveTo(newCenter: Pair<Int, Int>, animationDurationMs: Int = 1000, intervalMs: Int = 10) {
        if (newCenter == center) return
        val (cx, cy) = center
        val (ncx, ncy) = newCenter
        center = newCenter

        // if not rendered yet, animation and HTML element stuff is not needed
        if (root == null) return


        // remove and insert again the element, to be on top (achieve z-index-like ordering)
        val parent = root!!.parentElement!!
        parent.removeChild(root!!)
        parent.appendChild(root!!)

        val startTime = Date.now()

        intervalId?.let {window.clearInterval(it)}
        intervalId = window.setInterval({
            val timeLeft = startTime + animationDurationMs - Date.now()
            if (timeLeft < intervalMs) {
                root?.setAttribute("cx", "$ncx")
                root?.setAttribute("cy", "$ncy")
                window.clearInterval(this.intervalId!!)
            } else {
                val x = timeLeft/animationDurationMs * cx + (1-timeLeft/animationDurationMs) * ncx
                val y = timeLeft/animationDurationMs * cy + (1-timeLeft/animationDurationMs) * ncy
                root?.setAttribute("cx", "$x")
                root?.setAttribute("cy", "$y")
            }
        }, intervalMs)
    }
}