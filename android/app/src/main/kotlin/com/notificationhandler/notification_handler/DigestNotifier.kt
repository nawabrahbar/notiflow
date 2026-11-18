package com.notificationhandler.notification_handler

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Posts the single Notiflow "quiet hours ended" notification and keeps one inexact alarm
 * for the next window end. The alarm is only set while a window holds silenced items.
 */
object DigestNotifier {
    private const val TAG = "DigestNotifier"
    const val CHANNEL_ID = "catch_up_digest"
    const val NOTIFICATION_ID = 7001
    const val ACTION_OPEN_DIGEST = "com.notificationhandler.action.OPEN_DIGEST"
    const val ACTION_DIGEST_ALARM = "com.notificationhandler.action.DIGEST_ALARM"
    const val ACTION_DIGEST_DISMISSED = "com.notificationhandler.action.DIGEST_DISMISSED"
    const val EXTRA_WINDOW_IDS = "window_ids"

    private const val PREFS = "notiflow_digest"
    private const val KEY_ENABLED = "digest_notifications_enabled"
    private const val ALARM_WINDOW_MS = 10 * 60_000L

    private val lock = Any()

    fun isEnabled(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, true)

    fun setEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, enabled).apply()
        if (!enabled) NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    fun canPostNotifications(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    /** Sets (or clears) the inexact alarm for the next pending window end. */
    fun reschedule(context: Context, earliestAtMs: Long? = null) {
        try {
            val db = NotiflowDatabase.getInstance(context)
            val now = System.currentTimeMillis()
            var at = DigestPlanner.alarmTime(db.nextDigestDueMs(), now)
            if (at != null && earliestAtMs != null) at = maxOf(at, earliestAtMs)
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = alarmIntent(context)
            if (at == null) {
                alarmManager.cancel(pending)
            } else {
                alarmManager.setWindow(AlarmManager.RTC_WAKEUP, at, ALARM_WINDOW_MS, pending)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not schedule the digest alarm", e)
        }
    }

    /**
     * Posts one notification for every ended, not-yet-notified window. Waits briefly when
     * another window ends within a few minutes so they are combined.
     */
    fun postDue(context: Context) {
        synchronized(lock) {
            try {
                val db = NotiflowDatabase.getInstance(context)
                val now = System.currentTimeMillis()
                expireStaleHeld(db, now)
                val due = db.getDueDigestWindows(now)
                if (due.isEmpty()) {
                    reschedule(context)
                    return
                }
                val oldestDue = due.minOf { DigestPlanner.releaseAt(it.endMs) }
                DigestPlanner.combineDelay(oldestDue, db.nextPendingDueAfter(now), now)?.let { later ->
                    reschedule(context, later)
                    return
                }
                val ids = due.map { it.id }
                if (!isEnabled(context) || !canPostNotifications(context)) {
                    db.markDigestPosted(ids, NotiflowDatabase.DIGEST_SKIPPED)
                } else {
                    db.markDigestPosted(ids, NotiflowDatabase.DIGEST_SHOWN)
                    show(context, db.getShownUnreviewedWindows())
                }
                NativeScheduleStore.onActivityUpdatedListener?.invoke()
                reschedule(context)
            } catch (e: Exception) {
                Log.w(TAG, "Could not post the catch-up digest", e)
            }
        }
    }

    /** Held rows whose release time passed long ago never came back (app removed them, or a restart). */
    private fun expireStaleHeld(db: NotiflowDatabase, now: Long) {
        for (held in db.getAllHeld()) {
            if (held.releaseAtMs + 2 * DigestPlanner.MINUTE_MS < now) {
                db.finishHeld(held.key, NotiflowDatabase.DELIVERY_REMOVED)
            }
        }
    }

    /** Called after windows are reviewed in the app; clears the notification when nothing is left. */
    fun onReviewed(context: Context) {
        try {
            if (NotiflowDatabase.getInstance(context).getShownUnreviewedWindows().isEmpty()) {
                NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
            }
        } catch (_: Exception) {
        }
    }

    private fun show(context: Context, windows: List<NotiflowDatabase.DueWindow>) {
        val text = DigestPlanner.digestText(
            windows.map { DigestPlanner.AppCount(it.appName.ifBlank { it.packageName }, it.count) }
        ) ?: return
        ensureChannel(context)
        val ids = windows.map { it.id }.toLongArray()

        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_DIGEST
            putExtra(EXTRA_WINDOW_IDS, ids)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val contentIntent = PendingIntent.getActivity(
            context, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val dismissIntent = Intent(context, DigestReceiver::class.java).apply {
            action = ACTION_DIGEST_DISMISSED
            putExtra(EXTRA_WINDOW_IDS, ids)
        }
        val deleteIntent = PendingIntent.getBroadcast(
            context, 1, dismissIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val publicVersion = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_digest)
            .setContentTitle(text.publicTitle)
            .build()

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_digest)
            .setContentTitle(text.title)
            .setContentText(text.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text.body))
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setPublicVersion(publicVersion)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setContentIntent(contentIntent)
            .setDeleteIntent(deleteIntent)
            .setAutoCancel(true)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, notification)
        } catch (e: SecurityException) {
            Log.w(TAG, "Notification permission missing", e)
        }
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Catch-up digest", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "One notification when quiet hours end, with how many notifications are back."
            }
        )
    }

    private fun alarmIntent(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            2,
            Intent(context, DigestReceiver::class.java).setAction(ACTION_DIGEST_ALARM),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

    /** Marks windows from a tapped or dismissed digest notification as reviewed. */
    fun markReviewed(context: Context, ids: LongArray?) {
        if (ids == null || ids.isEmpty()) return
        try {
            NotiflowDatabase.getInstance(context).markWindowsReviewed(ids.toList())
            NativeScheduleStore.onActivityUpdatedListener?.invoke()
        } catch (_: Exception) {
        }
    }
}

/** Digest alarm and notification dismissal (internal broadcasts only). */
class DigestReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            DigestNotifier.ACTION_DIGEST_ALARM -> {
                val pending = goAsync()
                Thread {
                    try {
                        DigestNotifier.postDue(context.applicationContext)
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
            DigestNotifier.ACTION_DIGEST_DISMISSED ->
                DigestNotifier.markReviewed(context.applicationContext, intent.getLongArrayExtra(DigestNotifier.EXTRA_WINDOW_IDS))
        }
    }
}

/** Re-schedules the pending digest alarm after a restart or app update. */
class DigestBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                val pending = goAsync()
                Thread {
                    try {
                        DigestNotifier.postDue(context.applicationContext)
                    } finally {
                        pending.finish()
                    }
                }.start()
            }
        }
    }
}
