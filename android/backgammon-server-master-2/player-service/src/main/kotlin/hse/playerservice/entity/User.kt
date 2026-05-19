package hse.playerservice.entity

import jakarta.persistence.*
import player.InvitePolicy

@Entity
@Table(
    schema = "sch1", name = "\"user\"",
    uniqueConstraints = [
        UniqueConstraint(columnNames = ["login"]),
    ],
)
data class User(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long,
    val login: String,
    val username: String,
    val password: String,
    val invitePolicyCode: Int = InvitePolicy.ALL.code,
)