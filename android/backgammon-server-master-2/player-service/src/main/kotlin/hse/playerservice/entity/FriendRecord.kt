package hse.playerservice.entity

import jakarta.persistence.*
import java.time.Instant

@Entity
@Table(name = "friend_record", schema = "sch1")
data class FriendRecord(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long,
    val firstUser: Long,
    val secondUser: Long,
    val createdAt: Instant,
)