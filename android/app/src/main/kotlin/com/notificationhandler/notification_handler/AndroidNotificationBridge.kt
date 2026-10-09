package com.notificationhandler.notification_handler

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class AndroidNotificationBridge(
    private val context: Context,
    channel: MethodChannel
) : MethodChannel.MethodCallHandler {

    private val scheduleStore = NativeScheduleStore(context)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPlatformSupported" -> {
                result.success(true)
            }
            "isNotificationAccessGranted" -> {
                val enabledListeners = NotificationManagerCompat.getEnabledListenerPackages(context)
                val granted = enabledListeners.contains(context.packageName)
                result.success(granted)
            }
            "openNotificationAccessSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SETTINGS_ERROR", "Could not open notification listener settings", e.message)
                }
            }
            "openAppDetailsSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = android.net.Uri.fromParts("package", context.packageName, null)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("SETTINGS_ERROR", "Could not open app details settings", e.message)
                }
            }
            "getInstalledApplications" -> {
                executor.execute {
                    try {
                        val apps = loadInstalledApplications()
                        mainHandler.post {
                            result.success(apps)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("QUERY_ERROR", "Failed to retrieve installed apps", e.message)
                        }
                    }
                }
            }
            "syncSchedules" -> {
                val payload = call.argument<String>("payload")
                if (payload != null) {
                    scheduleStore.savePayload(payload)
                }
                result.success(null)
            }
            "exportBackupFile" -> {
                val fileName = call.argument<String>("fileName") ?: "notiflow_backup.notiflow"
                val content = call.argument<String>("content") ?: ""
                try {
                    val exportDir = context.getExternalFilesDir(null) ?: context.filesDir
                    val file = java.io.File(exportDir, fileName)
                    file.writeText(content)

                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        type = "application/json"
                        putExtra(Intent.EXTRA_SUBJECT, "Notiflow Rules Backup ($fileName)")
                        putExtra(Intent.EXTRA_TEXT, content)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    val chooser = Intent.createChooser(shareIntent, "Export .notiflow Rules Backup").apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                    context.startActivity(chooser)
                    result.success(file.absolutePath)
                } catch (e: Exception) {
                    result.error("EXPORT_ERROR", "Failed to export rules backup: ${e.message}", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun loadInstalledApplications(): List<Map<String, Any?>> {
        val pm = context.packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val resolveInfos = pm.queryIntentActivities(mainIntent, 0)
        val list = mutableListOf<Map<String, Any?>>()
        val seenPackages = mutableSetOf<String>()

        for (info in resolveInfos) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == context.packageName || seenPackages.contains(pkg)) continue
            seenPackages.add(pkg)

            val appName = info.loadLabel(pm).toString()
            val iconDrawable = info.loadIcon(pm)
            val iconBytes = drawableToByteArray(iconDrawable)
            val isSystem = (info.activityInfo.applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            list.add(
                mapOf(
                    "packageName" to pkg,
                    "displayName" to appName,
                    "iconBytes" to iconBytes,
                    "isSystemApp" to isSystem
                )
            )
        }

        // Sort alphabetically by app name
        return list.sortedBy { (it["displayName"] as? String)?.lowercase() ?: "" }
    }

    private fun drawableToByteArray(drawable: Drawable?): ByteArray? {
        if (drawable == null) return null
        return try {
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val width = if (drawable.intrinsicWidth > 0) drawable.intrinsicWidth else 96
                    val height = if (drawable.intrinsicHeight > 0) drawable.intrinsicHeight else 96
                    val bmp = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }
            val stream = ByteArrayOutputStream()
            // Compress down to 96x96 if too large to avoid method channel buffer overhead
            val scaledBitmap = if (bitmap.width > 128 || bitmap.height > 128) {
                Bitmap.createScaledBitmap(bitmap, 96, 96, true)
            } else {
                bitmap
            }
            scaledBitmap.compress(Bitmap.CompressFormat.PNG, 90, stream)
            stream.toByteArray()
        } catch (e: Exception) {
            null
        }
    }
}
