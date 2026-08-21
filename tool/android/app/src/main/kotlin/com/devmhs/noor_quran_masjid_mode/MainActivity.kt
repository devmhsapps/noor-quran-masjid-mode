package com.devmhs.noor_quran_masjid_mode

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
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
            "requestExactAlarmAccess" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                }
                result.success(null)
            }
            "requestBatteryOptimizationAccess" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !isBatteryUnrestricted()) {
                    startActivity(Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:$packageName")))
                }
                result.success(null)
            }
            "start" -> {
                if (!notificationManager.isNotificationPolicyAccessGranted) {
                    result.error("DND_ACCESS_REQUIRED", "Notification policy access was not granted", null)
                    return
                }
                if (!MasjidModeScheduler.canScheduleExactAlarm(this)) {
                    result.error("EXACT_ALARM_ACCESS_REQUIRED", "Exact alarm access was not granted", null)
                    return
                }
                if (!isBatteryUnrestricted()) {
                    result.error("BATTERY_ACCESS_REQUIRED", "Battery optimization is still enabled", null)
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
                MasjidModeScheduler.schedule(this, endsAt)
                MasjidModeService.start(this, MasjidModeService.ACTION_START)
                result.success(statusPayload())
            }
            "cancel" -> {
                MasjidModeService.start(this, MasjidModeService.ACTION_CANCEL)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun restoreIfExpired() {
        if (!preferences.getBoolean(MasjidModeService.KEY_ACTIVE, false)) return
        if (preferences.getLong(MasjidModeService.KEY_ENDS_AT, 0L) > System.currentTimeMillis()) return
        if (notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(preferences.getInt(MasjidModeService.KEY_PREVIOUS_FILTER, NotificationManager.INTERRUPTION_FILTER_ALL))
        }
        MasjidModeScheduler.cancel(this)
        preferences.edit().clear().apply()
    }

    private fun isBatteryUnrestricted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val manager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return manager.isIgnoringBatteryOptimizations(packageName)
    }

    private fun statusPayload(): Map<String, Any?> {
        val active = preferences.getBoolean(MasjidModeService.KEY_ACTIVE, false)
        return mapOf(
            "active" to active,
            "dndAccessGranted" to notificationManager.isNotificationPolicyAccessGranted,
            "exactAlarmGranted" to MasjidModeScheduler.canScheduleExactAlarm(this),
            "batteryUnrestricted" to isBatteryUnrestricted(),
            "endsAt" to if (active) preferences.getLong(MasjidModeService.KEY_ENDS_AT, 0L) else null,
        )
    }
}
