package com.vorobyov.backgammon.models

interface ActionListener {
    fun onCheckerAdded(point: Int, checker: Checker, checkersAtPoint: Int)
    fun onCheckerMoved(from: Int, to: Int, checker: Checker)
    fun onInitialDieRolled(player: Checker.Colors, amount: Int)
    fun onDiesRolled(player: Checker.Colors, dies: Pair<Int, Int>)

    fun onInviteSelectPoint(player: Checker.Colors)
    fun onAvailablePointsReceived(player: Checker.Colors, points: List<Int>, forPoint: Int)
    fun clearPointsHighlighting()
    fun onInviteSelectedPointClick(player: Checker.Colors)

    fun onSkipMove(player: Checker.Colors)

    fun onBarPut(point: Int, color: Checker.Colors)
    fun onMoveFromBar(player: Checker.Colors)
    fun onAvailablePointsForBarReceived(player: Checker.Colors, points: List<Int>)
    fun onCheckerMovedFromBar(player: Checker.Colors, point: Int)
    fun onCheckerBearingOff(player: Checker.Colors, point: Int)

    fun onWin(player: Checker.Colors)

}