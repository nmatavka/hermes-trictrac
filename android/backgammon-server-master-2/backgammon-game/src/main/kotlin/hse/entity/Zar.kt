package hse.entity

import hse.enums.GameEntityType
import java.time.Instant

class Zar(
    val gameId: Int,
    val moveId: Int,
    val z: List<Int>,
    at: Instant
) : TypedMongoEntity(GameEntityType.ZAR, at)