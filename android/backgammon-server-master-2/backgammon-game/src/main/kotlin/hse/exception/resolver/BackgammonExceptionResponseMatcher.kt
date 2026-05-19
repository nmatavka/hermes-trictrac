package hse.exception.resolver

import game.backgammon.exception.BackgammonException
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.web.servlet.ModelAndView

interface BackgammonExceptionResponseMatcher {
    fun handle(exception: BackgammonException, request: HttpServletRequest, response: HttpServletResponse): ModelAndView?
}