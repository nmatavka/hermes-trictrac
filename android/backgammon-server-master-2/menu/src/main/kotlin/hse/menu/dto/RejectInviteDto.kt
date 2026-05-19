package hse.menu.dto

data class RejectInviteDto(
    val by: Long
) : SseEventDto(EventType.REJECT_INVITE)