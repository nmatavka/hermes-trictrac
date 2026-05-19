package com.hamersztein.engine

import com.hamersztein.engine.model.DiceThrow
import kotlin.random.Random

class DiceThrower(
    var throwCount: Int = 0,
    private val thrownDice: Array<DiceThrow> = Array(200) { DiceThrow(Random.nextInt(1, 7), Random.nextInt(1, 7)) }
) {

    operator fun invoke() = thrownDice[throwCount].also {
        throwCount++
    }
}

