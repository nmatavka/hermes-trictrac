import java.util.*

class Game {
    internal var generator: Random
    var board: Board
        internal set
    var player: Stone.Color
        internal set
    internal var dice: Dice
    val isEnded: Boolean
        get() = board.getHome(Stone.Color.WHITE) == 15 || board.getHome(Stone.Color.BLACK) == 15

    init {
        generator = Random()
        board = Board()
        player = Stone.Color.NONE
        dice = Dice()
    }

    fun roll() {
        if (player === Stone.Color.NONE) {
            dice.rollDifferent()
        } else {
            dice.roll()
        }
        when (player) {
            Stone.Color.WHITE -> player = Stone.Color.BLACK
            Stone.Color.BLACK -> player = Stone.Color.WHITE
            Stone.Color.NONE -> if (dice.diceOne > dice.diceTwo) {
                player = Stone.Color.WHITE
            } else {
                player = Stone.Color.BLACK
            }
        }
    }

    fun canMove(from: Int, count: Int): Boolean {
        if (!dice.isRolled)
            return false
        if (!dice.isOnDice(count))
            return false
        return if ((!board.canMove(from, count)!!)!!) false else board.getStone(from).color() === player
    }

    @Throws(WrongMoveException::class)
    fun move(from: Int, count: Int) {
        if (!canMove(from, count))
            throw WrongMoveException()
        board.move(from, count)
        dice.takeDice(count)
    }

    fun canPut(number: Int): Boolean {
        if (!dice.isRolled)
            return false
        return if (!dice.isOnDice(number)) false else board.canPut(player, number)
    }

    @Throws(WrongMoveException::class)
    fun put(number: Int) {
        if (!canPut(number))
            throw WrongMoveException()
        board.put(player, number)
        dice.takeDice(number)
    }

    fun getDice(): ShowOnlyDice {
        return ShowOnlyDice(dice)
    }

    fun winner(): Stone.Color {
        if (!isEnded)
            return Stone.Color.NONE
        return if (board.getHome(Stone.Color.WHITE) == 15) Stone.Color.WHITE else Stone.Color.BLACK
    }

}
