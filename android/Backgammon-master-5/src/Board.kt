class Board {
    private var homeWhite: Int = 0
    private var homeBlack: Int = 0
    private var barWhite: Int = 0
    private var barBlack: Int = 0
    private var stoneCounts: IntArray? = null
    private var stoneColors: Array<Stone.Color?>? = null

    init {
        init()
    }

    fun init() {
        homeWhite = 0
        homeBlack = 0
        barWhite = 0
        barBlack = 0
        stoneCounts = IntArray(24)
        stoneColors = arrayOfNulls(24)
        for (i in 0..23) {
            this.stoneColors!![i] = Stone.Color.NONE
        }
        stoneCounts!![0] = 2
        stoneColors!![0] = Stone.Color.WHITE
        stoneCounts!![11] = 5
        stoneColors!![11] = Stone.Color.WHITE
        stoneCounts!![16] = 5
        stoneColors!![16] = Stone.Color.WHITE
        stoneCounts!![18] = 3
        stoneColors!![18] = Stone.Color.WHITE
        stoneCounts!![23] = 2
        stoneColors!![23] = Stone.Color.BLACK
        stoneCounts!![12] = 5
        stoneColors!![12] = Stone.Color.BLACK
        stoneCounts!![7] = 5
        stoneColors!![7] = Stone.Color.BLACK
        stoneCounts!![5] = 3
        stoneColors!![5] = Stone.Color.BLACK
    }

    fun getStoneCount(i: Int): Int {
        return if (i < 0 || i > 24) 0 else stoneCounts!![i]
    }

    fun getStone(i: Int): Stone {
        if (i < 0 || i > 24)
            return Stone.NONE
        when (stoneColors!![i]) {
            Stone.Color.WHITE -> return Stone.WHITE
            Stone.Color.BLACK -> return Stone.BLACK
            else -> return Stone.NONE
        }
    }

    fun getBarCount(color: Stone.Color): Int {
        when (color) {
            Stone.Color.WHITE -> return barWhite
            Stone.Color.BLACK -> return barBlack
            else -> return 0
        }
    }

    fun canMove(from: Int, count: Int): Boolean? {
        if (from < 0 || from > 24) {
            return false
        }
        if (stoneCounts!![from] == 0) {
            return false
        }
        val who = stoneColors!![from]
        val target: Int
        if (who === Stone.Color.WHITE) {
            if (barWhite > 0) {
                return false
            }
            target = from + count
        } else {
            if (barBlack > 0) {
                return false
            }
            target = from - count
        }
        if (target > 23 || target < 0) {
            return who?.let { hasAllInBase(it, from) }
        }
        val targetWho = stoneColors!![target]
        return if (targetWho === who || targetWho === Stone.Color.NONE) {
            true
        } else {
            stoneCounts!![target] == 1
        }
    }

    fun canPut(color: Stone.Color, number: Int): Boolean {
        when (color) {
            Stone.Color.WHITE -> {
                if (barWhite == 0) {
                    return false
                }
                if (stoneColors!![number - 1] === Stone.Color.BLACK) {
                    return false
                }
            }
            Stone.Color.BLACK -> {
                if (barBlack == 0) {
                    return false
                }
                if (stoneColors!![24 - number] === Stone.Color.WHITE) {
                    return false
                }
            }
            else -> return false
        }
        return true
    }

    fun hasAllInBase(color: Stone.Color, except: Int): Boolean {
        val f: Int
        val t: Int
        when (color) {
            Stone.Color.WHITE -> {
                if (barWhite > 0) {
                    return false
                }
                f = 0
                t = 18
            }
            Stone.Color.BLACK -> {
                if (barBlack > 0) {
                    return false
                }
                f = 6
                t = 24
            }
            else -> return false
        }
        for (i in f until t) {
            if (stoneColors!![i] === color && (i != except || stoneCounts!![i] > 1)) {
                return false
            }
        }
        return true
    }

    @Throws(WrongMoveException::class)
    fun move(from: Int, count: Int) {
        if (!canMove(from, count)!!) {
            throw WrongMoveException()
        }
        if (stoneColors!![from] === Stone.Color.WHITE) {
            val target = from + count
            if (target > 23) {
                homeWhite++
            } else if (stoneColors!![target] === Stone.Color.BLACK) {
                removeStone(target)
                barBlack++
                addStone(target, Stone.Color.WHITE)
            } else {
                addStone(target, Stone.Color.WHITE)
            }
        } else {
            val target = from - count
            if (target < 0) {
                homeBlack++
            } else if (stoneColors!![target] === Stone.Color.WHITE) {
                removeStone(target)
                barWhite++
                addStone(target, Stone.Color.BLACK)
            } else {
                addStone(target, Stone.Color.BLACK)
            }
        }
        removeStone(from)
    }

    @Throws(WrongMoveException::class)
    fun put(color: Stone.Color, number: Int) {
        if (!canPut(color, number)) {
            throw WrongMoveException()
        }
        when (color) {
            Stone.Color.WHITE -> {
                barWhite--
                addStone(number - 1, color)
            }
            Stone.Color.BLACK -> {
                barBlack--
                addStone(24 - number, color)
            }
            else -> Stone.NONE
        }
    }

    private fun removeStone(from: Int) {
        require(stoneCounts!![from] > 0) { "Removing stone from zero at $from" }
        stoneCounts!![from]--
        if (stoneCounts!![from] == 0) {
            stoneColors?.set(from, Stone.Color.NONE)
        }
    }

    private fun addStone(to: Int, color: Stone.Color) {
        require(!(stoneColors!![to] !== Stone.Color.NONE && stoneColors!![to] !== color)) { "Adding wrong color of stone to $to" }
        stoneCounts!![to]++
        if (stoneColors!![to] === Stone.Color.NONE) {
            stoneColors?.set(to, color)
        }
    }

    fun getHome(color: Stone.Color): Int {
        when (color) {
            Stone.Color.WHITE -> return homeWhite
            Stone.Color.BLACK -> return homeBlack
            else -> return 0
        }
    }
}
