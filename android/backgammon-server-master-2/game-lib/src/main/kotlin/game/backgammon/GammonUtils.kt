package game.backgammon

fun Gammon.tossZar(): Int {
    return this.zar.nextInt(1, 7)
}

fun Gammon.setZarStartConfiguration(): ArrayList<Int> {
    var firstZar = tossZar()
    var secondZar = tossZar()
    while (firstZar == secondZar) {
        firstZar = tossZar()
        secondZar = tossZar()
    }
    turn = if (firstZar > secondZar) {
        1
    } else -1
    return arrayListOf(firstZar, secondZar)
}

fun Gammon.fillZar(res1: Int, res2: Int) {
    val result = mutableListOf<Int>()
    for (i in 0..<if (res1 == res2) 2 else 1) {
        result.add(res1)
        result.add(res2)
    }

    zarResults = ArrayList(result)
    foolZar = ArrayList(result)
}