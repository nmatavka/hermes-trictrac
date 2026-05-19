class Stone {
    var color: Color? = null

    enum class Color {
        WHITE, BLACK, NONE
    }

    constructor(color: Color) {
        this.color = color
    }

    constructor(color: Boolean) {
        this.color = if (color) Color.WHITE else Color.BLACK
    }

    constructor() {
        this.color = Color.NONE
    }

    override fun hashCode(): Int {
        val prime = 31
        var result = 1
        result = prime * result + if (color == null) 0 else color!!.hashCode()
        return result
    }

    override fun equals(`obj`: Any?): Boolean {
        if (this === `obj`) {
            return true
        }
        if (`obj` == null) {
            return false
        }
        if (javaClass != `obj`.javaClass) {
            return false
        }
        val other = `obj` as Stone?
        return color == other!!.color
    }

    override fun toString(): String {
        when (color) {
            Stone.Color.NONE -> return " "
            Stone.Color.WHITE -> return "O"
            Stone.Color.BLACK -> return "#"
            else -> return "$"
        }
    }

    fun color(): Color? {
        return color
    }

    companion object {
        var WHITE = Stone(Color.WHITE)
        var BLACK = Stone(Color.BLACK)
        var NONE = Stone(Color.NONE)
    }
}
