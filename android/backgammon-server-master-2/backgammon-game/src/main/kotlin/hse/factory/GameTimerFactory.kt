package hse.factory

import game.common.enums.TimePolicy
import hse.entity.GameTimer
import org.springframework.stereotype.Component
import java.time.Clock
import java.time.Duration

@Component
class GameTimerFactory(
    val clock: Clock
) {
    fun getTimer(matchId: Int, points: Int, timePolicy: TimePolicy): GameTimer? {
        val now = clock.instant()
        if (timePolicy == TimePolicy.NO_TIMER) {
            return null
        }

        val remainTime = if (timePolicy == TimePolicy.DEFAULT_TIMER) {
            Duration.ofMinutes(2L * points)
        } else if (timePolicy == TimePolicy.BLITZ) {
            getBlitzRemainTime(points)
        } else {
            null
        } ?: return null
        return GameTimer(matchId, now, remainTime, remainTime, Duration.ofSeconds(8))
    }

    private fun getBlitzRemainTime(points: Int): Duration? {
        return when (points) {
            1 -> Duration.ofSeconds(30)
            3 -> Duration.ofMinutes(3)
            5 -> Duration.ofMinutes(5)
            7 -> Duration.ofMinutes(7)
            else -> null
        }
    }
}