package game.engine

import game.items.Checker

class GameManager {

    fun move(board: MutableList<MutableList<Checker>>, pickedPosition: Int, destination: Int) {
        val checkersOrigin = board[pickedPosition]
        val checkersDestination = board[destination]
        val checker: Checker? = MoveValidator.pickChecker(checkersOrigin)

        if (checker != null && MoveValidator.isCheckerAtPoint(checker, checkersOrigin)) {
            if (MoveValidator.isMoveValid(checkersOrigin.get(checkersOrigin.size - 1).color, checkersDestination)) {
                checkersOrigin.removeAt(checkersOrigin.size - 1)
                checkersDestination.add(checker)
            }
        }
    }
}