package hse.facade

import game.backgammon.dto.MoveDto
import game.backgammon.dto.MoveResponseDto
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import game.backgammon.enums.Color.BLACK
import game.backgammon.enums.Color.WHITE
import game.backgammon.enums.DoubleCubePositionEnum
import game.backgammon.lng.RegularGammonGame
import game.backgammon.request.CreateBackgammonGameRequest
import game.backgammon.response.ConfigResponse
import game.backgammon.response.MoveResponse
import game.backgammon.sht.ShortGammonGame
import hse.dto.*
import hse.entity.DoubleCube
import hse.entity.GameTimer
import hse.factory.GameTimerFactory
import hse.producer.GameEndMessageProducer
import hse.service.DoubleCubeService
import hse.service.EmitterService
import hse.service.GameTimerService
import hse.service.GammonStoreService
import hse.wrapper.BackgammonWrapper
import kafka.GameEndMessage
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException
import java.time.Duration
import kotlin.math.pow

@Service
class GameFacade(
    private val emitterService: EmitterService,
    private val gammonStoreService: GammonStoreService,
    private val doubleCubeService: DoubleCubeService,
    private val timerService: GameTimerService,
    private val gameTimerFactory: GameTimerFactory,
    private val gameEndMessageProducer: GameEndMessageProducer
) {
    private val logger: Logger = LoggerFactory.getLogger(this::class.java)

    fun createAndConnect(matchId: Int, request: CreateBackgammonGameRequest): Int {
        val game = createMatch(matchId, request)
        val timer = gameTimerFactory.getTimer(matchId, request.points, request.timePolicy)
        game.connect(request.firstUserId, request.secondUserId)
        gammonStoreService.saveGameOnCreation(matchId, 1, game)
        timerService.save(matchId, timer)
        emitterService.sendForAll(
            matchId,
            GameStartedEvent(timer?.remainBlackTime?.toMillis(), timer?.remainWhiteTime?.toMillis())
        )
        return matchId
    }

    fun moveInGame(matchId: Int, playerId: Int, moves: List<MoveDto>): MoveResponse {
        val game = gammonStoreService.getMatchById(matchId)
        checkGameState(game)
        val timer = getTimer(matchId, game)
        val res = game.move(playerId, moves)
        val playerColor = game.getPlayerColor(playerId)
        val response = MoveResponse(
            moves = res.changes.map { MoveResponseDto(it.first, it.second) },
            color = playerColor,
        )
        gammonStoreService.saveAfterMove(matchId, game.gameId, playerId, game, res)
        if (timer != null) {
            timerService.update(matchId, game.getCurrentTurn(), timer)
        }
        emitterService.sendEventExceptUser(
            playerId,
            matchId,
            MoveEvent(
                response.moves,
                playerColor,
                timer?.remainBlackTime?.toMillis(),
                timer?.remainWhiteTime?.toMillis()
            )
        )
        if (game.checkEnd()) {
            handleGameEnd(matchId, game, timer)
        }
        return response
    }

    fun tossZar(matchId: Int, userId: Int) {
        val fullGame = getMatchById(matchId)
        val game = fullGame.game
        checkGameState(game)
        val timer = getTimer(matchId, game)
        val doubles = fullGame.doubleCubes
        if (doubles.isNotEmpty()) {
            if (!doubles.last().isAccepted) {
                throw ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "there is no response on double request")
            }
        }
        val res = game.tossZar(userId)
        gammonStoreService.storeZar(
            matchId,
            game,
            res.value,
        )
        if (timer != null) {
            timerService.update(matchId, game.getCurrentTurn(), timer)
        }
        emitterService.sendForAll(
            matchId,
            TossZarEvent(
                res.value,
                game.getPlayerColor(userId),
                timer?.remainBlackTime?.toMillis(),
                timer?.remainWhiteTime?.toMillis()
            )
        )
    }

    fun getConfiguration(userId: Int, matchId: Int): ConfigResponse {
        val fullGame = getMatchById(matchId)
        var game = fullGame.game
        val timer: GameTimer? = try {
            getTimer(matchId, game)
        } catch (_: ResponseStatusException) {
            game = getMatchById(matchId).game
            game.setPossibleEndFlag(true)
            null
        }
        val configData = game.getConfiguration(userId)
        val doubleCubes = fullGame.doubleCubes
        val doubleCubePosition = doubleCubeService.getDoubleCubePosition(matchId, game, doubleCubes)
        val doubleCubeValue =
            if (doubleCubePosition == DoubleCubePositionEnum.UNAVAILABLE) null else 2.0.pow(doubleCubes.size.toDouble())
                .toInt()
        val winner = if (game.checkEnd()) gammonStoreService.getWinnersInMatch(matchId).last() else null
        if (timer != null) {
            timerService.actualize(matchId, game.getCurrentTurn(), timer)
        }
        return ConfigResponse(
            gameData = configData,
            blackPoints = game.blackPoints,
            whitePoints = game.whitePoints,
            threshold = game.thresholdPoints,
            players = game.getPlayers(),
            doubleCubeValue = doubleCubeValue,
            doubleCubePosition = doubleCubePosition,
            winner = winner,
            remainWhiteTime = timer?.remainWhiteTime?.toMillis() ?: 0,
            remainBlackTime = timer?.remainBlackTime?.toMillis() ?: 0,
            increment = timer?.increment?.toMillis() ?: 0,
        )
    }

    fun safeCheckTimeOut(matchId: Int): Boolean {
        val game = getMatchById(matchId).game
        try {
            timerService.validateAndGet(matchId, game.timePolicy, game.getCurrentTurn()) { timer ->
                handleOutOfTime(matchId, game, timer)
            }
        } catch (e: ResponseStatusException) {
            if (e.statusCode == HttpStatus.FORBIDDEN) {
                return true
            }
        }
        return false
    }

    fun checkTimeOut(matchId: Int) {
        if (!safeCheckTimeOut(matchId)) {
            throw ResponseStatusException(HttpStatus.TOO_EARLY, "Game not ended")
        }
    }

    private fun createMatch(roomId: Int, request: CreateBackgammonGameRequest): BackgammonWrapper {
        if (gammonStoreService.checkMatchExists(roomId)) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "Game $roomId already exists")
        }
        val gameType = request.type
        val game = when (gameType) {
            BackgammonType.SHORT_BACKGAMMON -> ShortGammonGame()
            BackgammonType.REGULAR_GAMMON -> RegularGammonGame()
        }
        return BackgammonWrapper(
            game = game,
            type = gameType,
            blackPoints = 0,
            whitePoints = 0,
            thresholdPoints = request.points,
            gameId = 1,
            timePolicy = request.timePolicy
        )
    }

    fun getGamesCountInMatch(matchId: Int): Int {
        return gammonStoreService.getAllGamesId(matchId).size
    }

    fun handleGameEnd(roomId: Int, wrapper: BackgammonWrapper, timer: GameTimer?) {
        val endState = wrapper.gameEndStatus()
        val doubles = doubleCubeService.getAllDoubles(roomId, wrapper.gameId).count { it.isAccepted }
        val winner = endState[true]!!
        val winnerPoints = wrapper.getPointsForGame() * 2.0.pow(doubles).toInt()
        addPointsToWinner(wrapper, winnerPoints, winner)
        val endMatch = wrapper.blackPoints >= wrapper.thresholdPoints || wrapper.whitePoints >= wrapper.thresholdPoints
        afterGameEnd(endMatch, wrapper, roomId, winner, timer, winnerPoints, false)
    }

    fun surrender(userId: Int, matchId: Int, surrenderMatch: Boolean) {
        val fullGame = getMatchById(matchId)
        val game = fullGame.game
        checkGameState(game)
        val timer = getTimer(matchId, game)
        val surrenderedColor = game.getPlayerColor(userId)
        val winnerColor = surrenderedColor.getOpponent()
        if (surrenderMatch) {
            logger.info("surrender match $matchId")
            return afterGameEnd(
                endMatch = true,
                game = game,
                matchId = matchId,
                winner = winnerColor,
                timer = timer,
                winnerPoints = 0,
                isSurrender = true
            )
        }
        val doubles = fullGame.doubleCubes
        val winnerPoints = 2.0.pow(doubles.count { it.isAccepted }).toInt()
        addPointsToWinner(game, winnerPoints, winnerColor)
        val endMatch = game.blackPoints >= game.thresholdPoints
                || game.whitePoints >= game.thresholdPoints
        validateSurrender(matchId, userId, surrenderedColor, game, doubles, endMatch)
        afterGameEnd(endMatch, game, matchId, winnerColor, timer, winnerPoints, true)
    }

    private fun checkGameState(game: BackgammonWrapper) {
        if (game.checkEnd()) {
            throw ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Game is already end")
        }
    }

    private fun addPointsToWinner(game: BackgammonWrapper, points: Int, winner: Color) {
        if (winner == BLACK) {
            game.blackPoints += points
        } else {
            game.whitePoints += points
        }
    }

    private fun validateSurrender(
        matchId: Int,
        userId: Int,
        surrenderColor: Color,
        game: BackgammonWrapper,
        doubles: List<DoubleCube>,
        endMatch: Boolean
    ) {
        if (endMatch) {
            return
        }
        val doubleCubePosition = doubleCubeService.getDoubleCubePosition(matchId, game, doubles)
        val hasInStore = game.hasInStore(userId)
        if (hasInStore && doubleCubePosition == DoubleCubePositionEnum.UNAVAILABLE) {
            return
        }
        if (hasInStore && surrenderColor == BLACK && doubleCubePosition == DoubleCubePositionEnum.BELONGS_TO_BLACK) {
            return
        }
        if (hasInStore && surrenderColor == WHITE && doubleCubePosition == DoubleCubePositionEnum.BELONGS_TO_WHITE) {
            return
        }
        if (doubles.isEmpty() || doubles.last().isAccepted || doubles.last().by == surrenderColor) {
            throw ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "cant surrender")
        } else {
            return
        }
    }

    private fun getTimer(matchId: Int, game: BackgammonWrapper): GameTimer? {
        val timer = timerService.validateAndGet(matchId, game.timePolicy, game.getCurrentTurn()) { timer ->
            handleOutOfTime(matchId, game, timer)
        } ?: return null
        if (timer.remainBlackTime == Duration.ZERO || timer.remainWhiteTime == Duration.ZERO) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Out of time")
        }
        return timer
    }

    private fun handleOutOfTime(matchId: Int, wrapper: BackgammonWrapper, timer: GameTimer) {
        val winner = if (timer.remainBlackTime == Duration.ZERO) WHITE else BLACK
        afterGameEnd(
            endMatch = true,
            game = wrapper,
            matchId = matchId,
            winner = winner,
            timer = timer,
            winnerPoints = 0,
            isSurrender = false
        )
    }

    fun doubleCube(matchId: Int, userId: Int) {
        val game = gammonStoreService.getMatchById(matchId)
        val gameTimer = getTimer(matchId, game)
        doubleCubeService.doubleCube(matchId, userId, game, gameTimer)
        if (gameTimer != null) {
            timerService.update(matchId, game.getCurrentTurn(), gameTimer)
        }
    }

    fun acceptDouble(matchId: Int, userId: Int) {
        val fullGame = getMatchById(matchId)
        val game = fullGame.game
        val turn = game.getCurrentTurn().getOpponent()
        val gameTimer = getTimer(matchId, game)
        doubleCubeService.acceptDouble(matchId, userId, game, gameTimer, fullGame.doubleCubes)
        if (gameTimer != null) {
            timerService.update(matchId, turn, gameTimer)
        }
    }

    private fun getMatchById(matchId: Int): GameWithDoubleCubes {
        val game = gammonStoreService.getMatchById(matchId)
        val doubleCubes = doubleCubeService.getAllDoubles(matchId, game.gameId)
        if (doubleCubes.isNotEmpty() && !doubleCubes.last().isAccepted) {
            game.invertTurn()
        }
        return GameWithDoubleCubes(game, doubleCubes)
    }

    private fun updateGameStatusAndRating(matchId: Int, wrapper: BackgammonWrapper, winner: Color) {
        val players = wrapper.getPlayers()
        gameEndMessageProducer.sendMessage(
            GameEndMessage(
                matchId = matchId.toLong(),
                winnerId = players[winner]!!.toLong(),
                loserId = players[winner.getOpponent()]!!.toLong(),
                gameType = wrapper.type,
                gameTimePolicy = wrapper.timePolicy,
            )
        )

    }

    private fun afterGameEnd(
        endMatch: Boolean,
        game: BackgammonWrapper,
        matchId: Int,
        winner: Color,
        timer: GameTimer?,
        winnerPoints: Int,
        isSurrender: Boolean
    ) {
        gammonStoreService.endGame(winner, matchId, game, winnerPoints, endMatch, isSurrender)
        if (!endMatch) {
            game.restore()
            gammonStoreService.saveGameOnCreation(matchId, game.gameId, game)
        } else {
            updateGameStatusAndRating(matchId, game, winner)
        }
        emitterService.sendForAll(
            matchId, EndGameEvent(
                win = winner,
                blackPoints = game.blackPoints,
                whitePoints = game.whitePoints,
                isMatchEnd = endMatch,
                remainBlackTime = timer?.remainBlackTime?.toMillis(),
                remainWhiteTime = timer?.remainWhiteTime?.toMillis()
            )
        )
    }
}
