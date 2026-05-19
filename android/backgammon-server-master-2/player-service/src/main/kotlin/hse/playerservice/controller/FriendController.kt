package hse.playerservice.controller

import hse.playerservice.service.FriendService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.server.ResponseStatusException
import player.request.AddFriendRequest
import player.request.RemoveFriendRequest
import player.response.CanAddFriendResponse
import player.response.CheckFriendResponse
import player.response.GetFriendResponse

@RestController
@RequestMapping("/friends")
class FriendController(
    private val friendService: FriendService
) {

    companion object {
        const val AUTH_HEADER = "auth-user"
    }

    @PostMapping("/add")
    fun addFriend(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @RequestBody request: AddFriendRequest
    ): ResponseEntity<Void> {
        return friendService.addFriend(userId, request)
    }

    @DeleteMapping("/remove")
    fun removeFriend(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @RequestBody request: RemoveFriendRequest
    ): ResponseEntity<Void> {
        return friendService.removeFriend(userId, request)
    }

    @GetMapping
    fun getFriends(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @RequestParam offset: Int,
        @RequestParam limit: Int
    ): List<GetFriendResponse> {
        return friendService.getFriends(userId, offset, limit)
    }

    @GetMapping("/requests")
    fun getFriendRequests(@RequestHeader(AUTH_HEADER) userId: Long): List<GetFriendResponse> {
        return friendService.getFriendRequests(userId)
    }

    @GetMapping("/check")
    fun isFriend(
        @RequestHeader(AUTH_HEADER, required = false) userId: Long? = null,
        @RequestParam(required = false) firstUser: Long? = null,
        @RequestParam secondUser: Long
    ): CheckFriendResponse {
        val result = if (userId != null) {
            friendService.isFriends(userId, secondUser)
        } else if (firstUser != null) {
            friendService.isFriends(firstUser, secondUser)
        } else {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST)
        }
        return CheckFriendResponse(result)
    }

    @GetMapping("/can-add-friend/{anotherUserId}")
    fun canAddFriend(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @PathVariable("anotherUserId") anotherUserId: Long
    ): CanAddFriendResponse {
        return CanAddFriendResponse(friendService.canAddFriend(userId, anotherUserId))
    }
}