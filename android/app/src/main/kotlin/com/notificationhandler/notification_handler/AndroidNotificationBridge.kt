package com.notificationhandler.notification_handler

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

class AndroidNotificationBridge(
    private val context: Context,
    channel: MethodChannel,
    private val activity: Activity? = null
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val REQUEST_CODE_PICK_BACKUP = 9104
        private const val REQUEST_CODE_EXPORT_BACKUP = 9105
    }

    private val scheduleStore = NativeScheduleStore(context)
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportContent: String? = null
    private var pendingExportFileName: String? = null
    private var permissionWatcherRunnable: Runnable? = null

    init {
        channel.setMethodCallHandler(this)
        NativeScheduleStore.onActivityUpdatedListener = {
            mainHandler.post {
                try {
                    channel.invokeMethod("onActivityUpdated", null)
                } catch (_: Exception) {
                }
            }
        }
    }

    private fun startPermissionGrantWatcher() {
        permissionWatcherRunnable?.let { mainHandler.removeCallbacks(it) }
        val alreadyGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)
        if (alreadyGranted) return

        var attempts = 0
        val runnable = object : Runnable {
            override fun run() {
                attempts++
                val granted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(context.packageName)
                if (granted) {
                    permissionWatcherRunnable = null
                    try {
                        val returnIntent = Intent(context, MainActivity::class.java).apply {
                            addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                            )
                        }
                        context.startActivity(returnIntent)
                    } catch (_: Exception) {
                    }
                    return
                }
                if (attempts < 150) {
                    mainHandler.postDelayed(this, 400L)
                } else {
                    permissionWatcherRunnable = null
                }
            }
        }
        permissionWatcherRunnable = runnable
        mainHandler.postDelayed(runnable, 500L)
    }

    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_PICK_BACKUP -> {
                val pending = pendingPickResult
                pendingPickResult = null
                if (pending == null) return true

                if (resultCode == Activity.RESULT_OK && data?.data != null) {
                    try {
                        val uri = data.data!!
                        val content = context.contentResolver
                            .openInputStream(uri)
                            ?.bufferedReader(Charsets.UTF_8)
                            ?.use { it.readText() }
                        pending.success(content)
                    } catch (e: Exception) {
                        pending.error("PICK_ERROR", "Failed to read selected backup file: ${e.message}", null)
                    }
                } else {
                    pending.success(null)
                }
                return true
            }
            REQUEST_CODE_EXPORT_BACKUP -> {
                val pending = pendingExportResult
                val contentToWrite = pendingExportContent
                val fallbackFileName = pendingExportFileName ?: "notiflow_backup.notiflow"
                pendingExportResult = null
                pendingExportContent = null
                pendingExportFileName = null
                if (pending == null) return true

                if (resultCode == Activity.RESULT_OK && data?.data != null && contentToWrite != null) {
                    try {
                        val uri = data.data!!
                        val outStream = try {
                            context.contentResolver.openOutputStream(uri, "wt")
                        } catch (_: Exception) {
                            context.contentResolver.openOutputStream(uri)
                        }
                        if (outStream == null) {
                            pending.error("EXPORT_ERROR", "Unable to open output stream for selected file", null)
                            return true
                        }
                        outStream.use { stream ->
                            stream.write(contentToWrite.toByteArray(Charsets.UTF_8))
                            stream.flush()
                        }

                        var displayName = fallbackFileName
                        try {
                            context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                                ?.use { cursor ->
                                    if (cursor.moveToFirst()) {
                                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                                        if (idx >= 0) {
                                            val resolved = cursor.getString(idx)
                                            if (!resolved.isNullOrBlank()) {
                                                displayName = resolved
                                            }
                                        }
                                    }
                                }
                        } catch (_: Exception) {
                        }
                        pending.success(displayName)
                    } catch (e: Exception) {
                        pending.error("EXPORT_ERROR", "Failed to save backup file: ${e.message}", null)
                    }
                } else {
                    pending.success(null)
                }
                return true
            }
            else -> return false
        }
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
                    startPermissionGrantWatcher()
                    var launchedDetail = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val componentName = ComponentName(
                                context,
                                NotificationHandlerListenerService::class.java
                            )
                            val detailIntent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS).apply {
                                putExtra(
                                    Settings.EXTRA_NOTIFICATION_LISTENER_COMPONENT_NAME,
                                    componentName.flattenToString()
                                )
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            context.startActivity(detailIntent)
                            launchedDetail = true
                        } catch (_: Exception) {
                            launchedDetail = false
                        }
                    }
                    if (!launchedDetail) {
                        val fallbackIntent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        context.startActivity(fallbackIntent)
                    }
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
                val hostActivity = activity
                if (hostActivity != null) {
                    try {
                        pendingExportResult = result
                        pendingExportContent = content
                        pendingExportFileName = fileName
                        val createIntent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, fileName)
                        }
                        hostActivity.startActivityForResult(createIntent, REQUEST_CODE_EXPORT_BACKUP)
                    } catch (e: Exception) {
                        pendingExportResult = null
                        pendingExportContent = null
                        pendingExportFileName = null
                        result.error("EXPORT_ERROR", "Failed to open file save dialog: ${e.message}", null)
                    }
                } else {
                    try {
                        val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                            ?: context.getExternalFilesDir(null)
                            ?: context.filesDir
                        if (!downloadsDir.exists()) {
                            downloadsDir.mkdirs()
                        }
                        val file = java.io.File(downloadsDir, fileName)
                        file.writeText(content, Charsets.UTF_8)
                        result.success(file.absolutePath)
                    } catch (e: Exception) {
                        result.error("EXPORT_ERROR", "Failed to export rules backup: ${e.message}", null)
                    }
                }
            }
            "pickBackupFile" -> {
                val hostActivity = activity
                if (hostActivity != null) {
                    try {
                        pendingPickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }
                        hostActivity.startActivityForResult(intent, REQUEST_CODE_PICK_BACKUP)
                    } catch (e: Exception) {
                        pendingPickResult = null
                        result.error("PICK_ERROR", "Could not open document picker: ${e.message}", null)
                    }
                } else {
                    result.success(null)
                }
            }
            "getActivityLog" -> {
                result.success(scheduleStore.getActivityLogJson())
            }
            "clearActivityLog" -> {
                scheduleStore.clearActivityLog()
                result.success(null)
            }
            "openApp" -> {
                val pkg = call.argument<String>("packageName")
                if (pkg.isNullOrBlank()) {
                    result.success(false)
                    return
                }
                try {
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(pkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        context.startActivity(launchIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (_: Exception) {
                    result.success(false)
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
