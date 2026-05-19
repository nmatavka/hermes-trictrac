package hse.entity

import hse.enums.GameEntityType
import java.time.Instant

class MoveWithId(
    val matchId: Int,
    val gameId: Int,
    val moveSet: MoveSet,
    at: Instant
) : TypedMongoEntity(GameEntityType.MOVE, at)