package hse.playerservice.controller

import hse.playerservice.service.UserService
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import player.request.*
import player.response.JwtResponse
import player.response.UserInfoResponse


@RestController
class UserController(
    private val userService: UserService,
) {

    companion object {
        const val AUTH_HEADER = "auth-user"
    }

    @PostMapping("/create")
    fun createUser(@RequestBody request: CreateUserRequest): JwtResponse {
        return userService.createUser(request)
    }


    @PostMapping("/login")
    fun login(
        @RequestBody request: AuthRequest,
        response: HttpServletResponse
    ): JwtResponse {
        return userService.authenticate(request.login, request.password)
    }

    @GetMapping("/auth")
    fun auth(@RequestParam token: String): JwtResponse {
        return userService.authenticate(token)
    }

    @PostMapping("/password")
    fun changePassword(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @RequestBody changePasswordRequest: ChangePasswordRequest
    ): JwtResponse {
        return userService.changePassword(userId, changePasswordRequest)
    }

    @DeleteMapping("/delete")
    fun deleteUser(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @RequestBody request: DeleteUserRequest
    ): ResponseEntity<Void> {
        return userService.deleteUser(userId, request)
    }

    @PostMapping("/image")
    fun uploadImage(@RequestHeader(AUTH_HEADER) userId: Long, @RequestBody file: MultipartFile): ResponseEntity<Void> {
        return userService.saveUserImage(userId, file)
    }

    @GetMapping("/image")
    fun getImage(@RequestParam userId: Long): ResponseEntity<ByteArray> {
        val res = userService.getImage(userId)
        return ResponseEntity.ok().header("Content-Type", res.extension).body(res.image)
    }

    @GetMapping("/userinfo")
    fun getUserInfo(@RequestParam userId: Long): UserInfoResponse {
        return userService.getUserInfo(userId)
    }

    @PostMapping("/userinfo")
    fun updateUserInfo(
        @RequestHeader(AUTH_HEADER) userId: Long,
        @RequestBody updateUserInfoRequest: UpdateUserInfoRequest
    ) {
        userService.update(userId, updateUserInfoRequest)
    }

    @GetMapping("/usernames")
    fun getUsernames(@RequestParam ids: String): List<String> {
        return userService.getAllUsernames(ids.split(",").map { it.toLong() }.toList())
    }

    @GetMapping("/me")
    fun getSelfInfo(@RequestHeader(AUTH_HEADER) userId: Long): UserInfoResponse {
        return userService.getUserInfo(userId)
    }

    @GetMapping("/is-authorized")
    fun checkAuth() {
    }
}