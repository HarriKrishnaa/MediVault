package com.medivault.medivault

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Handles notification action button taps:
 *   - TAKEN       → log adherence, acknowledge, stop repeats, dismiss notification
 *   - NOT_WILLING → log adherence, acknowledge, stop repeats, dismiss notification
 *   - REMIND_LATER → dismiss notification, schedule new follow-up alarm
 */
class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        const val TAG = "NotifAction"
        const val ACTION_TAKEN = "com.medivault.ACTION_TAKEN"
        const val ACTION_NOT_WILLING = "com.medivault.ACTION_NOT_WILLING"
        const val ACTION_REMIND_LATER = "com.medivault.ACTION_REMIND_LATER"
        const val EXTRA_REMINDER_ID = "reminder_id"
        const val EXTRA_MEDICINE_NAME = "medicine_name"
        const val EXTRA_HOUR = "hour"
        const val EXTRA_MINUTE = "minute"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra(EXTRA_REMINDER_ID, -1)
        if (id < 0) return

        val name = intent.getStringExtra(EXTRA_MEDICINE_NAME) ?: "your medicine"
        val hour = intent.getIntExtra(EXTRA_HOUR, 0)
        val minute = intent.getIntExtra(EXTRA_MINUTE, 0)

        when (intent.action) {
            ACTION_TAKEN -> {
                Log.d(TAG, "✅ User TOOK medicine for alarm #$id")
                // Log adherence to SQLite
                AdherenceDbHelper(context).logAction(id, name, "taken")
                TtsAlarmScheduler.acknowledge(context, id)
                dismissNotification(context, id)
            }
            ACTION_NOT_WILLING -> {
                Log.d(TAG, "❌ User NOT WILLING for alarm #$id")
                // Log adherence to SQLite
                AdherenceDbHelper(context).logAction(id, name, "not_now")
                TtsAlarmScheduler.acknowledge(context, id)
                dismissNotification(context, id)
            }
            ACTION_REMIND_LATER -> {
                Log.d(TAG, "⏰ User wants REMIND LATER for alarm #$id")
                dismissNotification(context, id)
                // Explicitly schedule a new follow-up alarm (configurable duration).
                TtsAlarmScheduler.scheduleFollowUp(context, id, name, hour, minute)
            }
        }
    }

    private fun dismissNotification(context: Context, id: Int) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(id)
    }
}
