package com.k1apps.backgammon.gamelogic.event

import com.k1apps.backgammon.gamelogic.Player

data class DiceThrownEvent(val player: Player)

data class DiceBoxThrownEvent(val player: Player)