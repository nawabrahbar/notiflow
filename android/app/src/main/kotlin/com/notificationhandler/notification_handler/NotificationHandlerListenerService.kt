package com.notificationhandler.notification_handler

import android.app.Notification
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import java.util.concurrent.Executors

/**
 * System-bound service that listens for posted notifications, records triaged
 * and muted notification details locally on-device for the Activity Log, and applies
 * suppression schedules. Notifications silenced inside a rule window are snoozed until
 * the window ends so Android brings the originals back; permanent mutes, ongoing
 * notifications and calls are cancelled.
 *
 * Runs as an independent Android background service managed by Android system_server.
 * All recorded activity stays strictly in an on-device SQLite database (zero network transmission).
 */
class NotificationHandlerListenerService : NotificationListenerService(), HeldNotificationController {
    companion object {
        private const val TAG = "NotificationHandlerNLS"
        var isConnected: Boolean = false
            private set

        /** The connected listener, used to re-snooze or release held notifications after rule edits. */
        @Volatile
        var controller: HeldNotificationController? = null
            private set
    }

    private lateinit var scheduleStore: NativeScheduleStore
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private val postDigestRunnable = Runnable {
        worker.execute { DigestNotifier.postDue(applicationContext) }
    }

    override fun onCreate() {
        super.onCreate()
        scheduleStore = NativeScheduleStore(this)
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isConnected = true
        controller = this
        Log.i(TAG, "Notification listener connected successfully.")
        checkHeldAfterConnect()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isConnected = false
        controller = null
        Log.i(TAG, "Notification listener disconnected.")
    }

    /** True when a chat notification was re-posted because the user sent the latest message. */
    private fun isOwnMessage(extras: android.os.Bundle?, title: String): Boolean {
        if (extras == null) return false
        val selfName = extras.getCharSequence(Notification.EXTRA_SELF_DISPLAY_NAME)?.toString()?.trim()
            ?: if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                (extras.getParcelable(Notification.EXTRA_MESSAGING_PERSON) as? android.app.Person)
                    ?.name?.toString()?.trim()
            } else null
        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
        val last = messages?.lastOrNull() as? android.os.Bundle
        if (last != null) {
            // MessagingStyle stores a null sender for messages sent by the user.
            val sender = last.getCharSequence("sender")?.toString()?.trim()
            val senderPerson = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                @Suppress("DEPRECATION")
                (last.getParcelable("sender_person") as? android.app.Person)?.name?.toString()?.trim()
            } else null
            val name = sender?.takeIf { it.isNotEmpty() } ?: senderPerson?.takeIf { it.isNotEmpty() }
            if (name == null) return true
            return !selfName.isNullOrEmpty() && name == selfName
        }
        return !selfName.isNullOrEmpty() && title == selfName
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val packageName = sbn.packageName ?: return
        val key = sbn.key ?: return

        // Skip our own notifications
        if (packageName == applicationContext.packageName) return

        val notification = sbn.notification
        val category = notification?.category ?: ""
        val extras = notification?.extras

        val isCall = category.equals(Notification.CATEGORY_CALL, ignoreCase = true) ||
                     category.equals("call", ignoreCase = true) ||
                     extras?.containsKey("android.callType") == true

        // Skip ongoing persistent foreground service notifications UNLESS it is an incoming call
        if (sbn.isOngoing && !isCall) return

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

        val appName = resolveAppName(packageName)
        val postTime = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()

        val isForeground = ((notification?.flags ?: 0) and Notification.FLAG_FOREGROUND_SERVICE) != 0
        val canSnooze = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            !sbn.isOngoing && !isForeground && !isCall

        val decision = scheduleStore.evaluateAndRecordNotification(
            packageName = packageName,
            postTimeMs = postTime,
            appName = appName,
            title = title,
            message = message,
            subText = subText,
            category = category,
            isGroupSummary = isGroupSummary,
            notificationKey = key,
            conversationKey = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                notification?.shortcutId ?: ""
            } else "",
            evaluationTimeMs = System.currentTimeMillis(),
            canSnooze = canSnooze,
            isSelfMessage = isOwnMessage(extras, title)
        )

        if (decision.isReturningOriginal && !decision.shouldBlock) {
            // An original is back after its window: post the digest once returns settle.
            mainHandler.removeCallbacks(postDigestRunnable)
            mainHandler.postDelayed(postDigestRunnable, DigestPlanner.SETTLE_MS)
            return
        }

        if (decision.shouldBlock) {
            val snoozeMs = decision.snoozeDurationMs
            if (snoozeMs == null || !snooze(key, snoozeMs)) {
                if (snoozeMs != null) scheduleStore.onHeldNotificationRemoved(key)
                cancelNotification(key)
            }
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?, rankingMap: RankingMap?, reason: Int) {
        super.onNotificationRemoved(sbn, rankingMap, reason)
        val key = sbn?.key ?: return
        // Snoozing and our own cancels also remove; only the source app removing it counts.
        if (reason == REASON_APP_CANCEL || reason == REASON_APP_CANCEL_ALL) {
            worker.execute { scheduleStore.onHeldNotificationRemoved(key) }
        }
    }

    override fun snooze(key: String, durationMs: Long): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            snoozeNotification(key, durationMs.coerceAtLeast(DigestPlanner.RELEASE_NOW_MS))
            true
        } catch (e: Exception) {
            Log.w(TAG, "Snooze failed for a notification; cancelling instead", e)
            false
        }
    }

    override fun cancel(key: String): Boolean {
        return try {
            cancelNotification(key)
            true
        } catch (_: Exception) {
            false
        }
    }

    /** After a restart or reconnect, forget held items Android no longer has and re-apply rules. */
    private fun checkHeldAfterConnect() {
        val present = HashSet<String>()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val snoozed = snoozedNotifications ?: return
                snoozed.forEach { it.key?.let(present::add) }
            }
            val active = activeNotifications ?: return
            active.forEach { it.key?.let(present::add) }
        } catch (e: Exception) {
            Log.w(TAG, "Could not read snoozed notifications", e)
            return
        }
        worker.execute {
            scheduleStore.dropLostHeld(present)
            scheduleStore.reconcileHeld(this)
            DigestNotifier.postDue(applicationContext)
        }
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(postDigestRunnable)
        worker.shutdown()
        super.onDestroy()
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

