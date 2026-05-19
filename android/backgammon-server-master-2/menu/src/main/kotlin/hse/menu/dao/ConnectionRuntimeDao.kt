package hse.menu.dao

import game.common.enums.GameType
import game.common.enums.GammonGamePoints
import game.common.enums.TimePolicy
import hse.menu.dto.ConnectQueueHolder
import hse.menu.dto.ConnectionDto
import hse.menu.dto.GameSearchDetails
import org.springframework.beans.factory.config.BeanDefinition.SCOPE_SINGLETON
import org.springframework.context.annotation.Scope
import org.springframework.stereotype.Repository
import java.util.concurrent.ConcurrentLinkedQueue


@Repository
@Scope(SCOPE_SINGLETON)
class ConnectionRuntimeDao(
    val connectionContext: ConnectQueueHolder,
) : ConnectionDao {
    override fun enqueue(connection: ConnectionDto, points: GammonGamePoints, timePolicy: TimePolicy) {
        val gameSearchDetails = GameSearchDetails(connection.gameType, points, timePolicy)
        connectionContext.connectionQueues.putIfAbsent(gameSearchDetails, ConcurrentLinkedQueue())
        connectionContext.connectionQueues[gameSearchDetails]!!.add(connection)
    }

    override fun flushAll(gameType: GameType, points: GammonGamePoints, timePolicy: TimePolicy): List<ConnectionDto> {
        val gameSearchDetails = GameSearchDetails(gameType, points, timePolicy)
        val queue = connectionContext.connectionQueues[gameSearchDetails] ?: return listOf()
        val drained = mutableListOf<ConnectionDto>()
        while (true) {
            val item = queue.poll() ?: break
            drained.add(item)
        }
        return drained

    }
}