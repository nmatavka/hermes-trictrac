package hse.playerservice.repository

import hse.playerservice.entity.FriendRequest
import org.springframework.data.repository.CrudRepository

interface FriendRequestRepository : CrudRepository<FriendRequest, Long> {

    fun findFirstByFromAndTo(from: Long, to: Long): FriendRequest?

    fun findByTo(to: Long): List<FriendRequest>
}