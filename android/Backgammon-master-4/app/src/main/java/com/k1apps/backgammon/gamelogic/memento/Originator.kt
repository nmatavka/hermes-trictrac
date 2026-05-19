package com.k1apps.backgammon.gamelogic.memento

interface Originator {
    fun createMemento(): Memento
    fun restore(memento: Memento)
}