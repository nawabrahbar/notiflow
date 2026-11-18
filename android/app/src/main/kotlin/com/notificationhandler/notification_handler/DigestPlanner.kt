package com.notificationhandler.notification_handler

/**
 * Pure Catch-Up Digest decisions (no Android dependencies) so they can be unit tested:
 * snooze vs cancel, re-snoozing after rule edits, alarm timing, combining windows and
 * the end-of-rule notification wording.
 */
object DigestPlanner {
    const val MINUTE_MS = 60_000L
    /** Snooze length used to hand a held notification back right away. */
    const val RELEASE_NOW_MS = 1_000L
    /** Small delay so originals returning together produce one notification. */
    const val SETTLE_MS = 15_000L
    /** Windows whose digest falls due within this span of each other are combined. */
    const val COMBINE_MS = 3 * MINUTE_MS
    /** A due digest is never held back longer than this to wait for another window. */
    const val MAX_COMBINE_WAIT_MS = 10 * MINUTE_MS

    sealed class HoldAction {
        object Allow : HoldAction()
        object Cancel : HoldAction()
        data class Snooze(val releaseAtMs: Long, val durationMs: Long) : HoldAction()
    }

    sealed class HeldAction {
        object Keep : HeldAction()
        object Release : HeldAction()
        object Cancel : HeldAction()
        data class Resnooze(val releaseAtMs: Long, val durationMs: Long) : HeldAction()
    }

    /** First allowed moment after a window whose last silenced minute starts at [windowEndMs]. */
    fun releaseAt(windowEndMs: Long): Long = windowEndMs + MINUTE_MS

    /**
     * How to silence a notification. Snooze needs a finite window and a notification that
     * can sensibly come back later; permanent mute, ongoing/foreground notifications and
     * calls keep the cancel behaviour.
     */
    fun holdAction(shouldBlock: Boolean, canSnooze: Boolean, window: Pair<Long, Long>?, nowMs: Long): HoldAction {
        if (!shouldBlock) return HoldAction.Allow
        if (!canSnooze || window == null) return HoldAction.Cancel
        val release = releaseAt(window.second)
        if (release <= nowMs) return HoldAction.Cancel
        return HoldAction.Snooze(release, release - nowMs)
    }

    /**
     * What to do with a notification that is already snoozed after the rules changed.
     * [stillBlocked] is the current decision for its app; [window] is the window around now.
     */
    fun reconcileHeld(currentReleaseAtMs: Long, stillBlocked: Boolean, window: Pair<Long, Long>?, nowMs: Long): HeldAction {
        if (!stillBlocked) return HeldAction.Release
        if (window == null) return HeldAction.Cancel
        val release = releaseAt(window.second)
        if (release <= nowMs) return HeldAction.Release
        if (release == currentReleaseAtMs) return HeldAction.Keep
        return HeldAction.Resnooze(release, release - nowMs)
    }

    /** When the digest alarm should fire for the earliest pending window, or null for none. */
    fun alarmTime(earliestDueMs: Long?, nowMs: Long): Long? {
        if (earliestDueMs == null) return null
        return maxOf(earliestDueMs, nowMs) + SETTLE_MS
    }

    /**
     * Returns a later time to post at when another window ends within [COMBINE_MS], so
     * windows ending close together produce one notification; null to post now.
     */
    fun combineDelay(oldestDueMs: Long, nextPendingDueMs: Long?, nowMs: Long): Long? {
        if (nextPendingDueMs == null) return null
        if (nextPendingDueMs - nowMs > COMBINE_MS) return null
        if (nowMs - oldestDueMs >= MAX_COMBINE_WAIT_MS) return null
        return nextPendingDueMs + SETTLE_MS
    }

    data class AppCount(val appName: String, val count: Int)
    data class DigestText(val title: String, val body: String, val publicTitle: String)

    /** Notification wording; app names and counts only. Null when there is nothing to report. */
    fun digestText(counts: List<AppCount>): DigestText? {
        val merged = counts.filter { it.count > 0 }
            .groupBy { it.appName }
            .map { (name, items) -> AppCount(name, items.sumOf { it.count }) }
            .sortedWith(compareByDescending<AppCount> { it.count }.thenBy { it.appName.lowercase() })
        if (merged.isEmpty()) return null
        val total = merged.sumOf { it.count }
        val publicTitle = "Quiet hours ended · $total ${plural(total)}"
        if (merged.size == 1) {
            val only = merged.first()
            return DigestText(
                title = "${only.appName} quiet hours ended",
                body = if (total == 1) "1 notification is back" else "$total notifications are back",
                publicTitle = publicTitle
            )
        }
        return DigestText(
            title = "Quiet hours ended",
            body = merged.joinToString(" · ") { "${it.appName} ${it.count}" },
            publicTitle = publicTitle
        )
    }

    private fun plural(count: Int) = if (count == 1) "notification" else "notifications"
}
