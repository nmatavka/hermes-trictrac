class ShowOnlyDice(internal var dice: Dice) {
    val isRolled: Boolean
        get() = dice.isRolled
    val diceOne: Int
        get() = dice.diceOne
    val diceTwo: Int
        get() = dice.diceTwo

    fun isOnDice(number: Int): Boolean {
        return dice.isOnDice(number)
    }

}
