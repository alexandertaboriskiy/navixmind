package ai.navixmind.services

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Method channel for controlling the TaskForegroundService from Flutter.
 */
class ForegroundServiceChannel(flutterEngine: FlutterEngine, private val context: Context) {
    companion object {
        const val CHANNEL_NAME = "ai.navixmind/foreground_service"
    }

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME
    )

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startTask" -> {
                    val taskId = call.argument<String>("taskId")
                    val title = call.argument<String>("title")
                    if (taskId != null && title != null) {
                        TaskForegroundService.start(context, taskId, title)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "taskId and title required", null)
                    }
                }
                "updateProgress" -> {
                    val taskId = call.argument<String>("taskId")
                    val progress = call.argument<Int>("progress")
                    val message = call.argument<String>("message")
                    if (taskId != null && progress != null && message != null) {
                        TaskForegroundService.updateProgress(context, taskId, progress, message)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "taskId, progress, and message required", null)
                    }
                }
                "stopTask" -> {
                    TaskForegroundService.stop(context)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
