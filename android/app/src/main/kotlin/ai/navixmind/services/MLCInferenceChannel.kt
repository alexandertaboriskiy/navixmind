package ai.navixmind.services

import ai.mlc.mlcllm.MLCEngine
import ai.mlc.mlcllm.OpenAIProtocol
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Wraps MLC LLM MLCEngine via MethodChannel for on-device inference.
 *
 * MethodChannel: ai.navixmind/mlc_inference
 *   - loadModel(modelId, modelPath, modelLib)
 *   - generate(messagesJson, toolsJson?, maxTokens)
 *   - unloadModel()
 *   - getLoadedModel()
 *
 * All MLC operations run on a single-threaded [inferenceExecutor] because
 * MLCEngine is not thread-safe. Results are posted back on the main thread.
 *
 * MLCEngine internally spawns two background threads for the inference loop
 * and stream-back loop. The engine is created once on first [loadModel] call
 * and reused for the lifetime of the app.
 */
class MLCInferenceChannel(flutterEngine: FlutterEngine) {

    companion object {
        private const val TAG = "MLCInference"
        private const val CHANNEL_NAME = "ai.navixmind/mlc_inference"
    }

    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME
    )

    private val mainHandler = Handler(Looper.getMainLooper())

    // Single-threaded executor — MLCEngine is NOT thread-safe
    private val inferenceExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "mlc-inference").also { it.isDaemon = true }
    }

    // Engine state (only accessed from inferenceExecutor thread)
    private var engine: MLCEngine? = null
    private var loadedModelId: String? = null
    private var loadedModelLib: String? = null

    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "loadModel" -> {
                    val modelId = call.argument<String>("modelId")
                    val modelPath = call.argument<String>("modelPath")
                    val modelLib = call.argument<String>("modelLib")
                    if (modelId == null || modelPath == null || modelLib == null) {
                        result.error("INVALID_ARGS", "modelId, modelPath, modelLib required", null)
                        return@setMethodCallHandler
                    }
                    loadModel(modelId, modelPath, modelLib, result)
                }
                "generate" -> {
                    val messagesJson = call.argument<String>("messagesJson")
                    val toolsJson = call.argument<String>("toolsJson")
                    val maxTokens = call.argument<Int>("maxTokens") ?: 2048
                    if (messagesJson == null) {
                        result.error("INVALID_ARGS", "messagesJson required", null)
                        return@setMethodCallHandler
                    }
                    generate(messagesJson, toolsJson, maxTokens, result)
                }
                "unloadModel" -> {
                    unloadModel(result)
                }
                "getLoadedModel" -> {
                    result.success(loadedModelId)
                }
                "getGpuMemoryMB" -> {
                    getGpuMemoryMB(result)
                }
                else -> result.notImplemented()
            }
        }
        Log.d(TAG, "MLCInferenceChannel initialized")
    }

    /**
     * Load a model into GPU memory for inference.
     *
     * Creates the MLCEngine on first call (starts background threads),
     * then calls reload() to load the specified model. Takes 10-30s
     * depending on model size.
     */
    private fun loadModel(
        modelId: String,
        modelPath: String,
        modelLib: String,
        result: MethodChannel.Result
    ) {
        // Already loaded?
        if (loadedModelId == modelId && engine != null) {
            Log.d(TAG, "Model $modelId already loaded")
            mainHandler.post { result.success(true) }
            return
        }

        inferenceExecutor.execute {
            try {
                Log.i(TAG, "Loading model $modelId from $modelPath (lib=$modelLib)")
                val startTime = System.currentTimeMillis()

                // Verify model directory exists
                val modelDir = File(modelPath)
                if (!modelDir.exists() || !modelDir.isDirectory) {
                    mainHandler.post {
                        result.error("MODEL_NOT_FOUND", "Model directory not found: $modelPath", null)
                    }
                    return@execute
                }

                // Unload previous model if any
                engine?.unload()

                // Create engine on first use (spawns background inference threads)
                if (engine == null) {
                    try {
                        engine = MLCEngine()
                        Log.i(TAG, "MLCEngine created successfully")
                    } catch (e: UnsatisfiedLinkError) {
                        mainHandler.post {
                            result.error(
                                "MLC_NOT_AVAILABLE",
                                "MLC LLM native libraries not found. Ensure mlc4j is built.",
                                e.message
                            )
                        }
                        return@execute
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error(
                                "MLC_NOT_AVAILABLE",
                                "Failed to create MLCEngine: ${e.message}",
                                null
                            )
                        }
                        return@execute
                    }
                }

                // Load model into GPU memory via OpenCL
                engine!!.reload(modelPath, modelLib)

                loadedModelId = modelId
                loadedModelLib = modelLib
                val elapsed = System.currentTimeMillis() - startTime
                Log.i(TAG, "Model $modelId loaded in ${elapsed}ms")

                mainHandler.post { result.success(true) }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to load model $modelId", e)
                mainHandler.post {
                    result.error("LOAD_FAILED", "Failed to load model: ${e.message}", null)
                }
            }
        }
    }

    /**
     * Run inference on the loaded model.
     *
     * Accepts messages in OpenAI chat format (JSON array), optionally with tool schemas.
     * Uses MLCEngine's streaming API (ReceiveChannel) and collects all chunks into
     * a complete response, then converts to Claude API format.
     */
    private fun generate(
        messagesJson: String,
        toolsJson: String?,
        maxTokens: Int,
        result: MethodChannel.Result
    ) {
        if (engine == null || loadedModelId == null) {
            result.error("NO_MODEL", "No model loaded. Call loadModel first.", null)
            return
        }

        inferenceExecutor.execute {
            try {
                Log.d(TAG, "Generating response (maxTokens=$maxTokens)")
                val startTime = System.currentTimeMillis()

                val messages = parseMessages(messagesJson)
                val tools = if (toolsJson != null) parseTools(toolsJson) else null

                // Run streaming inference via coroutines
                val openaiResponseJson = runBlocking {
                    val channel = engine!!.chat.completions.create(
                        messages = messages,
                        max_tokens = maxTokens,
                        temperature = 0.7f,
                        stream_options = OpenAIProtocol.StreamOptions(include_usage = true),
                        tools = tools
                    )

                    // Accumulate streaming chunks into a complete response
                    val fullText = StringBuilder()
                    val toolCallAccumulators = mutableMapOf<Int, ToolCallAccumulator>()
                    var finishReason = "stop"
                    var promptTokens = 0
                    var completionTokens = 0

                    for (response in channel) {
                        for (choice in response.choices) {
                            // Accumulate text deltas
                            choice.delta.content?.let { content ->
                                fullText.append(content.asText())
                            }

                            // Accumulate tool call deltas (streamed incrementally by index)
                            choice.delta.tool_calls?.forEachIndexed { _, tc ->
                                val acc = toolCallAccumulators.getOrPut(toolCallAccumulators.size) {
                                    ToolCallAccumulator()
                                }
                                if (tc.id.isNotEmpty()) acc.id = tc.id
                                if (tc.function.name.isNotEmpty()) acc.name = tc.function.name
                                tc.function.arguments?.let { args ->
                                    acc.arguments = args
                                }
                            }

                            choice.finish_reason?.let { fr ->
                                finishReason = fr
                            }
                        }

                        // Usage arrives on the final chunk
                        response.usage?.let { usage ->
                            promptTokens = usage.prompt_tokens
                            completionTokens = usage.completion_tokens
                        }
                    }

                    // Assemble into OpenAI non-streaming response format
                    assembleOpenAIResponse(
                        fullText.toString(),
                        toolCallAccumulators.values.toList(),
                        finishReason,
                        promptTokens,
                        completionTokens
                    )
                }

                val elapsed = System.currentTimeMillis() - startTime
                Log.d(TAG, "Generation completed in ${elapsed}ms")

                // Convert OpenAI format → Claude format
                val claudeResponse = buildClaudeCompatibleResponse(openaiResponseJson)
                mainHandler.post { result.success(claudeResponse) }
            } catch (e: Exception) {
                Log.e(TAG, "Generation failed", e)
                mainHandler.post {
                    result.error("GENERATE_FAILED", "Generation failed: ${e.message}", null)
                }
            }
        }
    }

    /**
     * Parse OpenAI-format messages JSON array into MLCEngine message objects.
     */
    private fun parseMessages(messagesJson: String): List<OpenAIProtocol.ChatCompletionMessage> {
        val jsonArray = JSONArray(messagesJson)
        val messages = mutableListOf<OpenAIProtocol.ChatCompletionMessage>()

        for (i in 0 until jsonArray.length()) {
            val msgObj = jsonArray.getJSONObject(i)
            val role = when (msgObj.optString("role", "user")) {
                "system" -> OpenAIProtocol.ChatCompletionRole.system
                "assistant" -> OpenAIProtocol.ChatCompletionRole.assistant
                "tool" -> OpenAIProtocol.ChatCompletionRole.tool
                else -> OpenAIProtocol.ChatCompletionRole.user
            }

            val content = msgObj.optString("content", "")
            val toolCallId = if (msgObj.has("tool_call_id")) {
                msgObj.optString("tool_call_id", null)
            } else null

            messages.add(OpenAIProtocol.ChatCompletionMessage(
                role = role,
                content = content,
                tool_call_id = toolCallId
            ))
        }

        return messages
    }

    /**
     * Parse OpenAI-format tools JSON array into MLCEngine ChatTool objects.
     *
     * Preserves the full JSON schema for parameters so the model sees
     * proper OpenAI function-calling format (type, properties, required).
     */
    private fun parseTools(toolsJson: String): List<OpenAIProtocol.ChatTool> {
        val jsonArray = JSONArray(toolsJson)
        val tools = mutableListOf<OpenAIProtocol.ChatTool>()
        for (i in 0 until jsonArray.length()) {
            val toolObj = jsonArray.getJSONObject(i)
            val funcObj = toolObj.getJSONObject("function")
            val name = funcObj.getString("name")
            val description = funcObj.optString("description", null)

            // Convert parameters JSON object to Map<String, String> for MLC API
            val paramsMap: Map<String, String> = funcObj.optJSONObject("parameters")?.let { paramsObj ->
                val map = mutableMapOf<String, String>()
                for (key in paramsObj.keys()) {
                    map[key] = paramsObj.get(key).toString()
                }
                map
            } ?: emptyMap()

            tools.add(OpenAIProtocol.ChatTool(
                type = "function",
                function = OpenAIProtocol.ChatFunction(
                    name = name,
                    description = description,
                    parameters = paramsMap
                )
            ))
        }

        Log.d(TAG, "Parsed ${tools.size} tools")
        return tools
    }

    /**
     * Helper to accumulate streaming tool call deltas.
     */
    private class ToolCallAccumulator {
        var id: String = "call_${System.currentTimeMillis()}"
        var name: String = ""
        var arguments: Map<String, String>? = null
    }

    /**
     * Assemble collected streaming data into a complete OpenAI non-streaming response JSON.
     */
    private fun assembleOpenAIResponse(
        text: String,
        toolCalls: List<ToolCallAccumulator>,
        finishReason: String,
        promptTokens: Int,
        completionTokens: Int
    ): String {
        val message = JSONObject().apply {
            put("content", text)
            if (toolCalls.isNotEmpty()) {
                val tcArray = JSONArray()
                for (tc in toolCalls) {
                    if (tc.name.isEmpty()) continue
                    tcArray.put(JSONObject().apply {
                        put("id", tc.id)
                        put("type", "function")
                        put("function", JSONObject().apply {
                            put("name", tc.name)
                            put("arguments", JSONObject(tc.arguments ?: emptyMap<String, String>()).toString())
                        })
                    })
                }
                if (tcArray.length() > 0) {
                    put("tool_calls", tcArray)
                }
            }
        }

        return JSONObject().apply {
            put("choices", JSONArray().put(JSONObject().apply {
                put("message", message)
                put("finish_reason", finishReason)
            }))
            put("usage", JSONObject().apply {
                put("prompt_tokens", promptTokens)
                put("completion_tokens", completionTokens)
            })
        }.toString()
    }

    /**
     * Convert MLCEngine's OpenAI-format response to Claude API format.
     *
     * Maps: choices[0].message → content[], finish_reason → stop_reason,
     * tool_calls → tool_use blocks, usage → input_tokens/output_tokens.
     */
    fun buildClaudeCompatibleResponse(openaiResponseJson: String): String {
        val openai = JSONObject(openaiResponseJson)

        val choices = openai.optJSONArray("choices")
        val choice = choices?.optJSONObject(0) ?: JSONObject()
        val message = choice.optJSONObject("message") ?: JSONObject()
        val finishReason = choice.optString("finish_reason", "stop")

        // Build Claude content array
        val claudeContent = JSONArray()

        // Add text content if present
        val textContent = message.optString("content", "")
        if (textContent.isNotEmpty()) {
            claudeContent.put(JSONObject().apply {
                put("type", "text")
                put("text", textContent)
            })
        }

        // Convert tool_calls to Claude format
        val toolCalls = message.optJSONArray("tool_calls")
        var hasToolCalls = false
        if (toolCalls != null && toolCalls.length() > 0) {
            hasToolCalls = true
            for (i in 0 until toolCalls.length()) {
                val tc = toolCalls.getJSONObject(i)
                val function = tc.optJSONObject("function") ?: continue
                val toolCallId = tc.optString("id", "call_${System.currentTimeMillis()}_$i")
                val functionName = function.optString("name", "")
                val argumentsStr = function.optString("arguments", "{}")

                // Parse arguments JSON
                val arguments = try {
                    JSONObject(argumentsStr)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to parse tool call arguments: $argumentsStr")
                    JSONObject()
                }

                claudeContent.put(JSONObject().apply {
                    put("type", "tool_use")
                    put("id", toolCallId)
                    put("name", functionName)
                    put("input", arguments)
                })
            }
        }

        // If no text and no tool calls, add empty text
        if (textContent.isEmpty() && !hasToolCalls) {
            claudeContent.put(JSONObject().apply {
                put("type", "text")
                put("text", "")
            })
        }

        // Map stop reason
        val claudeStopReason = when {
            hasToolCalls || finishReason == "tool_calls" -> "tool_use"
            finishReason == "length" -> "max_tokens"
            else -> "end_turn"
        }

        // Convert usage
        val openaiUsage = openai.optJSONObject("usage") ?: JSONObject()
        val claudeUsage = JSONObject().apply {
            put("input_tokens", openaiUsage.optInt("prompt_tokens", 0))
            put("output_tokens", openaiUsage.optInt("completion_tokens", 0))
        }

        // Build final response
        val claudeResponse = JSONObject().apply {
            put("stop_reason", claudeStopReason)
            put("content", claudeContent)
            put("usage", claudeUsage)
        }

        return claudeResponse.toString()
    }

    /**
     * Unload the current model from GPU memory.
     */
    private fun unloadModel(result: MethodChannel.Result) {
        inferenceExecutor.execute {
            unloadEngineInternal()
            mainHandler.post { result.success(true) }
        }
    }

    /**
     * Internal unload — must be called from inferenceExecutor thread.
     */
    private fun unloadEngineInternal() {
        if (engine != null && loadedModelId != null) {
            try {
                engine!!.unload()
                Log.i(TAG, "Unloaded model $loadedModelId")
            } catch (e: Exception) {
                Log.w(TAG, "Error unloading engine: ${e.message}")
            }
            loadedModelId = null
            loadedModelLib = null
        }
    }

    /**
     * Query total GPU memory via TVM's OpenCL device attribute.
     * Returns the value in MB, or -1 if unavailable.
     */
    private fun getGpuMemoryMB(result: MethodChannel.Result) {
        inferenceExecutor.execute {
            try {
                // TVM kTotalGlobalMemory = 14, Device.opencl() = deviceType 4
                val getDeviceAttr = org.apache.tvm.Function.getFunction("runtime.GetDeviceAttr")
                if (getDeviceAttr == null) {
                    mainHandler.post { result.success(-1) }
                    return@execute
                }
                val device = org.apache.tvm.Device.opencl()
                val totalBytes = getDeviceAttr
                    .pushArg(device.deviceType)
                    .pushArg(device.deviceId)
                    .pushArg(14) // kTotalGlobalMemory
                    .invoke()
                    .asLong()
                val totalMB = (totalBytes / (1024 * 1024)).toInt()
                Log.i(TAG, "GPU memory: ${totalMB} MB")
                mainHandler.post { result.success(totalMB) }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to query GPU memory: ${e.message}")
                mainHandler.post { result.success(-1) }
            }
        }
    }

    /**
     * Called when system is under memory pressure.
     * Automatically unloads the model to free GPU memory.
     */
    fun onTrimMemory(level: Int) {
        // Only unload under genuine memory pressure, NOT on every background event.
        // TRIM_MEMORY_UI_HIDDEN=20 fires on every app background (e.g. file picker) — too aggressive.
        // TRIM_MEMORY_MODERATE=60 or TRIM_MEMORY_COMPLETE=80 indicate real system pressure.
        if (level >= 60 && engine != null && loadedModelId != null) {
            Log.w(TAG, "Memory pressure (level=$level), unloading model")
            inferenceExecutor.execute {
                unloadEngineInternal()
            }
        }
    }

    /**
     * Cleanup resources. Call from Activity.onDestroy().
     */
    fun cleanup() {
        inferenceExecutor.execute {
            unloadEngineInternal()
            // Engine keeps running (background threads) but model is unloaded
        }
        inferenceExecutor.shutdown()
        Log.d(TAG, "MLCInferenceChannel cleaned up")
    }
}
