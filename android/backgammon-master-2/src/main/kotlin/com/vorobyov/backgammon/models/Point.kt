package com.vorobyov.backgammon.models

import java.util.*

class Point(val pos: Int) {

    private val checkers = Stack<Checker>()

    fun clear() = checkers.clear()

    val checkersCount: Int
    get() = checkers.size


    fun addChecker(checker: Checker) {
        checkers.push(checker)
    }

    fun popChecker(): Checker {
        require(!isFree())

        return checkers.pop()
    }

    fun popFirst(): Checker {
        require(!isFree())

        val first = checkers.first()
        checkers.removeFirst()

        return first
    }

    fun getLastChecker(): Checker {
        require(!isFree())
        return checkers.last()
    }

    fun isFree() = checkers.isEmpty()

    val checkersColor: Checker.Colors
    get() = checkers.last().color

    val boardPosition: Int
    get() = when (checkersColor) {
        Checker.Colors.WHITE -> pos
        Checker.Colors.BLACK -> 4 - pos
    }

    fun isHome(color: Checker.Colors): Boolean = when (color) {
        Checker.Colors.WHITE -> pos in 0..5
        Checker.Colors.BLACK -> pos in 18..23
    }


    fun hasChecker(color: Checker.Colors): Boolean {
        for (checker in checkers) {
            if (checker.color == color)
                return true
        }
        return false
    }


    fun allInHome(whoseHome: Checker.Colors): Boolean {
        if (!isHome(whoseHome)) {
            for (checker in checkers) {
                if (checker.color == whoseHome)
                    return false
            }
        }
        return true
    }

    /*
    "шашка может двигаться только на открытый пункт,
    то есть на такой, который не занят двумя или более шашками противоположного цвета"
     */
    fun isFreeFor(color: Checker.Colors): Boolean = checkers.filter { it.color != color }.size < 2


    /*
    "Пункт, занятый только одной шашкой,
    носит название «блот».
    Если шашка противоположного цвета останавливается на этом пункте,
    блот считается побитым и кладется на бар"
     */
    fun isBlotFor(color: Checker.Colors): Boolean = checkers.size == 1 && checkers.first().color != color


    override fun toString(): String {
        return "Point {pos=${pos}}"
    }
}

