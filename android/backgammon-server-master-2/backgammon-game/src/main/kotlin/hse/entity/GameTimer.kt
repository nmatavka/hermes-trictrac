package hse.entity

import java.time.Duration
import java.time.Instant

class GameTimer(
    val matchId: Int,
    var lastAction: Instant,
    var remainBlackTime: Duration,
    var remainWhiteTime: Duration,
    var increment: Duration,
)