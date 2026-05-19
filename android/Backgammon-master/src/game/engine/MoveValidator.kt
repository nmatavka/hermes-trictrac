package game.engine

import game.items.Checker
import game.items.utils.Color

class MoveValidator {
    companion object {
        private val prompter = Prompter()
        fun isMoveValid(color: Color, destination: MutableList<Checker>): Boolean =
            if (destination.isEmpty() || destination.last().color == color) {
                true
            } else {
                prompter.invalidMove()
                false
            }

        fun isCheckerAtPoint(checker: Checker?, pickedPoint: MutableList<Checker>): Boolean =
            if (pickedPoint.last().color == checker?.color) {
                true
            } else {
                prompter.noCheckerAtPoint()
                false
            }

        fun pickChecker(pickedPoint: MutableList<Checker>): Checker? =
            try {
                pickedPoint.get(pickedPoint.size - 1)
            } catch (e: IndexOutOfBoundsException) {
                prompter.noCheckerAtPoint()
                null
            }
    }
}