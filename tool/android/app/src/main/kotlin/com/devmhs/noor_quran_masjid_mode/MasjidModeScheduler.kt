package com.devmhs.noor_quran_masjid_mode

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object MasjidModeScheduler {
    private const val REQUEST_CODE = 4906

    private fun pendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, MasjidAlarmReceiver::class.java).setAction(MasjidAlarmReceiver.ACTION_FINISH)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    fun canScheduleExactAlarm(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return manager.canScheduleExactAlarms()
    }

    fun schedule(context: Context, endsAt: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val alarm = pendingIntent(context)
        manager.cancel(alarm)
        manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, endsAt, alarm)
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(context))
    }
}
