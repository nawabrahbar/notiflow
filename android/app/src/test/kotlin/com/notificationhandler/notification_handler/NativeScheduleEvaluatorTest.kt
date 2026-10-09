package com.notificationhandler.notification_handler

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

class NativeScheduleEvaluatorTest {

    @Test
    fun testUnmanagedAppReturnsFalse() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [],
                "schedules": [],
                "overrides": []
            }
        """.trimIndent())

        val shouldBlock = evaluator.shouldBlockNotification("com.unknown.app", System.currentTimeMillis())
        assertFalse("Unmanaged app must never be blocked", shouldBlock)
    }

    @Test
    fun testNormalIntervalAllowWindow() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_whatsapp", "packageName": "com.whatsapp", "enabled": true}
                ],
                "schedules": [
                    {
                        "id": "rule_1",
                        "appId": "app_whatsapp",
                        "enabled": true,
                        "mode": "allowDuring",
                        "startTime": {"hour": 9, "minute": 0},
                        "endTime": {"hour": 18, "minute": 0},
                        "daysOfWeek": [1, 2, 3, 4, 5, 6, 7],
                        "isOvernight": false
                    }
                ],
                "overrides": []
            }
        """.trimIndent())

        // 08:30 (outside 09:00-18:00) -> should BLOCK
        val morningBlocked = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 8)
            set(Calendar.MINUTE, 30)
        }.timeInMillis
        assertTrue("8:30 AM should be blocked outside 9-18 allow window",
            evaluator.shouldBlockNotification("com.whatsapp", morningBlocked))

        // 12:00 (inside 09:00-18:00) -> should ALLOW (shouldBlock == false)
        val middayAllowed = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        assertFalse("12:00 PM should be allowed inside 9-18 allow window",
            evaluator.shouldBlockNotification("com.whatsapp", middayAllowed))

        // 19:00 (outside 09:00-18:00) -> should BLOCK
        val eveningBlocked = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 19)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        assertTrue("7:00 PM should be blocked outside 9-18 allow window",
            evaluator.shouldBlockNotification("com.whatsapp", eveningBlocked))
    }

    @Test
    fun testOvernightIntervalAllowWindow() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_whatsapp", "packageName": "com.whatsapp", "enabled": true}
                ],
                "schedules": [
                    {
                        "id": "rule_overnight",
                        "appId": "app_whatsapp",
                        "enabled": true,
                        "mode": "allowDuring",
                        "startTime": {"hour": 18, "minute": 0},
                        "endTime": {"hour": 6, "minute": 0},
                        "daysOfWeek": [1, 2, 3, 4, 5, 6, 7],
                        "isOvernight": true
                    }
                ],
                "overrides": []
            }
        """.trimIndent())

        // 17:30 (before 18:00) -> should BLOCK
        val afternoon = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 17)
            set(Calendar.MINUTE, 30)
        }.timeInMillis
        assertTrue("5:30 PM should be blocked outside 18:00-06:00 allow window",
            evaluator.shouldBlockNotification("com.whatsapp", afternoon))

        // 20:00 (evening) -> should ALLOW
        val evening = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 20)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        assertFalse("8:00 PM should be allowed in 18:00-06:00 window",
            evaluator.shouldBlockNotification("com.whatsapp", evening))

        // 03:00 (early morning) -> should ALLOW
        val night = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 3)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        assertFalse("3:00 AM should be allowed in 18:00-06:00 window",
            evaluator.shouldBlockNotification("com.whatsapp", night))

        // 07:00 (after 06:00) -> should BLOCK
        val morning = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 7)
            set(Calendar.MINUTE, 0)
        }.timeInMillis
        assertTrue("7:00 AM should be blocked outside 18:00-06:00 window",
            evaluator.shouldBlockNotification("com.whatsapp", morning))
    }
}
