package com.vorobyov.backgammon.models

interface IPlayers {
    fun askInitialRollDie(player: Checker.Colors)
    fun askRollDies(player: Checker.Colors)
    fun askBearingOff(player: Checker.Colors, point: Int)
}