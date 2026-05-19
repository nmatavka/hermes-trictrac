package hse.playerservice.controller

import hse.playerservice.service.UserRatingService
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RestController
import player.request.ChangeRatingRequest

@RestController
class UserRatingController(private val userRatingService: UserRatingService) {
    @PostMapping("rating")
    fun updateRating(@RequestBody changeRatingRequest: ChangeRatingRequest) {
        userRatingService.changeRating(changeRatingRequest)
    }
}