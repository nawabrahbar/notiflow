package com.notificationhandler.notification_handler

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.util.Calendar

data class NativeManagedApp(
    val id: String,
    val packageName: String,
    val enabled: Boolean,
    val isHistoryOnly: Boolean = false
)

data class NativeTimeOfDay(
    val hour: Int,
    val minute: Int
) : Comparable<NativeTimeOfDay> {
    val totalMinutes: Int get() = hour * 60 + minute

    override fun compareTo(other: NativeTimeOfDay): Int =
        totalMinutes.compareTo(other.totalMinutes)
}

data class NativeScheduleRule(
    val id: String,
    val appId: String,
    val name: String? = null,
    val enabled: Boolean,
    val mode: String, // allowDuring, blockDuring, allDayAllow, allDayBlock
    val startTime: NativeTimeOfDay,
    val endTime: NativeTimeOfDay,
    val daysOfWeek: Set<Int>, // 1 = Monday ... 7 = Sunday
    val isOvernight: Boolean,
    val allowVipContacts: Boolean = true
)

data class NativeOverride(
    val id: String,
    val appId: String,
    val mode: String, // allow, block
    val startMs: Long,
    val endMs: Long
)

data class NativeEvaluationDecision(
    val shouldBlock: Boolean,
    val isManagedOrOverridden: Boolean,
    val reason: String,
    val ruleName: String? = null,
    val timeWindow: String? = null,
    /** Set when the notification should be snoozed (not cancelled) for this long. */
    val snoozeDurationMs: Long? = null,
    /** True when this post is a notification Notiflow had snoozed coming back. */
    val isReturningOriginal: Boolean = false
)

/** Lets the store re-snooze or cancel held notifications through the connected listener. */
interface HeldNotificationController {
    fun snooze(key: String, durationMs: Long): Boolean
    fun cancel(key: String): Boolean
}

/**
 * Pure Kotlin evaluator for background schedule decisions.
 * Completely testable on JVM without Android Context.
 */
class NativeScheduleEvaluator {
    @Volatile
    var cachedApps: Map<String, NativeManagedApp> = emptyMap()
        private set

    @Volatile
    var cachedRules: List<NativeScheduleRule> = emptyList()
        private set

    @Volatile
    var cachedOverrides: Map<String, NativeOverride> = emptyMap()
        private set

    @Volatile
    var unmanagedAppsUntouched: Boolean = true
        private set

    @Volatile
    var vipEmergencyBypass: Boolean = true
        private set

