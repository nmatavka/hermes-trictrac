package com.k1apps.backgammon.gamelogic

fun pieceListArrangementNormal(arrayList: MutableList<Piece>) {
    setPiecesLocation(arrayList.subList(0, 2), 24)
    setPiecesLocation(arrayList.subList(2, 7), 13)
    setPiecesLocation(arrayList.subList(7, 10), 8)
    setPiecesLocation(arrayList.subList(10, 15), 6)
}

fun pieceListArrangementReverse(arrayList: MutableList<Piece>) {
    setPiecesLocation(arrayList.subList(0, 2), 1)
    setPiecesLocation(arrayList.subList(2, 7), 12)
    setPiecesLocation(arrayList.subList(7, 10), 17)
    setPiecesLocation(arrayList.subList(10, 15), 19)
}

fun pieceListArrangement(arrayList: MutableList<Piece>, configList: ArrangementListConfig) {
    var pieceIndex = 0
    configList.arrayConfig.forEach { arrangementConfig ->
        for (item in 1..arrangementConfig.count) {
            arrayList[pieceIndex].location = arrangementConfig.location
            pieceIndex++
        }
    }

}

fun pieceListArrangementInOneLocation(arrayList: MutableList<Piece>, location: Int) {
    arrayList.forEach {
        it.location = location
    }
}

private fun setPiecesLocation(list: MutableList<Piece>, location: Int) {
    list.forEach {
        it.location = location
    }
}
