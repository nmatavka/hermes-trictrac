package hse.menu.service

import game.backgammon.request.CreateGameRequest
import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy
import hse.menu.dto.*
import hse.menu.enums.GameStatus
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.server.ResponseStatusException
import player.InvitePolicy
import java.time.Clock
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

@Service
class MenuService(
    private val connectionService: ConnectionService,
    private val gameService: GameService,
    private val playerService: PlayerService,
    @Value("\${disable-job}") isTest: Boolean = false,
    @Value("\${app.search-job.timeout}") val searchJobTimeout: Long,
    private val sseEmitterService: SseEmitterService,
    private val clock: Clock
) {

    private final val logger = LoggerFactory.getLogger(MenuService::class.java)


    private var executor: ExecutorService = Executors.newVirtualThreadPerTaskExecutor()

    init {
        if (!isTest) {
            TimePolicy.entries.forEach { timePolicy ->
                GameType.entries.forEach { type ->
                    GammonGamePoints.entries.forEach { points ->
                        executor.execute { connectionJob(type, points, timePolicy) }
                    }
                }
            }
        }
    }

    fun connect(userId: Long, request: CreateGameRequest): Int {
        val points = GammonGamePoints.of(request.points) ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST)
        val userRating = playerService.getUserRating(userId, request.type, request.timePolicy)
        logger.info("connect: $userId, userRating: $userRating")
        val connectionDto = ConnectionDto(userId, CountDownLatch(1), request.type, userRating.toInt())
        connectionService.connect(connectionDto, points, request.timePolicy)
        connectionDto.latch.await()
        return connectionDto.gameId ?: throw ResponseStatusException(
            HttpStatus.CONFLICT,
            "Упал коннект - очередь поиска не отдала id игры"
        )
    }

    fun disconnect(userId: Long) {
        connectionService.disconnect(userId)
    }

    private fun connectionJob(gameType: GameType, points: GammonGamePoints, timePolicy: TimePolicy) {
        while (true) {
            val connections = connectionService.take(gameType, points, timePolicy)
                .sortedBy { it.userRating }
            if (connections.isNotEmpty()) {
                logger.info("Нашел $connections")
            }
            for (i in 0..<connections.size - connections.size % 2 step 2) {
                val first = connections[i]
                val second = connections[i + 1]
                connect(first, second, gameType, points, timePolicy)
            }
            if (connections.size % 2 != 0) {
                connectionService.connect(connections.last(), points, timePolicy)
            }
            if (connections.isEmpty() || connections.size == 1) {
                Thread.sleep(searchJobTimeout)
            }
        }
    }

    private fun connect(
        firstPlayerConnection: ConnectionDto,
        secondPlayerConnection: ConnectionDto,
        gameType: GameType,
        points: GammonGamePoints,
        timePolicy: TimePolicy
    ) {
        logger.info("Коннект $firstPlayerConnection, $secondPlayerConnection")
        if (connectionService.checkInBan(firstPlayerConnection.userId)) {
            firstPlayerConnection.latch.countDown()
            connectionService.connect(secondPlayerConnection, points, timePolicy)
            return
        }
        if (connectionService.checkInBan(secondPlayerConnection.userId)) {
            firstPlayerConnection.latch.countDown()
            connectionService.connect(firstPlayerConnection, points, timePolicy)
            return
        }
        if (firstPlayerConnection.userId == secondPlayerConnection.userId) {
            firstPlayerConnection.latch.countDown()
            connectionService.connect(firstPlayerConnection, points, timePolicy)
            return
        }
        val game = gameService.storeGame(
            gameType,
            points,
            timePolicy,
            firstPlayerConnection.userId,
            secondPlayerConnection.userId
        )
        if (game == null) {
            logger.warn("Не удалось сгенерить игру")
            firstPlayerConnection.latch.countDown()
            secondPlayerConnection.latch.countDown()
            return
        }
        firstPlayerConnection.gameId = game.id.toInt()
        secondPlayerConnection.gameId = game.id.toInt()
        firstPlayerConnection.latch.countDown()
        secondPlayerConnection.latch.countDown()
    }

    @Transactional
    fun invite(fromUser: Long, toUser: Long, createGameRequest: CreateGameRequest) {
        if (fromUser == toUser) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cant invite yourself")
        }
        val game = getLastInviteGame(fromUser)
        if (game != null && game.opponentUserInfo?.id != toUser) {
            throw ResponseStatusException(HttpStatus.UNPROCESSABLE_ENTITY, "Cant refresh invite")
        }
        if (game != null) {
            gameService.updateGameTime(game, fromUser, toUser)
            return sseEmitterService.send(
                InviteEventDto(fromUser, game.gameType, game.gamePoints.value, game.timePolicy),
                listOf(toUser)
            )
        }
        val toUserInvitePolicy = playerService.getInvitePolicy(toUser)
        if (toUserInvitePolicy == InvitePolicy.FRIENDS_ONLY && !playerService.checkIsFriends(fromUser, toUser)) {
            throw ResponseStatusException(HttpStatus.FORBIDDEN, "Cant invite user due to invite policy")
        }
        val points =
            GammonGamePoints.of(createGameRequest.points) ?: throw ResponseStatusException(HttpStatus.BAD_REQUEST)
        gameService.storeGameByInvitation(
            createGameRequest.type,
            points,

            createGameRequest.timePolicy,
            fromUser,
            toUser
        )
        sseEmitterService.send(
            InviteEventDto(fromUser, createGameRequest.type, createGameRequest.points, createGameRequest.timePolicy),
            listOf(toUser)
        )
    }

    @Transactional
    fun answerOnInvite(userId: Long, invitedBy: Long, accept: Boolean): Long {
        val game = gameService.findByPlayersAndStatus(userId, invitedBy, GameStatus.NOT_STARTED)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Invitation not found")
        if (!accept) {
            sseEmitterService.send(RejectInviteDto(userId), listOf(invitedBy))
            gameService.declineGameFromInvitation(game)
            return -1
        }
        checkHasCurrentGames(userId)
        gameService.startGame(game)
        sseEmitterService.send(AcceptInviteEventDto(userId, game.id), listOf(invitedBy))
        return game.id
    }

    @Transactional
    fun cancelInvite(userId: Long, invitedPlayer: Long) {
        val game = gameService.findByPlayersAndStatus(invitedPlayer, userId, GameStatus.NOT_STARTED)
            ?: throw ResponseStatusException(HttpStatus.NOT_FOUND, "Invitation not found")
        gameService.declineGameFromInvitation(game)
    }

    private fun getLastInviteGame(userId: Long): PlayerGame? {
        val userGames = gameService.getGamesByPlayer(userId, 0, 1)
        if (userGames.isNotEmpty()) {
            return if (userGames.first().gameStatus == GameStatus.END) {
                null
            } else {
                userGames.first()
            }
        }
        return null
    }

    private fun checkHasCurrentGames(userId: Long) {
        val userGames = gameService.getGamesByPlayer(userId, 0, 10)
        if (userGames.isNotEmpty() && userGames.find { it.gameStatus == GameStatus.IN_PROCESS } != null) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "Already has game")
        }
    }
}