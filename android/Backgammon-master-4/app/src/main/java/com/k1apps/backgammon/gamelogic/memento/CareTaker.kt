package com.k1apps.backgammon.gamelogic.memento

interface CareTaker {
    fun undo()
    fun redo()
}

class CareTakerImpl : CareTaker {
    private var currentIndex: Byte = -1
    private var mementos = arrayListOf<Memento>()

    override fun undo() {
    }

    override fun redo() {
    }

}