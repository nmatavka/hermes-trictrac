import fixtures.loadFixture
import analysis.GameAnalysis
import analysis.RollAnalysis
import gnubg.destination
import gnubg.parseMoveString
import gnubg.singleMove
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.sequences.shouldHaveSize
import io.kotest.matchers.shouldBe

val testStringOne = """
1. Cubeful 2-ply    13/7* 6/1*                   Eq.: +0.517
       0.581 0.332 0.012 - 0.419 0.126 0.010
        2-ply cubeful prune [world class]
    2. Cubeful 2-ply    24/18 6/1*                   Eq.: +0.500 (-0.017)
       0.587 0.260 0.007 - 0.413 0.092 0.003
        2-ply cubeful prune [world class]
    3. Cubeful 2-ply    18/7*                        Eq.: +0.455 (-0.062)
       0.577 0.273 0.016 - 0.423 0.113 0.006
        2-ply cubeful prune [world class]
    4. Cubeful 0-ply    13/8 13/7*                   Eq.: +0.270 (-0.247)
       0.542 0.259 0.018 - 0.458 0.140 0.011
        0-ply cubeful prune [expert]
    5. Cubeful 0-ply    24/13                        Eq.: +0.240 (-0.276)
       0.542 0.200 0.007 - 0.458 0.102 0.003
        0-ply cubeful prune [expert]
    6. Cubeful 0-ply    24/18 9/4                    Eq.: +0.224 (-0.293)
       0.537 0.197 0.007 - 0.463 0.100 0.004
        0-ply cubeful prune [expert]
    7. Cubeful 0-ply    24/18 13/8                   Eq.: +0.169 (-0.348)
       0.522 0.202 0.007 - 0.478 0.114 0.005
        0-ply cubeful prune [expert]
    8. Cubeful 0-ply    13/7*/2                      Eq.: +0.115 (-0.402)
       0.509 0.231 0.016 - 0.491 0.157 0.013
        0-ply cubeful prune [expert]
    9. Cubeful 0-ply    13/7* 9/4                    Eq.: +0.068 (-0.449)
       0.494 0.239 0.016 - 0.506 0.164 0.014
        0-ply cubeful prune [expert]
   10. Cubeful 0-ply    18/13 9/3                    Eq.: -0.052 (-0.569)
       0.468 0.192 0.008 - 0.532 0.149 0.010
        0-ply cubeful prune [expert])"""

val testStringThree = """
    1. Cubeful 2-ply    24/18 13/10                  Eq.: +0.013
       0.506 0.132 0.006 - 0.494 0.136 0.006
        2-ply cubeful prune [world class]
    2. Cubeful 2-ply    24/15                        Eq.: -0.003 (-0.016)
       0.504 0.123 0.005 - 0.496 0.135 0.005
        2-ply cubeful prune [world class]
    3. Cubeful 2-ply    24/21 13/7                   Eq.: -0.042 (-0.055)
       0.488 0.134 0.007 - 0.512 0.137 0.006
        2-ply cubeful prune [world class]
    4. Cubeful 2-ply    24/21 24/18                  Eq.: -0.054 (-0.067)
       0.492 0.121 0.005 - 0.508 0.145 0.005
        2-ply cubeful prune [world class]
    5. Cubeful 2-ply    13/4                         Eq.: -0.060 (-0.073)
       0.482 0.139 0.007 - 0.518 0.144 0.007
        2-ply cubeful prune [world class]
    6. Cubeful 2-ply    13/10 13/7                   Eq.: -0.087 (-0.100)
       0.477 0.139 0.008 - 0.523 0.150 0.010
        2-ply cubeful prune [world class]
    7. Cubeful 2-ply    24/18 6/3                    Eq.: -0.129 (-0.142)
       0.474 0.117 0.005 - 0.526 0.156 0.007
        2-ply cubeful prune [world class]
    8. Cubeful 2-ply    24/18 8/5                    Eq.: -0.133 (-0.146)
       0.474 0.120 0.006 - 0.526 0.161 0.008
        2-ply cubeful prune [world class]
    9. Cubeful 0-ply    13/7 6/3                     Eq.: -0.148 (-0.161)
       0.465 0.128 0.009 - 0.535 0.163 0.012
        0-ply cubeful prune [expert]
   10. Cubeful 0-ply    13/7 8/5                     Eq.: -0.151 (-0.164)
       0.464 0.128 0.009 - 0.536 0.163 0.013
        0-ply cubeful prune [expert] 
""".trimIndent()

val testStringTwo =
    """1. Cubeful 2-ply    24/22 13/10                  Eq.: -0.148
       0.468 0.124 0.005 - 0.532 0.164 0.008
        2-ply cubeful prune [world class]
    2. Cubeful 2-ply    24/21 13/11                  Eq.: -0.152 (-0.004)
       0.468 0.121 0.005 - 0.532 0.163 0.008
        2-ply cubeful prune [world class]
    3. Cubeful 2-ply    13/11 13/10                  Eq.: -0.170 (-0.021)
       0.459 0.129 0.006 - 0.541 0.163 0.011
        2-ply cubeful prune [world class]
    4. Cubeful 2-ply    13/8                         Eq.: -0.198 (-0.050)
       0.454 0.119 0.005 - 0.546 0.168 0.008
        2-ply cubeful prune [world class]
    5. Cubeful 2-ply    24/22 24/21                  Eq.: -0.208 (-0.060)
       0.455 0.110 0.004 - 0.545 0.167 0.006
        2-ply cubeful prune [world class]
    6. Cubeful 2-ply    13/10 6/4                    Eq.: -0.248 (-0.100)
       0.447 0.118 0.006 - 0.553 0.181 0.015
        2-ply cubeful prune [world class]
    7. Cubeful 2-ply    24/21 8/6                    Eq.: -0.264 (-0.116)
       0.439 0.111 0.004 - 0.561 0.172 0.007
        2-ply cubeful prune [world class]
    8. Cubeful 2-ply    13/10 8/6                    Eq.: -0.286 (-0.138)
       0.431 0.115 0.005 - 0.569 0.174 0.011
        2-ply cubeful prune [world class]
    9. Cubeful 0-ply    24/21 6/4                    Eq.: -0.244 (-0.096)
       0.447 0.109 0.006 - 0.553 0.180 0.010
        0-ply cubeful prune [expert]
   10. Cubeful 0-ply    6/1*                         Eq.: -0.249 (-0.101)
       0.440 0.114 0.005 - 0.560 0.169 0.012
        0-ply cubeful prune [expert]) 
    """

