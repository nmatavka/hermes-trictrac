package com.hamersztein.engine.model

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

data class DiceThrow(
    val left: Int,
    val right: Int,
    val total: Int = left + right,
    val difference: Int = abs(left - right),
    val larger: Int = max(left, right),
    val smaller: Int = min(left, right),
    val isDouble: Boolean = left == right
)
