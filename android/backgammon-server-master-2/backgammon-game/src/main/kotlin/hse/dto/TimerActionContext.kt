package hse.dto

import java.time.Duration
import java.time.Instant
import java.time.ZonedDateTime

data class TimerActionContext(
    val opponentLastAction: Instant,
    val playerRemainTime: Duration
)