import kotlinx.html.TagConsumer
import org.w3c.dom.Element
import org.w3c.dom.HTMLElement
import kotlin.reflect.KProperty

abstract class AppScreen(protected val app: IController, protected val root: HTMLElement)

/**
 * An animated view for the game. For each function call, if the displayed
 * animation or wait period has ended,
 * the animationEnded() function is called on the controller.
 */
interface IAnimatedGameScreen {
    fun initialDiceRoll(result1: Int, result2: Int)
    fun playerDiceRoll(result1: Int, result2: Int, playerIdx: Int)
    fun moveChecker(fieldFrom: Int, fieldTo: Int)
    fun bearOffChecker(fieldFrom: Int)
    fun newTurnOf(playerIdx: Int)
    fun roundEnded(gameEnd: Boolean, userWon: Boolean)
    fun noMovesAvailable()
}

/**
 * A non-animated interface of the game screen. These functions work synchronously.
 */
interface IGameScreen {
    fun setPlayerScores(player1: Int, player2: Int)
    fun setPosition(fields: List<Int>, fieldPlayerIdx: List<Int>, turnOf: Int, dieNums: Pair<Int, Int>?)
    fun highlightFields(fields: List<Int>)
    fun highlightCheckersAt(fields: List<Int>)
    fun focusField(field: Int?)
}

/**
 * Part of the view that can be rendered into an HTMLElement.
 */
interface Renderable {
    fun render(tc: TagConsumer<HTMLElement>)
}

/**
 * Part of the view that can be rendered into an Element of the webpage, but
 * not necessarily into an HTMLElement. (the parent could be an SVGElement)
 */
interface RenderableInto {
    fun render(parent: Element)
}

/**
 * A component of the game screen.
 */
abstract class Component {
    var root: Element? = null
        protected set
    fun remove() {
        root?.remove()
    }
}

class CSSClassDelegate(val classname: String, initValue: Boolean = false) {
    private var classActive: Boolean = initValue

    operator fun getValue(thisRef: Component, property: KProperty<*>): Boolean {
        return classActive
    }

    operator fun setValue(thisRef: Component, property: KProperty<*>, value: Boolean) {
        if (value == classActive) return
        classActive = value
        if (value) thisRef.root?.classList?.add(classname)
        else thisRef.root?.classList?.remove(classname)
    }
}

/**
 * A component of the game screen that can be activated to display in a different manner.
 */
abstract class ActivateableComponent: Component() {
    var isActive: Boolean by CSSClassDelegate("active")
}
