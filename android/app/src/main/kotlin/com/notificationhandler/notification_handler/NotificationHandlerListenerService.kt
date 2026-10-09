package com.notificationhandler.notification_handler

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

/**
 * System-bound service that listens for posted notifications and applies
 * suppression schedules by calling [cancelNotification].
 *
 * Runs as an independent Android background service managed by Android system_server.
 * Never persists or inspects notification contents (titles, messages, or extras).
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

        // Skip our own notifications
        if (packageName == applicationContext.packageName) return

        val postTime = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()

        val shouldBlock = scheduleStore.shouldBlockNotification(packageName, postTime)
        if (shouldBlock) {
            Log.d(TAG, "Suppressing notification from package: $packageName")
            cancelNotification(key)
        }
    }
}
