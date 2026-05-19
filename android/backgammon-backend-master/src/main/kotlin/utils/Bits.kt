package utils

import java.util.Base64
import java.util.function.BooleanSupplier
import java.util.function.IntSupplier

@JvmInline value class Bits(private val value: String) : BooleanSupplier, IntSupplier {
    fun getBits(bitNumbers: IntRange) = value.substring(
        bitNumbers.start - 1..bitNumbers.endInclusive - 1
    ).let { Bits(it) }

    override fun getAsBoolean(): Boolean = when (value) {
        "0" -> false
        "1" -> true
        else -> throw Error("Should only cast single bit to boolean.")
    }

    val asBinaryString get() = value.reversed()

    fun getBoolean(bitNumber: Int) = getBits(bitNumber..bitNumber).asBoolean

    override fun getAsInt(): Int {
        return value.reversed().toInt(2)
    }


    companion object {
        fun fromBase64String(base64String: String) = Bits(
            Base64.getDecoder().decode(base64String).joinToString("") {
                it.toUByte().toString(2).padStart(8, '0').reversed()
            }
        )
    }
}