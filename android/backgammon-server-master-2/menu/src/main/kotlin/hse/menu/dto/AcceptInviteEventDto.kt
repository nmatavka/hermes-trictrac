package hse.menu.dto

import hse.menu.dto.EventType.ACCEPT_INVITE


data class AcceptInviteEventDto(
    val by: Long,
    val gameId: Long
) : SseEventDto(ACCEPT_INVITE)