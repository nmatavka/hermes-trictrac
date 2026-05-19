package hse.menu.entity

import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy
import hse.menu.enums.GameStatus
import jakarta.persistence.*
import java.time.OffsetDateTime

@Entity
@Table(
    schema = "menu", name = "game",
)
data class Game(
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = -1,
    val gameType: GameType,
    val gamePoints: GammonGamePoints,
    val timePolicy: TimePolicy,
    val firstPlayerId: Long,
    val secondPlayerId: Long,
    var status: GameStatus,
    var winnerId: Long? = null,
    val expirationTime: OffsetDateTime? = null,
)