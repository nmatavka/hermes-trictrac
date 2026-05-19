package hse.menu.dao

import hse.menu.entity.Game
import hse.menu.enums.GameStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.repository.PagingAndSortingRepository
import org.springframework.stereotype.Repository

@Repository
interface GameDao : JpaRepository<Game, Long>, PagingAndSortingRepository<Game, Long> {
    fun findByFirstPlayerIdAndSecondPlayerIdAndStatus(
        firstPlayerId: Long,
        secondPlayerId: Long,
        status: GameStatus
    ): List<Game>
}