    @Synchronized
    fun parsePayload(payload: String?) {
        if (payload.isNullOrBlank()) {
            cachedApps = emptyMap()
            cachedRules = emptyList()
            cachedOverrides = emptyMap()
            unmanagedAppsUntouched = true
            vipEmergencyBypass = true
            return
        }

        try {
            val root = JSONObject(payload)

            unmanagedAppsUntouched = root.optBoolean("unmanagedAppsUntouched", true)
            vipEmergencyBypass = root.optBoolean("vipEmergencyBypass", true)

            // 1. Managed Apps
            val appsArray = root.optJSONArray("managedApps") ?: org.json.JSONArray()
            val appsMap = mutableMapOf<String, NativeManagedApp>()
            for (i in 0 until appsArray.length()) {
                val obj = appsArray.getJSONObject(i)
                val app = NativeManagedApp(
                    id = obj.getString("id"),
                    packageName = obj.getString("packageName"),
                    enabled = obj.optBoolean("enabled", true),
                    isHistoryOnly = obj.optBoolean("isHistoryOnly", false)
                )
                appsMap[app.packageName] = app
            }
            cachedApps = appsMap

            // 2. Schedule Rules
            val rulesArray = root.optJSONArray("schedules") ?: org.json.JSONArray()
            val rulesList = mutableListOf<NativeScheduleRule>()
            for (i in 0 until rulesArray.length()) {
                val obj = rulesArray.getJSONObject(i)
                val startObj = obj.getJSONObject("startTime")
                val endObj = obj.getJSONObject("endTime")

                val daysArray = obj.getJSONArray("daysOfWeek")
                val daysSet = mutableSetOf<Int>()
                for (d in 0 until daysArray.length()) {
                    daysSet.add(daysArray.getInt(d))
                }

                val startTime = NativeTimeOfDay(startObj.getInt("hour"), startObj.getInt("minute"))
                val endTime = NativeTimeOfDay(endObj.getInt("hour"), endObj.getInt("minute"))
                val rawName = obj.optString("name", "").trim()

                val allowVipContacts = obj.optBoolean("allowVipContacts", true)

                val rule = NativeScheduleRule(
                    id = obj.getString("id"),
                    appId = obj.getString("appId"),
                    name = if (rawName.isNotEmpty()) rawName else null,
                    enabled = obj.optBoolean("enabled", true),
                    mode = obj.getString("mode"),
                    startTime = startTime,
                    endTime = endTime,
                    daysOfWeek = daysSet,
                    isOvernight = obj.optBoolean("isOvernight", startTime > endTime),
                    allowVipContacts = allowVipContacts
                )
                rulesList.add(rule)
            }
            cachedRules = rulesList

            // 3. Overrides
            val overridesArray = root.optJSONArray("overrides") ?: org.json.JSONArray()
            val overridesMap = mutableMapOf<String, NativeOverride>()
            for (i in 0 until overridesArray.length()) {
                val obj = overridesArray.getJSONObject(i)
                val startMs = parseTimestampMs(obj, "startDateTime", "startMs")
                val endMs = parseTimestampMs(obj, "endDateTime", "endMs")

                val ov = NativeOverride(
                    id = obj.getString("id"),
                    appId = obj.getString("appId"),
                    mode = obj.getString("mode"),
                    startMs = startMs,
                    endMs = endMs
                )
                overridesMap[ov.appId] = ov

                // Also map packageName <-> appId for per-app overrides so lookups succeed either way
                val matchingApp = appsMap.values.firstOrNull {
                    it.id.equals(ov.appId, ignoreCase = true) ||
                        it.packageName.equals(ov.appId, ignoreCase = true)
                }
                if (matchingApp != null) {
                    overridesMap[matchingApp.packageName] = ov
                    overridesMap[matchingApp.id] = ov
                }
            }
            cachedOverrides = overridesMap
        } catch (e: Exception) {
            // Gracefully ignore parse error in background
        }
    }

    private fun parseTimestampMs(obj: JSONObject, keyIso: String, keyMs: String): Long {
        val ms = obj.optLong(keyMs, -1L)
        if (ms > 0) return ms

        val iso = obj.optString(keyIso, "").trim()
        if (iso.isEmpty()) return 0L

        // 1. Standard ISO Instant (UTC with 'Z')
        try {
            return java.time.Instant.parse(iso).toEpochMilli()
        } catch (_: Exception) {}

        // 2. OffsetDateTime (e.g. 2026-11-14T10:30:00+02:00)
        try {
            return java.time.OffsetDateTime.parse(iso).toInstant().toEpochMilli()
        } catch (_: Exception) {}

        // 3. LocalDateTime (local ISO without zone: 2026-11-14T10:30:00.123456)
        try {
            return java.time.LocalDateTime.parse(iso)
                .atZone(java.time.ZoneId.systemDefault())
                .toInstant()
                .toEpochMilli()
        } catch (_: Exception) {}

        // 4. Numeric string epoch
        try {
            val num = iso.toLongOrNull()
            if (num != null && num > 0) return num
        } catch (_: Exception) {}

        return 0L
    }

    // Tracks caller timestamps for the 3-minute urgent repeated call bypass:
    // Key is "$packageName:$callerIdentity", Value is timestampMs of the last call
    private val callerHistory = java.util.concurrent.ConcurrentHashMap<String, Long>()

    /**
     * Urgent repeated-call check (3-minute window). Returns true when this is the
     * 2nd call from the same caller within 3 minutes; otherwise records the call.
     */
    private fun isRepeatCallBypass(packageName: String, title: String, postTimeMs: Long): Boolean {
        val callerKey = "$packageName:${if (title.isNotBlank()) title.trim() else "unknown"}"
        val lastCallMs = callerHistory[callerKey]
        val threeMinutesMs = 3 * 60 * 1000L

        if (callerHistory.size > 200) {
            callerHistory.entries.removeIf { postTimeMs - it.value > threeMinutesMs * 3 }
        }

        if (lastCallMs != null && (postTimeMs - lastCallMs) in 1..threeMinutesMs) {
            callerHistory.remove(callerKey)
            return true
        }
        callerHistory[callerKey] = postTimeMs
        return false
    }

