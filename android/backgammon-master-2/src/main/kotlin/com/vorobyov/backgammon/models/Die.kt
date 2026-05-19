package com.vorobyov.backgammon.models

class Die {
    var amount: Int = 0
    private set

    val hidden: Boolean
    get() = amount == 0

    fun roll(): Int = (1..6).random().apply { amount = this }

    fun hide() {
        amount = 0
    }
}