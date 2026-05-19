package game.items

import game.items.utils.Color

class Board {

    //TODO change the checker lists with stacks
    val daska = mutableListOf(
        mutableListOf(Checker(Color.WHITE), Checker(Color.WHITE)),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK)
        ),
        mutableListOf(),
        mutableListOf(Checker(Color.BLACK), Checker(Color.BLACK), Checker(Color.BLACK)),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE)
        ),
        mutableListOf(
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK),
            Checker(Color.BLACK)
        ),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(Checker(Color.WHITE), Checker(Color.WHITE), Checker(Color.WHITE)),
        mutableListOf(),
        mutableListOf(
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE),
            Checker(Color.WHITE)
        ),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(),
        mutableListOf(Checker(Color.BLACK), Checker(Color.BLACK))
    )

    fun printBoard() {
        for (j in 0..4) {
            print("| |")
            for (i in 0..11) {
                if (i == 6) {
                    print(" ")
                }
                if (daska[i].isNotEmpty()) {
                    try {
                        print("(${daska[i][j].color.letter})")
                    } catch (e: IndexOutOfBoundsException) {
                        print("   ")
                    }
                } else {
                    print("  ")
                }
            }
            print("| |")
            println()
        }

        println()

        for (j in 4 downTo 0) {
            print("| |")
            for (i in 23 downTo 12) {
                if (i == 17) {
                    print(" ")
                }

                if (daska[i].isNotEmpty()) {
                    try {
                        print("(${daska[i][j].color.letter})")
                    } catch (e: IndexOutOfBoundsException) {
                        print("   ")
                    }
                } else {
                    print("  ")
                }
            }
            print("| |")
            println()
        }
    }
}