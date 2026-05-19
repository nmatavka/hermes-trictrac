package hse.dao

import hse.dao.MongoUtils.Companion.ENTITY_TYPE
import hse.dao.MongoUtils.Companion.GAME_ID
import hse.dao.MongoUtils.Companion.MOVE_ID
import hse.dao.MongoUtils.Companion.getMatchCollectionName
import hse.dto.GammonRestoreContextDto
import hse.entity.*
import hse.enums.GameEntityType
import org.springframework.data.domain.Sort
import org.springframework.data.mongodb.core.MongoTemplate
import org.springframework.data.mongodb.core.query.Criteria
import org.springframework.data.mongodb.core.query.Query
import org.springframework.stereotype.Repository
import java.time.Clock
import java.time.ZonedDateTime

@Repository
class GammonMoveDaoImpl(
    private val mongoTemplate: MongoTemplate,
    private val clock: Clock,
) : GammonMoveDao {


    override fun saveMoves(matchId: Int, gameId: Int, moveSet: MoveSet) {
        mongoTemplate.save(MoveWithId(matchId, gameId, moveSet, clock.instant()), getMatchCollectionName(matchId))
    }

    override fun saveZar(matchId: Int, gameId: Int, moveId: Int, zar: List<Int>) {
        mongoTemplate.save(Zar(gameId, moveId, zar, clock.instant()), getMatchCollectionName(matchId))
    }

    override fun getMoves(matchId: Int, gameId: Int): List<MoveSet> {
        val query = Query().addCriteria(
            Criteria.where(ENTITY_TYPE).`is`(GameEntityType.MOVE.name).and(GAME_ID).`is`(gameId)
        )
        query.fields().exclude(ENTITY_TYPE)
        return mongoTemplate.find(
            query,
            MoveWithId::class.java,
            getMatchCollectionName(matchId)
        )
            .map { it.moveSet }
    }

    override fun getZar(matchId: Int, gameId: Int, lastMoveId: Int): List<Int> {
        val query =
            Query().addCriteria(
                Criteria.where(ENTITY_TYPE).`is`(GameEntityType.ZAR.name).and(GAME_ID).`is`(gameId).and(
                    MOVE_ID
                ).`is`(lastMoveId)
            )
                .with(Sort.by(Sort.Direction.DESC, GAME_ID))
                .limit(1)
        query.fields().exclude(ENTITY_TYPE)


        return mongoTemplate.find(
            query,
            Zar::class.java,
            getMatchCollectionName(matchId)
        ).firstOrNull()?.z ?: listOf()
    }

    override fun checkMatchExists(matchId: Int): Boolean {
        return mongoTemplate.collectionExists(getMatchCollectionName(matchId))
    }

    override fun saveStartGameContext(matchId: Int, gameId: Int, context: GammonRestoreContextDto) {
        mongoTemplate.save(GameWithId(matchId, gameId, context, clock.instant()), getMatchCollectionName(matchId))
    }

    override fun getStartGameContext(matchId: Int, gameId: Int): GammonRestoreContextDto? {
        val query =
            Query().addCriteria(
                Criteria.where(ENTITY_TYPE).`is`(GameEntityType.START_STATE.name).and(GAME_ID).`is`(gameId)
            )
        query.fields().exclude(ENTITY_TYPE)
        return mongoTemplate.find(
            query,
            GameWithId::class.java,
            getMatchCollectionName(matchId)
        ).firstOrNull()?.restoreContextDto
    }

    override fun getCurrentGameInMathId(matchId: Int): Int? {
        val query =
            Query().addCriteria(Criteria.where(ENTITY_TYPE).`is`(GameEntityType.START_STATE.name))
                .with(Sort.by(Sort.Direction.DESC, GAME_ID))
                .limit(1)
        query.fields().exclude(ENTITY_TYPE)


        return mongoTemplate.find(
            query,
            GameWithId::class.java,
            getMatchCollectionName(matchId)
        ).firstOrNull()?.gameId
    }

    override fun getAllGameIds(matchId: Int): List<Int> {
        val query = Query().addCriteria(Criteria.where(ENTITY_TYPE).`is`(GameEntityType.START_STATE.name))
            .with(Sort.by(Sort.Direction.ASC, GAME_ID))
        query.fields().exclude(ENTITY_TYPE)
        return mongoTemplate.find(query, GameWithId::class.java, getMatchCollectionName(matchId)).map { it.gameId }
    }

    override fun storeWinner(winner: GameWinner) {
        mongoTemplate.save(winner, getMatchCollectionName(winner.matchId))
    }

    override fun getWinners(matchId: Int): List<GameWinner> {
        val query = Query().addCriteria(
            Criteria.where(ENTITY_TYPE).`is`(GameEntityType.WINNER_INFO.name)
        )
        return mongoTemplate.find(query, GameWinner::class.java, getMatchCollectionName(matchId))
    }

    override fun getAllInGameOrderByInsertionTime(matchId: Int, gameId: Int): List<TypedMongoEntity> {
        val query = Query().addCriteria(Criteria.where(GAME_ID).`is`(gameId)).with(Sort.by(Sort.Direction.ASC, "_id"))
        query.fields().exclude(ENTITY_TYPE)
        return mongoTemplate.find(query, TypedMongoEntity::class.java, getMatchCollectionName(matchId))
    }
}