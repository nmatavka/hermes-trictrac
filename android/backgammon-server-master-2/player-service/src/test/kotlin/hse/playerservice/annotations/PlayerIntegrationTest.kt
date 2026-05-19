package hse.playerservice.annotations

import org.springframework.boot.test.autoconfigure.jdbc.AutoConfigureTestDatabase
import org.springframework.boot.test.autoconfigure.orm.jpa.AutoConfigureDataJpa
import org.springframework.boot.test.autoconfigure.orm.jpa.AutoConfigureTestEntityManager
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.test.context.TestPropertySource

@SpringBootTest(
    webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
)
@AutoConfigureMockMvc
@AutoConfigureTestDatabase(
    replace = AutoConfigureTestDatabase.Replace.AUTO_CONFIGURED,
)
@AutoConfigureTestEntityManager
@AutoConfigureDataJpa
@TestPropertySource("classpath:application-test.yaml")
annotation class PlayerIntegrationTest()
