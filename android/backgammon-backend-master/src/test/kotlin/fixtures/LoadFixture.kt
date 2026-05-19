package fixtures

import utils.Filename
import java.io.File

fun getFixtureFilename(fixtureName: String) = Filename("./src/test/kotlin/fixtures/$fixtureName")

fun loadFixture(fixtureName: String) = getFixtureFilename(fixtureName).load().readText()