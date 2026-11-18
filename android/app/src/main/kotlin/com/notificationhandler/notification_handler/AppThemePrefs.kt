package com.notificationhandler.notification_handler

import android.app.Activity
import android.content.Context
import android.content.res.Resources
import android.graphics.drawable.ColorDrawable
import android.os.Build

/**
 * Keeps the launch screen in step with Notiflow's own light/dark toggle (not the phone's).
 * The launcher icon is always the light design.
 */
object AppThemePrefs {
    const val LIGHT = "light"
    const val DARK = "dark"
    const val SYSTEM = "system"
    private const val PREFS = "notiflow_theme"
    private const val KEY_MODE = "mode"

    fun mode(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_MODE, SYSTEM) ?: SYSTEM

    fun setMode(context: Context, activity: Activity?, mode: String) {
        val value = if (mode == LIGHT || mode == DARK) mode else SYSTEM
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_MODE, value).apply()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && activity != null) {
            // Android remembers this theme for the next launches of the app.
            val theme = when (value) {
                LIGHT -> R.style.SplashTheme_Light
                DARK -> R.style.SplashTheme_Dark
                else -> Resources.ID_NULL
            }
            try {
                activity.splashScreen.setSplashScreenTheme(theme)
            } catch (_: Exception) {
            }
        }
    }

    /** Window colour shown between the launch screen and Flutter's first frame. */
    fun applyWindowBackground(activity: Activity) {
        val color = when (mode(activity)) {
            LIGHT -> R.color.splash_background_light
            DARK -> R.color.splash_background_dark
            else -> return
        }
        activity.window.setBackgroundDrawable(ColorDrawable(activity.getColor(color)))
    }
}
