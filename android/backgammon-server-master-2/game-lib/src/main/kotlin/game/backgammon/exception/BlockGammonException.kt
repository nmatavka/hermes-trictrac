package game.backgammon.exception

class BlockGammonException(to: Int) : BackgammonException("cant put checker to: $to, it will create block") {
}