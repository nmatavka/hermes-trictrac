package player

enum class InvitePolicy(val code: Int) {
    ALL(0),
    FRIENDS_ONLY(1);

    companion object {
        fun ofCode(code: Int) = entries.first { it.code == code }
    }
}