    private fun findManagedApp(packageName: String): NativeManagedApp? {
        return cachedApps[packageName]
            ?: cachedApps.entries.firstOrNull { it.key.equals(packageName, ignoreCase = true) }?.value
    }

    fun evaluateNotification(
        packageName: String,
        postTimeMs: Long,
        category: String = "",
        title: String = ""
    ): NativeEvaluationDecision {
        // Keep the legacy repeat-caller implementation below dormant for future research.
        if (isCallNotification(category, false)) {
            return NativeEvaluationDecision(
                shouldBlock = false,
                isManagedOrOverridden = false,
                reason = "Call notification left untouched"
            )
        }
        val app = findManagedApp(packageName)
        val appOverride = (if (app != null) cachedOverrides[app.id] ?: cachedOverrides[app.packageName] else null)
            ?: cachedOverrides[packageName]

        // 0. A paused (disabled) app always lets notifications through, even while a temporary mute is running
        if (app != null && !app.enabled) {
            return NativeEvaluationDecision(
                shouldBlock = false,
                isManagedOrOverridden = true,
                reason = "Unmanaged or paused app"
            )
        }

        // 1. Check active per-app override (takes priority over recurring schedules)
        if (appOverride != null && postTimeMs >= appOverride.startMs && postTimeMs < appOverride.endMs) {
            val blocked = appOverride.mode == "block"
            return NativeEvaluationDecision(
                shouldBlock = blocked,
                isManagedOrOverridden = true,
                reason = if (blocked) "Muted by temporary app override" else "Allowed by temporary app override",
                ruleName = "Temporary Override"
            )
        }

        val isCall = category.equals("call", ignoreCase = true) ||
                     category.equals("android.category.call", ignoreCase = true)

        // 2. Check active global override (applies to enabled managed apps, and global_mute applies if active)
        val globalOverride = cachedOverrides["global_mute"]
            ?: cachedOverrides["global_allow"]
            ?: cachedOverrides["global"]
        if (globalOverride != null && postTimeMs >= globalOverride.startMs && postTimeMs < globalOverride.endMs) {
            val blocked = globalOverride.mode == "block"
            if (blocked && (app == null || app.enabled)) {
                // Repeat callers ring through during Quick Mute when the toggle is on
                if (vipEmergencyBypass && isCall && isRepeatCallBypass(packageName, title, postTimeMs)) {
                    return NativeEvaluationDecision(
                        shouldBlock = false,
                        isManagedOrOverridden = true,
                        reason = "Allowed by urgent repeated call bypass (< 3 mins)",
                        ruleName = "Urgent Call Bypass"
                    )
                }
                return NativeEvaluationDecision(
                    shouldBlock = true,
                    isManagedOrOverridden = true,
                    reason = "Silenced by Global Mute override",
                    ruleName = "Global Mute"
                )
            } else if (!blocked && app != null && app.enabled) {
                return NativeEvaluationDecision(
                    shouldBlock = false,
                    isManagedOrOverridden = true,
                    reason = "Allowed by Global Allow override",
                    ruleName = "Global Allow"
                )
            }
        }

        if (app == null) {
            if (!unmanagedAppsUntouched) {
                return NativeEvaluationDecision(
                    shouldBlock = true,
                    isManagedOrOverridden = true,
                    reason = "Blocked (unmanaged apps pass-through disabled)",
                    ruleName = "Strict Mode"
                )
            }
            return NativeEvaluationDecision(
                shouldBlock = false,
                isManagedOrOverridden = false,
                reason = "Unmanaged or paused app"
            )
        }

        if (app.isHistoryOnly) {
            return NativeEvaluationDecision(
                shouldBlock = false,
                isManagedOrOverridden = true,
                reason = "Recorded for history; no app-specific rules"
            )
        }

        val activeRules = cachedRules.filter { it.appId == app.id && it.enabled }
        if (activeRules.isEmpty()) {
            return NativeEvaluationDecision(
                shouldBlock = false,
                isManagedOrOverridden = true,
                reason = "Allowed (no active schedule rules)"
            )
        }

        val cal = Calendar.getInstance().apply { timeInMillis = postTimeMs }
        val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
        val todayIso = if (dayOfWeek == Calendar.SUNDAY) 7 else dayOfWeek - 1
        val yesterdayIso = if (todayIso == 1) 7 else todayIso - 1
        val currentTime = NativeTimeOfDay(cal.get(Calendar.HOUR_OF_DAY), cal.get(Calendar.MINUTE))

        val allowRules = activeRules.filter { it.mode == "allowDuring" || it.mode == "allDayAllow" }
        val blockRules = activeRules.filter { it.mode == "blockDuring" || it.mode == "allDayBlock" }

        // Explicit block rules take priority
        for (rule in blockRules) {
            if (isRuleMatching(rule, todayIso, yesterdayIso, currentTime)) {
                val label = rule.name ?: "Block Schedule"
                val window = formatRuleWindow(rule)

                // Urgent repeated call escalation check (3-minute window)
                if (vipEmergencyBypass && isCall && rule.allowVipContacts) {
                    if (isRepeatCallBypass(packageName, title, postTimeMs)) {
                        return NativeEvaluationDecision(
                            shouldBlock = false,
                            isManagedOrOverridden = true,
                            reason = "Allowed by urgent repeated call bypass (< 3 mins)",
                            ruleName = "Urgent Call Bypass",
                            timeWindow = window
                        )
                    }
                }

                return NativeEvaluationDecision(
                    shouldBlock = true,
                    isManagedOrOverridden = true,
                    reason = "Blocked by ‘$label’ rule ($window)",
                    ruleName = label,
                    timeWindow = window
                )
            }
        }

        // Allow rules
        if (allowRules.isNotEmpty()) {
            for (rule in allowRules) {
                if (isRuleMatching(rule, todayIso, yesterdayIso, currentTime)) {
                    val label = rule.name ?: "Allow Schedule"
                    val window = formatRuleWindow(rule)
                    return NativeEvaluationDecision(
                        shouldBlock = false,
                        isManagedOrOverridden = true,
                        reason = "Allowed by ‘$label’ rule ($window)",
                        ruleName = label,
                        timeWindow = window
                    )
                }
            }
            val firstAllow = allowRules.first()
            val label = firstAllow.name ?: "Allow Schedule"
            val window = formatRuleWindow(firstAllow)

            // Urgent repeated call escalation check outside allow window
            if (vipEmergencyBypass && isCall && firstAllow.allowVipContacts) {
                if (isRepeatCallBypass(packageName, title, postTimeMs)) {
                    return NativeEvaluationDecision(
                        shouldBlock = false,
                        isManagedOrOverridden = true,
                        reason = "Allowed by urgent repeated call bypass (< 3 mins)",
                        ruleName = "Urgent Call Bypass",
                        timeWindow = window
                    )
                }
            }

            return NativeEvaluationDecision(
                shouldBlock = true,
                isManagedOrOverridden = true,
                reason = "Blocked outside ‘$label’ allow window ($window)",
                ruleName = label,
                timeWindow = window
            )
        }

        return NativeEvaluationDecision(
            shouldBlock = false,
            isManagedOrOverridden = true,
            reason = "Outside active block schedule"
        )
    }

