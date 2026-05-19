package view

import ActivateableComponent
import CSSClassDelegate
import RenderableInto
import kotlinx.browser.document
import org.w3c.dom.Element
import org.w3c.dom.events.Event
import org.w3c.dom.svg.SVGElement
import kotlin.math.max

class Triangle(
    val baseCenter: Pair<Int, Int>, val height: Int, val width: Int,
    private val isDark: Boolean
): ActivateableComponent(), RenderableInto {

    var listener: (Event) -> Unit = {}
        set (value) {
            field = value
            if (root != null) (root as SVGElement).onclick = value
        }
    var isFocused: Boolean by CSSClassDelegate("focused")

    override fun render(parent: Element) {
        val elem = document.createElementNS(SVG_NS, "polygon") as SVGElement
        elem.classList.add(if (isDark) "dark" else "light")
        val (x, y) = baseCenter
        val (x1, x2) = Pair(max(0, x - width / 2), x + width / 2)
        val yTop = y + height
        elem.setAttribute("points", "$x1,$y $x2,$y, $x,$yTop")
        parent.appendChild(elem)
        elem.onclick = listener
        root = elem
    }
}