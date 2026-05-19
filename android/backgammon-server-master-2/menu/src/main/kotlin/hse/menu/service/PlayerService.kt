package hse.menu.service

import game.common.enums.GameType
import game.common.enums.TimePolicy
import hse.menu.adapter.PlayerAdapter
import kafka.GameEndMessage
import org.springframework.cache.annotation.Cacheable
import org.springframework.stereotype.Service
import player.InvitePolicy
import player.request.ChangeRatingRequest
import player.response.UserInfoResponse

@Service
class PlayerService(
    private val playerAdapter: PlayerAdapter,
) {
    fun getUserRating(userId: Long, gameType: GameType, timePolicy: TimePolicy): Long {
        val rating = playerAdapter.getUserInfo(userId).rating
        return (if (gameType == GameType.SHORT_BACKGAMMON) {
            if (timePolicy == TimePolicy.BLITZ) {
                rating.nardeBlitz
            } else {
                rating.nardeDefault
            }
        } else {
            if (timePolicy == TimePolicy.BLITZ) {
                rating.nardeBlitz
            } else {
                rating.nardeDefault
            }
        }).toLong()
    }

    fun getInvitePolicy(userId: Long): InvitePolicy {
        return playerAdapter.getUserInfo(userId).invitePolicy
    }

    fun checkIsFriends(firstUserId: Long, secondUserId: Long): Boolean {
        return playerAdapter.checkIsFriends(firstUserId, secondUserId).isFriends
    }


    @Cacheable("menu-user-info")
    fun getUserInfo(userId: Long): UserInfoResponse? {
        return try {
            playerAdapter.getUserInfo(userId)
        } catch (_: Exception) {
            null
        }
    }

    fun updateRating(gameEndMessage: GameEndMessage) {
        playerAdapter.updateRating(
            ChangeRatingRequest(
                winnerId = gameEndMessage.winnerId,
                loserId = gameEndMessage.loserId,
                gameType = gameEndMessage.gameType,
                gameTimePolicy = gameEndMessage.gameTimePolicy,
            )
        )
    }
}