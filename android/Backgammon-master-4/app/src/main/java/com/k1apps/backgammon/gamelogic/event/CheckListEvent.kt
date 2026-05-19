package com.k1apps.backgammon.gamelogic.event

import com.k1apps.backgammon.gamelogic.Piece

data class CheckListEvent(val homeRange: IntRange, val list: ArrayList<Piece>)