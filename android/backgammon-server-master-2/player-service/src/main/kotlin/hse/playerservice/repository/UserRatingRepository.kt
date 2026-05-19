package hse.playerservice.repository

import hse.playerservice.entity.UserRating
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface UserRatingRepository : JpaRepository<UserRating, Int> {
    fun findByUserId(userId: Long): UserRating
}