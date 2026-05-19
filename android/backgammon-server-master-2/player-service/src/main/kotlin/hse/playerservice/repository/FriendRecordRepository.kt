package hse.playerservice.repository

import hse.playerservice.entity.FriendRecord
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.CrudRepository
import org.springframework.transaction.annotation.Transactional

interface FriendRecordRepository : CrudRepository<FriendRecord, Int> {

    fun existsFriendRecordByFirstUserAndSecondUser(firstUser: Long, secondUser: Long): Boolean

    @Modifying
    @Transactional
    fun deleteFriendRecordByFirstUserAndSecondUser(firstUser: Long, secondUser: Long)

    @Query(
        "select * from sch1.friend_record fr where fr.first_user = :userId or fr.second_user = :userId order by fr.id",
        nativeQuery = true
    )
    fun findAllFriends(userId: Long, pageable: Pageable): List<FriendRecord>
}