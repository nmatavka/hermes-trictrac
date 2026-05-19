package hse.playerservice.mapper

import hse.playerservice.entity.User
import hse.playerservice.entity.UserRating
import org.springframework.stereotype.Component
import player.InvitePolicy
import player.response.Rating
import player.response.UserInfoResponse

@Component
class UserMapper {
    fun toUserInfoResponse(user: User, userRating: UserRating): UserInfoResponse {
        return UserInfoResponse(
            user.id,
            user.username,
            user.login,
            InvitePolicy.ofCode(user.invitePolicyCode),
            rating = Rating(
                backgammonBlitz = userRating.backgammonBlitz,
                backgammonDefault = userRating.backgammonDefault,
                nardeBlitz = userRating.nardeBlitz,
                nardeDefault = userRating.nardeDefault,
            )
        )
    }
}