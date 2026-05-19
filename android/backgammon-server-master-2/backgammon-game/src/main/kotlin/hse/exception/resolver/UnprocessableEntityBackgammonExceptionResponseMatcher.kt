package hse.exception.resolver

import game.backgammon.exception.*
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerMapping
import org.springframework.web.servlet.ModelAndView


@Component
class UnprocessableEntityBackgammonExceptionResponseMatcher : BackgammonExceptionResponseMatcher {

    companion object {
        private val unprocessableEntity = setOf(
            CantExitBackgammonException::class,
            EmptyBarBackgammonException::class,
            GameIsOverBackgammonException::class,
            IncorrectDirectionBackgammonException::class,
            IncorrectNumberOfMovesBackgammonException::class,
            IncorrectPositionForMoveBackgammonException::class,
            IncorrectTurnBackgammonException::class,
            NoSuchZarBackgammonException::class,
            NotEmptyBarBackgammonException::class,
            OutOfBoundsBackgammonException::class,
            ReTossZarBackgammonException::class,
            CantCountWinPointsGammonException::class,
        )
    }

    override fun handle(
        exception: BackgammonException,
        request: HttpServletRequest,
        response: HttpServletResponse
    ): ModelAndView? {
        if (unprocessableEntity.none { it.isInstance(exception) }) {
            return null
        }

        val pathVariables = request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE) as Map<Any, String>
        val msg = "[game id: ${pathVariables["roomId"]}] ${exception.message}"
        response.sendError(HttpStatus.UNPROCESSABLE_ENTITY.value(), msg)
        return ModelAndView().addObject("message", msg)
    }
}