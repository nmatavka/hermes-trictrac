package com.hamersztein.engine.model

import com.hamersztein.engine.model.Colour.LIGHT

class Bar(private val light: Space = Space(), private val dark: Space = Space()) {
    val numLight by lazy {
        light.count
    }

    val numDark by lazy {
        dark.count
    }

    fun addPiece(colour: Colour) {
        (if (colour == LIGHT) light else dark).count++
    }

    fun removePiece(colour: Colour) {
        (if (colour == LIGHT) light else dark).count--
    }
}