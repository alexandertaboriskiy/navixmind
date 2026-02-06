package ai.navixmind

import android.os.Handler
import android.os.Looper
import com.chaquo.python.Python
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService

/**
 * Kotlin bridge between Flutter and Python via Chaquopy.
 *
 * CRITICAL THREADING NOTES:
 * - Python calls MUST run in a background thread to prevent deadlocks
 * - Results are posted back to main thread for Flutter
 * - Uses single-threaded executor to ensure Python GIL compatibility
 * - EventChannel allows Python to send async messages to Flutter
 */
class PythonMethodChannel(private val flutterEngine: FlutterEngine) {

    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "ai.navixmind/python_bridge"
    )

    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "ai.navixmind/python_events"
    )

    // Single-threaded executor dedicated to Python calls (queries)
    private val pythonExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "PythonExecutor").apply { isDaemon = true }
    }

    // Separate executor for sending responses back to Python.
    // CRITICAL: This must NOT share the same thread as pythonExecutor,
    // otherwise sendResponseToPython deadlocks when callPython is waiting
    // for the response (callPython blocks pythonExecutor → response queued
    // behind it → deadlock).
    private val responseExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "PythonResponseExecutor").apply { isDaemon = true }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    init {
        // Set up method channel for Flutter → Python calls
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "initializePython" -> {
                    initializePython(call.argument<String>("logDir") ?: "", result)
                }
                "callPython" -> {
                    val payload = call.argument<String>("payload")
                    if (payload != null) {
                        callPython(payload, result)
                    } else {
                        result.error("INVALID_ARGS", "payload is required", null)
                    }
                }
                "sendResponseToPython" -> {
                    val response = call.argument<String>("response")
                    if (response != null) {
                        sendResponseToPython(response, result)
                    } else {
                        result.error("INVALID_ARGS", "response is required", null)
                    }
                }
                "getPythonStatus" -> {
                    getPythonStatus(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Set up event channel for Python → Flutter messages
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    /**
     * Initialize Python runtime and set up the bridge.
     * This should be called once on app startup.
     */
    private fun initializePython(logDir: String, result: MethodChannel.Result) {
        pythonExecutor.execute {
            try {
                val py = Python.getInstance()

                // Initialize crash logger
                val crashLogger = py.getModule("navixmind.crash_logger")
                crashLogger.callAttr("initialize", logDir)

                // Initialize bridge
                val bridge = py.getModule("navixmind.bridge")
                bridge.callAttr("initialize")

                // Start polling for async messages from Python
                startMessagePolling(py)

                mainHandler.post {
                    result.success(mapOf("success" to true))
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("PYTHON_INIT_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    @Volatile
    private var isPolling = false

    /**
     * Poll Python for queued messages and forward to Flutter via EventChannel.
     * This replaces the callback mechanism which isn't supported in Chaquopy.
     */
    private fun startMessagePolling(py: Python) {
        isPolling = true
        android.util.Log.i("PythonPoller", "Starting message polling thread")
        Thread {
            var messageCount = 0
            while (isPolling) {
                try {
                    val bridge = py.getModule("navixmind.bridge")
                    val bridgeInstance = bridge.callAttr("get_bridge")

                    // Check for pending messages
                    while (bridgeInstance.callAttr("has_pending_messages").toBoolean()) {
                        val message = bridgeInstance.callAttr("get_pending_message")
                        if (message != null && message.toString() != "None") {
                            val messageStr = message.toString()
                            messageCount++
                            android.util.Log.d("PythonPoller", "Got message #$messageCount: ${messageStr.take(100)}...")
                            // Send to Flutter on main thread
                            mainHandler.post {
                                if (eventSink != null) {
                                    eventSink?.success(messageStr)
                                    android.util.Log.d("PythonPoller", "Sent to Flutter via eventSink")
                                } else {
                                    android.util.Log.w("PythonPoller", "eventSink is null, message dropped!")
                                }
                            }
                        }
                    }

                    // Small sleep to prevent busy waiting
                    Thread.sleep(50)
                } catch (e: Exception) {
                    // Log but don't crash on polling errors
                    android.util.Log.e("PythonPoller", "Polling error: ${e.message}")
                }
            }
            android.util.Log.i("PythonPoller", "Polling thread stopped, sent $messageCount messages")
        }.apply {
            isDaemon = true
            name = "PythonMessagePoller"
            start()
        }
    }

    /**
     * Call Python agent with JSON-RPC payload.
     * CRITICAL: Runs in background thread to prevent deadlock.
     */
    private fun callPython(payload: String, result: MethodChannel.Result) {
        pythonExecutor.execute {
            try {
                val py = Python.getInstance()
                val agent = py.getModule("navixmind.agent")
                val response = agent.callAttr("handle_request", payload).toString()

                mainHandler.post {
                    result.success(response)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("PYTHON_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    /**
     * Send native tool response back to Python.
     * Used for async native->Python communication.
     */
    private fun sendResponseToPython(response: String, result: MethodChannel.Result) {
        android.util.Log.i("NativeToolResponse", "Sending response to Python: ${response.take(200)}...")
        responseExecutor.execute {
            try {
                val py = Python.getInstance()
                val bridge = py.getModule("navixmind.bridge")
                android.util.Log.i("NativeToolResponse", "Calling bridge.receive_response")
                bridge.callAttr("receive_response", response)
                android.util.Log.i("NativeToolResponse", "Response sent successfully")

                mainHandler.post {
                    result.success(null)
                }
            } catch (e: Exception) {
                android.util.Log.e("NativeToolResponse", "Failed to send response: ${e.message}")
                mainHandler.post {
                    result.error("PYTHON_ERROR", e.message, e.stackTraceToString())
                }
            }
        }
    }

    /**
     * Get Python runtime status.
     */
    private fun getPythonStatus(result: MethodChannel.Result) {
        pythonExecutor.execute {
            try {
                val py = Python.getInstance()
                val bridge = py.getModule("navixmind.bridge")
                val status = bridge.callAttr("get_status").toString()

                mainHandler.post {
                    result.success(status)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.success("error")
                }
            }
        }
    }

    /**
     * Cleanup resources on activity destroy.
     */
    fun cleanup() {
        isPolling = false
        eventSink = null
        pythonExecutor.shutdown()
        responseExecutor.shutdown()
    }
}
