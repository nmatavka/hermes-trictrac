package hse.playerservice.repository

import hse.playerservice.entity.User
import jakarta.transaction.Transactional
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param

interface UserRepository : JpaRepository<User, Long> {
    fun findByLogin(login: String): User?

    fun existsByLogin(login: String): Boolean

    @Query("update sch1.\"user\" u set invite_policy = :newPolicy where u.id = :userId", nativeQuery = true)
    @Modifying
    @Transactional
    fun changePolicy(userId: Long, newPolicy: String)
}