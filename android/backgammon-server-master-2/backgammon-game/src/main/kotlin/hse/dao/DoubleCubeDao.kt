package hse.dao

import hse.dao.MongoUtils.Companion.ENTITY_TYPE
import hse.dao.MongoUtils.Companion.GAME_ID
import hse.dao.MongoUtils.Companion.MOVE_ID
import hse.dao.MongoUtils.Companion.getMatchCollectionName
import hse.entity.DoubleCube
import hse.enums.GameEntityType
import org.springframework.data.mongodb.core.MongoTemplate
import org.springframework.data.mongodb.core.query.Criteria
import org.springframework.data.mongodb.core.query.Query
import org.springframework.data.mongodb.core.query.Update
import org.springframework.stereotype.Repository

@Repository
class DoubleCubeDao(
    val mongoTemplate: MongoTemplate
) {
    fun acceptDouble(matchId: Int, gameId: Int, moveId: Int) {
        val query = Query().addCriteria(
            Criteria.where(ENTITY_TYPE).`is`(GameEntityType.DOUBLE.name).and(GAME_ID).`is`(gameId).and(MOVE_ID)
                .`is`(moveId)
        )
        val update = Update().set("isAccepted", "true")
        mongoTemplate.updateFirst(query, update, getMatchCollectionName(matchId))
    }

    fun getAllDoubles(matchId: Int, gameId: Int): List<DoubleCube> {
        val query = Query().addCriteria(
            Criteria.where(ENTITY_TYPE).`is`(GameEntityType.DOUBLE.name).and(GAME_ID).`is`(gameId)
        )
        query.fields().exclude(ENTITY_TYPE)
        return mongoTemplate.find(
            query,
            DoubleCube::class.java,
            getMatchCollectionName(matchId)
        )
    }

    fun saveDouble(matchId: Int, doubleCube: DoubleCube) {
        mongoTemplate.save(doubleCube, getMatchCollectionName(matchId))
    }
}