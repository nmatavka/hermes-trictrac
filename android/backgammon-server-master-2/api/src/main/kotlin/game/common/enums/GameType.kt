package game.common.enums

enum class GameType(val type: GeneralGameType) {
    SHORT_BACKGAMMON(GeneralGameType.BACKGAMMON),
    REGULAR_GAMMON(GeneralGameType.BACKGAMMON);

    enum class GeneralGameType {
        BACKGAMMON
    }
}