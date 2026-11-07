package com.notificationhandler.notification_handler

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.util.Calendar

data class NativeManagedApp(
    val id: String,
    val packageName: String,
    val enabled: Boolean
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
    val isOvernight: Boolean
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
    val timeWindow: String? = null
)

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

    @Synchronized
    fun parsePayload(payload: String?) {
        if (payload.isNullOrBlank()) {
            cachedApps = emptyMap()
            cachedRules = emptyList()
            cachedOverrides = emptyMap()
            return
        }

        try {
            val root = JSONObject(payload)

            // 1. Managed Apps
            val appsArray = root.optJSONArray("managedApps") ?: org.json.JSONArray()
            val appsMap = mutableMapOf<String, NativeManagedApp>()
            for (i in 0 until appsArray.length()) {
                val obj = appsArray.getJSONObject(i)
                val app = NativeManagedApp(
                    id = obj.getString("id"),
                    packageName = obj.getString("packageName"),
                    enabled = obj.optBoolean("enabled", true)
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

                val rule = NativeScheduleRule(
                    id = obj.getString("id"),
                    appId = obj.getString("appId"),
                    name = if (rawName.isNotEmpty()) rawName else null,
                    enabled = obj.optBoolean("enabled", true),
                    mode = obj.getString("mode"),
                    startTime = startTime,
                    endTime = endTime,
                    daysOfWeek = daysSet,
                    isOvernight = obj.optBoolean("isOvernight", startTime > endTime)
                )
                rulesList.add(rule)
            }
            cachedRules = rulesList

            // 3. Overrides
            val overridesArray = root.optJSONArray("overrides") ?: org.json.JSONArray()
            val overridesMap = mutableMapOf<String, NativeOverride>()
            for (i in 0 until overridesArray.length()) {
                val obj = overridesArray.getJSONObject(i)
                val startIso = obj.getString("startDateTime")
                val endIso = obj.getString("endDateTime")

                val startMs = java.time.Instant.parse(startIso).toEpochMilli()
                val endMs = java.time.Instant.parse(endIso).toEpochMilli()

                val ov = NativeOverride(
                    id = obj.getString("id"),
                    appId = obj.getString("appId"),
                    mode = obj.getString("mode"),
                    startMs = startMs,
                    endMs = endMs
                )
                overridesMap[ov.appId] = ov
            }
            cachedOverrides = overridesMap
        } catch (e: Exception) {
            // Gracefully ignore parse error in background
        }
    }

    fun evaluateNotification(packageName: String, postTimeMs: Long): NativeEvaluationDecision {
        val app = cachedApps[packageName]

        // 1. Check active per-app override if the app is managed and enabled
        if (app != null && app.enabled) {
            val appOverride = cachedOverrides[app.id]
            if (appOverride != null && postTimeMs >= appOverride.startMs && postTimeMs < appOverride.endMs) {
                val blocked = appOverride.mode == "block"
                return NativeEvaluationDecision(
                    shouldBlock = blocked,
                    isManagedOrOverridden = true,
                    reason = if (blocked) "Muted by temporary app override" else "Allowed by temporary app override",
                    ruleName = "Temporary Override"
                )
            }
        }

        // 2. Check active global override (applies to enabled managed apps, and global_mute applies if active)
        val globalOverride = cachedOverrides["global_mute"]
            ?: cachedOverrides["global_allow"]
            ?: cachedOverrides["global"]
        if (globalOverride != null && postTimeMs >= globalOverride.startMs && postTimeMs < globalOverride.endMs) {
            val blocked = globalOverride.mode == "block"
            if (blocked && (app == null || app.enabled)) {
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

        if (app == null || !app.enabled) {
            return NativeEvaluationDecision(
                shouldBlock = false,
                isManagedOrOverridden = false,
                reason = "Unmanaged or paused app"
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

    fun shouldBlockNotification(packageName: String, postTimeMs: Long): Boolean {
        return evaluateNotification(packageName, postTimeMs).shouldBlock
    }

    fun isManagedPackage(packageName: String): Boolean {
        val app = cachedApps[packageName] ?: return false
        return app.enabled
    }

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
        private const val MAX_ACTIVITY_EVENTS = 150
        private const val DEDUP_WINDOW_MS = 2000L

        @Volatile
        var onActivityUpdatedListener: (() -> Unit)? = null
    }

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    private val evaluator = NativeScheduleEvaluator()

    @Volatile
    private var lastLoadedPayload: String? = null

    init {
        loadFromPreferences()
    }

    fun savePayload(jsonPayload: String) {
        prefs.edit().putString(KEY_PAYLOAD, jsonPayload).apply()
        evaluator.parsePayload(jsonPayload)
        lastLoadedPayload = jsonPayload
    }

    fun reloadIfChanged() {
        val currentPayload = prefs.getString(KEY_PAYLOAD, null)
        if (currentPayload != lastLoadedPayload) {
            evaluator.parsePayload(currentPayload)
            lastLoadedPayload = currentPayload
        }
    }

    private fun loadFromPreferences() {
        val payload = prefs.getString(KEY_PAYLOAD, null)
        evaluator.parsePayload(payload)
        lastLoadedPayload = payload
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
        isGroupSummary: Boolean = false
    ): NativeEvaluationDecision {
        reloadIfChanged()
        val decision = evaluator.evaluateNotification(packageName, postTimeMs)

        // Record notification details when blocked (muted) or when from an actively managed app.
        // Skip empty group summary container notifications so we don't duplicate real messages.
        val hasContent = title.isNotBlank() || message.isNotBlank()
        val shouldRecord = (decision.shouldBlock || decision.isManagedOrOverridden) &&
            (!isGroupSummary || hasContent)

        if (shouldRecord) {
            recordTriageEvent(
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
                isGroupSummary = isGroupSummary
            )
        }
        return decision
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
        isGroupSummary: Boolean = false
    ) {
        try {
            val raw = prefs.getString(KEY_ACTIVITY_LOG, null)
            val currentArray = if (!raw.isNullOrBlank()) org.json.JSONArray(raw) else org.json.JSONArray()

            // Deduplicate rapid consecutive updates of the exact same notification or group summary
            if (currentArray.length() > 0) {
                val latest = currentArray.optJSONObject(0)
                if (latest != null) {
                    val samePkg = latest.optString("packageName") == packageName
                    val sameBlock = latest.optBoolean("isBlocked") == isBlocked
                    val prevTs = latest.optLong("timestampMs", 0L)
                    val withinWindow = kotlin.math.abs(postTimeMs - prevTs) <= DEDUP_WINDOW_MS
                    val sameTitle = latest.optString("title") == title
                    val sameMessage = latest.optString("message") == message

                    if (samePkg && sameBlock && withinWindow) {
                        if ((sameTitle && sameMessage) || isGroupSummary) {
                            return
                        }
                    }
                }
            }

            val effectiveReason = reason ?: if (isBlocked) "Silenced by schedule rule" else "Allowed by schedule window"

            val eventObj = JSONObject().apply {
                put("id", "${postTimeMs}_${packageName.hashCode()}")
                put("packageName", packageName)
                if (appName.isNotBlank()) put("appName", appName)
                put("title", title)
                put("message", message)
                if (subText.isNotBlank()) put("subText", subText)
                if (category.isNotBlank()) put("category", category)
                put("timestampMs", postTimeMs)
                put("isBlocked", isBlocked)
                put("reason", effectiveReason)
                if (!ruleName.isNullOrBlank()) put("ruleName", ruleName)
                if (!timeWindow.isNullOrBlank()) put("timeWindow", timeWindow)
            }
            val nextArray = org.json.JSONArray()
            nextArray.put(eventObj)
            val limit = minOf(currentArray.length(), MAX_ACTIVITY_EVENTS - 1)
            for (i in 0 until limit) {
                nextArray.put(currentArray.getJSONObject(i))
            }
            prefs.edit().putString(KEY_ACTIVITY_LOG, nextArray.toString()).apply()
            onActivityUpdatedListener?.invoke()
        } catch (_: Exception) {
            // Ignore logging failures in background
        }
    }

    fun getActivityLogJson(): String {
        return prefs.getString(KEY_ACTIVITY_LOG, "[]") ?: "[]"
    }

    fun clearActivityLog() {
        prefs.edit().remove(KEY_ACTIVITY_LOG).apply()
        onActivityUpdatedListener?.invoke()
    }
}