    fun shouldBlockNotification(
        packageName: String,
        postTimeMs: Long,
        category: String = "",
        title: String = ""
    ): Boolean {
        return evaluateNotification(
            packageName = packageName,
            postTimeMs = postTimeMs,
            category = category,
            title = title
        ).shouldBlock
    }

    /**
     * Finds the continuous silenced period around [timeMs] for [packageName] with the
     * current rules and overrides, so overlapping rules, overnight rules and temporary
     * mutes merge into one window. Scans minute by minute without side effects.
     *
     * Returns `startMs` (first silenced minute) and `endMs` (last silenced minute), or
     * null when the app is not silenced at [timeMs] or stays silenced beyond
     * [maxScanDays] in either direction (treated as a permanent mute: no digest).
     */
    fun findSilencedWindow(
        packageName: String,
        timeMs: Long,
        maxScanDays: Int = 8
    ): Pair<Long, Long>? {
        if (!evaluateNotification(packageName, timeMs).shouldBlock) return null
        val minuteMs = 60_000L
        val maxSteps = maxScanDays * 24 * 60
        val baseMinute = timeMs - Math.floorMod(timeMs, minuteMs)

        var end: Long? = null
        var probe = baseMinute
        for (i in 0 until maxSteps) {
            val next = probe + minuteMs
            if (!evaluateNotification(packageName, next).shouldBlock) {
                end = probe
                break
            }
            probe = next
        }
        if (end == null) return null

        var start: Long? = null
        probe = baseMinute
        for (i in 0 until maxSteps) {
            val prev = probe - minuteMs
            if (!evaluateNotification(packageName, prev).shouldBlock) {
                start = probe
                break
            }
            probe = prev
        }
        if (start == null) return null
        return Pair(start, end)
    }

