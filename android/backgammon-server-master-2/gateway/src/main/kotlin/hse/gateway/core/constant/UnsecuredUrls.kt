package hse.gateway.core.constant

const val PLAYER_SERVICE = "/player"

const val LOGIN = "$PLAYER_SERVICE/login"

const val REGISTER = "$PLAYER_SERVICE/create"

const val AUTH = "$PLAYER_SERVICE/auth"

const val IS_AUTHORIZED = "$PLAYER_SERVICE/is-authorized"

const val USERINFO = "$PLAYER_SERVICE/userinfo"

val toAuth = setOf(
    LOGIN,
    REGISTER,
)