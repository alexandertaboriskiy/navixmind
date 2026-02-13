package ai.navixmind

import ai.navixmind.services.MLCInferenceChannel
import ai.navixmind.services.ModelDownloadChannel
import android.content.ComponentCallbacks2
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : FlutterActivity() {
    private lateinit var pythonChannel: PythonMethodChannel
    private lateinit var modelDownloadChannel: ModelDownloadChannel
    private lateinit var mlcInferenceChannel: MLCInferenceChannel
    private val FILE_CHANNEL = "ai.navixmind/file_opener"
    private val SHARE_CHANNEL = "ai.navixmind/share_receiver"

    private var shareChannel: MethodChannel? = null
    private var pendingShareData: Map<String, Any?>? = null
    private var flutterEngineReady = false

    // Shared file size limit — generous because files are processed locally
    // by Python, not sent directly to LLM cloud APIs.
    private val SHARE_SIZE_LIMIT = 500L * 1024 * 1024 // 500MB

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Python with application context
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }

        pythonChannel = PythonMethodChannel(flutterEngine)
        modelDownloadChannel = ModelDownloadChannel(flutterEngine, applicationContext)
        mlcInferenceChannel = MLCInferenceChannel(flutterEngine)

        // File opener channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFile" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath == null) {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                        return@setMethodCallHandler
                    }
                    openFile(filePath, result)
                }
                else -> result.notImplemented()
            }
        }

        // Share receiver channel
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
        flutterEngineReady = true

        // Deliver any buffered share data from cold start
        pendingShareData?.let { data ->
            shareChannel?.invokeMethod("onFilesShared", data)
            pendingShareData = null
        }

        // Handle share intent on cold start
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent) {
        val action = intent.action ?: return

        when (action) {
            Intent.ACTION_SEND -> {
                val uris = mutableListOf<Uri>()

                // Try EXTRA_STREAM first
                @Suppress("DEPRECATION")
                val streamUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                if (streamUri != null) {
                    uris.add(streamUri)
                } else {
                    // Fallback: some apps use clipData instead
                    intent.clipData?.let { clipData ->
                        for (i in 0 until clipData.itemCount) {
                            clipData.getItemAt(i).uri?.let { uris.add(it) }
                        }
                    }
                }

                val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)

                // Clear intent action to prevent re-processing on config changes
                intent.action = null

                if (uris.isNotEmpty() || extraText != null) {
                    processSharedUris(uris, extraText)
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM) ?: arrayListOf()
                val extraText = intent.getStringExtra(Intent.EXTRA_TEXT)

                // Clear intent action to prevent re-processing on config changes
                intent.action = null

                if (uris.isNotEmpty() || extraText != null) {
                    processSharedUris(uris, extraText)
                }
            }
        }
    }

    private fun processSharedUris(uris: List<Uri>, extraText: String?) {
        CoroutineScope(Dispatchers.Main).launch {
            val files = withContext(Dispatchers.IO) {
                val sharedDir = File(filesDir, "navixmind_shared")
                sharedDir.mkdirs()

                // Clean up old shared files (older than 24 hours)
                cleanupOldSharedFiles(sharedDir)

                val usedNames = mutableSetOf<String>()
                val fileList = mutableListOf<Map<String, Any?>>()

                for (uri in uris) {
                    try {
                        // Resolve filename
                        var filename = resolveFilename(uri) ?: "shared_${System.currentTimeMillis()}.dat"

                        // Handle duplicate filenames
                        filename = deduplicateFilename(filename, usedNames)
                        usedNames.add(filename)

                        // Check file size before copying
                        val sizeLimit = SHARE_SIZE_LIMIT

                        // Open input stream and copy
                        val inputStream = contentResolver.openInputStream(uri)
                        if (inputStream == null) {
                            fileList.add(mapOf(
                                "path" to "",
                                "name" to filename,
                                "size" to 0L,
                                "error" to "Could not read file: $filename"
                            ))
                            continue
                        }

                        val destFile = File(sharedDir, filename)
                        inputStream.use { input ->
                            destFile.outputStream().use { output ->
                                input.copyTo(output)
                            }
                        }

                        val fileSize = destFile.length()

                        if (fileSize > sizeLimit) {
                            destFile.delete()
                            val limitMB = sizeLimit / (1024 * 1024)
                            fileList.add(mapOf(
                                "path" to "",
                                "name" to filename,
                                "size" to fileSize,
                                "error" to "$filename is too large (${formatSize(fileSize)}). Max: ${limitMB}MB"
                            ))
                            continue
                        }

                        fileList.add(mapOf(
                            "path" to destFile.absolutePath,
                            "name" to filename,
                            "size" to fileSize,
                            "error" to null
                        ))
                    } catch (e: Exception) {
                        Log.e("ShareReceiver", "Failed to process shared URI: $uri", e)
                        fileList.add(mapOf(
                            "path" to "",
                            "name" to (uri.lastPathSegment ?: "unknown") as String,
                            "size" to 0L,
                            "error" to "Failed to process file: ${e.message}"
                        ))
                    }
                }

                fileList
            }

            deliverSharedFiles(files, extraText)
        }
    }

    private fun deliverSharedFiles(files: List<Map<String, Any?>>, extraText: String?) {
        val data = mapOf(
            "files" to files,
            "text" to extraText
        )

        if (flutterEngineReady && shareChannel != null) {
            shareChannel?.invokeMethod("onFilesShared", data)
        } else {
            // Buffer for delivery after engine is ready
            pendingShareData = data
        }
    }

    private fun resolveFilename(uri: Uri): String? {
        try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (nameIndex >= 0) {
                        return cursor.getString(nameIndex)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w("ShareReceiver", "Failed to resolve filename for $uri", e)
        }
        return uri.lastPathSegment
    }

    private fun deduplicateFilename(name: String, usedNames: Set<String>): String {
        if (name !in usedNames) return name

        val dotIndex = name.lastIndexOf('.')
        val baseName = if (dotIndex > 0) name.substring(0, dotIndex) else name
        val extension = if (dotIndex > 0) name.substring(dotIndex) else ""

        var counter = 1
        while ("${baseName}_$counter$extension" in usedNames) {
            counter++
        }
        return "${baseName}_$counter$extension"
    }

    private fun formatSize(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        if (bytes < 1024 * 1024) return "${bytes / 1024} KB"
        return "${bytes / (1024 * 1024)} MB"
    }

    private fun cleanupOldSharedFiles(dir: File) {
        val cutoff = System.currentTimeMillis() - 24 * 60 * 60 * 1000
        dir.listFiles()?.forEach { file ->
            if (file.lastModified() < cutoff) {
                file.delete()
            }
        }
    }

    private fun openFile(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                result.error("FILE_NOT_FOUND", "File does not exist: $filePath", null)
                return
            }

            val uri = FileProvider.getUriForFile(
                this,
                "${applicationContext.packageName}.fileprovider",
                file
            )

            // Determine MIME type from extension
            val extension = MimeTypeMap.getFileExtensionFromUrl(file.name)
            val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Don't use resolveActivity() — it returns null on Android 11+
            // due to package visibility filtering. Just try startActivity
            // and catch ActivityNotFoundException.
            try {
                startActivity(intent)
                result.success(true)
            } catch (e: android.content.ActivityNotFoundException) {
                result.success(false)
            }
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        if (::mlcInferenceChannel.isInitialized) {
            mlcInferenceChannel.onTrimMemory(level)
        }
    }

    override fun onDestroy() {
        pythonChannel.cleanup()
        modelDownloadChannel.cleanup()
        if (::mlcInferenceChannel.isInitialized) {
            mlcInferenceChannel.cleanup()
        }
        super.onDestroy()
    }
}
