package hse.menu.service

import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy
import hse.menu.adapter.GameAdapter
import hse.menu.dao.GameDao
import hse.menu.dto.PlayerGame
import hse.menu.entity.Game
import hse.menu.enums.GameStatus
import kafka.GameEndMessage
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.OffsetDateTime

@Service
class GameService(
    private val gameDao: GameDao,
    private val gameAdapter: GameAdapter,
    private val playerService: PlayerService,
    private val clock: Clock,
) {
    companion object {
        const val EXPIRATION_MINUTES: Long = 10
    }

    fun storeGame(
        gameType: GameType,
        gamePoints: GammonGamePoints,
        timePolicy: TimePolicy,
        firstPlayerId: Long,
        secondPlayerId: Long
    ): Game? {
        var game = Game(
            gameType = gameType,
            gamePoints = gamePoints,
            timePolicy = timePolicy,
            firstPlayerId = firstPlayerId,
            secondPlayerId = secondPlayerId,
            status = GameStatus.NOT_STARTED,
        )
        game = gameDao.save(game)
        gameAdapter.gameCreation(game) ?: return null
        game.status = GameStatus.IN_PROCESS
        return gameDao.save(game)
    }

    fun storeGameByInvitation(
        gameType: GameType,
        gamePoints: GammonGamePoints,
        timePolicy: TimePolicy,
        firstPlayerId: Long,
        secondPlayerId: Long
    ): Game {
        val game = Game(
            gameType = gameType,
            gamePoints = gamePoints,
            timePolicy = timePolicy,
            firstPlayerId = firstPlayerId,
            secondPlayerId = secondPlayerId,
            status = GameStatus.NOT_STARTED,
            expirationTime = OffsetDateTime.now(clock).plusMinutes(EXPIRATION_MINUTES)
        )
        return gameDao.save(game)
    }

    fun updateGameTime(
        playerGame: PlayerGame,
        firstPlayerId: Long,
        secondPlayerId: Long,
    ): Game {
        val game = Game(
            id = playerGame.gameId,
            gameType = playerGame.gameType,
            gamePoints = playerGame.gamePoints,
            timePolicy = playerGame.timePolicy,
            firstPlayerId = firstPlayerId,
            secondPlayerId = secondPlayerId,
            status = playerGame.gameStatus,
            expirationTime = OffsetDateTime.now(clock).plusMinutes(EXPIRATION_MINUTES)
        )
        return gameDao.save(game)
    }

    fun startGame(game: Game) {
        gameAdapter.gameCreation(game) ?: return
        game.status = GameStatus.IN_PROCESS
        gameDao.save(game)
    }

    fun declineGameFromInvitation(game: Game) {
        gameDao.deleteAllById(listOf(game.id))
    }

    @Transactional
    fun handleGameEnd(gameEndMessage: GameEndMessage) {
        val game = gameDao.findById(gameEndMessage.matchId).orElse(null) ?: return
        game.winnerId = gameEndMessage.winnerId
        game.status = GameStatus.END
        gameDao.save(game)
        playerService.updateRating(gameEndMessage)
    }

    fun getGamesByPlayer(playerId: Long, pageNumber: Int, pageSize: Int): List<PlayerGame> {
        val pageable = PageRequest.of(pageNumber, pageSize, Sort.Direction.DESC, "id")
        val games = gameDao.findAll(pageable)
        return games.toList().map {
            PlayerGame(
                it.id,
                it.status,
                it.timePolicy,
                it.gameType,
                it.gamePoints,
                playerService.getUserInfo(it.firstPlayerId + it.secondPlayerId - playerId)
            )
        }
    }

    fun findByPlayersAndStatus(invitedUser: Long, invitedBy: Long, status: GameStatus): Game? {
        return gameDao.findByFirstPlayerIdAndSecondPlayerIdAndStatus(invitedBy, invitedUser, status).firstOrNull()
    }
}
