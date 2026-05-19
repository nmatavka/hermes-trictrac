package scorers

import kotlin.js.Promise
import kotlinx.coroutines.await

@JsModule("onnxruntime-web")
@JsNonModule
external object ort {

    class Tensor<T>(s: String, a: Array<T>, dims: Array<Int>) {
        val size: Int
        val dims: List<Int>
        val data: Array<T>
    }

    class InferenceSession {
        companion object {
            fun create(path: String): Promise<InferenceSession>
        }
        suspend fun run(feeds: dynamic): Promise<dynamic>
    }
}


/**
 * Adapter for running a neural net using the Onnx Runtime.
 * The web runtime is used: https://www.npmjs.com/package/onnxruntime-web
 */
class OnnxSession() {
    var session: ort.InferenceSession? = null
    lateinit var inputShape: Array<Int>
    lateinit var outputShape: Array<Int>

    /**
     * Open a session loading the network at `path`.
     * The input and output layers has to be called input and output respectively.
     */
    suspend fun open(path: String, inputShape: Array<Int>, outputShape: Array<Int>) {
        session = ort.InferenceSession.create(path).await()
        this.inputShape = inputShape
        this.outputShape = outputShape
    }

    /**
     * Runs the network on an input batch.
     */
    suspend fun evaluate(input: Array<Float>): Array<Float> {
        session ?: error("OnnxSession has not been opened yet.")
        val inputT = ort.Tensor("float32", input, inputShape)
        val input = js("{}")
        input.input = inputT
        val output = session!!.run(input).await()
        return (output.output as ort.Tensor<Float>).data
    }
}