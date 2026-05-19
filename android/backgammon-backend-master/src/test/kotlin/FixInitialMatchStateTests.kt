import fixtures.loadFixture
import gnubg.doesMatchNeedToBeFixed
import gnubg.fixMatchString
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import java.io.File


class FixInitialMatchStateTests : FunSpec({
    test("match needs fixing") {
        doesMatchNeedToBeFixed(loadFixture("match-needs-fixing.mat")) shouldBe true
    }

    test("match does not need fixing") {
        doesMatchNeedToBeFixed(loadFixture("match-does-not-need-fixing.mat")) shouldBe false
    }

    test("match does not need fixing 2") {
        doesMatchNeedToBeFixed(loadFixture("match-does-not-need-fixing2.mat")) shouldBe false
    }

    test("fix match") {
        fixMatchString(loadFixture("match-needs-fixing.mat")) shouldBe loadFixture("match-needs-fixing~FIXED.mat")
    }

    test("fix match after game") {
        val beforeFix = loadFixture("match-needs-fixing-2.mat")
        doesMatchNeedToBeFixed(beforeFix) shouldBe true

        val expected = loadFixture("match-needs-fixing-2~FIXED.mat")
        val actual = fixMatchString(beforeFix)

        println(actual)
    }
})