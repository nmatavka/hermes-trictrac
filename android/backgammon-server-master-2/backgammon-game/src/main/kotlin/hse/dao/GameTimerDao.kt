package hse.dao

import hse.dao.MongoUtils.Companion.MATCH_ID
import hse.entity.GameTimer
import org.springframework.data.mongodb.core.MongoTemplate
import org.springframework.data.mongodb.core.ReplaceOptions
import org.springframework.data.mongodb.core.query.Criteria
import org.springframework.data.mongodb.core.query.Query
import org.springframework.stereotype.Repository

@Repository
class GameTimerDao(
    private val mongoTemplate: MongoTemplate,
) {
    private final val COLLECTION = "timer"

    fun getByMatchId(matchId: Int): GameTimer? {
        val query = Query().addCriteria(Criteria.where(MATCH_ID).`is`(matchId))
        return mongoTemplate.findOne(query, GameTimer::class.java, COLLECTION)
    }

    fun setByMatchId(matchId: Int, gameTimer: GameTimer) {
        val query = Query().addCriteria(Criteria.where(MATCH_ID).`is`(matchId))
        mongoTemplate.replace(query, gameTimer, ReplaceOptions().upsert(), COLLECTION)
    }

    fun deleteByMatchId(matchId: Int) {
        val query = Query().addCriteria(Criteria.where(MATCH_ID).`is`(matchId))
        mongoTemplate.remove(query, GameTimer::class.java, COLLECTION)
    }

    fun getAll(): List<GameTimer> {
        return mongoTemplate.findAll(GameTimer::class.java, COLLECTION)
    }
}