package com.devmhs.noor_quran_masjid_mode

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MasjidAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_FINISH) {
            MasjidModeService.start(context, MasjidModeService.ACTION_FINISH)
        }
    }

    companion object {
        const val ACTION_FINISH = "com.devmhs.noor_quran.FINISH"
    }
}
