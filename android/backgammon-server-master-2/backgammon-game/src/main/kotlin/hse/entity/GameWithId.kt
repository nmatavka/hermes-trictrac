package hse.entity

import hse.dto.GammonRestoreContextDto
import hse.enums.GameEntityType
import java.time.Instant

class GameWithId(
    val matchId: Int,
    val gameId: Int,
    val restoreContextDto: GammonRestoreContextDto,
    at: Instant,
) : TypedMongoEntity(GameEntityType.START_STATE, at)