package game.backgammon.sht

import game.backgammon.*
import game.backgammon.dto.*
import game.backgammon.exception.*
import game.backgammon.lng.RegularGammonGame.Companion.BLACK_STORAGE
import game.backgammon.lng.RegularGammonGame.Companion.WHITE_STORAGE
import org.apache.commons.collections4.CollectionUtils
import java.util.*
import kotlin.math.*

class ShortGammonGame(
    zar: Random = Random()
) : Gammon(zar) {
    private var testDeck: ArrayList<Int>
    private var testZar: ArrayList<Int>
    private var testBar = HashMap<Int, Int>()

    var deck = ArrayList<Int>(26)

    var bar = hashMapOf(
        BLACK to 0,
        WHITE to 0
    )


    init {
        for (i in 0..<26) {
            deck.add(0)
        }
        deck[1] = -2
        deck[12] = -5
        deck[17] = -3
        deck[19] = -5

        deck[24] = 2
        deck[13] = 5
        deck[8] = 3
        deck[6] = 5

        zarResults = setZarStartConfiguration()
        foolZar = ArrayList(zarResults)
        testDeck = ArrayList(deck)
        testZar = ArrayList(zarResults)
        testBar = HashMap(bar)
    }

    companion object {
        const val WHITE_STORE = 0
        const val BLACK_STORE = 25
    }


    constructor(restoreContext: GammonRestorer.GammonRestoreContext) : this() {
        deck = ArrayList(26)
        for (i in 0..<26) {
            deck.add(0)
        }
        for (i in restoreContext.deck.entries) {
            deck[i.key] = i.value
        }

        bar = HashMap(restoreContext.bar)
        turn = restoreContext.turn
        endFlag = restoreContext.endFlag
        zarResults = ArrayList(restoreContext.zarResult)
        foolZar = ArrayList(zarResults)

        testDeck = ArrayList(deck)
        testZar = ArrayList(zarResults)
        testBar = HashMap(bar)

        if (restoreContext.zarResult.isEmpty()) {
            return
        }

        validateTossedZar(restoreContext.zarResult[0], restoreContext.zarResult[1])
    }

    override fun reload(): Gammon {
        return ShortGammonGame(zar = zar)
    }

    override fun getConfiguration(): ConfigDto {
        return ConfigDto(
            zar = foolZar,
            bar = bar,
            turn = turn,
            deck = deck,
        )
    }

    override fun move(user: Int, moves: List<MoveDto>): ChangeDto {

        if (zarResults.size != moves.size) {
            throw IncorrectNumberOfMovesBackgammonException()
        }

        validateGameState(user)

        testDeck = ArrayList(deck)
        testZar = ArrayList(zarResults)
        testBar = HashMap(bar)

        val res = mutableListOf<Pair<Int, Int>>()

        moves.forEach { move ->
            res.addAll(makeMove(user, move))
        }
        turn = -user
        deck = ArrayList(testDeck)
        zarResults = ArrayList(testZar)
        bar = HashMap(testBar)
        validateEnd()
        return ChangeDto(res)
    }

    override fun getEndState(): EndDto? {
        if (!endFlag) {
            return null
        }
        return EndDto(if (deck[WHITE_STORE] == 15) WHITE else BLACK)
    }

    override fun tossBothZar(user: Int): TossZarDto {
        if (zarResults.isNotEmpty()) {
            throw ReTossZarBackgammonException()
        } else if (user != turn) {
            throw IncorrectTurnBackgammonException()
        }
        val res1 = tossZar()
        val res2 = tossZar()
        return validateTossedZar(res1, res2)
    }

    override fun checkEnd(): Boolean {
        return endFlag
    }

    override fun getWinPoints(): Int {
        val points = if (deck[BLACK_STORAGE].absoluteValue == 15) {
            if (deck[WHITE_STORAGE] != 0) {
                REGULAR_DEFEAT
            } else if (bar[WHITE] != 0) {
                KOKS_DEFEAT
            } else {
                MARS_DEFEAT
            }
        } else {
            if (deck[BLACK_STORAGE] != 0) {
                REGULAR_DEFEAT
            } else if (bar[BLACK] != 0) {
                KOKS_DEFEAT
            } else {
                MARS_DEFEAT
            }
        }
        return points
    }

    override fun hasInStore(user: Int): Boolean {
        if (user == BLACK) {
            return deck[BLACK_STORE] != 0
        }
        return deck[WHITE_STORE] != 0
    }

    private fun findMaxFromSequence(zar: List<Int>): Int {
        val canMoveHome = checkAllInHome(turn)
        val currZar = zar.firstOrNull() ?: return 0
        val nextZar = zar.subList(1, zar.size)
        var next = 0
        var flag = false
        val dif = -turn * currZar
        if (testBar[turn] != 0) {
            val barIdx = getBarFrom(turn)
            if (testDeck[barIdx + dif].absoluteValue > 1 && testDeck[barIdx + dif].sign != turn) {
                return 0
            }
            testBar[turn] = testBar[turn]!! - turn
            testDeck[barIdx + dif] += turn
            next = findMaxFromSequence(nextZar)
            testDeck[barIdx + dif] -= turn
            testBar[turn] = testBar[turn]!! + turn
            return next + 1
        }

        for (i in 1..24) {
            if (testDeck[i] == 0 || testDeck[i].sign != turn) {
                continue
            }
            val pos = i + dif
            if ((pos == WHITE_STORE || pos == BLACK_STORE) && !canMoveHome) {
                continue
            }
            if (pos in testDeck.indices) {
                if (testDeck[pos].absoluteValue <= 1 || testDeck[pos].sign == turn) {
                    flag = true
                    val beforePos = testDeck[pos]
                    val beforeI = testDeck[i]
                    testDeck[i] -= turn
                    testDeck[pos] = turn * max(abs(turn), abs(testDeck[pos] + turn))
                    next = max(next, findMaxFromSequence(nextZar))
                    testDeck[pos] = beforePos
                    testDeck[i] = beforeI
                }
            }
        }
        if (!flag && canMoveHome) {
            var idx = 0
            val dist = if (turn == BLACK) {
                idx = testDeck.indexOfFirst { it.sign == -1 }
                BLACK_STORE - idx
            } else {
                idx = testDeck.indexOfLast { it != 0 && it.sign == 1 }
                idx
            }
            // todo: оптимизировать валидацию -> когда попали вот сюда, не надо выполнять следующий пересчет хода
            if (dist != 0 && dist < currZar) {
                testDeck[idx] -= turn
                next = findMaxFromSequence(nextZar)
                testDeck[idx] += turn
                flag = true
            }
        }
        return if (flag) {
            1 + next
        } else {
            0
        }
    }

    private fun makeMove(user: Int, move: MoveDto): List<Pair<Int, Int>> {
        validateAll(user, move)
        val knocked = checkKnockOut(move.to, user)
        testZar.remove(abs(move.to - move.from))
        testDeck[move.to] += user

        val moveMap = if (move.from == WHITE_STORE || move.from == BLACK_STORE) {
            testBar[user] = testBar[user]!!.minus(user)
            move.from to move.to
        } else {
            testDeck[move.from] -= user
            move.from to move.to
        }
        return if (knocked == null) {
            listOf(moveMap)
        } else {
            listOf(knocked, moveMap)
        }

    }

    private fun checkKnockOut(to: Int, user: Int): Pair<Int, Int>? {
        if (testDeck[to] == -user) {
            testBar[-user] = testBar[-user]!!.plus(-user)
            testDeck[to] = 0
            return to to getBarTo(-user)
        }
        return null
    }

    private fun validateAll(user: Int, move: MoveDto) {
        validateMoveFromBar(user, move)
        validateZar(user, move)
        validateMove(user, move)
        validateExit(user, move)
    }

    private fun validateGameState(user: Int) {
        if (endFlag) {
            throw GameIsOverBackgammonException()
        }
        if (user != BLACK && user != WHITE) {
            throw IncorrectInputtedUserBackgammonException()
        }
        if (user != turn) {
            throw IncorrectTurnBackgammonException()
        }
    }

    private fun validateMoveFromBar(user: Int, move: MoveDto) {
        val moveFromBar = move.from == WHITE_STORE || move.from == BLACK_STORE
        if (!moveFromBar && testBar[user]!! > 0) {
            throw NotEmptyBarBackgammonException()
        } else if (moveFromBar && testBar[user]!! == 0) {
            throw EmptyBarBackgammonException()
        }
    }

    private fun validateZar(user: Int, move: MoveDto) {
        val dif = abs(move.to - move.from)
        if (testZar.contains(dif)) {
            return
        }
        if (checkAllInHome(user)) {
            if (testZar.max() > dif) {
                val farthest = if (move.to > move.from) {
                    testDeck.filterIndexed { idx, _ -> checkTurn(idx) && idx > 18 && idx < move.from }
                } else {
                    testDeck.filterIndexed { idx, _ -> checkTurn(idx) && idx < 7 && idx > move.from }
                }
                if (farthest.isEmpty()) {
                    testZar.remove(testZar.max())
                }
                return
            }
        }

        throw NoSuchZarBackgammonException(move.from, move.to)
    }

    private fun validateMove(user: Int, move: MoveDto) {
        if (user * (move.to - move.from) > WHITE_STORE) {
            throw IncorrectDirectionBackgammonException(move.from, move.to)
        }
        if (move.from < WHITE_STORE || move.from >= deck.size || move.to < WHITE_STORE || move.to >= deck.size) {
            throw OutOfBoundsBackgammonException(move.from, move.to)
        }
        if (move.from != WHITE_STORE && move.from != BLACK_STORE && testDeck[move.from] * user <= WHITE_STORE) {
            throw IncorrectPositionForMoveBackgammonException(move.from)
        }
        if (!canMove(move.to)) {
            throw IncorrectPositionForMoveBackgammonException(move.to)
        }

    }

    private fun checkAllInHome(user: Int): Boolean {
        return if (user == BLACK) {
            testDeck.indexOfFirst { it.sign == user } > 18
        } else {
            testDeck.indexOfLast { it != WHITE_STORE && it.sign == user } < 7
        }
    }

    private fun validateExit(user: Int, move: MoveDto) {
        if (move.to == WHITE_STORE || move.to == BLACK) {
            if (!checkAllInHome(user)) {
                throw CantExitBackgammonException()
            }
        }

    }

    private fun getBarFrom(user: Int): Int {
        return when (user) {
            BLACK -> WHITE_STORE
            WHITE -> BLACK_STORE
            else -> throw IncorrectInputtedUserBackgammonException()
        }
    }

    private fun getBarTo(user: Int): Int {
        return when (user) {
            BLACK -> -1
            WHITE -> 26
            else -> throw IncorrectInputtedUserBackgammonException()
        }
    }

    private fun validateEnd(): Boolean {
        if (abs(deck[WHITE_STORE]) == 15 || abs(deck[BLACK_STORE]) == 15) {
            endFlag = true
            return true
        }
        return false
    }

    private fun canMove(to: Int): Boolean {
        val canTo = to >= WHITE_STORE && to < testDeck.size && testDeck[to] * turn >= -1
        if (!canTo) {
            return false
        }
        return if (to > WHITE_STORE && to < testDeck.size - 1) {
            true
        } else if (to == WHITE_STORE || to == testDeck.size - 1) {
            return checkAllInHome(turn)
        } else {
            false
        }
    }

    private fun checkTurn(position: Int): Boolean {
        return position >= WHITE_STORE && position < testDeck.size && testDeck[position] != WHITE_STORE && testDeck[position].sign == turn
    }


    private fun validateTossedZar(res1: Int, res2: Int): TossZarDto {
        fillZar(res1, res2)

        val tmp = ArrayList(zarResults)

        var maxMoves = 0

        for (zarPermutation in CollectionUtils.permutations(zarResults)) {
            testDeck = ArrayList(deck)
            testZar = ArrayList(zarResults)
            testBar = HashMap(bar)
            maxMoves = max(maxMoves, findMaxFromSequence(zarPermutation))
            if (maxMoves == tmp.size) {
                break
            } else if (tmp.size == 4) {
                break
            }
        }
        if (maxMoves == tmp.size) {
            zarResults = ArrayList(tmp)
        } else if (tmp.size == 4 && maxMoves != 0) {
            zarResults = ArrayList(tmp.subList(0, maxMoves))
        } else if (tmp.size == 2 && maxMoves == 1) {
            val maxZar = max(res1, res2)
            val minZar = min(res1, res2)
            val maxDif = -maxZar * turn
            if (testBar[turn]!!.absoluteValue > 0) {
                val maxTo = getBarFrom(turn) + maxDif
                zarResults = if (canMove(maxTo)) {
                    arrayListOf(maxZar)
                } else {
                    arrayListOf(minZar)
                }
            } else {
                zarResults = if ((1..24).any { checkTurn(it) && canMove(it + maxDif) }) {
                    arrayListOf(maxZar)
                } else {
                    arrayListOf(minZar)
                }
            }
        } else if (maxMoves == 0) {
            zarResults.clear()
        }

        return TossZarDto(tmp)
    }

    override fun toString(): String {
        return "turn = $turn, zarResults = $zarResults, bar = $bar"
    }
}