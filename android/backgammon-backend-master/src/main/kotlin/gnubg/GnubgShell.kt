package gnubg

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import utils.getEnvVar
import java.io.BufferedReader
import java.io.BufferedWriter
import java.io.Closeable
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.util.Scanner


class GnuBgShell(
    private val scope: CoroutineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
) : Closeable {
    private var process: Process? = null
    private var writer: BufferedWriter? = null
    private var scanner: Scanner? = null

    // Mutex ensures we don't send two commands at once (overlapping outputs)
    private val mutex = Mutex()

    fun start() {
        val builder =
            ProcessBuilder(
                getEnvVar("GNUBG_COMMAND"),
                "-t",
                "--quiet",
                *when (getEnvVar("GNUBG_SETTINGS_FOLDER")) {
                    is String -> arrayOf("-s", getEnvVar("GNUBG_SETTINGS_FOLDER"))
                    else -> emptyArray<String>()
                },
            ) // -t for TTY, --quiet for less noise
        builder.redirectErrorStream(true) // Merge stderr into stdout
        process = builder.start()

        writer = BufferedWriter(OutputStreamWriter(process!!.outputStream))
        scanner = Scanner(process!!.inputStream).useDelimiter("gnubg>>")
    }


    suspend fun sendCommand(vararg commands: String): String {
        return mutex.withLock {
            val lines = mutableListOf<String>()

            commands.forEach { command ->
                writer?.write("$command \n show prompt")
                writer?.newLine()
                writer?.flush()


                val response = withTimeout(10000) {
                    val scanner = scanner ?: throw IllegalStateException("Shell not started")

                    when (scanner.hasNext()) {
                        true -> scanner.next()
                        false -> "no response for command $command found."
                    }
                }
                lines.add(response)
            }

            lines.joinToString("\n")
        }
    }

    override fun close() {
        process?.destroy()
    }
}

val shellProcess = GnuBgShell().also { shell ->
    shell.start()
}

