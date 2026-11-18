package com.notificationhandler.notification_handler

import org.junit.Assert.assertEquals
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

    @Test
    fun testGlobalMuteOverrideBlocksManagedApp() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_whatsapp", "packageName": "com.whatsapp", "enabled": true}
                ],
                "schedules": [],
                "overrides": [
                    {
                        "id": "ov_global",
                        "appId": "global_mute",
                        "mode": "block",
                        "startDateTime": "2026-01-01T00:00:00Z",
                        "endDateTime": "2030-01-01T00:00:00Z"
                    }
                ]
            }
        """.trimIndent())

        val testTime = java.time.Instant.parse("2026-06-01T12:00:00Z").toEpochMilli()
        assertTrue(
            "Global mute override must block managed app even without rules",
            evaluator.shouldBlockNotification("com.whatsapp", testTime)
        )
        assertTrue(
            "Global mute override must also block unmanaged app when Mute All is active",
            evaluator.shouldBlockNotification("com.other.app", testTime)
        )
    }

    @Test
    fun testEvaluateNotificationReturnsRuleNameAndTimeWindow() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_slack", "packageName": "com.Slack", "enabled": true}
                ],
                "schedules": [
                    {
                        "id": "rule_work",
                        "appId": "app_slack",
                        "name": "Deep Work Shield",
                        "enabled": true,
                        "mode": "blockDuring",
                        "startTime": {"hour": 9, "minute": 0},
                        "endTime": {"hour": 17, "minute": 0},
                        "daysOfWeek": [1, 2, 3, 4, 5, 6, 7],
                        "isOvernight": false
                    }
                ],
                "overrides": []
            }
        """.trimIndent())

        val blockTime = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 11)
            set(Calendar.MINUTE, 15)
        }.timeInMillis

        val decision = evaluator.evaluateNotification("com.Slack", blockTime)
        assertTrue(decision.shouldBlock)
        assertTrue(decision.isManagedOrOverridden)
        org.junit.Assert.assertEquals("Deep Work Shield", decision.ruleName)
        org.junit.Assert.assertEquals("09:00 - 17:00", decision.timeWindow)
        assertTrue(decision.reason.contains("Deep Work Shield"))
        assertTrue(decision.reason.contains("09:00 - 17:00"))
    }

    @Test
    fun testPerAppTemporaryMuteOverrideWithLocalIsoAndEpochMs() {
        val evaluator = NativeScheduleEvaluator()
        val now = System.currentTimeMillis()
        val future = now + 15 * 60 * 1000L

        // Test with local ISO format WITHOUT trailing Z (the exact bug from 1.5.4) and epoch ms fallback
        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_slack_123", "packageName": "com.Slack", "enabled": true}
                ],
                "schedules": [],
                "overrides": [
                    {
                        "id": "ov_quick_15m",
                        "appId": "app_slack_123",
                        "mode": "block",
                        "startDateTime": "2026-11-14T10:30:00.123456",
                        "endDateTime": "2026-11-14T10:45:00.123456",
                        "startMs": $now,
                        "endMs": $future
                    }
                ]
            }
        """.trimIndent())

        val testTime = now + 5 * 60 * 1000L
        val decision = evaluator.evaluateNotification("com.Slack", testTime)
        assertTrue("Quick temporary mute override must block notifications during active window", decision.shouldBlock)
        assertTrue(decision.isManagedOrOverridden)
        assertTrue(decision.reason.contains("Muted by temporary app override"))

        // After the window expires -> should ALLOW
        val afterExpiryTime = future + 1000L
        val afterDecision = evaluator.evaluateNotification("com.Slack", afterExpiryTime)
        assertFalse("Notification must be allowed after override expires", afterDecision.shouldBlock)
    }

    @Test
    fun testPausedAppAllowsAndRemainsEligibleForActivityLogDuringMute() {
        val evaluator = NativeScheduleEvaluator()
        val now = System.currentTimeMillis()
        val future = now + 30 * 60 * 1000L

        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_discord_456", "packageName": "com.discord", "enabled": false}
                ],
                "schedules": [],
                "overrides": [
                    {
                        "id": "ov_discord_30m",
                        "appId": "app_discord_456",
                        "mode": "block",
                        "startDateTime": "2026-11-14T12:00:00Z",
                        "endDateTime": "2026-11-14T12:30:00Z",
                        "startMs": $now,
                        "endMs": $future
                    }
                ]
            }
        """.trimIndent())

        val testTime = now + 10 * 60 * 1000L
        val decision = evaluator.evaluateNotification("com.discord", testTime)
        assertFalse("A paused app must let notifications through even while a temporary mute is active", decision.shouldBlock)
        assertTrue("Paused home-page apps must still be included in the activity log", decision.isManagedOrOverridden)
    }

    @Test
    fun testHomePageAppsRemainEligibleForActivityLogRegardlessOfSchedule() {
        for (enabled in listOf(true, false)) {
            for (mode in listOf("allDayAllow", "allDayBlock")) {
                val evaluator = NativeScheduleEvaluator()
                evaluator.parsePayload("""
                    {
                        "managedApps": [
                            {"id": "app", "packageName": "com.example", "enabled": $enabled}
                        ],
                        "schedules": [
                            {
                                "id": "rule",
                                "appId": "app",
                                "enabled": true,
                                "mode": "$mode",
                                "startTime": {"hour": 0, "minute": 0},
                                "endTime": {"hour": 23, "minute": 59},
                                "daysOfWeek": [1, 2, 3, 4, 5, 6, 7]
                            }
                        ],
                        "overrides": []
                    }
                """.trimIndent())

                val decision = evaluator.evaluateNotification("com.example", System.currentTimeMillis())
                assertTrue("Managed app must be logged (enabled=$enabled, mode=$mode)", decision.isManagedOrOverridden)
                if (enabled && mode == "allDayBlock") {
                    assertTrue(decision.shouldBlock)
                } else {
                    assertFalse(decision.shouldBlock)
                }
            }
        }
    }

    @Test
    fun testUnmanagedAppsUntouchedFalseBlocksUnmanagedApps() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [],
                "schedules": [],
                "overrides": [],
                "unmanagedAppsUntouched": false
            }
        """.trimIndent())

        val decision = evaluator.evaluateNotification("com.unknown.app", System.currentTimeMillis())
        assertTrue("Unmanaged app must be blocked when unmanagedAppsUntouched is false", decision.shouldBlock)
        assertTrue(decision.isManagedOrOverridden)
        org.junit.Assert.assertEquals("Strict Mode", decision.ruleName)
    }

    @Test
    fun testVipEmergencyBypassToggleAndCaseInsensitivePackageLookup() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload("""
            {
                "managedApps": [
                    {"id": "app_slack", "packageName": "com.Slack", "enabled": true}
                ],
                "schedules": [
                    {
                        "id": "rule_work",
                        "appId": "app_slack",
                        "name": "Deep Work Shield",
                        "enabled": true,
                        "mode": "blockDuring",
                        "startTime": {"hour": 9, "minute": 0},
                        "endTime": {"hour": 17, "minute": 0},
                        "daysOfWeek": [1, 2, 3, 4, 5, 6, 7],
                        "isOvernight": false,
                        "allowVipContacts": true
                    }
                ],
                "overrides": [],
                "vipEmergencyBypass": false
            }
        """.trimIndent())

        val callTime1 = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 11)
            set(Calendar.MINUTE, 10)
            set(Calendar.SECOND, 0)
        }.timeInMillis
        val callTime2 = callTime1 + 60_000L

        // Case-insensitive lookup ("com.slack" vs "com.Slack") + vipEmergencyBypass = false
        val firstCall = evaluator.evaluateNotification("com.slack", callTime1, category = "call", title = "Alice")
        val secondCall = evaluator.evaluateNotification("com.slack", callTime2, category = "call", title = "Alice")
        assertTrue(firstCall.shouldBlock)
        assertTrue("Second call within 3 mins must still be blocked when global vipEmergencyBypass is false", secondCall.shouldBlock)
    }

    private fun globalMutePayload(bypass: Boolean) = """
        {
            "managedApps": [],
            "schedules": [],
            "overrides": [
                {
                    "id": "ov_global",
                    "appId": "global_mute",
                    "mode": "block",
                    "startDateTime": "2026-01-01T00:00:00Z",
                    "endDateTime": "2030-01-01T00:00:00Z"
                }
            ],
            "vipEmergencyBypass": $bypass
        }
    """.trimIndent()

    @Test
    fun testRepeatCallerRingsThroughDuringGlobalMute() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload(globalMutePayload(bypass = true))
        val t1 = java.time.Instant.parse("2026-06-01T12:00:00Z").toEpochMilli()

        val first = evaluator.evaluateNotification("com.google.android.dialer", t1, category = "call", title = "Mom")
        val second = evaluator.evaluateNotification("com.google.android.dialer", t1 + 90_000L, category = "call", title = "Mom")
        val chat = evaluator.evaluateNotification("com.whatsapp", t1 + 100_000L, category = "msg", title = "Mom")

        assertTrue("First call is silenced by Quick Mute", first.shouldBlock)
        assertFalse("Second call within 3 mins must ring through", second.shouldBlock)
        assertEquals("Urgent Call Bypass", second.ruleName)
        assertTrue("Non-call notifications stay muted", chat.shouldBlock)
    }

    @Test
    fun testRepeatCallerStaysMutedDuringGlobalMuteWhenBypassOff() {
        val evaluator = NativeScheduleEvaluator()
        evaluator.parsePayload(globalMutePayload(bypass = false))
        val t1 = java.time.Instant.parse("2026-06-01T12:00:00Z").toEpochMilli()

        evaluator.evaluateNotification("com.google.android.dialer", t1, category = "call", title = "Mom")
        val second = evaluator.evaluateNotification("com.google.android.dialer", t1 + 90_000L, category = "call", title = "Mom")
        assertTrue(second.shouldBlock)
    }
}
