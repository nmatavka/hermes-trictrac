import game.engine.GameManager
import game.engine.Prompter.Companion.COMMAND_EXIT
import game.engine.Prompter.Companion.COMMAND_ROLL
import game.items.Board
import game.items.Dice

fun main() {
    val board = Board()
    val gameManager = GameManager()
    val dice = Dice()

    board.printBoard()

    var command: String = readln()

    while (command != COMMAND_EXIT) {
        val diceOne: Int
        val diceTwo: Int

        if (command == COMMAND_ROLL) {
            val dices = dice.roll()
            diceOne = dices[0]
            diceTwo = dices[1]
            println(diceOne.toString() + diceTwo)
        } else {
            command = readln()
            continue
        }

        val commandArr = command.split(" ")

        gameManager.move(board.daska, commandArr[0].toInt(), commandArr[1].toInt())

        board.printBoard()

        command = readln()
    }
}