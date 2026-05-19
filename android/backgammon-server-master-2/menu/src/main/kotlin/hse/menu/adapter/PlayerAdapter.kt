package hse.menu.adapter

import org.springframework.cloud.openfeign.FeignClient
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import player.request.ChangeRatingRequest
import player.response.CheckFriendResponse
import player.response.UserInfoResponse

@FeignClient("player-service")
interface PlayerAdapter {
    @GetMapping("/player/userinfo")
    fun getUserInfo(@RequestParam("userId") userId: Long): UserInfoResponse

    @GetMapping("/player/friends/check")
    fun checkIsFriends(
        @RequestParam("firstUser") firstUser: Long,
        @RequestParam("secondUser") secondUser: Long
    ): CheckFriendResponse

    @PostMapping("/player/rating")
    fun updateRating(
        @RequestBody changeRatingRequest: ChangeRatingRequest
    )
}