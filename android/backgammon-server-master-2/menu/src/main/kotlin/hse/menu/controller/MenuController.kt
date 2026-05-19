package hse.menu.controller

import game.backgammon.request.CreateGameRequest
import game.backgammon.response.AnswerInviteResponse
import hse.menu.dto.PlayerGame
import hse.menu.service.GameService
import hse.menu.service.MenuService
import org.springframework.web.bind.annotation.*


@RestController
@RequestMapping("menu")
class MenuController(
    private val menuService: MenuService,
    private val gameService: GameService
) {
    companion object {
        const val AUTH_USER = "auth-user"
    }

    @PostMapping("connect")
    fun connect(
        @RequestHeader(AUTH_USER) user: Long,
        @RequestBody request: CreateGameRequest,
    ): Int {
        return menuService.connect(user, request)
    }

    @PostMapping("disconnect")
    fun disconnect(@RequestHeader(AUTH_USER) user: Long) {
        menuService.disconnect(user)
    }

    @GetMapping("played-games")
    fun getPlayerGames(
        @RequestParam userId: Long,
        @RequestParam pageNumber: Int,
        @RequestParam pageSize: Int
    ): List<PlayerGame> {
        return gameService.getGamesByPlayer(userId, pageNumber, pageSize)
    }

    @PostMapping("invite/{invitedPlayer}")
    fun invite(
        @RequestHeader(AUTH_USER) user: Long,
        @PathVariable invitedPlayer: Long,
        @RequestBody createGameRequest: CreateGameRequest
    ) {
        menuService.invite(user, invitedPlayer, createGameRequest)
    }

    @PostMapping("invite/cancel/{invitedPlayer}")
    fun cancelInvite(
        @RequestHeader(AUTH_USER) userId: Long,
        @PathVariable invitedPlayer: Long,
    ) {
        menuService.cancelInvite(userId, invitedPlayer)
    }

    @PostMapping("invite/answer/{invitedByPlayer}")
    fun answerOnInvite(
        @RequestHeader(AUTH_USER) user: Long,
        @PathVariable invitedByPlayer: Long,
        @RequestParam(defaultValue = "false") accept: Boolean
    ): AnswerInviteResponse {
        return AnswerInviteResponse(menuService.answerOnInvite(user, invitedByPlayer, accept))
    }
}