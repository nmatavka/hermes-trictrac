val diceWeight: Map<Dice, Int> = Dice.allDice()
    .map {
        if (it.num1 > it.num2) Dice(it.num2, it.num1) else it
    }
    .groupingBy { it }.eachCount()
val uniqueDice = diceWeight.keys.toList()
val totalDiceWeight = Dice.allDice().count()
