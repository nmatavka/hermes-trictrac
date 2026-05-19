package game.backgammon.lng

import game.backgammon.*
import game.backgammon.dto.*
import game.backgammon.exception.*
import org.apache.commons.collections4.CollectionUtils
import java.util.*
import kotlin.math.absoluteValue
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sign

class RegularGammonGame(
    zar: Random = Random()
) : Gammon(zar) {

    var deck = ArrayList<Int>()
    private var testDeck = ArrayList<Int>()
    private var testZar = ArrayList<Int>()

    companion object {
        const val BLACK_HEAD = 13
        const val WHITE_HEAD = 1
        const val BLACK_STORAGE = 0
        const val WHITE_STORAGE = 25
    }

    init {
        for (i in 0..<26) {
            deck.add(0)
        }

        deck[BLACK_HEAD] = -15
        deck[WHITE_HEAD] = 15
        zarResults = setZarStartConfiguration()
        testDeck = ArrayList(deck)
        testZar = ArrayList(zarResults)
    }

    constructor(restoreContext: GammonRestorer.GammonRestoreContext) : this() {
        deck[BLACK_HEAD] = 0
        deck[WHITE_HEAD] = 0

        for (i in restoreContext.deck) {
            deck[i.key] = i.value
        }
        endFlag = restoreContext.endFlag
        turn = restoreContext.turn
        zarResults = ArrayList(restoreContext.zarResult)
        foolZar = ArrayList(zarResults)
        testDeck = ArrayList(deck)
        testZar = ArrayList(zarResults)

        if (zarResults.isEmpty()) {
            return
        }

        validateTossedZar(restoreContext.zarResult[0], restoreContext.zarResult[1])
    }

    override fun reload(): Gammon {
        return RegularGammonGame(zar = zar)
    }

    override fun getConfiguration(): ConfigDto {
        return ConfigDto(
            zar = zarResults,
            turn = turn,
            deck = deck,
            bar = mapOf()
        )
    }

    override fun move(user: Int, moves: List<MoveDto>): ChangeDto {
        validateBeforeMoves(user, moves)

        testDeck = ArrayList(deck)
        testZar = ArrayList(zarResults)

        for (move in moves) {
            makeMove(move)
        }


        turn = -turn
        deck = ArrayList(testDeck)
        zarResults = ArrayList(testZar)

        return ChangeDto(
            changes = moves.map { Pair(it.from, it.to) }
        )
    }

    override fun getEndState(): EndDto? {
        if (!endFlag) {
            return null
        }
        return EndDto(if (deck[BLACK_STORAGE].absoluteValue == 15) BLACK else WHITE)
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
            if (deck[WHITE_STORAGE] == 0) {
                MARS_DEFEAT
            } else {
                REGULAR_DEFEAT
            }
        } else {
            if (deck[BLACK_STORAGE] == 0) {
                MARS_DEFEAT
            } else {
                REGULAR_DEFEAT
            }
        }
        return points
    }

    override fun hasInStore(user: Int): Boolean {
        if (user == BLACK) {
            return deck[BLACK_STORAGE] != 0
        }
        return deck[WHITE_STORAGE] != 0
    }

    private fun validateBeforeMoves(user: Int, moves: List<MoveDto>) {
        if (zarResults.size != moves.size) {
            throw IncorrectNumberOfMovesBackgammonException()
        }
        if (endFlag) {
            throw GameIsOverBackgammonException()
        }
        if (user != WHITE && user != BLACK) {
            throw IncorrectInputtedUserBackgammonException()
        }
        if (user != turn) {
            throw IncorrectTurnBackgammonException()
        }
        val fromHead = if (turn == WHITE) {
            moves.count { it.from == WHITE_HEAD }
        } else {
            moves.count { it.from == BLACK_HEAD }
        }
        if (fromHead > 1) {
            throw ToMuchMovesFromHeadBackgammonException()
        }


    }

    private fun validateMove(move: MoveDto) {
        if (testDeck[move.from] == 0 || testDeck[move.from].sign != turn) {
            throw IncorrectPositionForMoveBackgammonException(move.from)
        }
        if (!testZar.contains(getDistance(move.from, move.to))) {
            throw NoSuchZarBackgammonException(move.from, move.to)
        }
        if (turn == WHITE && move.to < move.from) {
            throw IncorrectDirectionBackgammonException(move.from, move.to)
        }
        if (turn == BLACK && move.to < move.from) {
            if (!(move.from >= 18 && move.to <= 6) && move.to != BLACK_STORAGE) {
                throw IncorrectDirectionBackgammonException(move.from, move.to)
            }
        }
        if (!checkOpponentInHome() && checkIfMoveCreatesBlock(move.to)) {
            throw BlockGammonException(move.to)
        }
        if (((turn == BLACK && move.to == BLACK_STORAGE) || (turn == WHITE && move.to == WHITE_STORAGE)) && !checkYourInHome()) {
            throw CantExitBackgammonException()
        }
    }

    private fun makeMove(move: MoveDto) {
        validateMove(move)

        testZar.remove(getDistance(move.from, move.to))

        testDeck[move.from] -= turn
        testDeck[move.to] += turn
    }

    private fun getDistance(from: Int, to: Int): Int {
        if (turn == WHITE) {
            return to - from
        }
        if (from > 18 && to < 13) {
            return (24 + to) - from
        }
        if (to == BLACK_STORAGE) {
            return 13 - from
        }
        return to - from
    }

    private fun canMove(from: Int, to: Int): Boolean {
        if (testDeck[from] == 0 || testDeck[from].sign != turn) {
            return false
        }
        if (testDeck[to] != BLACK_STORAGE && testDeck[to].sign != turn) {
            return false
        }

        if (to == BLACK_STORAGE || to == WHITE_STORAGE) {
            return checkYourInHome()
        }

        return true
    }

    private fun validateTossedZar(res1: Int, res2: Int): TossZarDto {
        fillZar(res1, res2)
        val tmp = ArrayList(zarResults)
        var maxMoves = 0
        for (combination in CollectionUtils.permutations(tmp)) {
            maxMoves = max(maxMoves, findMaxSequence(combination))
            if (tmp.size == 4) {
                break
            } else if (maxMoves == tmp.size) {
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

            zarResults = if ((1..24).any {
                    testDeck[it] != 0 && testDeck[it].sign == turn && canMove(
                        it,
                        getToByDistance(it, maxZar)
                    )
                }) {
                arrayListOf(maxZar)
            } else {
                arrayListOf(minZar)
            }

        } else if (maxMoves == 0) {
            zarResults.clear()
        }

        return TossZarDto(tmp)

    }

    private fun findMaxSequence(currentZar: List<Int>, canMoveFromHead: Boolean = true): Int {
        if (currentZar.isEmpty()) {
            return 0
        }
        val nextZar = currentZar.first()
        var maxNext = 0
        for (from in 1..24) {
            if (testDeck[from] == 0 || testDeck[from].sign != turn) {
                continue
            }
            val isMoveFromHead =
                canMoveFromHead && ((turn == WHITE && from == WHITE_HEAD) || (turn == BLACK && from == BLACK_HEAD))
            val to = getToByDistance(from, nextZar)
            if (canMove(from, to)) {
                testDeck[from] -= turn
                testDeck[to] += turn
                maxNext = max(maxNext, 1 + findMaxSequence(currentZar.subList(1, currentZar.size), isMoveFromHead))
                testDeck[from] += turn
                testDeck[to] -= turn
            }

        }
        return maxNext
    }

    private fun getToByDistance(from: Int, distance: Int): Int {
        if (turn == WHITE) {
            return from + distance
        }
        if (from + distance > 24) {
            return (from + distance - 24) + 1
        }
        return from + distance

    }

    private fun checkOpponentInHome(): Boolean {
        if (turn == WHITE) {
            return testDeck[BLACK_STORAGE] < 0 || testDeck.subList(6, 13).any { it != 0 && it.sign == BLACK }
        }
        return testDeck.subList(19, WHITE_STORAGE + 1).any { it != 0 && it.sign == WHITE }
    }

    private fun checkYourInHome(): Boolean {
        if (turn == WHITE) {
            return testDeck.indexOfFirst { it > 0 } >= 19
        }
        return testDeck.indexOfFirst { it < 0 } >= 7 && testDeck.indexOfLast { it < 0 } <= 12
    }

    private fun checkIfMoveCreatesBlock(to: Int): Boolean {
        if (to == BLACK_STORAGE || to == WHITE_STORAGE) {
            return false
        }
        var nextIdx = to % 24 + 1
        var inARow = 0
        while (testDeck[nextIdx] != 0 || testDeck[nextIdx].sign == turn) {
            nextIdx = nextIdx % 24 + 1
            ++inARow
        }
        nextIdx = to - 1
        while (testDeck[nextIdx] != 0 || testDeck[nextIdx].sign == turn) {
            --nextIdx
            if (nextIdx == 0) {
                nextIdx = 24
            }
            ++inARow
        }
        return inARow >= 5
    }

    override fun toString(): String {
        return "turn = $turn, zarResults = $zarResults"
    }

}