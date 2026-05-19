package game.backgammon.exception

class OutOfBoundsBackgammonException(
    from: Int,
    to: Int,
) : BackgammonException("move: $from -> $to is out of bounds")