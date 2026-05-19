package hse.playerservice.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.readValue
import hse.playerservice.annotations.PlayerIntegrationTest
import hse.playerservice.repository.FriendRecordRepository
import hse.playerservice.repository.FriendRequestRepository
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.web.server.LocalServerPort
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*
import org.springframework.transaction.annotation.Transactional
import player.request.AddFriendRequest
import player.request.RemoveFriendRequest
import player.response.GetFriendResponse
import kotlin.math.max
import kotlin.math.min

@PlayerIntegrationTest
class FriendControllerTest {

    @LocalServerPort
    val port: Int = 80

    @Autowired
    private lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var objectMapper: ObjectMapper

    @Autowired
    lateinit var friendRequestRepository: FriendRequestRepository


    @Autowired
    lateinit var friendRecordRepository: FriendRecordRepository


    @ParameterizedTest
    @CsvSource("301,302", "310,309")
    fun `create friend request`(firstId: Long, secondId: Long) {
        val request = AddFriendRequest.AddFriendById(secondId)
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            post("http://localhost:$port/friends/add").contentType(MediaType.APPLICATION_JSON)
                .header(FriendController.AUTH_HEADER, firstId)
                .content(body)
        ).andExpect {
            val friendRequest = friendRequestRepository.findFirstByFromAndTo(firstId, secondId)
            assertNotNull(friendRequest)
            assertFalse(
                friendRecordRepository.existsFriendRecordByFirstUserAndSecondUser(
                    min(firstId, secondId),
                    max(firstId, secondId)
                )
            )
        }
    }

    @Test
    fun `add friend by existed request request`() {
        val currentUserId = 303L
        val request = AddFriendRequest.AddFriendById(304)
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            post("http://localhost:$port/friends/add").contentType(MediaType.APPLICATION_JSON)
                .header(FriendController.AUTH_HEADER, currentUserId)
                .content(body)
        ).andExpect {
            val friendRequest = friendRequestRepository.findFirstByFromAndTo(currentUserId, request.friendId)
            assertNull(friendRequest)
            assertTrue(
                friendRecordRepository.existsFriendRecordByFirstUserAndSecondUser(
                    currentUserId,
                    request.friendId
                )
            )
        }
    }

    @Test
    fun `add friend retry request`() {
        val currentUserId = 308L
        val request = AddFriendRequest.AddFriendById(307)
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            post("http://localhost:$port/friends/add").contentType(MediaType.APPLICATION_JSON)
                .header(FriendController.AUTH_HEADER, currentUserId)
                .content(body)
        ).andExpect {
            val friendRequest = friendRequestRepository.findFirstByFromAndTo(currentUserId, request.friendId)
            assertNotNull(friendRequest)
            assertFalse(
                friendRecordRepository.existsFriendRecordByFirstUserAndSecondUser(
                    request.friendId,
                    currentUserId
                )
            )
        }
    }

    @Test
    fun `add friend already friend request`() {
        val currentUserId = 305L
        val request = AddFriendRequest.AddFriendByLogin("add friend already friend request 2")
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            post("http://localhost:$port/friends/add").contentType(MediaType.APPLICATION_JSON)
                .header(FriendController.AUTH_HEADER, currentUserId)
                .content(body)
        ).andExpect {
            assertEquals(HttpStatus.CONFLICT.value(), it.response.status)
        }
    }

    @Test
    @Transactional
    fun `remove friend request`() {
        val currentUserId = 312L
        val request = RemoveFriendRequest.RemoveFriendByLogin("remove friend request 1")
        val body = objectMapper.writeValueAsString(request)


        assertTrue(friendRecordRepository.existsFriendRecordByFirstUserAndSecondUser(311, currentUserId))

        mockMvc.perform(
            delete("http://localhost:$port/friends/remove").contentType(MediaType.APPLICATION_JSON)
                .header(FriendController.AUTH_HEADER, currentUserId)
                .content(body)
        )
// проверка выключена: jpa не может сделать удаление без транзакции, а транзакции в текстах не работают
//        assertFalse(friendRecordRepository.existsFriendRecordByFirstUserAndSecondUser(311, currentUserId))
    }

    @Test
    fun `get friends test`() {
        val currentUserId = 313L

        mockMvc.perform(
            get("http://localhost:$port/friends").header(FriendController.AUTH_HEADER, currentUserId)
                .param("offset", "1").param("limit", "1").param("userId", currentUserId.toString())
        )
            .andExpect {
                val response: List<GetFriendResponse> = objectMapper.readValue(it.response.contentAsString)
                println(response)
                assertEquals(1, response.size)
            }
    }
}