package player.request

import com.fasterxml.jackson.annotation.JsonSubTypes
import com.fasterxml.jackson.annotation.JsonTypeInfo
import game.backgammon.enums.BackgammonType
import game.common.enums.GameType
import game.common.enums.TimePolicy
import player.InvitePolicy

data class AuthRequest(
    val login: String,
    val password: String
)


data class JwtRequest(
    val accessToken: String,
    val token: String
)

data class ChangePasswordRequest(
    val oldPassword: String,
    val newPassword: String
)

data class DeleteUserRequest(
    val password: String
)

data class CreateUserRequest(
    val login: String,
    val password: String,
    val username: String = login,
)

@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.EXISTING_PROPERTY, property = "type")
@JsonSubTypes(
    value =
    [
        JsonSubTypes.Type(value = AddFriendRequest.AddFriendByLogin::class, name = "BY_LOGIN"),
        JsonSubTypes.Type(value = AddFriendRequest.AddFriendById::class, name = "BY_ID")
    ]
)
open class AddFriendRequest(
    val type: AddType
) {
    enum class AddType {
        BY_ID,
        BY_LOGIN
    }

    data class AddFriendById(val friendId: Long) : AddFriendRequest(AddType.BY_ID)
    data class AddFriendByLogin(val friendLogin: String) : AddFriendRequest(AddType.BY_LOGIN)
}


@JsonTypeInfo(use = JsonTypeInfo.Id.NAME, include = JsonTypeInfo.As.EXISTING_PROPERTY, property = "type")
@JsonSubTypes(
    value =
    [
        JsonSubTypes.Type(value = RemoveFriendRequest.RemoveFriendByLogin::class, name = "BY_LOGIN"),
        JsonSubTypes.Type(value = RemoveFriendRequest.RemoveFriendById::class, name = "BY_ID")
    ]
)
open class RemoveFriendRequest(
    val type: RemoveType
) {
    enum class RemoveType {
        BY_ID,
        BY_LOGIN
    }

    data class RemoveFriendById(val friendId: Long) : RemoveFriendRequest(RemoveType.BY_ID)
    data class RemoveFriendByLogin(val friendLogin: String) : RemoveFriendRequest(RemoveType.BY_LOGIN)
}

data class UpdateUserInfoRequest(
    val login: String?,
    val username: String?,
    val invitePolicy: InvitePolicy?
)

data class ChangeRatingRequest(
    val winnerId: Long,
    val loserId: Long,
    val gameType: BackgammonType,
    val gameTimePolicy: TimePolicy
)