package hse.exception.resolver

import game.backgammon.exception.BackgammonException
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.stereotype.Component
import org.springframework.web.servlet.ModelAndView
import org.springframework.web.servlet.handler.AbstractHandlerExceptionResolver

@Component
class BackgammonExceptionResolver(
    val handlers: List<BackgammonExceptionResponseMatcher>
) : AbstractHandlerExceptionResolver() {

    override fun doResolveException(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any?,
        ex: Exception
    ): ModelAndView? {
        if (ex !is BackgammonException) {
            return null
        }

        return handlers.firstNotNullOf { it.handle(ex, request, response) }
    }
}