    fun isManagedPackage(packageName: String): Boolean {
        val app = findManagedApp(packageName) ?: return false
        return app.enabled
    }

    fun isHistoryOnlyPackage(packageName: String): Boolean =
        findManagedApp(packageName)?.isHistoryOnly == true

    private fun formatRuleWindow(rule: NativeScheduleRule): String {
        if (rule.mode == "allDayAllow" || rule.mode == "allDayBlock") {
            return "All Day"
        }
        return String.format(
            "%02d:%02d - %02d:%02d",
            rule.startTime.hour,
            rule.startTime.minute,
            rule.endTime.hour,
            rule.endTime.minute
        )
    }

    private fun isRuleMatching(
        rule: NativeScheduleRule,
        todayIso: Int,
        yesterdayIso: Int,
        currentTime: NativeTimeOfDay
    ): Boolean {
        if (rule.mode == "allDayAllow" || rule.mode == "allDayBlock") {
            return rule.daysOfWeek.contains(todayIso)
        }

        if (!rule.isOvernight) {
            if (!rule.daysOfWeek.contains(todayIso)) return false
            return currentTime >= rule.startTime && currentTime <= rule.endTime
        } else {
            if (rule.daysOfWeek.contains(todayIso) && currentTime >= rule.startTime) {
                return true
            }
            if (rule.daysOfWeek.contains(yesterdayIso) && currentTime <= rule.endTime) {
                return true
            }
            return false
        }
    }
}

class NativeScheduleStore(context: Context) {
    companion object {
        const val PREF_NAME = "notification_handler_schedules"
        const val KEY_PAYLOAD = "payload"
        const val KEY_ACTIVITY_LOG = "activity_log"
        private const val KEY_LAST_PRUNE_MS = "activity_last_prune_ms"
        private const val DEDUP_WINDOW_MS = 2000L
        private const val PRUNE_INTERVAL_MS = 24L * 60 * 60 * 1000

        @Volatile
        var onActivityUpdatedListener: (() -> Unit)? = null
    }

    private val appContext: Context = context.applicationContext

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    private val database = NotiflowDatabase.getInstance(context)

    private val evaluator = NativeScheduleEvaluator()

    @Volatile
    private var lastLoadedPayload: String? = null

    // Last computed silenced window per package, valid while the payload is unchanged.
    private val windowCache = java.util.concurrent.ConcurrentHashMap<String, Pair<Long, Long>>()

    init {
        loadFromPreferences()
        migrateLegacyActivityLog()
        pruneIfDue(force = true)
    }

    fun savePayload(jsonPayload: String) {
        prefs.edit().putString(KEY_PAYLOAD, jsonPayload).apply()
        evaluator.parsePayload(jsonPayload)
        lastLoadedPayload = jsonPayload
        windowCache.clear()
    }

    fun reloadIfChanged() {
        val currentPayload = prefs.getString(KEY_PAYLOAD, null)
        if (currentPayload != lastLoadedPayload) {
            evaluator.parsePayload(currentPayload)
            lastLoadedPayload = currentPayload
            windowCache.clear()
        }
    }

    private fun loadFromPreferences() {
        val payload = prefs.getString(KEY_PAYLOAD, null)
        evaluator.parsePayload(payload)
        lastLoadedPayload = payload
    }

    @Synchronized
    private fun migrateLegacyActivityLog() {
        try {
            val raw = prefs.getString(KEY_ACTIVITY_LOG, null) ?: return
            if (raw.isNotBlank()) database.importLegacyEvents(raw)
            prefs.edit().remove(KEY_ACTIVITY_LOG).apply()
        } catch (e: Exception) {
            android.util.Log.e("NativeScheduleStore", "Activity history migration failed; legacy history was retained", e)
        }
    }

