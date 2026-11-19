package com.notificationhandler.notification_handler

import android.content.Context
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NotiflowDatabaseTest {
    private val name = "notiflow-instrumentation-test.db"
    private lateinit var context: Context
    private lateinit var database: NotiflowDatabase

    @Before
    fun setup() {
        context = InstrumentationRegistry.getInstrumentation().targetContext
        context.deleteDatabase(name)
        database = NotiflowDatabase(context, name)
    }

    @After
    fun cleanup() {
        database.close()
        context.deleteDatabase(name)
    }

    private fun event(key: String, time: Long, title: String = "Message") =
        NotiflowDatabase.EventInput(
            "com.example.chat", "Chat", title, "Hello", "", "msg", time,
            key, "", true, "Scheduled", "Work", null, false
        )

    @Test
    fun historySourceSurvivesUpdatesAndPerAppDeletionKeepsOtherActivity() {
        val window = database.upsertWindow("com.example.chat", "Chat", "Quick Mute", 1000, 9000)
        database.recordEvent(event("history", 2000).copy(isHistoryOnly = true), window, 2000)
        database.recordEvent(event("history", 5000, "Updated").copy(isHistoryOnly = false), window, 2000)
        database.recordEvent(event("rules", 8000, "Scheduled"), window, 2000)
        database.recordEvent(
            event("other", 8000).copy(packageName = "com.other", isHistoryOnly = true), null, 2000
        )
        val before = JSONArray(database.getEventsJson(0))
        val updated = (0 until before.length()).map { before.getJSONObject(it) }
            .single { it.getString("title") == "Updated" }
        assertTrue(updated.getBoolean("isHistoryOnly"))
        val digestBefore = JSONArray(database.getDigestJson(100000)).getJSONObject(0).getJSONArray("events")
        assertEquals(1, (0 until digestBefore.length()).count {
            digestBefore.getJSONObject(it).getBoolean("isHistoryOnly")
        })

        database.deleteHistoryForApp("com.example.chat")
        val after = JSONArray(database.getEventsJson(0))
        assertEquals(2, after.length())
        val digestAfter = JSONArray(database.getDigestJson(100000)).getJSONObject(0).getJSONArray("events")
        assertEquals(1, digestAfter.length())
        assertEquals("Scheduled", digestAfter.getJSONObject(0).getString("title"))
    }

    @Test
    fun versionTwoUpgradeKeepsExistingRowsWithoutHistoryClassification() {
        database.close()
        context.openOrCreateDatabase(name, Context.MODE_PRIVATE, null).use { db ->
            db.execSQL("""
                CREATE TABLE notification_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, package_name TEXT NOT NULL,
                    app_name TEXT, title TEXT, message TEXT, sub_text TEXT, category TEXT,
                    post_time_ms INTEGER NOT NULL, notification_key TEXT, conversation_key TEXT,
                    action TEXT NOT NULL, reason TEXT, rule_name TEXT, time_window TEXT,
                    window_id INTEGER, is_group_summary INTEGER NOT NULL DEFAULT 0, delivery TEXT
                )
            """.trimIndent())
            db.execSQL("""
                INSERT INTO notification_events(package_name,title,post_time_ms,action)
                VALUES('com.example.chat','Before upgrade',1000,'allowed')
            """.trimIndent())
            db.version = 2
        }
        database = NotiflowDatabase(context, name)
        val events = JSONArray(database.getEventsJson(0))
        assertEquals(1, events.length())
        assertEquals("Before upgrade", events.getJSONObject(0).getString("title"))
        assertFalse(events.getJSONObject(0).getBoolean("isHistoryOnly"))
    }

    @Test
    fun groupSummaryRepeatingAMessageIsHidden() {
        val message = event("child", 2000)
        val summary = message.copy(notificationKey = "summary", postTimeMs = 2010, isGroupSummary = true)
        assertTrue(database.recordEvent(message, null, 2000))
        assertFalse(database.recordEvent(summary, null, 2000))

        // A summary that arrived before its message is still hidden from the log.
        database.recordEvent(summary.copy(postTimeMs = 9000), null, 2000)
        database.recordEvent(event("later", 9010, "Other"), null, 2000)
        val events = JSONArray(database.getEventsJson(0))
        assertEquals(2, events.length())
        assertEquals("Other", events.getJSONObject(0).getString("title"))
    }

    @Test
    fun migrationIsAtomicAndIdempotent() {
        val legacy = """[{"packageName":"com.example.chat","timestampMs":1000,"title":"Old"}]"""
        database.importLegacyEvents(legacy)
        database.importLegacyEvents(legacy)
        assertEquals(1, JSONArray(database.getEventsJson(0)).length())
    }

    @Test
    fun malformedMigrationDoesNotCommitOrPreventRetry() {
        try {
            database.importLegacyEvents("""[{"packageName":"com.example.chat"},{}]""")
            fail("Malformed activity must not be discarded")
        } catch (_: Exception) {
            assertEquals(0, JSONArray(database.getEventsJson(0)).length())
        }
        database.importLegacyEvents("""[{"packageName":"com.example.chat","timestampMs":1000}]""")
        assertEquals(1, JSONArray(database.getEventsJson(0)).length())
    }

    @Test
    fun distinctKeysCountSeparatelyAndUpdatesDeduplicate() {
        val window = database.upsertWindow("com.example.chat", "Chat", "Work", 1000, 5000)
        database.recordEvent(event("first", 2000), window, 2000)
        database.recordEvent(event("second", 2500), window, 2000)
        database.recordEvent(event("first", 3000, "Updated"), window, 2000)
        val digest = JSONArray(database.getDigestJson(65000))
        assertEquals(1, digest.length())
        assertEquals(2, digest.getJSONObject(0).getJSONArray("events").length())
        assertEquals(2, JSONArray(database.getEventsJson(0)).length())
    }

    @Test
    fun ruleExtendedAfterItsNotificationGetsANewWindow() {
        val first = database.upsertWindow("com.example.chat", "Chat", "Work", 1000, 5000)
        database.recordEvent(event("first", 2000), first, 2000)
        database.markDigestPosted(listOf(first), NotiflowDatabase.DIGEST_SHOWN)
        database.markWindowsReviewed(listOf(first), 70000)

        val second = database.upsertWindow("com.example.chat", "Chat", "Work", 1000, 9000)
        assertNotEquals(first, second)
        database.recordEvent(event("second", 8000), second, 8000)
        assertEquals(listOf(second), database.getDueDigestWindows(70000).map { it.id })
        assertEquals(second, database.upsertWindow("com.example.chat", "Chat", "Work", 1000, 9500))

        val windows = JSONArray(database.getDigestJson(100000))
        val extended = (0 until windows.length()).map { windows.getJSONObject(it) }.first { it.getLong("id") == second }
        assertEquals(5000, extended.getLong("startMs"))
    }

        @Test
    fun reviewedStatePersistsAndPruningRemovesOldEvents() {
        val old = database.upsertWindow("old", "Old", null, 0, 1000)
        database.recordEvent(event("old", 500).copy(packageName = "old"), old, 2000)
        val recent = database.upsertWindow("com.example.chat", "Chat", null, 10000, 20000)
        database.recordEvent(event("new", 15000), recent, 2000)
        database.markWindowsReviewed(listOf(recent))
        database.close()
        database = NotiflowDatabase(context, name)
        val digest = JSONArray(database.getDigestJson(100000))
        assertTrue(digest.getJSONObject(0).getBoolean("reviewed"))
        database.pruneOlderThan(5000)
        assertEquals(1, JSONArray(database.getEventsJson(0)).length())
        assertEquals(1, JSONArray(database.getDigestJson(100000)).length())
    }

    @Test
    fun retentionPrunesEventsJustOverThirtyDaysButKeepsBoundary() {
        val now = 2 * NotiflowDatabase.RETENTION_MS
        val cutoff = now - NotiflowDatabase.RETENTION_MS
        database.recordEvent(event("expired", cutoff - 1), null, 2000)
        database.recordEvent(event("boundary", cutoff), null, 2000)
        database.pruneOlderThan(cutoff)
        val events = JSONArray(database.getEventsJson(0))
        assertEquals(1, events.length())
        assertEquals(cutoff, events.getJSONObject(0).getLong("timestampMs"))
    }
}
