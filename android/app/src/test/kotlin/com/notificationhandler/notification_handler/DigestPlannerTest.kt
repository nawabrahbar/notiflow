package com.notificationhandler.notification_handler

import com.notificationhandler.notification_handler.DigestPlanner.AppCount
import com.notificationhandler.notification_handler.DigestPlanner.HeldAction
import com.notificationhandler.notification_handler.DigestPlanner.HoldAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DigestPlannerTest {
    private val min = DigestPlanner.MINUTE_MS
    private val now = 1_000_000L * min
    private val window = (now - 30 * min) to (now + 59 * min)

    @Test
    fun snoozesUntilTheMinuteAfterTheWindow() {
        assertEquals(HoldAction.Snooze(now + 60 * min, 60 * min), DigestPlanner.holdAction(true, true, window, now))
    }

    @Test
    fun cancelsWhenItCannotSnooze() {
        assertEquals(HoldAction.Allow, DigestPlanner.holdAction(false, true, window, now))
        assertEquals(HoldAction.Cancel, DigestPlanner.holdAction(true, false, window, now))
        assertEquals(HoldAction.Cancel, DigestPlanner.holdAction(true, true, null, now))
        assertEquals(HoldAction.Cancel, DigestPlanner.holdAction(true, true, (now - 5 * min) to (now - min), now))
    }

    @Test
    fun reconcilesHeldNotificationsAfterRuleEdits() {
        val release = now + 60 * min
        assertEquals(HeldAction.Keep, DigestPlanner.reconcileHeld(release, true, window, now))
        assertEquals(HeldAction.Release, DigestPlanner.reconcileHeld(release, false, window, now))
        assertEquals(HeldAction.Cancel, DigestPlanner.reconcileHeld(release, true, null, now))
        assertEquals(
            HeldAction.Resnooze(now + 120 * min, 120 * min),
            DigestPlanner.reconcileHeld(release, true, window.first to (now + 119 * min), now)
        )
    }

    @Test
    fun alarmOnlyWhenADigestIsPending() {
        assertNull(DigestPlanner.alarmTime(null, now))
        assertEquals(now + 5 * min + DigestPlanner.SETTLE_MS, DigestPlanner.alarmTime(now + 5 * min, now))
        assertEquals(now + DigestPlanner.SETTLE_MS, DigestPlanner.alarmTime(now - 5 * min, now))
    }

    @Test
    fun combinesWindowsEndingCloseTogether() {
        assertNull(DigestPlanner.combineDelay(now, null, now))
        assertEquals(now + 2 * min + DigestPlanner.SETTLE_MS, DigestPlanner.combineDelay(now, now + 2 * min, now))
        assertNull(DigestPlanner.combineDelay(now, now + 4 * min, now))
        assertNull(DigestPlanner.combineDelay(now - 10 * min, now + min, now))
    }

    @Test
    fun wordsSingleAppDigest() {
        val one = DigestPlanner.digestText(listOf(AppCount("WhatsApp", 1)))!!
        assertEquals("WhatsApp quiet hours ended", one.title)
        assertEquals("1 notification is back", one.body)
        assertEquals("Quiet hours ended · 1 notification", one.publicTitle)
        assertEquals("12 notifications are back", DigestPlanner.digestText(listOf(AppCount("WhatsApp", 5), AppCount("WhatsApp", 7)))!!.body)
    }

    @Test
    fun wordsMultiAppDigestByCount() {
        val text = DigestPlanner.digestText(listOf(AppCount("Slack", 4), AppCount("WhatsApp", 12), AppCount("Mail", 0)))!!
        assertEquals("Quiet hours ended", text.title)
        assertEquals("WhatsApp 12 · Slack 4", text.body)
        assertEquals("Quiet hours ended · 16 notifications", text.publicTitle)
        assertNull(DigestPlanner.digestText(listOf(AppCount("Mail", 0))))
    }
}
