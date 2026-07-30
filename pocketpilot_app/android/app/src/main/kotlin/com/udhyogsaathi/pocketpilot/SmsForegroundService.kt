package com.udhyogsaathi.pocketpilot

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
 * Foreground service that keeps PocketPilot's SMS capture alive even when
 * the app is fully closed. Android requires a visible notification for any
 * foreground service — this reuses the same "PocketPilot is watching for
 * transactions" framing the daily-limit notification already uses, so it
 * doesn't read as a separate, confusing second notification to the user.
 *
 * This service does NOT do the actual SMS parsing/classification itself —
 * that stays in Dart. Its only job is to exist as a long-lived Android
 * process so the OS doesn't kill the app before SmsReceiver can do its
 * work, and to keep the persistent notification alive/updated.
 */
class SmsForegroundService : Service() {

    companion object {
        private const val CHANNEL_ID = "pocketpilot_sms_service"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_NEW_MESSAGE = "com.udhyogsaathi.pocketpilot.NEW_SMS"

        @JvmStatic
        fun notifyNewMessage(context: Context) {
            val intent = Intent(context, SmsForegroundService::class.java)
            intent.action = ACTION_NEW_MESSAGE
            try {
                context.startService(intent)
            } catch (_: IllegalStateException) {
                // Service can't be started from background on some OEMs if the
                // app was force-stopped by the user — nothing more we can do
                // here; the pending SMS queue is still safely persisted and
                // will be drained on next app open regardless.
            }
        }

        @JvmStatic
        fun start(context: Context) {
            val intent = Intent(context, SmsForegroundService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        @JvmStatic
        fun stop(context: Context) {
            context.stopService(Intent(context, SmsForegroundService::class.java))
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        // START_STICKY: if Android kills this service under memory pressure,
        // it restarts it automatically without needing a new triggering
        // intent — appropriate here since this service's job (existing so
        // SmsReceiver keeps working) is inherently a "just keep running"
        // task, not a one-shot job tied to specific intent data.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Transaction Watching",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Keeps PocketPilot watching for new bank SMS in the background"
            channel.setShowBadge(false)
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PocketPilot is watching for transactions")
            .setContentText("Bank SMS will be detected automatically, even with the app closed.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }
}
