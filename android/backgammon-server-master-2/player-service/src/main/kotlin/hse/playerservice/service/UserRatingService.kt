package hse.playerservice.service

import game.backgammon.enums.BackgammonType.REGULAR_GAMMON
import game.backgammon.enums.BackgammonType.SHORT_BACKGAMMON
import game.common.enums.TimePolicy
import hse.playerservice.entity.User
import hse.playerservice.entity.UserRating
import hse.playerservice.repository.UserRatingRepository
import hse.playerservice.service.UserService.Companion.NO_ID
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.server.ResponseStatusException
import player.request.ChangeRatingRequest
import kotlin.math.max
import kotlin.math.pow

@Service
class UserRatingService(
    val userRatingRepository: UserRatingRepository
) {
    val logger: Logger = LoggerFactory.getLogger(UserRatingService::class.java)

    companion object {
        const val DEFAULT_RATING = 100
    }

    fun createDefaultRating(user: User) {
        val userRating = UserRating(
            id = NO_ID,
            user = user,
            backgammonBlitz = DEFAULT_RATING,
            backgammonDefault = DEFAULT_RATING,
            nardeBlitz = DEFAULT_RATING,
            nardeDefault = DEFAULT_RATING,
            numberOfGames = 0
        )
        userRatingRepository.save(userRating)
    }

    fun findByUserId(id: Long): UserRating {
        return userRatingRepository.findByUserId(id)
    }

    @Transactional(propagation = Propagation.REQUIRED)
    fun changeRating(changeRatingRequest: ChangeRatingRequest) {
        val winnerRating = userRatingRepository.findByUserId(changeRatingRequest.winnerId)
        val loserRating = userRatingRepository.findByUserId(changeRatingRequest.loserId)
        val winnerCurrentRating: Int
        val loserCurrentRating: Int
        if (changeRatingRequest.gameType == REGULAR_GAMMON && changeRatingRequest.gameTimePolicy == TimePolicy.DEFAULT_TIMER) {
            winnerCurrentRating = winnerRating.nardeDefault
            loserCurrentRating = loserRating.nardeDefault
        } else if (changeRatingRequest.gameType == REGULAR_GAMMON && changeRatingRequest.gameTimePolicy == TimePolicy.BLITZ) {
            winnerCurrentRating = winnerRating.nardeBlitz
            loserCurrentRating = loserRating.nardeBlitz
        } else if (changeRatingRequest.gameType == SHORT_BACKGAMMON && changeRatingRequest.gameTimePolicy == TimePolicy.DEFAULT_TIMER) {
            winnerCurrentRating = winnerRating.backgammonDefault
            loserCurrentRating = loserRating.backgammonDefault
        } else if (changeRatingRequest.gameType == SHORT_BACKGAMMON && changeRatingRequest.gameTimePolicy == TimePolicy.BLITZ) {
            winnerCurrentRating = winnerRating.backgammonBlitz
            loserCurrentRating = loserRating.backgammonBlitz
        } else {
            throw ResponseStatusException(HttpStatus.FORBIDDEN)
        }
        val winnerExpected = getExpected(winnerCurrentRating, loserCurrentRating)
        val loserExpected = getExpected(loserCurrentRating, winnerCurrentRating)
        val winnerCoefficient = getRatingCoefficient(winnerCurrentRating, winnerRating.numberOfGames)
        val loserCoefficient = getRatingCoefficient(loserCurrentRating, loserRating.numberOfGames)
        val winnerNewRating = winnerCurrentRating + winnerCoefficient * (1 - winnerExpected)
        val loserNewRating = max(loserCurrentRating - loserCoefficient * loserExpected, DEFAULT_RATING.toDouble())
        if (changeRatingRequest.gameType == REGULAR_GAMMON && changeRatingRequest.gameTimePolicy == TimePolicy.DEFAULT_TIMER) {
            winnerRating.nardeDefault = winnerNewRating.toInt()
            loserRating.nardeDefault = loserNewRating.toInt()
        } else if (changeRatingRequest.gameType == REGULAR_GAMMON) {
            winnerRating.nardeBlitz = winnerNewRating.toInt()
            loserRating.nardeBlitz = loserNewRating.toInt()
        } else if (changeRatingRequest.gameTimePolicy == TimePolicy.DEFAULT_TIMER) {
            winnerRating.backgammonDefault = winnerNewRating.toInt()
            loserRating.backgammonDefault = loserNewRating.toInt()
        } else {
            winnerRating.backgammonBlitz = winnerNewRating.toInt()
            loserRating.backgammonBlitz = loserNewRating.toInt()
        }
        winnerRating.numberOfGames += 1
        loserRating.numberOfGames += 1
        userRatingRepository.saveAllAndFlush(mutableListOf(winnerRating, loserRating))
    }

    private fun getExpected(playerRating: Int, opponentRating: Int): Double {
        return 1.0 / (1 + 10.0.pow(((opponentRating - playerRating) / 400.0)))
    }

    private fun getRatingCoefficient(currentRating: Int, numberOfGame: Int): Long {
        return if (currentRating >= 2400) {
            10
        } else if (numberOfGame < 30) {
            40
        } else {
            20
        }
    }
}