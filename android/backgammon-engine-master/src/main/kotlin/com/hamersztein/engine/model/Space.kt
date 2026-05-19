package com.hamersztein.engine.model

data class Space(
    var count: Int = 0,
    var colour: Colour? = null
) {
    fun reset() {
        count = 0
        colour = null
    }

    fun canMoveHere() = count <= 1
}
