package gnubg

import java.util.Base64

fun Byte.toBinaryString() = toUByte().toString(2).padStart(8, '0')

@OptIn(ExperimentalStdlibApi::class) fun parsePosition(matchStatus: ParsedCommandResponse) {
    val bytes = matchStatus.positionId.encodeToByteArray()
    val x = Base64.getDecoder().decode(bytes)

    val decoded = Base64.getDecoder().decode(bytes).map { it.toBinaryString() }


    decoded.joinToString(" ").run(::println)
}