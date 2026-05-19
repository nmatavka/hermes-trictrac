package hse.playerservice.controller

import com.fasterxml.jackson.databind.ObjectMapper
import hse.playerservice.annotations.PlayerIntegrationTest
import hse.playerservice.repository.UserRepository
import hse.playerservice.service.JwtService
import hse.playerservice.service.UserService
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito
import org.mockito.kotlin.any
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.web.server.LocalServerPort
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*
import player.request.*
import player.response.JwtResponse

@PlayerIntegrationTest
class UserControllerTest {

    @Autowired
    private lateinit var userService: UserService

    @LocalServerPort
    val port: Int = 80

    @Autowired
    private lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var userRepository: UserRepository

    @MockitoBean
    lateinit var jwtService: JwtService

    @Autowired
    lateinit var objectMapper: ObjectMapper

    @MockitoBean
    lateinit var passwordEncoder: PasswordEncoder

    @BeforeEach
    fun setup() {
        Mockito.`when`(jwtService.generateToken(any())).thenReturn("token")
        Mockito.`when`(passwordEncoder.encode(anyString())).thenAnswer { it.arguments[0] as String }
        Mockito.`when`(passwordEncoder.matches(anyString(), anyString()))
            .thenAnswer { it.arguments[0] == it.arguments[1] }
    }

    companion object {
        const val TOKEN = "token"
        const val AUTH_HEADER = "auth-user"
    }

    @Test
    fun `create user test`() {
        val login = "create user test"
        val request = CreateUserRequest(login, "123")
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            post("http://localhost:$port/create").contentType(MediaType.APPLICATION_JSON)
                .content(body)
        ).andExpect {
            val jwtResponse = objectMapper.readValue(it.response.contentAsString, JwtResponse::class.java)
            assertEquals(TOKEN, jwtResponse.token)
            assertEquals(1, jwtResponse?.userId)
        }

        val user = userRepository.findByLogin(login)
        assertNotNull(user)
        assertEquals(1, user!!.id)
    }

    @Test
    fun `login test`() {
        val request = AuthRequest("login test", "123")
        val body = objectMapper.writeValueAsString(request)
        Mockito.`when`(jwtService.generateToken(any())).thenReturn("token2")
        mockMvc.perform(
            post("http://localhost:$port/login").contentType(MediaType.APPLICATION_JSON)
                .content(body)
        ).andExpect {
            val jwtResponse = objectMapper.readValue(it.response.contentAsString, JwtResponse::class.java)
            assertEquals(9999, jwtResponse?.userId)
            assertEquals("token2", jwtResponse.token)
        }
    }

    @Test
    fun `change password test`() {
        val request = ChangePasswordRequest(oldPassword = "123", newPassword = "124")
        val userId = 1337L
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            post("http://localhost:$port/password").contentType(MediaType.APPLICATION_JSON).header(AUTH_HEADER, userId)
                .content(body)
        ).andExpect {
            val jwtResponse = objectMapper.readValue(it.response.contentAsString, JwtResponse::class.java)
            val userFromBd = userRepository.findById(userId)
            assertEquals(userId, jwtResponse?.userId)
            assertEquals("124", userFromBd.get().password)
        }

    }


    @Test
    fun `delete user test`() {
        val request = DeleteUserRequest("123")
        val userId = 228L
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            delete("http://localhost:$port/delete").contentType(MediaType.APPLICATION_JSON).header(AUTH_HEADER, userId)
                .content(body)
        ).andExpect {

            assertEquals(it.response.status, HttpStatus.OK.value())
            assertNull(userService.findUser(userId))
        }
    }

    @Test
    fun `update username test`() {
        val request = UpdateUserInfoRequest(null, "timur", null)
        val userId = 1489L
        val body = objectMapper.writeValueAsString(request)
        mockMvc.perform(
            put("http://localhost:$port/userinfo").contentType(MediaType.APPLICATION_JSON).header(
                AUTH_HEADER, userId
            ).content(body)
        ).andExpect {
            assertEquals(it.response.status, HttpStatus.OK.value())
            assertEquals("timur", userService.findUserForAuth(userId).username)
        }
    }
}