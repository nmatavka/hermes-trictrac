package hse.wrapper

import game.backgammon.Gammon
import game.backgammon.GammonRestorer
import game.backgammon.dto.*
import game.backgammon.enums.BackgammonType
import game.backgammon.enums.Color
import game.common.enums.TimePolicy
import hse.dto.GammonRestoreContextDto
import org.springframework.http.HttpStatus
import org.springframework.web.server.ResponseStatusException
import kotlin.math.absoluteValue
import kotlin.math.sign


class BackgammonWrapper(
    private var game: Gammon,
    val type: BackgammonType,
    var gameId: Int,
    var blackPoints: Int,
    var whitePoints: Int,
    val thresholdPoints: Int,
    val timePolicy: TimePolicy,
) {

    companion object {
        const val BLACK_COLOR = -1
        const val WHITE_COLOR = 1

        fun buildFromContext(restoreContextDto: GammonRestoreContextDto): BackgammonWrapper {
            val game = when (restoreContextDto.type) {
                BackgammonType.SHORT_BACKGAMMON -> GammonRestorer.restoreBackgammon(restoreContextDto.game)
                BackgammonType.REGULAR_GAMMON -> GammonRestorer.restoreGammon(restoreContextDto.game)
            }

            game.endFlag = restoreContextDto.game.endFlag
            val gameWrapper = BackgammonWrapper(
                game = game,
                type = restoreContextDto.type,
                blackPoints = restoreContextDto.blackPoints,
                whitePoints = restoreContextDto.whitePoints,
                thresholdPoints = restoreContextDto.thresholdPoints,
                gameId = restoreContextDto.gameNumber,
                timePolicy = restoreContextDto.timePolicy,
            )

            gameWrapper.firstPlayer = restoreContextDto.firstUserId
            gameWrapper.secondPlayer = restoreContextDto.secondUserId
            gameWrapper.numberOfMoves = restoreContextDto.numberOfMoves
            return gameWrapper
        }
    }

    private var firstPlayer: Int = -1

    private var secondPlayer: Int = -1

    var numberOfMoves: Int = 0

    fun connect(first: Int, second: Int) {
        firstPlayer = first
        secondPlayer = second
    }

    fun getPlayers(): Map<Color, Int> {
        return mapOf(Color.BLACK to firstPlayer, Color.WHITE to secondPlayer)
    }

    fun getConfiguration(playerId: Int): ConfigResponseDto {
        val config = game.getConfiguration()
        val playerMask = safeGetPlayerMask(playerId)
        val color = if (playerMask == null) null else getColor(playerMask)
        return ConfigResponseDto(
            color = color,
            turn = getColor(config.turn),
            bar = config.bar.entries.associate { getColor(it.key) to it.value.absoluteValue },
            deck = config.deck
                .mapIndexed { index, it ->
                    getDeckItemDto(index, it)
                }
                .filterNotNull()
                .toSet(),
            zar = config.zar,
            first = numberOfMoves == 0,
            type = type
        )
    }


    fun move(playerId: Int, moves: List<MoveDto>): ChangeDto {
        return game.move(getPlayerMask(playerId), moves).also { ++numberOfMoves }
    }

    fun tossZar(userId: Int): TossZarDto {
        return game.tossBothZar(getPlayerMask(userId))
    }


    fun getPlayerColor(userId: Int): Color {
        val mask = getPlayerMask(userId)
        return getColor(mask)
    }

    fun gameEndStatus(): Map<Boolean, Color> {
        val res = game.getEndState() ?: throw ResponseStatusException(HttpStatus.TOO_EARLY, "Game not ended")
        return listOf(firstPlayer, secondPlayer).associate { (getPlayerMask(it) == res.winner) to getPlayerColor(it) }
    }

    fun getPointsForGame(): Int {
        return game.getWinPoints()
    }

    fun checkEnd(): Boolean {
        return game.checkEnd()
    }

    fun getCurrentTurn(): Color {
        return getColor(game.turn)
    }

    fun getRestoreContext(): GammonRestoreContextDto {
        val config = game.getConfiguration()
        return GammonRestoreContextDto(
            game = GammonRestorer.GammonRestoreContext(
                deck = config.deck.mapIndexed { index, it -> index to it }.filter { it.second != 0 }.toMap(),
                turn = config.turn,
                zarResult = config.zar,
                bar = config.bar,
                endFlag = game.checkEnd(),
            ),
            firstUserId = firstPlayer,
            secondUserId = secondPlayer,
            type = type,
            numberOfMoves = numberOfMoves,
            blackPoints = blackPoints,
            whitePoints = whitePoints,
            thresholdPoints = thresholdPoints,
            gameNumber = gameId,
            timePolicy = timePolicy
        )
    }

    fun restore() {
        game = game.reload()
        gameId += 1
        numberOfMoves = 0
    }

    fun getZar(): List<Int> {
        return game.foolZar
    }

    fun isTurn(userId: Int): Boolean {
        return game.turn == getPlayerMask(userId)
    }

    fun invertTurn() {
        game.turn = -game.turn
    }

    fun setPossibleEndFlag(flag: Boolean) {
        game.endFlag = game.endFlag || flag
    }

    fun hasInStore(playerId: Int): Boolean {
        return game.hasInStore(getPlayerMask(playerId))
    }

    private fun getDeckItemDto(index: Int, value: Int): DeckItemDto? {
        return if (value == 0) {
            null
        } else {
            DeckItemDto(
                id = index,
                color = getColor(value.sign),
                count = value.absoluteValue
            )
        }
    }

    private fun getColor(mask: Int): Color {
        return when (mask) {
            BLACK_COLOR -> Color.BLACK
            WHITE_COLOR -> Color.WHITE
            else -> throw RuntimeException("mask should be -1 or 1, not $mask")
        }
    }

    private fun getPlayerMask(playerId: Int): Int {
        return safeGetPlayerMask(playerId) ?: throw ResponseStatusException(
            HttpStatus.UNPROCESSABLE_ENTITY,
            "Player not connected"
        )
    }

    private fun safeGetPlayerMask(playerId: Int): Int? {
        return when (playerId) {
            firstPlayer -> {
                BLACK_COLOR
            }
            secondPlayer -> {
                WHITE_COLOR
            }
            else -> {
                null
            }
        }
    }
}