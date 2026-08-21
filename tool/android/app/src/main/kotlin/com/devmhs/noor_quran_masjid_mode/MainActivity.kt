package com.devmhs.noor_quran_masjid_mode

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.devmhs.noor_quran/masjid_mode"

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val preferences
        get() = getSharedPreferences(MasjidModeService.PREFERENCES_NAME, Context.MODE_PRIVATE)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                restoreIfExpired()
                result.success(statusPayload())
            }
            "requestDndAccess" -> {
                startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                result.success(null)
            }
            "start" -> {
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    result.error("DND_ACCESS_REQUIRED", "Notification policy access was not granted", null)
                    return
                }
                val requested = call.argument<Int>("seconds") ?: 0
                if (requested !in 1..MasjidModeService.MAX_DURATION_SECONDS) {
                    result.error("INVALID_DURATION", "Duration must be between 1 second and 24 hours", null)
                    return
                }
                val endsAt = System.currentTimeMillis() + requested * 1000L
                preferences.edit()
                    .putBoolean(MasjidModeService.KEY_ACTIVE, true)
                    .putLong(MasjidModeService.KEY_ENDS_AT, endsAt)
                    .putInt(MasjidModeService.KEY_PREVIOUS_FILTER, notificationManager.currentInterruptionFilter)
                    .apply()
                notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
                startModeService(MasjidModeService.ACTION_START)
                result.success(statusPayload())
            }
            "cancel" -> {
                startModeService(MasjidModeService.ACTION_CANCEL)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startModeService(action: String) {
        val intent = Intent(this, MasjidModeService::class.java).setAction(action)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
    }

    private fun restoreIfExpired() {
        if (!preferences.getBoolean(MasjidModeService.KEY_ACTIVE, false)) return
        if (preferences.getLong(MasjidModeService.KEY_ENDS_AT, 0L) > System.currentTimeMillis()) return
        if (notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(preferences.getInt(MasjidModeService.KEY_PREVIOUS_FILTER, NotificationManager.INTERRUPTION_FILTER_ALL))
        }
        preferences.edit().clear().apply()
    }

    private fun statusPayload(): Map<String, Any?> {
        val active = preferences.getBoolean(MasjidModeService.KEY_ACTIVE, false)
        return mapOf(
            "active" to active,
            "dndAccessGranted" to notificationManager.isNotificationPolicyAccessGranted,
            "endsAt" to if (active) preferences.getLong(MasjidModeService.KEY_ENDS_AT, 0L) else null,
        )
    }
}
