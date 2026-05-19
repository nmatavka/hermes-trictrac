package game.backgammon.exception

class NoSuchZarBackgammonException(
    from: Int,
    to: Int,
) : BackgammonException("zar result not found for move: $from -> $to")