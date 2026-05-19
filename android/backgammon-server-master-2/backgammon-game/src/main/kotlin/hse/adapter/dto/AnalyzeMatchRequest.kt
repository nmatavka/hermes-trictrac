package hse.adapter.dto

import game.backgammon.response.HistoryResponse

data class AnalyzeMatchRequest(
    val games: List<HistoryResponse>,
    val matchId: Int,
)