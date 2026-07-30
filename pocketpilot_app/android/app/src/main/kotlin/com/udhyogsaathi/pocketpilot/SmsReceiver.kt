package com.udhyogsaathi.pocketpilot

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject

/**
 * Receives incoming SMS independently of the Flutter engine's lifecycle.
 * This is what makes SMS capture survive the app being fully closed —
 * Android wakes this receiver via the system broadcast even when the app
 * process isn't running, which is exactly the gap the old
 * telephony-package no-op background handler left open.
 *
 * Parsed candidates are stored in SharedPreferences (a queue of raw SMS +
 * timestamp), which PendingSmsBridge reads and drains from the Dart side
 * the next time the app is opened or the foreground service polls it.
 * Actual classification/amount-extraction stays in Dart (sms_parser_service.dart)
 * so there's exactly one parser to maintain, not two divergent ones.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) return

        val prefs = context.getSharedPreferences(PendingSmsBridge.PREFS_NAME, Context.MODE_PRIVATE)
        val existingJson = prefs.getString(PendingSmsBridge.PENDING_KEY, "[]") ?: "[]"
        val pending = JSONArray(existingJson)

        for (message in messages) {
            val body = message.messageBody ?: continue
            val timestamp = message.timestampMillis

            val entry = JSONObject()
            entry.put("body", body)
            entry.put("timestamp", timestamp)
            pending.put(entry)
        }

        // Cap the queue so a phone left unopened for a long time doesn't
        // grow this unboundedly; Dart-side dedup/fingerprinting still
        // applies once drained, this is just a safety bound on raw queue
        // size.
        val capped = if (pending.length() > 500) {
            val trimmed = JSONArray()
            for (i in (pending.length() - 500) until pending.length()) {
                trimmed.put(pending.get(i))
            }
            trimmed
        } else {
            pending
        }

        prefs.edit().putString(PendingSmsBridge.PENDING_KEY, capped.toString()).apply()

        // Nudge the foreground service to refresh its notification /
        // attempt a sync if it's already alive; if not running, this is a
        // no-op and the queue will simply be drained next app open.
        SmsForegroundService.notifyNewMessage(context)
    }
}