    private fun pruneIfDue(force: Boolean = false) {
        try {
            val now = System.currentTimeMillis()
            val last = prefs.getLong(KEY_LAST_PRUNE_MS, 0L)
            if (!force && now - last < PRUNE_INTERVAL_MS) return
            database.pruneOlderThan(now - NotiflowDatabase.RETENTION_MS)
            prefs.edit().putLong(KEY_LAST_PRUNE_MS, now).apply()
        } catch (_: Exception) {
        }
    }

    fun shouldBlockNotification(packageName: String, postTimeMs: Long): Boolean {
        return evaluateAndRecordNotification(
            packageName = packageName,
            postTimeMs = postTimeMs
        ).shouldBlock
    }

    fun evaluateAndRecordNotification(
        packageName: String,
        postTimeMs: Long,
        appName: String = "",
        title: String = "",
        message: String = "",
        subText: String = "",
        category: String = "",
        isGroupSummary: Boolean = false,
        notificationKey: String = "",
        conversationKey: String = "",
        evaluationTimeMs: Long = postTimeMs,
        canSnooze: Boolean = false,
        isSelfMessage: Boolean = false
    ): NativeEvaluationDecision {
        reloadIfChanged()
        val decision = evaluator.evaluateNotification(
            packageName = packageName,
            postTimeMs = evaluationTimeMs,
            category = category,
            title = title
        )

        val held = if (notificationKey.isNotBlank()) heldOrNull(notificationKey, evaluationTimeMs) else null
        if (held != null) return handleHeldRepost(held, decision, canSnooze, evaluationTimeMs)

        // Record blocked notifications and all managed apps, including paused apps.
        // Skip empty group summary container notifications so we don't duplicate real messages.
        val hasContent = title.isNotBlank() || message.isNotBlank()
        // The user's own replies are re-posted by chat apps; keep blocking them but don't log them.
        val shouldRecord = (decision.shouldBlock || decision.isManagedOrOverridden) &&
            (!isGroupSummary || hasContent) && !isSelfMessage

        var windowId: Long? = null
        if (shouldRecord) {
            windowId = recordTriageEvent(
                packageName = packageName,
                appName = appName,
                title = title,
                message = message,
                subText = subText,
                category = category,
                postTimeMs = postTimeMs,
                isBlocked = decision.shouldBlock,
                reason = decision.reason,
                ruleName = decision.ruleName,
                timeWindow = decision.timeWindow,
                isGroupSummary = isGroupSummary,
                notificationKey = notificationKey,
                conversationKey = conversationKey,
                isHistoryOnly = evaluator.isHistoryOnlyPackage(packageName)
            )
        }

        if (!decision.shouldBlock) return decision
        val window = silencedWindowFor(packageName, evaluationTimeMs)
        val action = DigestPlanner.holdAction(
            shouldBlock = true,
            canSnooze = canSnooze && notificationKey.isNotBlank(),
            window = window,
            nowMs = evaluationTimeMs
        )
        if (action is DigestPlanner.HoldAction.Snooze) {
            try {
                database.holdNotification(notificationKey, packageName, windowId, action.releaseAtMs)
                DigestNotifier.reschedule(appContext)
                return decision.copy(snoozeDurationMs = action.durationMs)
            } catch (_: Exception) {
                // Fall back to cancelling when the hold cannot be stored.
            }
        }
        return decision
    }

    /** The held row for [key], dropping it when it is long past its release (it never came back). */
    private fun heldOrNull(key: String, nowMs: Long): NotiflowDatabase.HeldNotification? {
        return try {
            val held = database.getHeld(key) ?: return null
            if (held.releaseAtMs + 2 * DigestPlanner.MINUTE_MS < nowMs) {
                database.finishHeld(key, NotiflowDatabase.DELIVERY_REMOVED)
                null
            } else held
        } catch (_: Exception) {
            null
        }
    }