val testStringFour = """
    double
    test    
    1. Cubeful 2-ply    bar/17*(2)                   Eq.: +0.324               
       0.556 0.128 0.007 - 0.444 0.132 0.002
        2-ply cubeful prune [world class]
    2. Cubeful 2-ply    bar/21(2) 13/9(2)            Eq.: +0.281 (-0.043)
       0.533 0.140 0.007 - 0.467 0.124 0.002
        2-ply cubeful prune [world class]
    3. Cubeful 2-ply    bar/21(2) 6/2(2)             Eq.: +0.128 (-0.196)
       0.482 0.123 0.005 - 0.518 0.133 0.002
        2-ply cubeful prune [world class]
    4. Cubeful 0-ply    bar/17*/13 bar/21            Eq.: +0.140 (-0.184)
       0.508 0.125 0.007 - 0.492 0.193 0.003
        0-ply cubeful prune [expert]
    5. Cubeful 0-ply    bar/21(2) 8/4(2)             Eq.: +0.055 (-0.269)
       0.462 0.128 0.007 - 0.538 0.156 0.004
        0-ply cubeful prune [expert]
    6. Cubeful 0-ply    bar/21(2) 13/5               Eq.: -0.012 (-0.336)
       0.447 0.111 0.006 - 0.553 0.172 0.004
        0-ply cubeful prune [expert]
    7. Cubeful 0-ply    bar/17* bar/21 13/9          Eq.: -0.026 (-0.350)
       0.464 0.130 0.010 - 0.536 0.240 0.011
        0-ply cubeful prune [expert]
    8. Cubeful 0-ply    bar/21(2) 13/9 6/2           Eq.: -0.108 (-0.431)
       0.425 0.106 0.006 - 0.575 0.203 0.006
        0-ply cubeful prune [expert]
    9. Cubeful 0-ply    bar/21(2) 8/4 6/2            Eq.: -0.135 (-0.458)
       0.416 0.104 0.006 - 0.584 0.205 0.006
        0-ply cubeful prune [expert]
   10. Cubeful 0-ply    bar/17* bar/21 6/2           Eq.: -0.150 (-0.474)
       0.431 0.112 0.008 - 0.569 0.259 0.009
        0-ply cubeful prune [expert]    
""".trimIndent()

val testStringFive = """
    test!
    1. Cubeful 2-ply    bar/15                       Eq.: -0.106
       0.480 0.115 0.004 - 0.520 0.150 0.006
        2-ply cubeful prune [world class]
    2. Cubeful 2-ply    bar/21 24/18                 Eq.: -0.141 (-0.034)
       0.474 0.115 0.005 - 0.526 0.160 0.006
        2-ply cubeful prune [world class]
    3. Cubeful 2-ply    bar/21 8/2*                  Eq.: -0.154 (-0.048)
       0.462 0.119 0.005 - 0.538 0.147 0.008
        2-ply cubeful prune [world class]
    4. Cubeful 2-ply    bar/21 13/7                  Eq.: -0.205 (-0.098)
       0.450 0.116 0.005 - 0.550 0.154 0.008
        2-ply cubeful prune [world class]
""".trimIndent()

class AnalysisStringTests : FunSpec({
    test("first") {
        val rollAnalysis = GameAnalysis.fromString(testStringOne) as RollAnalysis
        rollAnalysis.value shouldHaveSize 10
    }
    test("second") {
        val rollAnalysis = GameAnalysis.fromString(testStringTwo) as RollAnalysis
        println(rollAnalysis.value)
        rollAnalysis.value shouldHaveSize 10
    }
    test("third") {
        val rollAnalysis = GameAnalysis.fromString(testStringThree) as RollAnalysis
        rollAnalysis.value shouldHaveSize 10
    }
    test("fourth") {
        val rollAnalysis = GameAnalysis.fromString(testStringFour) as RollAnalysis
        rollAnalysis.value.map{it.moveString} shouldHaveSize 10
    }
    test("fifth") {
        val rollAnalysis = GameAnalysis.fromString(testStringFive) as RollAnalysis
        rollAnalysis.value.map {it.moveString} shouldHaveSize 4
        println(rollAnalysis.value)
    }

    test("roll analysis with bear off") {
        val rollAnalysis = GameAnalysis.fromString(loadFixture("roll-analysis-with-bear-off")) as RollAnalysis
        println(rollAnalysis)

        rollAnalysis.value.map {it.moveString} shouldBe listOf(
            "6/off(3) 5/off",
            "6/off 5/off"
        )
    }

    test("destination") {
        destination.findAll("6 off 5 off") shouldHaveSize 4
    }

    test("bear off move") {
        singleMove.findAll("6/off 4/off") shouldHaveSize 2
    }

    test("parse move string") {
        parseMoveString("    1. Cubeful 0-ply    6/off(3) 5/off               Eq.: +1.986")
            .shouldBe("6/off(3) 5/off")
    }
})