package hse.scheduler

import hse.facade.GameFacade
import hse.service.GameTimerService
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import java.time.Clock
import java.time.Duration.between

@Component
class MatchOutOfTimeScheduler(
    private val gameTimerService: GameTimerService,
    private val gameFacade: GameFacade,
    private val clock: Clock,
) {
    val logger: Logger = LoggerFactory.getLogger(this::class.java)

    @Scheduled(
        initialDelayString = "\${config.job.time-out.initial-delay}",
        fixedDelayString = "\${config.job.time-out.fixed-delay}"
    )
    fun schedule() {
        val now = clock.instant()
        gameTimerService.getAllTimers().stream()
            .filter {
                val actionTime = between(it.lastAction, now).toMillis()
                actionTime > it.remainWhiteTime.toMillis() || actionTime > it.remainBlackTime.toMillis()
            }
            .forEach {
                if (gameFacade.safeCheckTimeOut(it.matchId)) {
                    logger.info("${it.matchId} is timed out by job")
                }
            }
    }
}