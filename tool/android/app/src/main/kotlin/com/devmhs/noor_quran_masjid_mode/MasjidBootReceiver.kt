package com.devmhs.noor_quran_masjid_mode

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MasjidBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val preferences = context.getSharedPreferences(MasjidModeService.PREFERENCES_NAME, Context.MODE_PRIVATE)
        val endsAt = preferences.getLong(MasjidModeService.KEY_ENDS_AT, 0L)
        if (preferences.getBoolean(MasjidModeService.KEY_ACTIVE, false) && endsAt > System.currentTimeMillis() && MasjidModeScheduler.canScheduleExactAlarm(context)) {
            MasjidModeScheduler.schedule(context, endsAt)
        }
    }
}
