package ai.navixmind

import android.os.Bundle
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import ai.navixmind.services.ForegroundServiceChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private lateinit var pythonChannel: PythonMethodChannel
    private lateinit var foregroundServiceChannel: ForegroundServiceChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Python with application context
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(applicationContext))
        }

        pythonChannel = PythonMethodChannel(flutterEngine)
        foregroundServiceChannel = ForegroundServiceChannel(flutterEngine, applicationContext)
    }

    override fun onDestroy() {
        pythonChannel.cleanup()
        super.onDestroy()
    }
}
