package hse.exception.resolver

import game.backgammon.exception.BackgammonException
import game.backgammon.exception.IncorrectInputtedUserBackgammonException
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerMapping
import org.springframework.web.servlet.ModelAndView

@Component
class InternalBackgammonExceptionResponseMatcher : BackgammonExceptionResponseMatcher {
    companion object {
        private val internalExceptions = setOf(IncorrectInputtedUserBackgammonException::class)
    }

    override fun handle(
        exception: BackgammonException,
        request: HttpServletRequest,
        response: HttpServletResponse,
    ): ModelAndView? {
        if (internalExceptions.none { it.isInstance(exception) }) {
            return null
        }

        val pathVariables = request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE) as Map<Any, String>
        val msg = "[game id: ${pathVariables["roomId"]}] ${exception.message}"
        response.sendError(HttpStatus.INTERNAL_SERVER_ERROR.value(), msg)
        return ModelAndView().addObject("message", msg)
    }
}