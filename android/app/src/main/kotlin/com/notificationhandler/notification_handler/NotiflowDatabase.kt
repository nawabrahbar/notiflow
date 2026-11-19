package com.notificationhandler.notification_handler

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONArray
import org.json.JSONObject

/**
 * On-device SQLite store for the Activity log and Catch-Up Digest rule windows.
 * Nothing here leaves the phone; rows older than [RETENTION_MS] are pruned.
 */
class NotiflowDatabase internal constructor(context: Context, databaseName: String = DB_NAME) :
    SQLiteOpenHelper(context.applicationContext, databaseName, null, DB_VERSION) {

    companion object {
        const val DB_NAME = "notiflow.db"
        private const val DB_VERSION = 3
        const val RETENTION_MS = 30L * 24 * 60 * 60 * 1000
        private const val MAX_TEXT_LENGTH = 1000
        /** A group summary posted this close to a real message of the same app repeats it. */
        const val SUMMARY_SIBLING_MS = 5_000L
        private val PRIORITY_CATEGORIES = setOf("msg", "call", "email", "reminder", "alarm", "event")

        @Volatile
        private var instance: NotiflowDatabase? = null

        fun getInstance(context: Context): NotiflowDatabase =
            instance ?: synchronized(this) {
                instance ?: NotiflowDatabase(context).also { instance = it }
            }

        const val DELIVERY_SNOOZED = "snoozed"
        const val DELIVERY_RELEASED = "released"
        const val DELIVERY_REMOVED = "removed"
        const val DIGEST_SHOWN = 1
        const val DIGEST_SKIPPED = 2

        fun isPriority(category: String, conversationKey: String): Boolean =
            conversationKey.isNotBlank() || PRIORITY_CATEGORIES.contains(category.lowercase())
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE notification_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                package_name TEXT NOT NULL,
                app_name TEXT,
                title TEXT,
                message TEXT,
                sub_text TEXT,
                category TEXT,
                post_time_ms INTEGER NOT NULL,
                notification_key TEXT,
                conversation_key TEXT,
                action TEXT NOT NULL,
                reason TEXT,
                rule_name TEXT,
                time_window TEXT,
                window_id INTEGER,
                is_group_summary INTEGER NOT NULL DEFAULT 0,
                delivery TEXT,
                history_only INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE rule_windows (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                package_name TEXT NOT NULL,
                app_name TEXT,
                rule_name TEXT,
                start_ms INTEGER NOT NULL,
                end_ms INTEGER NOT NULL,
                reviewed INTEGER NOT NULL DEFAULT 0,
                digest_posted INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
        db.execSQL("CREATE INDEX idx_events_time ON notification_events(post_time_ms)")
        db.execSQL("CREATE INDEX idx_events_package ON notification_events(package_name)")
        db.execSQL("CREATE INDEX idx_events_window ON notification_events(window_id)")
        db.execSQL("CREATE INDEX idx_windows_package_end ON rule_windows(package_name, end_ms)")
        createHeldTable(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL("ALTER TABLE notification_events ADD COLUMN delivery TEXT")
            createHeldTable(db)
        }
        if (oldVersion < 3) {
            db.execSQL("ALTER TABLE notification_events ADD COLUMN history_only INTEGER NOT NULL DEFAULT 0")
        }
    }

    /**
     * Notifications currently snoozed by Notiflow, so a returning original is recognised
     * (let through, not logged again) and held items can be re-snoozed after rule edits.
     */
    private fun createHeldTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS held_notifications (
                notification_key TEXT PRIMARY KEY,
                package_name TEXT NOT NULL,
                window_id INTEGER,
                release_at_ms INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        db.execSQL("CREATE TABLE IF NOT EXISTS migration_state (name TEXT PRIMARY KEY)")
    }

    data class EventInput(
        val packageName: String,
        val appName: String,
        val title: String,
        val message: String,
        val subText: String,
        val category: String,
        val postTimeMs: Long,
        val notificationKey: String,
        val conversationKey: String,
        val isBlocked: Boolean,
        val reason: String,
        val ruleName: String?,
        val timeWindow: String?,
        val isGroupSummary: Boolean,
        val isHistoryOnly: Boolean = false
    )

    /**
     * Returns the id of the window for [packageName] that overlaps [startMs]..[endMs],
     * updating its bounds to the latest rule state, or creates a new one.
     * Windows whose end-of-rule notification was already handled are never reused, so a rule
     * extended after it ended gets a new window (starting where the old one ended) and its own
     * notification.
     */
    @Synchronized
    fun upsertWindow(packageName: String, appName: String, ruleName: String?, startMs: Long, endMs: Long): Long {
        val db = writableDatabase
        val handledEnd = db.rawQuery(
            "SELECT MAX(end_ms) FROM rule_windows WHERE package_name = ? AND start_ms <= ? AND end_ms >= ? " +
                "AND digest_posted != 0",
            arrayOf(packageName, endMs.toString(), startMs.toString())
        ).use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null }
        val effectiveStart = if (handledEnd != null) minOf(endMs, maxOf(startMs, handledEnd)) else startMs
        db.rawQuery(
            "SELECT id, start_ms FROM rule_windows WHERE package_name = ? AND start_ms <= ? AND end_ms >= ? " +
                "AND digest_posted = 0 ORDER BY end_ms DESC LIMIT 1",
            arrayOf(packageName, endMs.toString(), startMs.toString())
        ).use { c ->
            if (c.moveToFirst()) {
                val id = c.getLong(0)
                val existingStart = c.getLong(1)
                val values = ContentValues().apply {
                    put("start_ms", minOf(existingStart, effectiveStart))
                    put("end_ms", endMs)
                    if (appName.isNotBlank()) put("app_name", appName)
                    if (!ruleName.isNullOrBlank()) put("rule_name", ruleName)
                }
                db.update("rule_windows", values, "id = ?", arrayOf(id.toString()))
                return id
            }
        }
        val values = ContentValues().apply {
            put("package_name", packageName)
            put("app_name", appName)
            put("rule_name", ruleName)
            put("start_ms", effectiveStart)
            put("end_ms", endMs)
        }
        return db.insertOrThrow("rule_windows", null, values)
    }

    /**
     * Inserts an event. Inside a digest window, a repeat of the same notification key or
     * conversation updates the existing row so digest counts stay unique.
     * Returns false when the event was dropped as a rapid duplicate.
     */
    @Synchronized
    fun recordEvent(input: EventInput, windowId: Long?, dedupWindowMs: Long): Boolean {
        val db = writableDatabase
        val values = ContentValues().apply {
            put("package_name", input.packageName)
            put("app_name", input.appName)
            put("title", input.title.take(MAX_TEXT_LENGTH))
            put("message", input.message.take(MAX_TEXT_LENGTH))
            put("sub_text", input.subText.take(MAX_TEXT_LENGTH))
            put("category", input.category)
            put("post_time_ms", input.postTimeMs)
            put("notification_key", input.notificationKey)
            put("conversation_key", input.conversationKey)
            put("action", if (input.isBlocked) "silenced" else "allowed")
            put("reason", input.reason)
            put("rule_name", input.ruleName)
            put("time_window", input.timeWindow)
            if (windowId != null) put("window_id", windowId) else putNull("window_id")
            put("is_group_summary", if (input.isGroupSummary) 1 else 0)
            put("history_only", if (input.isHistoryOnly) 1 else 0)
        }

        if (input.isGroupSummary && hasMessageSibling(db, input.packageName, input.postTimeMs)) return false

        if (windowId != null && (input.notificationKey.isNotBlank() || input.conversationKey.isNotBlank())) {
            val existingId = findWindowDuplicate(db, windowId, input)
            if (existingId != null) {
                // Capture source belongs to the original row, not today's app mode.
                values.remove("history_only")
                db.update("notification_events", values, "id = ?", arrayOf(existingId.toString()))
                return true
            }
        }

        // Drop rapid repeats of the exact same notification (or its group summary).
        db.rawQuery(
            "SELECT title, message, post_time_ms, notification_key, window_id FROM notification_events WHERE package_name = ? AND action = ? " +
                "ORDER BY post_time_ms DESC, id DESC LIMIT 1",
            arrayOf(input.packageName, if (input.isBlocked) "silenced" else "allowed")
        ).use { c ->
            if (c.moveToFirst()) {
                val withinWindow = kotlin.math.abs(input.postTimeMs - c.getLong(2)) <= dedupWindowMs
                val sameContent = (c.getString(0) ?: "") == input.title && (c.getString(1) ?: "") == input.message
                val sameKey = input.notificationKey.isBlank() || (c.getString(3) ?: "").isBlank() ||
                    input.notificationKey == c.getString(3)
                val sameWindow = if (windowId == null) c.isNull(4) else !c.isNull(4) && c.getLong(4) == windowId
                if (withinWindow && sameWindow && sameKey && (sameContent || input.isGroupSummary)) return false
            }
        }

        db.insertOrThrow("notification_events", null, values)
        return true
    }

    private fun hasMessageSibling(db: SQLiteDatabase, packageName: String, postTimeMs: Long): Boolean =
        db.rawQuery(
            "SELECT 1 FROM notification_events WHERE package_name = ? AND is_group_summary = 0 " +
                "AND post_time_ms BETWEEN ? AND ? LIMIT 1",
            arrayOf(packageName, (postTimeMs - SUMMARY_SIBLING_MS).toString(), (postTimeMs + SUMMARY_SIBLING_MS).toString())
        ).use { it.moveToFirst() }

    private fun findWindowDuplicate(db: SQLiteDatabase, windowId: Long, input: EventInput): Long? {
        val clauses = mutableListOf<String>()
        val args = mutableListOf(windowId.toString(), input.packageName)
        if (input.notificationKey.isNotBlank()) {
            clauses.add("notification_key = ?")
            args.add(input.notificationKey)
        }
        if (input.conversationKey.isNotBlank()) {
            clauses.add("conversation_key = ?")
            args.add(input.conversationKey)
        }
        db.rawQuery(
            "SELECT id FROM notification_events WHERE window_id = ? AND package_name = ? AND is_group_summary = " +
                (if (input.isGroupSummary) "1" else "0") + " AND (" +
                clauses.joinToString(" OR ") + ") LIMIT 1",
            args.toTypedArray()
        ).use { c -> return if (c.moveToFirst()) c.getLong(0) else null }
    }

    @Synchronized
    fun pruneOlderThan(cutoffMs: Long) {
        val db = writableDatabase
        db.delete("notification_events", "post_time_ms < ?", arrayOf(cutoffMs.toString()))
        db.delete("rule_windows", "end_ms < ?", arrayOf(cutoffMs.toString()))
        db.delete("held_notifications", "release_at_ms < ?", arrayOf(cutoffMs.toString()))
    }

    /**
     * Deletes single log entries (swipe-to-delete). A group summary is only hidden while a
     * real message sits next to it, so summaries left without one are deleted too.
     */
    @Synchronized
    fun deleteEvents(ids: List<Long>) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            for (id in ids) {
                var packageName: String? = null
                var postTimeMs = 0L
                db.rawQuery(
                    "SELECT package_name, post_time_ms FROM notification_events WHERE id = ?",
                    arrayOf(id.toString())
                ).use { c ->
                    if (c.moveToFirst()) {
                        packageName = c.getString(0)
                        postTimeMs = c.getLong(1)
                    }
                }
                val pkg = packageName ?: continue
                db.delete("notification_events", "id = ?", arrayOf(id.toString()))
                db.execSQL(
                    "DELETE FROM notification_events WHERE is_group_summary = 1 AND package_name = ? " +
                        "AND post_time_ms BETWEEN ? AND ? AND NOT EXISTS (SELECT 1 FROM notification_events s " +
                        "WHERE s.package_name = notification_events.package_name AND s.is_group_summary = 0 " +
                        "AND s.post_time_ms BETWEEN notification_events.post_time_ms - ? " +
                        "AND notification_events.post_time_ms + ?)",
                    arrayOf<Any>(
                        pkg, postTimeMs - SUMMARY_SIBLING_MS, postTimeMs + SUMMARY_SIBLING_MS,
                        SUMMARY_SIBLING_MS, SUMMARY_SIBLING_MS
                    )
                )
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /** Deletes everything a digest window silenced; the window row stays so a running rule keeps it. */
    @Synchronized
    fun deleteWindowEvents(windowIds: List<Long>) {
        val ids = mutableListOf<Long>()
        for (windowId in windowIds) {
            readableDatabase.rawQuery(
                "SELECT id FROM notification_events WHERE window_id = ?",
                arrayOf(windowId.toString())
            ).use { c -> while (c.moveToNext()) ids.add(c.getLong(0)) }
        }
        deleteEvents(ids)
    }

    @Synchronized
    fun clearAll() {
        val db = writableDatabase
        db.delete("notification_events", null, null)
        db.delete("rule_windows", null, null)
    }

    /** Copies the legacy SharedPreferences Activity log (newest first) into the database. */
    @Synchronized
    fun importLegacyEvents(rawJson: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.rawQuery(
                "SELECT 1 FROM migration_state WHERE name = ?",
                arrayOf("legacy_activity_log")
            ).use { if (it.moveToFirst()) { db.setTransactionSuccessful(); return } }
            val array = JSONArray(rawJson)
            for (i in array.length() - 1 downTo 0) {
                val e = array.getJSONObject(i)
                val pkg = e.getString("packageName")
                require(pkg.isNotBlank()) { "Legacy activity event has no package name" }
                val values = ContentValues().apply {
                    put("package_name", pkg)
                    put("app_name", e.optString("appName"))
                    put("title", e.optString("title"))
                    put("message", e.optString("message"))
                    put("sub_text", e.optString("subText"))
                    put("category", e.optString("category"))
                    put("post_time_ms", e.optLong("timestampMs", System.currentTimeMillis()))
                    put("action", if (e.optBoolean("isBlocked")) "silenced" else "allowed")
                    put("reason", e.optString("reason"))
                    put("rule_name", e.optString("ruleName").ifBlank { null })
                    put("time_window", e.optString("timeWindow").ifBlank { null })
                }
                db.insertOrThrow("notification_events", null, values)
            }
            db.insertOrThrow("migration_state", null, ContentValues().apply {
                put("name", "legacy_activity_log")
            })
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    /** Deletes History-source entries without touching this app's scheduled activity. */
    @Synchronized
    fun deleteHistoryForApp(packageName: String) {
        val ids = mutableListOf<Long>()
        readableDatabase.rawQuery(
            "SELECT id FROM notification_events WHERE package_name = ? AND history_only = 1",
            arrayOf(packageName)
        ).use { c -> while (c.moveToNext()) ids.add(c.getLong(0)) }
        deleteEvents(ids)
    }

    /** Activity log JSON (newest first) in the shape the Flutter Activity screen expects. */
    @Synchronized
    fun getEventsJson(sinceMs: Long): String {
        val result = JSONArray()
        readableDatabase.rawQuery(
            "SELECT id, package_name, app_name, title, message, sub_text, category, post_time_ms, action, " +
                "reason, rule_name, time_window, window_id, delivery, conversation_key, history_only FROM notification_events e " +
                "WHERE post_time_ms >= ? AND NOT (is_group_summary = 1 AND EXISTS (" +
                "SELECT 1 FROM notification_events s WHERE s.package_name = e.package_name AND s.is_group_summary = 0 " +
                "AND s.post_time_ms BETWEEN e.post_time_ms - ? AND e.post_time_ms + ?)) " +
                "ORDER BY post_time_ms DESC, id DESC",
            arrayOf(sinceMs.toString(), SUMMARY_SIBLING_MS.toString(), SUMMARY_SIBLING_MS.toString())
        ).use { c ->
            while (c.moveToNext()) result.put(eventJson(c))
        }
        return result.toString()
    }

    private fun eventJson(c: android.database.Cursor): JSONObject = JSONObject().apply {
        put("id", c.getLong(0).toString())
        put("packageName", c.getString(1))
        c.getString(2)?.takeIf { it.isNotBlank() }?.let { put("appName", it) }
        put("title", c.getString(3) ?: "")
        put("message", c.getString(4) ?: "")
        c.getString(5)?.takeIf { it.isNotBlank() }?.let { put("subText", it) }
        c.getString(6)?.takeIf { it.isNotBlank() }?.let { put("category", it) }
        put("timestampMs", c.getLong(7))
        put("isBlocked", c.getString(8) != "allowed")
        val historyIdx = c.getColumnIndex("history_only")
        put("isHistoryOnly", historyIdx >= 0 && c.getInt(historyIdx) != 0)
        put("reason", c.getString(9) ?: "")
        c.getString(10)?.takeIf { it.isNotBlank() }?.let { put("ruleName", it) }
        c.getString(11)?.takeIf { it.isNotBlank() }?.let { put("timeWindow", it) }
        if (!c.isNull(12)) put("windowId", c.getLong(12))
        val deliveryIdx = c.getColumnIndex("delivery")
        if (deliveryIdx >= 0) c.getString(deliveryIdx)?.let { put("delivery", it) }
        val conversationIdx = c.getColumnIndex("conversation_key")
        if (conversationIdx >= 0) c.getString(conversationIdx)?.takeIf { it.isNotBlank() }?.let { put("conversationKey", it) }
    }

    /**
     * Ended windows (newest first) that silenced at least one notification, each with its
     * unique events. `endMs` is the last silenced minute; the window counts as ended once
     * that minute is over.
     */
    @Synchronized
    fun getDigestJson(nowMs: Long): String {
        val windows = JSONArray()
        val db = readableDatabase
        db.rawQuery(
            "SELECT w.id, w.package_name, w.app_name, w.rule_name, w.start_ms, w.end_ms, w.reviewed " +
                "FROM rule_windows w WHERE w.end_ms + 60000 <= ? AND EXISTS (SELECT 1 FROM notification_events e " +
                "WHERE e.window_id = w.id AND e.is_group_summary = 0) ORDER BY w.end_ms DESC, w.id DESC",
            arrayOf(nowMs.toString())
        ).use { c ->
            while (c.moveToNext()) {
                val windowId = c.getLong(0)
                val events = JSONArray()
                var priority = false
                db.rawQuery(
                    "SELECT id, package_name, app_name, title, message, sub_text, category, post_time_ms, action, " +
                        "reason, rule_name, time_window, window_id, conversation_key, delivery, history_only FROM notification_events " +
                        "WHERE window_id = ? AND is_group_summary = 0 ORDER BY post_time_ms DESC, id DESC",
                    arrayOf(windowId.toString())
                ).use { ec ->
                    while (ec.moveToNext()) {
                        events.put(eventJson(ec))
                        if (isPriority(ec.getString(6) ?: "", ec.getString(13) ?: "")) priority = true
                    }
                }
                windows.put(JSONObject().apply {
                    put("id", windowId)
                    put("packageName", c.getString(1))
                    put("appName", c.getString(2) ?: "")
                    c.getString(3)?.takeIf { it.isNotBlank() }?.let { put("ruleName", it) }
                    put("startMs", c.getLong(4))
                    put("endMs", c.getLong(5))
                    put("reviewed", c.getInt(6) == 1)
                    put("isPriority", priority)
                    put("count", events.length())
                    put("events", events)
                })
            }
        }
        return windows.toString()
    }

    /** Marks ended windows as reviewed; windows still running are left unreviewed. */
    @Synchronized
    fun markWindowsReviewed(ids: List<Long>, nowMs: Long = System.currentTimeMillis()) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        val values = ContentValues().apply { put("reviewed", 1) }
        db.beginTransaction()
        try {
            for (id in ids) {
                db.update("rule_windows", values, "id = ? AND end_ms <= ?", arrayOf(id.toString(), nowMs.toString()))
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    // -----------------------------------------------------------------------------------
    // Phase 2: snoozed notifications and the end-of-rule notification
    // -----------------------------------------------------------------------------------

    data class HeldNotification(
        val key: String,
        val packageName: String,
        val windowId: Long?,
        val releaseAtMs: Long
    )

    data class OpenWindow(val id: Long, val packageName: String, val startMs: Long, val endMs: Long)

    data class DueWindow(val id: Long, val packageName: String, val appName: String, val endMs: Long, val count: Int)

    /** Records that [key] is snoozed until [releaseAtMs] and marks its event "snoozed". */
    @Synchronized
    fun holdNotification(key: String, packageName: String, windowId: Long?, releaseAtMs: Long) {
        val db = writableDatabase
        db.insertWithOnConflict("held_notifications", null, ContentValues().apply {
            put("notification_key", key)
            put("package_name", packageName)
            if (windowId != null) put("window_id", windowId) else putNull("window_id")
            put("release_at_ms", releaseAtMs)
        }, SQLiteDatabase.CONFLICT_REPLACE)
        if (windowId != null) {
            db.update(
                "notification_events",
                ContentValues().apply { put("delivery", DELIVERY_SNOOZED) },
                "notification_key = ? AND window_id = ?",
                arrayOf(key, windowId.toString())
            )
        }
    }

    @Synchronized
    fun getHeld(key: String): HeldNotification? =
        readableDatabase.rawQuery(
            "SELECT notification_key, package_name, window_id, release_at_ms FROM held_notifications WHERE notification_key = ?",
            arrayOf(key)
        ).use { c -> if (c.moveToFirst()) heldFrom(c) else null }

    @Synchronized
    fun getAllHeld(): List<HeldNotification> {
        val result = mutableListOf<HeldNotification>()
        readableDatabase.rawQuery(
            "SELECT notification_key, package_name, window_id, release_at_ms FROM held_notifications ORDER BY release_at_ms",
            null
        ).use { c -> while (c.moveToNext()) result.add(heldFrom(c)) }
        return result
    }

    private fun heldFrom(c: android.database.Cursor) = HeldNotification(
        key = c.getString(0),
        packageName = c.getString(1),
        windowId = if (c.isNull(2)) null else c.getLong(2),
        releaseAtMs = c.getLong(3)
    )

    @Synchronized
    fun updateHeldRelease(key: String, releaseAtMs: Long) {
        writableDatabase.update(
            "held_notifications",
            ContentValues().apply { put("release_at_ms", releaseAtMs) },
            "notification_key = ?",
            arrayOf(key)
        )
    }

    /** Stops tracking [key] and records how it left the snooze ("released" or "removed"). */
    @Synchronized
    fun finishHeld(key: String, delivery: String) {
        val db = writableDatabase
        val held = getHeld(key) ?: return
        db.delete("held_notifications", "notification_key = ?", arrayOf(key))
        if (held.windowId != null) {
            db.update(
                "notification_events",
                ContentValues().apply { put("delivery", delivery) },
                "notification_key = ? AND window_id = ? AND delivery = ?",
                arrayOf(key, held.windowId.toString(), DELIVERY_SNOOZED)
            )
        }
    }

    /** Windows that have not ended yet at [nowMs] and whose notification is still pending. */
    @Synchronized
    fun getOpenWindows(nowMs: Long): List<OpenWindow> {
        val result = mutableListOf<OpenWindow>()
        readableDatabase.rawQuery(
            "SELECT id, package_name, start_ms, end_ms FROM rule_windows WHERE end_ms + 60000 > ? AND digest_posted = 0",
            arrayOf(nowMs.toString())
        ).use { c ->
            while (c.moveToNext()) result.add(OpenWindow(c.getLong(0), c.getString(1), c.getLong(2), c.getLong(3)))
        }
        return result
    }

    @Synchronized
    fun updateWindowEnd(id: Long, endMs: Long) {
        writableDatabase.update(
            "rule_windows",
            ContentValues().apply { put("end_ms", endMs) },
            "id = ?",
            arrayOf(id.toString())
        )
    }

    private val pendingDigestFilter =
        "w.digest_posted = 0 AND w.reviewed = 0 AND EXISTS (SELECT 1 FROM notification_events e " +
            "WHERE e.window_id = w.id AND e.is_group_summary = 0)"

    /** Earliest time a not-yet-notified window with silenced items ends, or null. */
    @Synchronized
    fun nextDigestDueMs(): Long? =
        readableDatabase.rawQuery(
            "SELECT MIN(w.end_ms) + 60000 FROM rule_windows w WHERE $pendingDigestFilter",
            null
        ).use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null }

    /** Earliest end of a not-yet-notified window that is still running at [nowMs], or null. */
    @Synchronized
    fun nextPendingDueAfter(nowMs: Long): Long? =
        readableDatabase.rawQuery(
            "SELECT MIN(w.end_ms) + 60000 FROM rule_windows w WHERE w.end_ms + 60000 > ? AND $pendingDigestFilter",
            arrayOf(nowMs.toString())
        ).use { c -> if (c.moveToFirst() && !c.isNull(0)) c.getLong(0) else null }

    /** Ended windows with silenced items that have not been notified yet. */
    @Synchronized
    fun getDueDigestWindows(nowMs: Long): List<DueWindow> = queryDigestWindows(
        "w.end_ms + 60000 <= ? AND $pendingDigestFilter",
        arrayOf(nowMs.toString())
    )

    /** Windows shown in the Notiflow notification that the user has not reviewed yet. */
    @Synchronized
    fun getShownUnreviewedWindows(): List<DueWindow> = queryDigestWindows(
        "w.digest_posted = $DIGEST_SHOWN AND w.reviewed = 0",
        emptyArray()
    )

    private fun queryDigestWindows(where: String, args: Array<String>): List<DueWindow> {
        val result = mutableListOf<DueWindow>()
        readableDatabase.rawQuery(
            "SELECT w.id, w.package_name, w.app_name, w.end_ms, (SELECT COUNT(*) FROM notification_events e " +
                "WHERE e.window_id = w.id AND e.is_group_summary = 0) AS cnt FROM rule_windows w WHERE $where " +
                "ORDER BY w.end_ms",
            args
        ).use { c ->
            while (c.moveToNext()) {
                val count = c.getInt(4)
                if (count > 0) {
                    result.add(DueWindow(c.getLong(0), c.getString(1), c.getString(2) ?: "", c.getLong(3), count))
                }
            }
        }
        return result
    }

    /** [state] is [DIGEST_SHOWN] or [DIGEST_SKIPPED] (toggle off or permission missing). */
    @Synchronized
    fun markDigestPosted(ids: List<Long>, state: Int) {
        if (ids.isEmpty()) return
        val db = writableDatabase
        val values = ContentValues().apply { put("digest_posted", state) }
        db.beginTransaction()
        try {
            for (id in ids) db.update("rule_windows", values, "id = ?", arrayOf(id.toString()))
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }
}
