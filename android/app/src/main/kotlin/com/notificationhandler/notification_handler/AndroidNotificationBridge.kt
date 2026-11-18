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
        private const val REQUEST_CODE_POST_NOTIFICATIONS = 9106
        private const val PERMISSION_PREFS = "notiflow_digest"
        private const val KEY_PERMISSION_ASKED_VERSION = "notification_permission_asked_version"
        private const val MAX_BACKUP_BYTES = 5 * 1024 * 1024L // 5 MB safety limit
    }

    private val scheduleStore = NativeScheduleStore(context)
    private val executor = Executors.newSingleThreadExecutor()
    // Icons and installed checks run separately so they never queue behind a full app scan.
    private val iconExecutor = Executors.newSingleThreadExecutor()
    // Activity log / digest reads stay off the main thread.
    private val dbExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingExportResult: MethodChannel.Result? = null
    private var pendingExportContent: String? = null
    private var pendingExportFileName: String? = null
    private var permissionWatcherRunnable: Runnable? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private val methodChannel = channel

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
                        var declaredSize = -1L
                        try {
                            context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)
                                ?.use { cursor ->
                                    if (cursor.moveToFirst()) {
                                        val idx = cursor.getColumnIndex(OpenableColumns.SIZE)
                                        if (idx >= 0 && !cursor.isNull(idx)) {
                                            declaredSize = cursor.getLong(idx)
                                        }
                                    }
                                }
                        } catch (_: Exception) {
                        }
                        if (declaredSize > MAX_BACKUP_BYTES) {
                            pending.error("PICK_ERROR", "Selected backup file exceeds the 5 MB limit.", null)
                            return true
                        }

                        val content = context.contentResolver.openInputStream(uri)?.use { stream ->
                            val out = ByteArrayOutputStream()
                            val buffer = ByteArray(8192)
                            var totalRead = 0L
                            var read: Int
                            while (stream.read(buffer).also { read = it } != -1) {
                                totalRead += read
                                if (totalRead > MAX_BACKUP_BYTES) {
                                    throw IllegalArgumentException("Selected backup file exceeds the 5 MB limit.")
                                }
                                out.write(buffer, 0, read)
                            }
                            out.toString(Charsets.UTF_8.name())
                        }
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

    /** Tells Flutter a digest notification was tapped; Flutter then consumes the pending open. */
    fun notifyOpenDigest() {
        mainHandler.post {
            try {
                methodChannel.invokeMethod("openDigest", null)
            } catch (_: Exception) {
            }
        }
    }

    private fun currentVersionCode(): Long = try {
        val info = context.packageManager.getPackageInfo(context.packageName, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else @Suppress("DEPRECATION") info.versionCode.toLong()
    } catch (_: Exception) {
        -1L
    }

    /**
     * Startup: asks once per install/update on Android 13+ when not granted.
     * Settings toggle: asks again while Android still shows the prompt, otherwise opens
     * the app's notification settings. Resolves with whether notifications can be posted.
     */
    private fun requestNotificationPermission(result: MethodChannel.Result, startupOnly: Boolean) {
        if (DigestNotifier.canPostNotifications(context)) {
            result.success(true)
            return
        }
        val prefs = context.getSharedPreferences(PERMISSION_PREFS, Context.MODE_PRIVATE)
        val act = activity
        val runtimePermission = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        val runtimeGranted = runtimePermission &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED

        if (startupOnly) {
            val version = currentVersionCode()
            if (!runtimePermission || runtimeGranted || act == null ||
                prefs.getLong(KEY_PERMISSION_ASKED_VERSION, Long.MIN_VALUE) == version
            ) {
                result.success(false)
                return
            }
            prefs.edit().putLong(KEY_PERMISSION_ASKED_VERSION, version).apply()
            launchPermissionPrompt(act, result)
            return
        }

        val canPrompt = runtimePermission && !runtimeGranted && act != null &&
            (!prefs.contains(KEY_PERMISSION_ASKED_VERSION) ||
                act.shouldShowRequestPermissionRationale(android.Manifest.permission.POST_NOTIFICATIONS))
        if (canPrompt && act != null) {
            prefs.edit().putLong(KEY_PERMISSION_ASKED_VERSION, currentVersionCode()).apply()
            launchPermissionPrompt(act, result)
            return
        }
        openAppNotificationSettings()
        result.success(false)
    }

    private fun launchPermissionPrompt(act: Activity, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || pendingPermissionResult != null) {
            result.success(false)
            return
        }
        pendingPermissionResult = result
        act.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE_POST_NOTIFICATIONS)
    }

    fun handlePermissionResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CODE_POST_NOTIFICATIONS) return false
        val pending = pendingPermissionResult
        pendingPermissionResult = null
        pending?.success(DigestNotifier.canPostNotifications(context))
        return true
    }

    private fun openAppNotificationSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(android.net.Uri.fromParts("package", context.packageName, null))
            }
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        } catch (_: Exception) {
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
            "getInstalledAppsLite" -> {
                executor.execute {
                    try {
                        val apps = loadInstalledApplications(withIcons = false)
                        mainHandler.post { result.success(apps) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("QUERY_ERROR", "Failed to retrieve installed apps", e.message)
                        }
                    }
                }
            }
            "getAppIcons" -> {
                val packages = call.argument<List<String>>("packageNames") ?: emptyList()
                iconExecutor.execute {
                    val icons = loadAppIcons(packages)
                    mainHandler.post { result.success(icons) }
                }
            }
            "getInstalledStatus" -> {
                val packages = call.argument<List<String>>("packageNames") ?: emptyList()
                iconExecutor.execute {
                    val status = packages.distinct().associateWith { isPackageInstalled(it) }
                    mainHandler.post { result.success(status) }
                }
            }
            "getChangedPackages" -> {
                val sequence = call.argument<Number>("sequenceNumber")?.toInt() ?: 0
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    result.success(null)
                } else {
                    try {
                        val changes = context.packageManager.getChangedPackages(sequence)
                        result.success(
                            mapOf(
                                "sequenceNumber" to (changes?.sequenceNumber ?: sequence),
                                "packageNames" to (changes?.packageNames ?: emptyList<String>())
                            )
                        )
                    } catch (_: Exception) {
                        result.success(null)
                    }
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
                    executor.execute {
                        scheduleStore.reconcileHeld(NotificationHandlerListenerService.controller)
                    }
                }
                result.success(null)
            }
            "getDigestSettings" -> {
                result.success(
                    mapOf(
                        "enabled" to DigestNotifier.isEnabled(context),
                        "permissionGranted" to DigestNotifier.canPostNotifications(context)
                    )
                )
            }
            "setDigestEnabled" -> {
                DigestNotifier.setEnabled(context, call.argument<Boolean>("enabled") ?: true)
                result.success(null)
            }
            "requestNotificationPermission" -> {
                requestNotificationPermission(result, startupOnly = false)
            }
            "requestNotificationPermissionOnStartup" -> {
                requestNotificationPermission(result, startupOnly = true)
            }
            "setAppThemeMode" -> {
                AppThemePrefs.setMode(context, activity, call.argument<String>("mode") ?: AppThemePrefs.SYSTEM)
                result.success(null)
            }
            "consumePendingDigestOpen" -> {
                result.success((activity as? MainActivity)?.consumePendingDigestOpen() ?: false)
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
                        val exportDir = context.getExternalFilesDir(null) ?: context.filesDir
                        if (!exportDir.exists()) {
                            exportDir.mkdirs()
                        }
                        val safeName = java.io.File(fileName).name.ifBlank { "notiflow_backup.notiflow" }
                        val file = java.io.File(exportDir, safeName)
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
                dbExecutor.execute {
                    val json = scheduleStore.getActivityLogJson()
                    mainHandler.post { result.success(json) }
                }
            }
            "getDigest" -> {
                dbExecutor.execute {
                    val json = scheduleStore.getDigestJson()
                    mainHandler.post { result.success(json) }
                }
            }
            "markDigestReviewed" -> {
                val ids = call.argument<List<Number>>("ids")?.map { it.toLong() } ?: emptyList()
                scheduleStore.markDigestReviewed(ids)
                result.success(null)
            }
            "deleteActivityEvents", "deleteDigestWindows" -> {
                val ids = call.argument<List<Any>>("ids")
                    ?.mapNotNull { (it as? Number)?.toLong() ?: it.toString().toLongOrNull() }
                    ?: emptyList()
                dbExecutor.execute {
                    if (call.method == "deleteActivityEvents") {
                        scheduleStore.deleteActivityEvents(ids)
                    } else {
                        scheduleStore.deleteDigestWindows(ids)
                    }
                    mainHandler.post { result.success(null) }
                }
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

    private fun loadInstalledApplications(withIcons: Boolean = true): List<Map<String, Any?>> {
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
            val iconBytes = if (withIcons) drawableToByteArray(info.loadIcon(pm)) else null
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

    /** Launcher icons for just the given packages; packages without an icon are left out. */
    private fun loadAppIcons(packages: List<String>): Map<String, ByteArray> {
        val pm = context.packageManager
        val icons = mutableMapOf<String, ByteArray>()
        for (pkg in packages.distinct()) {
            try {
                val component = pm.getLaunchIntentForPackage(pkg)?.component
                val drawable = if (component != null) pm.getActivityIcon(component) else pm.getApplicationIcon(pkg)
                drawableToByteArray(drawable)?.let { icons[pkg] = it }
            } catch (_: Exception) {
            }
        }
        return icons
    }

    private fun isPackageInstalled(pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (_: Exception) {
        false
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
