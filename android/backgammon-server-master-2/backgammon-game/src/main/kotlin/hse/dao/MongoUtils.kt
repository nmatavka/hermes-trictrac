package hse.dao

class MongoUtils {

    companion object {
        const val GAME_ID = "gameId"
        const val ENTITY_TYPE = "type"
        const val MOVE_ID = "moveId"
        const val MATCH_ID = "matchId"

        fun getMatchCollectionName(matchId: Int): String {
            return "match$matchId"
        }
    }
}