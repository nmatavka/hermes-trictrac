package gnubg

import utils.Filename
import utils.HasFilename
import java.io.File

fun doesMatchNeedToBeFixed(matchString: String): Boolean {
    return matchString.lines().last { line -> line.trim().startsWith("1)") }.trim().length == 6
}


fun fixMatchString(matchString: String): String {
    val lines = matchString.lines()
    val lastLine = lines.last().let { line ->
        line.replace("1)", "1)${List(28) { " " }.joinToString("")}")
    }
    val withoutLastLine = lines.dropLast(1)

    return (withoutLastLine + lastLine).joinToString("\n")
}

val resignRegex = Regex("offers to resign a (single game|gammon|backgammon)")


fun fixStartingMatch(inputFileName: HasFilename, outputFileName: HasFilename? = null) {
    val inputFile = inputFileName.load()
    val outputFile = outputFileName?.load() ?: inputFile

    val originalText = inputFile.readText()

    if (doesMatchNeedToBeFixed(originalText)) {
        outputFile.writeText(fixMatchString(originalText))
    }
}

