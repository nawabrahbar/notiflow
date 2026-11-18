package com.notificationhandler.notification_handler

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.notificationhandler/bridge"
    private var bridge: AndroidNotificationBridge? = null
    private var pendingDigestOpen = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        bridge = AndroidNotificationBridge(applicationContext, channel, this)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        AppThemePrefs.applyWindowBackground(this)
        handleDigestIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDigestIntent(intent)
    }

    /** A tapped catch-up notification opens Activity -> Digest and marks its windows reviewed. */
    private fun handleDigestIntent(intent: Intent?) {
        if (intent?.action != DigestNotifier.ACTION_OPEN_DIGEST) return
        DigestNotifier.markReviewed(applicationContext, intent.getLongArrayExtra(DigestNotifier.EXTRA_WINDOW_IDS))
        intent.action = Intent.ACTION_MAIN
        pendingDigestOpen = true
        bridge?.notifyOpenDigest()
    }

    fun consumePendingDigestOpen(): Boolean {
        val pending = pendingDigestOpen
        pendingDigestOpen = false
        return pending
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (bridge?.handleActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        if (bridge?.handlePermissionResult(requestCode) == true) return
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
