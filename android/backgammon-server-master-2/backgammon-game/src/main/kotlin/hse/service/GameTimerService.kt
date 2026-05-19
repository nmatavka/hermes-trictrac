package hse.service

import game.backgammon.enums.Color
import game.common.enums.TimePolicy
import hse.dao.GameTimerDao
import hse.entity.GameTimer
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException
import java.time.Clock
import java.time.Duration
import java.time.Duration.between

@Service
class GameTimerService(
    private val gameTimerDao: GameTimerDao,
    private val clock: Clock,
) {
    fun saveGet(
        matchId: Int,
        timePolicy: TimePolicy,
        turn: Color,
        onOutOfTime: (GameTimer) -> Unit
    ): GameTimer? {
        return try {
            validateAndGet(matchId, timePolicy, turn, onOutOfTime)
        } catch (_: ResponseStatusException) {
            null
        }
    }

    fun validateAndGet(
        matchId: Int,
        timePolicy: TimePolicy,
        turn: Color,
        onOutOfTime: (GameTimer) -> Unit
    ): GameTimer? {
        if (timePolicy == TimePolicy.NO_TIMER) {
            return null
        }
        val now = clock.instant()
        val gameTimer =
            gameTimerDao.getByMatchId(matchId) ?: throw ResponseStatusException(HttpStatus.FORBIDDEN, "Out of time")
        val actionTime = between(gameTimer.lastAction, now)

        if (turn == Color.BLACK && actionTime.toMillis() > gameTimer.remainBlackTime.toMillis()) {
            gameTimer.remainBlackTime = Duration.ZERO
            handleOutOfTime(matchId, gameTimer, onOutOfTime)
        } else if (turn == Color.WHITE && actionTime.toMillis() > gameTimer.remainWhiteTime.toMillis()) {
            gameTimer.remainWhiteTime = Duration.ZERO
            handleOutOfTime(matchId, gameTimer, onOutOfTime)
        }
        return gameTimer
    }

    fun update(matchId: Int, currentTurn: Color, gameTimer: GameTimer) {
        val now = clock.instant()
        if (currentTurn == Color.WHITE) {
            val remainTime = gameTimer.remainWhiteTime.minus(between(gameTimer.lastAction, now))
            gameTimer.remainWhiteTime = remainTime.plus(gameTimer.increment)
        } else {
            val remainTime = gameTimer.remainBlackTime.minus(between(gameTimer.lastAction, now))
            gameTimer.remainBlackTime = remainTime.plus(gameTimer.increment)
        }
        gameTimer.lastAction = now
        gameTimerDao.setByMatchId(matchId, gameTimer)
    }

    fun actualize(matchId: Int, currentTurn: Color, gameTimer: GameTimer) {
        val now = clock.instant()
        if (currentTurn == Color.WHITE) {
            val remainTime = gameTimer.remainWhiteTime.minus(between(gameTimer.lastAction, now))
            gameTimer.remainWhiteTime = remainTime
        } else {
            val remainTime = gameTimer.remainBlackTime.minus(between(gameTimer.lastAction, now))
            gameTimer.remainBlackTime = remainTime
        }
        gameTimer.lastAction = now
        gameTimerDao.setByMatchId(matchId, gameTimer)
    }

    fun save(matchId: Int, gameTimer: GameTimer?) {
        if (gameTimer != null) {
            gameTimerDao.setByMatchId(matchId, gameTimer)
        }
    }

    fun getAllTimers(): List<GameTimer> {
        return gameTimerDao.getAll()
    }

    private fun handleOutOfTime(matchId: Int, gameTimer: GameTimer, onOutOfTime: (GameTimer) -> Unit) {
        onOutOfTime(gameTimer)
        gameTimerDao.deleteByMatchId(matchId)
        throw ResponseStatusException(HttpStatus.FORBIDDEN, "Out of time")
    }
}