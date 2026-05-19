package game.backgammon.exception

class IncorrectDirectionBackgammonException(
    from: Int,
    to: Int
) : BackgammonException("incorrect direction for move: $from -> $to")