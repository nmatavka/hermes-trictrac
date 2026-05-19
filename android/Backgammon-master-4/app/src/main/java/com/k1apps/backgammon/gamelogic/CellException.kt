package com.k1apps.backgammon.gamelogic

import java.lang.Exception

class CellFilledWithDifferencePieceException : Exception()

class CellNumberException(override val message: String?): Exception()