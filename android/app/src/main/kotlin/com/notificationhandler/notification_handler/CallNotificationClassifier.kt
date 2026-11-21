package com.notificationhandler.notification_handler

// Call metadata does not identify every VoIP call; leave recognized call-like notifications alone.
internal fun isCallNotification(category: String, hasCallType: Boolean): Boolean =
    hasCallType || category.equals("call", ignoreCase = true) ||
        category.equals("android.category.call", ignoreCase = true)
