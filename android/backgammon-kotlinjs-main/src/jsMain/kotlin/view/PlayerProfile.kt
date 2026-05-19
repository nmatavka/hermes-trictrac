package view

import ActivateableComponent
import Renderable
import kotlinx.html.TagConsumer
import kotlinx.html.div
import kotlinx.html.span
import kotlinx.html.svg
import org.w3c.dom.HTMLElement

private fun TagConsumer<HTMLElement>.playerAvatar(isDark: Boolean, checkerRadius: Int, size: Int) {
    val avatarSvg = svg ("avatar") {}
    avatarSvg.setAttribute("style", "width:${size}px;height:${size}px")
    Checker(size/2 to size/2, checkerRadius, isDark).render(avatarSvg)
}

class PlayerProfile(private val name: String, private val isDark: Boolean, private val sideLeft: Boolean,
                    private val checkerRadius: Int, private val size: Int) :
    ActivateableComponent(), Renderable {

    override fun render(tc: TagConsumer<HTMLElement>) {
        root = tc.div("player-profile") {
            if (sideLeft) tc.playerAvatar(isDark, checkerRadius, size)
            span {
                +name
            }
            if (!sideLeft) tc.playerAvatar(isDark, checkerRadius, size)
        }
    }
}