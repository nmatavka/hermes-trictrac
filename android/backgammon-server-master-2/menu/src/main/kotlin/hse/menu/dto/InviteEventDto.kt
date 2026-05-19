package hse.menu.dto

import game.common.enums.GameType
import game.common.enums.TimePolicy
import hse.menu.dto.EventType.INVITE

data class InviteEventDto(
    val by: Long,
    val gameType: GameType,
    val points: Int,
    val timePolicy: TimePolicy,
) : SseEventDto(INVITE)