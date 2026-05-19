package com.zeroprojects.backgammon.logic

import kotlin.random.Random

class Dices {
    private var diceOne: Int = 0
    private var diceTwo: Int = 0

    private var diceOneUses: Int = 0
    private var diceTwoUses: Int = 0

    private val generator: Random = Random

    constructor() {
        generator
    }

    constructor(d: Dices) {
        diceOne = d.diceOne
        diceTwo = d.diceTwo
        diceOneUses = d.diceOneUses
        diceTwoUses = d.diceTwoUses
        generator
    }

    fun roll() {
        diceOne = Random.nextInt(1, 7)
        diceTwo = Random.nextInt(1, 7)
        if (diceOne == diceTwo) {
            diceOneUses = 2
            diceTwoUses = 2
        } else {
            diceOneUses = 1
            diceTwoUses = 1
        }
    }

    fun isOnDice(number: Int): Boolean {
        return (diceOneUses > 0 && diceOne == number) || (diceTwoUses > 0 && diceTwo == number)
    }

    fun rollDifferent() {
        do {
            diceOne = Random.nextInt(1, 7)
            diceTwo = Random.nextInt(1, 7)
        } while (diceOne == diceTwo)
        diceOneUses = 1
        diceTwoUses = 1
    }

    fun takeDice(number: Int) {
        when {
            diceOneUses > 0 && diceOne == number -> diceOneUses--
            diceTwoUses > 0 && diceTwo == number -> diceTwoUses--
            else -> throw IllegalArgumentException("Trying to take invalid dice $number")
        }
    }

    fun takeDiceOne(): Int {
        return if (diceOneUses == 0) {
            0
        } else {
            diceOneUses--
            diceOne
        }
    }

    fun takeDiceTwo(): Int {
        return if (diceTwoUses == 0) {
            0
        } else {
            diceTwoUses--
            diceTwo
        }
    }

    fun isRolled(): Boolean {
        return diceOneUses > 0 || diceTwoUses > 0
    }

    fun getDiceOne(): Int {
        return diceOne
    }

    fun getDiceTwo(): Int {
        return diceTwo
    }
}