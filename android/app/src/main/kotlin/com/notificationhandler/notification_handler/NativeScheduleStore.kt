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

                val rule = NativeScheduleRule(
                    id = obj.getString("id"),
                    appId = obj.getString("appId"),
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

    fun shouldBlockNotification(packageName: String, postTimeMs: Long): Boolean {
        val app = cachedApps[packageName] ?: return false
        if (!app.enabled) return false

        // Check active temporary override
        val override = cachedOverrides[app.id]
        if (override != null && postTimeMs >= override.startMs && postTimeMs < override.endMs) {
            return override.mode == "block"
        }

        val activeRules = cachedRules.filter { it.appId == app.id && it.enabled }
        if (activeRules.isEmpty()) return false

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
                return true
            }
        }

        // Allow rules
        if (allowRules.isNotEmpty()) {
            for (rule in allowRules) {
                if (isRuleMatching(rule, todayIso, yesterdayIso, currentTime)) {
                    return false
                }
            }
            return true // Outside all allow windows -> BLOCK
        }

        return false
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
        reloadIfChanged()
        return evaluator.shouldBlockNotification(packageName, postTimeMs)
    }
}
