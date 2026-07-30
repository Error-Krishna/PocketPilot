package com.udhyogsaathi.pocketpilot

import android.content.Context
import io.flutter.plugin.common.MethodChannel

/**
 * Shared constants + the drain operation for the SharedPreferences-backed
 * pending-SMS queue that SmsReceiver writes to and Dart reads from via
 * MainActivity's method channel.
 */
object PendingSmsBridge {
    const val PREFS_NAME = "pocketpilot_pending_sms"
    const val PENDING_KEY = "pending_sms_queue"
    const val CHANNEL_NAME = "com.udhyogsaathi.pocketpilot/sms_service"

    fun drainPending(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val json = prefs.getString(PENDING_KEY, "[]") ?: "[]"
        // Clear atomically after reading so a message is never double-
        // delivered to Dart across two drains in a row.
        prefs.edit().putString(PENDING_KEY, "[]").apply()
        return json
    }

    fun handleMethodCall(context: Context, call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startService" -> {
                SmsForegroundService.start(context)
                result.success(null)
            }
            "stopService" -> {
                SmsForegroundService.stop(context)
                result.success(null)
            }
            "drainPendingSms" -> {
                result.success(drainPending(context))
            }
            else -> result.notImplemented()
        }
    }
}
