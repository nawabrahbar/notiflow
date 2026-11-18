package com.notificationhandler.notification_handler

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.util.Calendar

class SilencedWindowTest {

    private fun at(dayOffset: Int, hour: Int, minute: Int): Long =
        Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, dayOffset)
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

    private fun rule(id: String, mode: String, sh: Int, sm: Int, eh: Int, em: Int) = """
        {"id": "$id", "appId": "app_wa", "enabled": true, "mode": "$mode",
         "startTime": {"hour": $sh, "minute": $sm}, "endTime": {"hour": $eh, "minute": $em},
         "daysOfWeek": [1, 2, 3, 4, 5, 6, 7]}
    """

    private fun evaluator(rules: List<String>, overrides: String = "") = NativeScheduleEvaluator().apply {
        parsePayload("""
            {"managedApps": [{"id": "app_wa", "packageName": "com.whatsapp", "enabled": true}],
             "schedules": [${rules.joinToString(",")}],
             "overrides": [$overrides]}
        """.trimIndent())
    }

    @Test
    fun singleRuleWindowSpansRuleTimes() {
        val ev = evaluator(listOf(rule("r1", "blockDuring", 9, 0, 17, 0)))
        val window = ev.findSilencedWindow("com.whatsapp", at(0, 12, 30) + 15_000)
        assertEquals(at(0, 9, 0), window!!.first)
        assertEquals(at(0, 17, 0), window.second)
    }

    @Test
    fun separateRulesGiveSeparateWindows() {
        val ev = evaluator(listOf(
            rule("r1", "blockDuring", 9, 0, 17, 0),
            rule("r2", "blockDuring", 19, 0, 21, 0)
        ))
        val evening = ev.findSilencedWindow("com.whatsapp", at(0, 20, 0))
        assertEquals(at(0, 19, 0), evening!!.first)
        assertEquals(at(0, 21, 0), evening.second)
        assertNull(ev.findSilencedWindow("com.whatsapp", at(0, 18, 0)))
    }

    @Test
    fun overlappingRulesMergeIntoOneWindow() {
        val ev = evaluator(listOf(
            rule("r1", "blockDuring", 9, 0, 13, 0),
            rule("r2", "blockDuring", 12, 0, 17, 0)
        ))
        val window = ev.findSilencedWindow("com.whatsapp", at(0, 10, 0))
        assertEquals(at(0, 9, 0), window!!.first)
        assertEquals(at(0, 17, 0), window.second)
    }

    @Test
    fun overnightRuleEndsNextMorning() {
        val ev = evaluator(listOf(rule("r1", "blockDuring", 22, 0, 7, 0)))
        val window = ev.findSilencedWindow("com.whatsapp", at(0, 23, 30))
        assertEquals(at(0, 22, 0), window!!.first)
        assertEquals(at(1, 7, 0), window.second)
    }

    @Test
    fun temporaryMuteIsItsOwnWindow() {
        val start = at(0, 10, 0)
        val end = start + 60 * 60_000L
        val ev = evaluator(emptyList(),
            """{"id": "o1", "appId": "global_mute", "mode": "block", "startMs": $start, "endMs": $end}""")
        val window = ev.findSilencedWindow("com.whatsapp", start + 5 * 60_000L)
        assertEquals(start, window!!.first)
        assertEquals(end - 60_000L, window.second)
    }

    @Test
    fun permanentMuteHasNoWindow() {
        val ev = evaluator(listOf(rule("r1", "allDayBlock", 0, 0, 23, 59)))
        assertNull(ev.findSilencedWindow("com.whatsapp", at(0, 12, 0)))
    }

    @Test
    fun allowedTimeHasNoWindow() {
        val ev = evaluator(listOf(rule("r1", "blockDuring", 9, 0, 17, 0)))
        assertNull(ev.findSilencedWindow("com.whatsapp", at(0, 18, 30)))
    }
}
