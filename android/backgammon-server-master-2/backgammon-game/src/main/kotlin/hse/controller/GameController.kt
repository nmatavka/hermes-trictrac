package hse.controller

import game.backgammon.enums.Color
import game.backgammon.request.CreateBackgammonGameRequest
import game.backgammon.request.MoveRequest
import game.backgammon.response.ConfigResponse
import game.backgammon.response.HistoryResponse
import game.backgammon.response.MoveResponse
import hse.service.EmitterService
import hse.facade.GameFacade
import hse.service.GameHistoryService
import jakarta.servlet.http.HttpServletResponse
import org.springframework.web.bind.annotation.*
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter


@RestController
@RequestMapping("backgammon")
class GameController(
    private val gameFacade: GameFacade,
    private val gameHistoryService: GameHistoryService,
    private val emitterService: EmitterService,
) {

    companion object {
        private const val USER_ID_HEADER = "auth-user"
    }

    @PostMapping("create-room/{roomId}")
    fun createGameRoom(
        @PathVariable roomId: Int,
        @RequestBody request: CreateBackgammonGameRequest
    ): Int {
        return gameFacade.createAndConnect(roomId, request)
    }

    @GetMapping("config/{roomId}")
    fun getConfiguration(
        @RequestHeader(USER_ID_HEADER) user: Int,
        @PathVariable("roomId") roomId: Int
    ): ConfigResponse {
        return gameFacade.getConfiguration(user, roomId)
    }

    @PostMapping("move/{roomId}")
    fun move(
        @RequestHeader(USER_ID_HEADER) userId: Int,
        @PathVariable roomId: Int,
        @RequestBody request: MoveRequest
    ): MoveResponse {
        return gameFacade.moveInGame(roomId, userId, request.moves)
    }

    @PostMapping("zar/{roomId}")
    fun tossZar(@RequestHeader(USER_ID_HEADER) userId: Int, @PathVariable roomId: Int) {
        gameFacade.tossZar(roomId, userId)
    }

    @PostMapping("/double/{roomId}")
    fun double(@RequestHeader(USER_ID_HEADER) userId: Int, @PathVariable roomId: Int) {
        gameFacade.doubleCube(roomId, userId)
    }

    @PostMapping("/double/accept/{roomId}")
    fun acceptDouble(@RequestHeader(USER_ID_HEADER) userId: Int, @PathVariable roomId: Int) {
        gameFacade.acceptDouble(roomId, userId)
    }

    @GetMapping("view/{roomId}")
    fun connectView(
        @RequestHeader(USER_ID_HEADER) userId: Int,
        @PathVariable roomId: Int,
        httpServletResponse: HttpServletResponse
    ): SseEmitter {
        return emitterService.create(roomId, userId)
    }

    @GetMapping("/{matchId}/count")
    fun getNumberOfGames(@PathVariable matchId: Int): Int {
        return gameFacade.getGamesCountInMatch(matchId)
    }

    @GetMapping("history/{matchId}")
    fun getHistory(
        @RequestHeader(USER_ID_HEADER) userId: Int,
        @PathVariable matchId: Int,
        @RequestParam(required = false) gameId: Int? = null
    ): HistoryResponse {
        return if (gameId == null) {
            gameHistoryService.getLastGameHistory(matchId)
        } else {
            gameHistoryService.getHistory(matchId, gameId)
        }
    }

    @GetMapping("analysis/{matchId}")
    fun getAnalysis(
        @RequestHeader(USER_ID_HEADER) userId: Int,
        @PathVariable matchId: Int,
    ): Any {
        return gameHistoryService.getAnalysis(matchId)
    }

    @PostMapping("surrender/{matchId}")
    fun surrender(
        @RequestHeader(USER_ID_HEADER) userId: Int,
        @PathVariable matchId: Int,
        @RequestBody endMatch: Boolean
    ) {
        return gameFacade.surrender(userId, matchId, endMatch)
    }

    @PostMapping("/timeout/{matchId}")
    fun outOfTime(@RequestHeader(USER_ID_HEADER) userId: Int, @PathVariable matchId: Int) {
        return gameFacade.checkTimeOut(matchId)
    }
}