    /**
     * A snoozed notification came back. If its app is no longer silenced it is let
     * through and not logged again; otherwise it is snoozed to the current window end.
     */
    private fun handleHeldRepost(
        held: NotiflowDatabase.HeldNotification,
        decision: NativeEvaluationDecision,
        canSnooze: Boolean,
        nowMs: Long
    ): NativeEvaluationDecision {
        try {
            if (!decision.shouldBlock) {
                database.finishHeld(held.key, NotiflowDatabase.DELIVERY_RELEASED)
                onActivityUpdatedListener?.invoke()
                return decision.copy(isReturningOriginal = true)
            }
            val window = silencedWindowFor(held.packageName, nowMs)
            val action = DigestPlanner.holdAction(true, canSnooze, window, nowMs)
            if (action is DigestPlanner.HoldAction.Snooze) {
                database.updateHeldRelease(held.key, action.releaseAtMs)
                return decision.copy(snoozeDurationMs = action.durationMs, isReturningOriginal = true)
            }
            database.finishHeld(held.key, NotiflowDatabase.DELIVERY_REMOVED)
        } catch (_: Exception) {
        }
        return decision.copy(isReturningOriginal = true)
    }

    /** Marks a held notification removed by its source app during the window. */
    fun onHeldNotificationRemoved(key: String) {
        try {
            if (database.getHeld(key) != null) {
                database.finishHeld(key, NotiflowDatabase.DELIVERY_REMOVED)
                onActivityUpdatedListener?.invoke()
            }

        } catch (_: Exception) {
        }
    }

    /** A previously held notification returned with call metadata; leave it visible. */
    fun onHeldNotificationReleased(key: String) {
        try {
            if (database.getHeld(key) != null) {
                database.finishHeld(key, NotiflowDatabase.DELIVERY_RELEASED)
                onActivityUpdatedListener?.invoke()
            }
        } catch (e: Exception) {
            android.util.Log.w("NativeScheduleStore", "Could not release held call notification", e)
        }
    }

    /**
     * After a restart or listener reconnect: held notifications that Android no longer has
     * (neither snoozed nor showing) are marked removed.
     */
    fun dropLostHeld(presentKeys: Set<String>) {
        try {
            for (held in database.getAllHeld()) {
                if (held.key !in presentKeys) database.finishHeld(held.key, NotiflowDatabase.DELIVERY_REMOVED)
            }
        } catch (_: Exception) {
        }
    }

    /**
     * Applies the saved rules to running windows and snoozed notifications (spec 3.4):
     * a changed end time re-snoozes, a finished/deleted/disabled rule releases now, and a
     * switch to permanent mute cancels. Uses its own evaluator so it can run off the main thread.
     */
    fun reconcileHeld(controller: HeldNotificationController?) {
        try {
            val now = System.currentTimeMillis()
            val eval = NativeScheduleEvaluator().apply { parsePayload(prefs.getString(KEY_PAYLOAD, null)) }
            val windows = HashMap<String, Pair<Long, Long>?>()
            val blocked = HashMap<String, Boolean>()
            fun windowFor(pkg: String) = windows.getOrPut(pkg) { eval.findSilencedWindow(pkg, now) }
            fun blockedFor(pkg: String) = blocked.getOrPut(pkg) { eval.evaluateNotification(pkg, now).shouldBlock }

            var changed = false
            val currentMinute = now - Math.floorMod(now, DigestPlanner.MINUTE_MS)
            for (w in database.getOpenWindows(now)) {
                val current = windowFor(w.packageName)
                if (current == null) {
                    database.updateWindowEnd(w.id, maxOf(w.startMs, currentMinute - DigestPlanner.MINUTE_MS))
                    changed = true
                } else if (current.second != w.endMs && current.first <= w.endMs + DigestPlanner.MINUTE_MS) {
                    database.updateWindowEnd(w.id, current.second)
                    changed = true
                }
            }

            for (held in database.getAllHeld()) {
                val action = DigestPlanner.reconcileHeld(
                    held.releaseAtMs, blockedFor(held.packageName), windowFor(held.packageName), now
                )
                when (action) {
                    is DigestPlanner.HeldAction.Resnooze ->
                        if (controller?.snooze(held.key, action.durationMs) == true) {
                            database.updateHeldRelease(held.key, action.releaseAtMs)
                        }
                    DigestPlanner.HeldAction.Release ->
                        // Comes back in a moment; the listener then marks it released.
                        controller?.snooze(held.key, DigestPlanner.RELEASE_NOW_MS)
                    DigestPlanner.HeldAction.Cancel ->
                        if (controller?.cancel(held.key) == true) {
                            database.finishHeld(held.key, NotiflowDatabase.DELIVERY_REMOVED)
                        }
                    DigestPlanner.HeldAction.Keep -> Unit
                }
            }
            windowCache.clear()
            DigestNotifier.reschedule(appContext)
            if (changed) onActivityUpdatedListener?.invoke()
        } catch (e: Exception) {
            android.util.Log.w("NativeScheduleStore", "Could not apply rule changes to held notifications", e)
        }
    }

