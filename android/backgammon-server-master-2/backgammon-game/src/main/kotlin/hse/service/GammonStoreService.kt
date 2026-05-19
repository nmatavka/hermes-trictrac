package hse.service

import com.fasterxml.jackson.databind.ObjectMapper
import game.backgammon.dto.ChangeDto
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import game.backgammon.lng.RegularGammonGame
import game.backgammon.sht.ShortGammonGame
import hse.adapter.RedisAdapter
import hse.dao.GammonMoveDao
import hse.dto.GammonRestoreContextDto
import hse.entity.GameWinner
import hse.entity.MoveSet
import hse.entity.TypedMongoEntity
import hse.wrapper.BackgammonWrapper
import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.stereotype.Component
import org.springframework.web.server.ResponseStatusException
import java.time.Clock
import kotlin.math.absoluteValue
import kotlin.math.sign


@Component
class GammonStoreService(
    private val gammonMoveDao: GammonMoveDao,
    private val redisAdapter: RedisAdapter,
    private val objectMapper: ObjectMapper,
    private val clock: Clock,
) {
    private val logger = LoggerFactory.getLogger(GammonStoreService::class.java)

    fun getMatchById(matchId: Int): BackgammonWrapper {
        return getGameFromCache(matchId) ?: getGameFromDataBase(matchId) ?: throw ResponseStatusException(
            HttpStatus.NOT_FOUND,
            "Game $matchId not found"
        )
    }

    fun checkMatchExists(matchId: Int): Boolean {
        return redisAdapter.exists(matchId.toString()) || gammonMoveDao.checkMatchExists(matchId)
    }

    fun saveGameOnCreation(matchId: Int, gameId: Int, game: BackgammonWrapper) {
        val restoreContext = game.getRestoreContext()
        putGameToCache(matchId, restoreContext)
        gammonMoveDao.saveStartGameContext(matchId, gameId, restoreContext)
    }

    fun saveAfterMove(matchId: Int, gameId: Int, playerId: Int, game: BackgammonWrapper, moves: ChangeDto) {
        val restoreContext = game.getRestoreContext()
        restoreContext.game.zarResult = listOf()
        putGameToCache(matchId, restoreContext)
        val moveSet = MoveSet(
            moves = moves,
            gameId = gameId,
            moveId = restoreContext.numberOfMoves,
            color = game.getPlayerColor(playerId)
        )
        gammonMoveDao.saveMoves(matchId, gameId, moveSet)
    }

    fun getAllMovesInGame(matchId: Int, gameId: Int): List<MoveSet> {
        return gammonMoveDao.getMoves(matchId, gameId)
    }

    fun getStartGameContext(matchId: Int, gameId: Int): GammonRestoreContextDto? {
        return gammonMoveDao.getStartGameContext(matchId, gameId)
    }

    fun storeZar(matchId: Int, game: BackgammonWrapper, zar: List<Int>) {
        putGameToCache(matchId, game.getRestoreContext())
        gammonMoveDao.saveZar(matchId, game.gameId, game.numberOfMoves, zar)
    }

    fun getWinnersInMatch(matchId: Int): List<Color> {
        return gammonMoveDao.getWinners(matchId).sortedBy { it.gameId }.map { it.color }
    }

    fun endGame(
        winner: Color,
        matchId: Int,
        wrapper: BackgammonWrapper,
        points: Int,
        endMatch: Boolean,
        isSurrender: Boolean
    ) {
        wrapper.setPossibleEndFlag(true)
        gammonMoveDao.storeWinner(
            GameWinner.of(
                matchId,
                wrapper.gameId,
                winner,
                points,
                isSurrender,
                endMatch,
                clock.instant()
            )
        )
        putGameToCache(matchId, wrapper.getRestoreContext())
    }

    fun getAllInGameInOrderByInsertionTime(matchId: Int, gameId: Int): List<TypedMongoEntity> {
        return gammonMoveDao.getAllInGameOrderByInsertionTime(matchId, gameId)
    }

    fun getCurrentGameId(matchId: Int): Int {
        return gammonMoveDao.getCurrentGameInMathId(matchId) ?: throw ResponseStatusException(
            HttpStatus.NOT_FOUND,
            "Game $matchId not found"
        )
    }

    fun getAllGamesId(matchId: Int): List<Int> {
        return gammonMoveDao.getAllGameIds(matchId)
    }

    private fun getGameFromCache(gameId: Int): BackgammonWrapper? {
        val json = redisAdapter.get(gameId.toString()) ?: return null
        val restoreContext = try {
            objectMapper.readValue(json, GammonRestoreContextDto::class.java)
        } catch (_: Exception) {
            null
        } ?: return null
        return BackgammonWrapper.buildFromContext(restoreContext)
    }


    private fun getGameFromDataBase(matchId: Int): BackgammonWrapper? {
        val gameId = getCurrentGameId(matchId)
        val movesPerChange = gammonMoveDao.getMoves(matchId, gameId)
        val startState = gammonMoveDao.getStartGameContext(matchId, gameId) ?: return null
        val lastZar = if (movesPerChange.isEmpty()) startState.game.zarResult else gammonMoveDao.getZar(
            matchId,
            gameId,
            movesPerChange.size
        )

        val game = when (startState.type) {
            BackgammonType.SHORT_BACKGAMMON -> restoreBackgammon(startState, movesPerChange, lastZar)
            BackgammonType.REGULAR_GAMMON -> restoreGammon(startState, movesPerChange, lastZar)
        }

        var blackPoints = 0
        var whitePoints = 0
        val winners = gammonMoveDao.getWinners(matchId)
        logger.info("winners: $winners")
        winners.forEach { if (it.color == Color.BLACK) blackPoints += it.points else whitePoints += it.points }
        game.blackPoints = blackPoints
        game.whitePoints = whitePoints
        val surrendered = winners.lastOrNull { it.surrender }
        game.setPossibleEndFlag(blackPoints >= game.thresholdPoints || whitePoints >= game.thresholdPoints || (surrendered != null && surrendered.endMatch))
        return game
    }

    private fun putGameToCache(roomId: Int, context: GammonRestoreContextDto) {
        redisAdapter.setex(roomId.toString(), objectMapper.writeValueAsString(context))
    }


    fun restoreBackgammon(
        startState: GammonRestoreContextDto,
        movesPerChange: List<MoveSet>,
        lastZar: List<Int>
    ): BackgammonWrapper {
        var turn = startState.game.turn
        val deck = ArrayList<Int>(28)
        for (i in 0..<28) {
            deck.add(0)
        }
        for (item in startState.game.deck) {
            deck[item.key + 1] = item.value
        }
        deck[0] = startState.game.bar[-1]!!
        deck[deck.size - 1] = startState.game.bar[1]!!

        for (moves in movesPerChange) {
            for (move in moves.moves.changes) {
                val shiftedFirst = if (move.first == 0) 0 else if (move.first == 25) deck.size - 1 else move.first + 1
                val shiftedSecond = move.second + 1
                val realSignOfMove = deck[shiftedFirst].sign
                if (realSignOfMove == 0) {
                    logger.error("move $move, sign = 0!")
                }
                deck[shiftedFirst] -= realSignOfMove.sign
                deck[shiftedSecond] += realSignOfMove.sign
            }
            turn = -turn
        }

        return BackgammonWrapper.buildFromContext(
            startState.copy(
                game = startState.game.copy(
                    turn = turn,
                    bar = mapOf(-1 to deck.first, 1 to deck.last),
                    deck = deck.subList(1, deck.size - 1).mapIndexed { index, i -> index to i }.toMap()
                        .filterValues { it != 0 },
                    zarResult = lastZar,
                    endFlag = startState.game.endFlag || deck[ShortGammonGame.WHITE_STORE + 1].absoluteValue == 15 || deck[ShortGammonGame.BLACK_STORE + 1].absoluteValue == 15
                ),
                numberOfMoves = movesPerChange.size,
            )
        )
    }

    fun restoreGammon(
        startState: GammonRestoreContextDto,
        movesPerChange: List<MoveSet>,
        lastZar: List<Int>,
    ): BackgammonWrapper {
        var turn = startState.game.turn
        val deck = ArrayList<Int>(26)
        for (i in 0..<26) {
            deck.add(0)
        }

        for (i in startState.game.deck) {
            deck[i.key] = i.value
        }

        for (moves in movesPerChange) {
            for (move in moves.moves.changes) {
                val realSignOfMove = deck[move.first].sign
                if (realSignOfMove == 0) {
                    logger.error("move $move, sign = 0")
                }
                deck[move.first] -= realSignOfMove.sign
                deck[move.second] += realSignOfMove.sign
            }
            turn = -turn
        }

        return BackgammonWrapper.buildFromContext(
            startState.copy(
                game = startState.game.copy(
                    turn = turn,
                    deck = deck.mapIndexed { index, i -> index to i }.toMap()
                        .filterValues { it != 0 },
                    zarResult = lastZar,
                    endFlag = deck[RegularGammonGame.WHITE_STORAGE].absoluteValue == 15 || deck[RegularGammonGame.BLACK_STORAGE].absoluteValue == 15
                ),
                numberOfMoves = movesPerChange.size
            )
        )
    }
}