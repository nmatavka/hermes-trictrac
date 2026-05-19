package hse.menu.service

import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy
import hse.menu.dao.ConnectionDao
import hse.menu.dto.ConnectionDto
import org.springframework.beans.factory.config.BeanDefinition.SCOPE_SINGLETON
import org.springframework.context.annotation.Scope
import org.springframework.stereotype.Service
import java.util.concurrent.ConcurrentHashMap

@Service
@Scope(SCOPE_SINGLETON)
class ConnectionService(
    val connectionDao: ConnectionDao,
    val inQueueFilter: MutableSet<Long> = ConcurrentHashMap.newKeySet(),
    val cancelledFilter: MutableSet<Long> = ConcurrentHashMap.newKeySet(),
) {

    fun connect(connectionDto: ConnectionDto, points: GammonGamePoints, timePolicy: TimePolicy) {
        val userId = connectionDto.userId
        cancelledFilter.remove(userId)
        if (userId in inQueueFilter) {
            return
        }
        inQueueFilter.add(userId)
        connectionDao.enqueue(connectionDto, points, timePolicy)
    }

    fun take(gameType: GameType, points: GammonGamePoints, timePolicy: TimePolicy): List<ConnectionDto> {
        val res = connectionDao.flushAll(gameType, points, timePolicy)
        res.forEach { inQueueFilter.remove(it.userId) }
        return res.filter { !cancelledFilter.contains(it.userId) }
    }

    fun checkInBan(userId: Long): Boolean {
        return cancelledFilter.contains(userId)
    }

    fun disconnect(userId: Long) {
        inQueueFilter.remove(userId)
        cancelledFilter.add(userId)
    }
}