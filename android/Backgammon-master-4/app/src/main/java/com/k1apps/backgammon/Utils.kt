package com.k1apps.backgammon

import kotlin.math.abs

object Utils {
    fun reverseLocation(location: Int): Int {
        return abs(location - 25)
    }

}