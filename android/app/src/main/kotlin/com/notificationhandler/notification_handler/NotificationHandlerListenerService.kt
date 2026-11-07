package com.notificationhandler.notification_handler

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * System-bound service that listens for posted notifications, records triaged
 * and muted notification details locally on-device for the Activity Log, and applies
 * suppression schedules by calling [cancelNotification].
 *
 * Runs as an independent Android background service managed by Android system_server.
 * All recorded activity stays strictly in local SharedPreferences (zero network transmission).
 */
class NotificationHandlerListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "NotificationHandlerNLS"
        var isConnected: Boolean = false
            private set
    }

    private lateinit var scheduleStore: NativeScheduleStore

    override fun onCreate() {
        super.onCreate()
        scheduleStore = NativeScheduleStore(this)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        Log.i(TAG, "Notification listener connected successfully.")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
        Log.i(TAG, "Notification listener disconnected.")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName ?: return
        val key = sbn.key ?: return

        // Skip our own notifications and ongoing persistent foreground service notifications
        if (packageName == applicationContext.packageName) return
        if (sbn.isOngoing) return

        val notification = sbn.notification
        val extras = notification?.extras
        val isGroupSummary = ((notification?.flags ?: 0) and Notification.FLAG_GROUP_SUMMARY) != 0

        val rawTitle = extras?.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim()
            ?: extras?.getCharSequence(Notification.EXTRA_TITLE_BIG)?.toString()?.trim()
            ?: ""

        val conversationTitle = extras?.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)?.toString()?.trim()
            ?: ""

        val title = when {
            rawTitle.isNotEmpty() -> rawTitle
            conversationTitle.isNotEmpty() -> conversationTitle
            else -> ""
        }

        val bigText = extras?.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim() ?: ""
        val standardText = extras?.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim() ?: ""
        val textLines = extras?.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.mapNotNull { it?.toString()?.trim() }
            ?.filter { it.isNotEmpty() }
            ?.joinToString("\n")
            ?: ""
        val summaryText = extras?.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString()?.trim() ?: ""
        val tickerText = notification?.tickerText?.toString()?.trim() ?: ""

        val message = when {
            bigText.isNotEmpty() -> bigText
            standardText.isNotEmpty() -> standardText
            textLines.isNotEmpty() -> textLines
            summaryText.isNotEmpty() -> summaryText
            tickerText.isNotEmpty() -> tickerText
            else -> ""
        }

        val extraSubText = extras?.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()?.trim()
            ?: extras?.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString()?.trim()
            ?: ""
        val subText = when {
            conversationTitle.isNotEmpty() && conversationTitle != title -> conversationTitle
            extraSubText.isNotEmpty() -> extraSubText
            else -> ""
        }

        val category = notification?.category ?: ""
        val appName = resolveAppName(packageName)
        val postTime = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()

        val decision = scheduleStore.evaluateAndRecordNotification(
            packageName = packageName,
            postTimeMs = postTime,
            appName = appName,
            title = title,
            message = message,
            subText = subText,
            category = category,
            isGroupSummary = isGroupSummary
        )

        if (decision.shouldBlock) {
            Log.d(TAG, "Suppressing notification from package: $packageName (${decision.reason})")
            cancelNotification(key)
        }
    }

    private fun resolveAppName(packageName: String): String {
        return try {
            val pm = applicationContext.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (_: Exception) {
            packageName
        }
    }
}