    private fun silencedWindowFor(packageName: String, timeMs: Long): Pair<Long, Long>? {
        windowCache[packageName]?.let { cached ->
            if (timeMs >= cached.first && timeMs < cached.second + 60_000L) return cached
        }
        val window = evaluator.findSilencedWindow(packageName, timeMs) ?: return null
        windowCache[packageName] = window
        return window
    }

    @Synchronized
    fun recordTriageEvent(
        packageName: String,
        postTimeMs: Long,
        isBlocked: Boolean,
        appName: String = "",
        title: String = "",
        message: String = "",
        subText: String = "",
        category: String = "",
        reason: String? = null,
        ruleName: String? = null,
        timeWindow: String? = null,
        isGroupSummary: Boolean = false,
        notificationKey: String = "",
        conversationKey: String = "",
        isHistoryOnly: Boolean = false
    ): Long? {
        return try {
            val effectiveReason = reason ?: if (isBlocked) "Silenced by schedule rule" else "Allowed by schedule window"
            val windowId = if (isBlocked) {
                silencedWindowFor(packageName, postTimeMs)?.let { (start, end) ->
                    database.upsertWindow(packageName, appName, ruleName, start, end)
                }
            } else null

            val recorded = database.recordEvent(
                NotiflowDatabase.EventInput(
                    packageName = packageName,
                    appName = appName,
                    title = title,
                    message = message,
                    subText = subText,
                    category = category,
                    postTimeMs = postTimeMs,
                    notificationKey = notificationKey,
                    conversationKey = conversationKey,
                    isBlocked = isBlocked,
                    reason = effectiveReason,
                    ruleName = ruleName,
                    timeWindow = timeWindow,
                    isGroupSummary = isGroupSummary,
                    isHistoryOnly = isHistoryOnly
                ),
                windowId,
                DEDUP_WINDOW_MS
            )
            pruneIfDue()
            if (recorded) onActivityUpdatedListener?.invoke()
            windowId
        } catch (_: Exception) {
            // Ignore logging failures in background
            null
        }
    }

    fun getActivityLogJson(): String {
        return try {
            database.getEventsJson(System.currentTimeMillis() - NotiflowDatabase.RETENTION_MS)
        } catch (_: Exception) {
            "[]"
        }
    }

    fun getDigestJson(): String {
        return try {
            database.getDigestJson(System.currentTimeMillis())
        } catch (_: Exception) {
            "[]"
        }
    }

    fun markDigestReviewed(ids: List<Long>) {
        try {
            database.markWindowsReviewed(ids)
            DigestNotifier.onReviewed(appContext)
            onActivityUpdatedListener?.invoke()
        } catch (_: Exception) {
        }
    }

    fun deleteActivityEvents(ids: List<Long>) = afterDelete { database.deleteEvents(ids) }

    fun deleteHistoryForApp(packageName: String) {
        database.deleteHistoryForApp(packageName)
        DigestNotifier.onReviewed(appContext)
        onActivityUpdatedListener?.invoke()
    }

    fun deleteDigestWindows(ids: List<Long>) = afterDelete { database.deleteWindowEvents(ids) }

    private fun afterDelete(delete: () -> Unit) {
        try {
            delete()
            // Drops the end-of-rule notification if nothing it listed is left.
            DigestNotifier.onReviewed(appContext)
        } catch (_: Exception) {
        }
        onActivityUpdatedListener?.invoke()
    }

    fun clearActivityLog() {
        try {
            database.clearAll()
        } catch (_: Exception) {
        }
        prefs.edit().remove(KEY_ACTIVITY_LOG).apply()
        windowCache.clear()
        onActivityUpdatedListener?.invoke()
    }
}
