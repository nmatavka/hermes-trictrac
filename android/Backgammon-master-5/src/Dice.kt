import java.util.*

class Dice {
    var diceOne: Int = 0
        private set
    var diceTwo: Int = 0
        private set
    private var diceOneUses: Int = 0
    private var diceTwoUses: Int = 0
    private var generator: Random? = null
    val isRolled: Boolean
        get() = diceOneUses > 0 || diceTwoUses > 0

    constructor() {
        generator = Random()
    }

    constructor(d: Dice) {
        diceOne = d.diceOne
        diceTwo = d.diceTwo
        diceOneUses = d.diceOneUses
        diceTwoUses = d.diceTwoUses
        generator = Random()
    }

    fun roll() {
        diceOne = generator!!.nextInt(6) + 1
        diceTwo = generator!!.nextInt(6) + 1
        if (diceOne == diceTwo) {
            diceOneUses = 2
            diceTwoUses = 2
        } else {
            diceOneUses = 1
            diceTwoUses = 1
        }
    }

    fun isOnDice(number: Int): Boolean {
        if (diceOneUses > 0 && diceOne == number)
            return true
        return diceTwoUses > 0 && diceTwo == number
    }

    fun rollDifferent() {
        do {
            diceOne = generator!!.nextInt(6) + 1
            diceTwo = generator!!.nextInt(6) + 1
        } while (diceOne == diceTwo)
        diceOneUses = 1
        diceTwoUses = 1
    }

    fun takeDice(number: Int) {
        if (diceOneUses > 0 && diceOne == number) {
            diceOneUses--
        } else if (diceTwoUses > 0 && diceTwo == number) {
            diceTwoUses--
        } else {
            throw IllegalArgumentException("Trying to take invalid dice $number")
        }
    }

    fun takeDiceOne(): Int {
        if (diceOneUses == 0)
            return 0
        diceOneUses--
        return diceOne
    }

    fun takeDiceTwo(): Int {
        if (diceTwoUses == 0)
            return 0
        diceTwoUses--
        return diceTwo
    }


}
