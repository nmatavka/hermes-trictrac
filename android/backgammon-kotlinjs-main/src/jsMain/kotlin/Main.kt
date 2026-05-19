import kotlinx.browser.window

// animation parameters for each element (in ms)
val ANIM_DURATION_DICE = 800
val ANIM_WAIT_AFTER_DICE = 800
val ANIM_FREQ_DICE = 75
val ANIM_DURATION_MOVE = 1000
val ANIM_FREQ_MOVE = 22
val ANIM_DURATION_NEW_TURN = 400
val ANIM_DURATION_ROUND_END = 1500
val ANIM_DURATION_GAME_END = 1500

val VERSION = "0.1"
val DEBUG = false

fun main() {
    val app = App()
    window.onload = {
        app.start()
    }
}