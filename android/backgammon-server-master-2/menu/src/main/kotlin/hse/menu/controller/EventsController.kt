package hse.menu.controller

import hse.menu.service.SseEmitterService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter

@RestController
@RequestMapping("/menu/events")
class EventsController(
    private val sseEmitterService: SseEmitterService
) {
    companion object {
        const val AUTH_USER = "auth-user"
    }

    @GetMapping
    fun subscribe(@RequestHeader(AUTH_USER) userId: Long): SseEmitter {
        return sseEmitterService.subscribe(userId)
    }
}