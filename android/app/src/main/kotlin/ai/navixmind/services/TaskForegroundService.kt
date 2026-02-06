package ai.navixmind.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service for long-running tasks like video processing.
 * Keeps the app alive and shows progress to the user.
 */
class TaskForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "navixmind_task_channel"
        const val NOTIFICATION_ID = 1001

        const val ACTION_START = "ai.navixmind.START_TASK"
        const val ACTION_STOP = "ai.navixmind.STOP_TASK"
        const val ACTION_UPDATE = "ai.navixmind.UPDATE_TASK"

        const val EXTRA_TASK_ID = "task_id"
        const val EXTRA_TASK_TITLE = "task_title"
        const val EXTRA_PROGRESS = "progress"
        const val EXTRA_MESSAGE = "message"

        fun start(context: Context, taskId: String, title: String) {
            val intent = Intent(context, TaskForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_TASK_TITLE, title)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun updateProgress(context: Context, taskId: String, progress: Int, message: String) {
            val intent = Intent(context, TaskForegroundService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_TASK_ID, taskId)
                putExtra(EXTRA_PROGRESS, progress)
                putExtra(EXTRA_MESSAGE, message)
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, TaskForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private var currentTaskId: String? = null
    private var currentTitle: String = "Processing"

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                currentTaskId = intent.getStringExtra(EXTRA_TASK_ID)
                currentTitle = intent.getStringExtra(EXTRA_TASK_TITLE) ?: "Processing"
                startForeground(NOTIFICATION_ID, createNotification(0, "Starting..."))
            }
            ACTION_UPDATE -> {
                val progress = intent.getIntExtra(EXTRA_PROGRESS, 0)
                val message = intent.getStringExtra(EXTRA_MESSAGE) ?: ""
                updateNotification(progress, message)
            }
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Task Processing",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows progress of background tasks"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(progress: Int, message: String): Notification {
        val cancelIntent = Intent(this, TaskForegroundService::class.java).apply {
            action = ACTION_STOP
        }
        val cancelPendingIntent = PendingIntent.getService(
            this,
            0,
            cancelIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("NavixMind - $currentTitle")
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setProgress(100, progress, progress == 0)
            .setOngoing(true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                cancelPendingIntent
            )
            .build()
    }

    private fun updateNotification(progress: Int, message: String) {
        val notification = createNotification(progress, message)
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, notification)
    }
}
