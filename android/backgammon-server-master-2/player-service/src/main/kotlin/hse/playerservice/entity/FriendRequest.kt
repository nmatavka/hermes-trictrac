package hse.playerservice.entity

import jakarta.persistence.*
import java.time.Instant

@Entity
@Table(
    name = "friend_request", schema = "sch1",
    uniqueConstraints = [UniqueConstraint(columnNames = ["from", "to"])]
)
data class FriendRequest(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long,
    @Column(name = "\"from\"")
    val from: Long,
    @Column(name = "\"to\"")
    val to: Long,
    @Column(name = "created_at")
    val createdAt: Instant,
)