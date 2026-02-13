package ai.navixmind.services

import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Kotlin-side download engine for HuggingFace model files.
 *
 * MethodChannel: ai.navixmind/model_download
 *   - startDownload(modelId, repoId, destDir)
 *   - cancelDownload(modelId)
 *   - getAvailableSpace
 *
 * EventChannel: ai.navixmind/model_download_events
 *   Streams JSON events: progress, complete, error, cancelled
 */
class ModelDownloadChannel(
    flutterEngine: FlutterEngine,
    private val appContext: android.content.Context
) {
    companion object {
        private const val TAG = "ModelDownload"
        private const val METHOD_CHANNEL = "ai.navixmind/model_download"
        private const val EVENT_CHANNEL = "ai.navixmind/model_download_events"
        private const val BUFFER_SIZE = 8192
        private const val PROGRESS_THROTTLE_MS = 200L
        private const val DISK_SPACE_BUFFER = 1.1 // 10% buffer
    }

    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        METHOD_CHANNEL
    )

    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        EVENT_CHANNEL
    )

    private val downloadExecutor: ExecutorService = Executors.newSingleThreadExecutor { r ->
        Thread(r, "ModelDownloader").apply { isDaemon = true }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private val activeDownloads = ConcurrentHashMap<String, AtomicBoolean>()

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .followRedirects(true)
        .build()

    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val modelId = call.argument<String>("modelId")
                    val repoId = call.argument<String>("repoId")
                    val destDir = call.argument<String>("destDir")
                    if (modelId == null || repoId == null || destDir == null) {
                        result.error("INVALID_ARGS", "modelId, repoId, destDir required", null)
                        return@setMethodCallHandler
                    }
                    startDownload(modelId, repoId, destDir, result)
                }
                "cancelDownload" -> {
                    val modelId = call.argument<String>("modelId")
                    if (modelId == null) {
                        result.error("INVALID_ARGS", "modelId required", null)
                        return@setMethodCallHandler
                    }
                    cancelDownload(modelId, result)
                }
                "getAvailableSpace" -> {
                    getAvailableSpace(result)
                }
                else -> result.notImplemented()
            }
        }

        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun startDownload(
        modelId: String,
        repoId: String,
        destDir: String,
        result: MethodChannel.Result
    ) {
        // Set cancel flag for this model
        val cancelFlag = AtomicBoolean(false)
        activeDownloads[modelId] = cancelFlag

        result.success(null)

        downloadExecutor.execute {
            try {
                doDownload(modelId, repoId, destDir, cancelFlag)
            } catch (e: Exception) {
                Log.e(TAG, "Download failed for $modelId", e)
                cleanupModelDir(File(destDir))
                emitEvent(modelId, "error", errorMessage = e.message ?: "Unknown error")
            } finally {
                activeDownloads.remove(modelId)
            }
        }
    }

    private fun doDownload(
        modelId: String,
        repoId: String,
        destDir: String,
        cancelFlag: AtomicBoolean
    ) {
        // 1. Fetch file manifest from HuggingFace API
        val apiUrl = "https://huggingface.co/api/models/$repoId"
        Log.i(TAG, "Fetching manifest from $apiUrl")

        val manifestRequest = Request.Builder().url(apiUrl).build()
        val manifestResponse = httpClient.newCall(manifestRequest).execute()

        if (!manifestResponse.isSuccessful) {
            emitEvent(modelId, "error",
                errorMessage = "Failed to fetch model info (HTTP ${manifestResponse.code})")
            return
        }

        val manifestBody = manifestResponse.body?.string()
            ?: run {
                emitEvent(modelId, "error", errorMessage = "Empty response from HuggingFace API")
                return
            }

        val manifestJson = JSONObject(manifestBody)
        val siblings = manifestJson.optJSONArray("siblings") ?: JSONArray()

        // 2. Filter files — skip metadata
        val skipFiles = setOf(".gitattributes", "README.md", ".gitignore")
        data class FileEntry(val rfilename: String, val size: Long)

        val files = mutableListOf<FileEntry>()
        for (i in 0 until siblings.length()) {
            val sibling = siblings.getJSONObject(i)
            val filename = sibling.getString("rfilename")
            if (filename in skipFiles) continue
            val size = sibling.optLong("size", 0)
            files.add(FileEntry(filename, size))
        }

        if (files.isEmpty()) {
            emitEvent(modelId, "error", errorMessage = "No downloadable files found in repository")
            return
        }

        // 3. Pre-fetch actual file sizes via HEAD requests
        Log.i(TAG, "Pre-fetching file sizes for ${files.size} files...")
        data class SizedFile(val rfilename: String, val size: Long)
        val sizedFiles = mutableListOf<SizedFile>()

        for (fileEntry in files) {
            if (cancelFlag.get()) {
                emitEvent(modelId, "cancelled")
                return
            }
            val fileUrl = "https://huggingface.co/$repoId/resolve/main/${fileEntry.rfilename}"
            val headRequest = Request.Builder().url(fileUrl).head().build()
            try {
                val headResponse = httpClient.newCall(headRequest).execute()
                val contentLength = headResponse.header("Content-Length")?.toLongOrNull() ?: 0L
                headResponse.close()
                sizedFiles.add(SizedFile(fileEntry.rfilename, contentLength))
                Log.i(TAG, "  ${fileEntry.rfilename}: $contentLength bytes")
            } catch (e: IOException) {
                // Fall back to size from manifest (likely 0)
                sizedFiles.add(SizedFile(fileEntry.rfilename, fileEntry.size))
                Log.w(TAG, "  HEAD failed for ${fileEntry.rfilename}, using manifest size: ${fileEntry.size}")
            }
        }

        // 4. Calculate total size and check disk space
        val totalExpectedBytes = sizedFiles.sumOf { it.size }
        Log.i(TAG, "Total expected download size: $totalExpectedBytes bytes (${totalExpectedBytes / (1024 * 1024)}MB)")
        val requiredSpace = (totalExpectedBytes * DISK_SPACE_BUFFER).toLong()

        val destFile = File(destDir)
        val parentDir = destFile.parentFile ?: destFile
        if (parentDir.exists()) {
            val stat = StatFs(parentDir.absolutePath)
            val availableBytes = stat.availableBlocksLong * stat.blockSizeLong
            if (availableBytes < requiredSpace) {
                val needMB = requiredSpace / (1024 * 1024)
                val haveMB = availableBytes / (1024 * 1024)
                emitEvent(modelId, "error",
                    errorMessage = "Not enough disk space. Need ${needMB}MB, have ${haveMB}MB")
                return
            }
        }

        // 5. Create destination directory
        destFile.mkdirs()

        // 6. Download files sequentially with byte-level progress
        val totalFiles = sizedFiles.size
        var totalBytesDownloaded = 0L

        for ((fileIndex, sizedFile) in sizedFiles.withIndex()) {
            if (cancelFlag.get()) {
                Log.i(TAG, "Download cancelled for $modelId")
                cleanupModelDir(destFile)
                emitEvent(modelId, "cancelled")
                return
            }

            val fileUrl = "https://huggingface.co/$repoId/resolve/main/${sizedFile.rfilename}"
            val targetFile = File(destFile, sizedFile.rfilename)
            val partFile = File(destFile, "${sizedFile.rfilename}.part")

            // Ensure parent directories exist for nested files
            targetFile.parentFile?.mkdirs()

            Log.i(TAG, "Downloading [${fileIndex + 1}/$totalFiles] ${sizedFile.rfilename}")

            val request = Request.Builder().url(fileUrl).build()
            val response = try {
                httpClient.newCall(request).execute()
            } catch (e: IOException) {
                Log.e(TAG, "Network error downloading ${sizedFile.rfilename}", e)
                cleanupModelDir(destFile)
                emitEvent(modelId, "error",
                    errorMessage = "Network error: ${e.message}")
                return
            }

            if (!response.isSuccessful) {
                cleanupModelDir(destFile)
                emitEvent(modelId, "error",
                    errorMessage = "Failed to download ${sizedFile.rfilename} (HTTP ${response.code})")
                return
            }

            val body = response.body
            if (body == null) {
                cleanupModelDir(destFile)
                emitEvent(modelId, "error",
                    errorMessage = "Empty response for ${sizedFile.rfilename}")
                return
            }

            try {
                var lastProgressTime = 0L

                body.byteStream().use { input ->
                    partFile.outputStream().use { output ->
                        val buffer = ByteArray(BUFFER_SIZE)
                        var bytesRead: Int

                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            if (cancelFlag.get()) {
                                Log.i(TAG, "Download cancelled mid-file for $modelId")
                                output.close()
                                cleanupModelDir(destFile)
                                emitEvent(modelId, "cancelled")
                                return
                            }

                            output.write(buffer, 0, bytesRead)
                            totalBytesDownloaded += bytesRead

                            // Throttled progress emission
                            val now = System.currentTimeMillis()
                            if (now - lastProgressTime >= PROGRESS_THROTTLE_MS) {
                                lastProgressTime = now

                                val progress = if (totalExpectedBytes > 0) {
                                    (totalBytesDownloaded.toDouble() / totalExpectedBytes)
                                        .coerceIn(0.0, 0.99)
                                } else 0.0

                                emitEvent(modelId, "progress",
                                    progress = progress,
                                    currentFile = sizedFile.rfilename,
                                    fileIndex = fileIndex + 1,
                                    totalFiles = totalFiles)
                            }
                        }
                    }
                }

                // Rename .part to final filename
                if (!partFile.renameTo(targetFile)) {
                    // Fallback: copy and delete
                    partFile.copyTo(targetFile, overwrite = true)
                    partFile.delete()
                }

            } catch (e: IOException) {
                Log.e(TAG, "IO error writing ${sizedFile.rfilename}", e)
                cleanupModelDir(destFile)
                emitEvent(modelId, "error",
                    errorMessage = "Disk write error: ${e.message}")
                return
            }
        }

        // 7. All files complete
        Log.i(TAG, "Download complete for $modelId ($totalBytesDownloaded bytes)")
        emitEvent(modelId, "complete")
    }

    private fun cancelDownload(modelId: String, result: MethodChannel.Result) {
        val flag = activeDownloads[modelId]
        if (flag != null) {
            flag.set(true)
            Log.i(TAG, "Cancel requested for $modelId")
        }
        result.success(null)
    }

    private fun getAvailableSpace(result: MethodChannel.Result) {
        try {
            val dataDir = appContext.filesDir
            val stat = StatFs(dataDir.absolutePath)
            val available = stat.availableBlocksLong * stat.blockSizeLong
            result.success(available)
        } catch (e: Exception) {
            result.error("SPACE_CHECK_FAILED", e.message, null)
        }
    }

    private fun cleanupModelDir(dir: File) {
        try {
            if (dir.exists()) {
                dir.deleteRecursively()
                Log.i(TAG, "Cleaned up directory: ${dir.absolutePath}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to clean up directory: ${dir.absolutePath}", e)
        }
    }

    private fun emitEvent(
        modelId: String,
        event: String,
        progress: Double? = null,
        currentFile: String? = null,
        fileIndex: Int? = null,
        totalFiles: Int? = null,
        errorMessage: String? = null
    ) {
        val json = JSONObject().apply {
            put("modelId", modelId)
            put("event", event)
            if (progress != null) put("progress", progress)
            if (currentFile != null) put("currentFile", currentFile)
            if (fileIndex != null) put("fileIndex", fileIndex)
            if (totalFiles != null) put("totalFiles", totalFiles)
            if (errorMessage != null) put("errorMessage", errorMessage)
        }

        mainHandler.post {
            eventSink?.success(json.toString())
        }
    }

    fun cleanup() {
        // Cancel all active downloads
        for ((modelId, flag) in activeDownloads) {
            flag.set(true)
            Log.i(TAG, "Cleanup: cancelling download for $modelId")
        }
        eventSink = null
        downloadExecutor.shutdown()
    }
}
