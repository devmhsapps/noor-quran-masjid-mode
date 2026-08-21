package com.devmhs.noor_quran_masjid_mode

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale

class MasjidModeService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var restoreTask: Runnable? = null

    private val preferences
        get() = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private val notificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        when (intent?.action) {
            ACTION_CANCEL -> restoreAndStop(false)
            ACTION_FINISH -> restoreAndStop(true)
            else -> scheduleRestore()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        restoreTask?.let(handler::removeCallbacks)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun scheduleRestore() {
        restoreTask?.let(handler::removeCallbacks)
        if (!preferences.getBoolean(KEY_ACTIVE, false)) {
            stopSelf()
            return
        }
        val delay = (preferences.getLong(KEY_ENDS_AT, 0L) - System.currentTimeMillis()).coerceAtLeast(0L)
        restoreTask = Runnable { restoreAndStop(true) }
        handler.postDelayed(restoreTask!!, delay)
    }

    private fun restoreAndStop(announce: Boolean) {
        restorePreviousMode(announce)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun restorePreviousMode(announce: Boolean) {
        val wasActive = preferences.getBoolean(KEY_ACTIVE, false)
        if (wasActive && notificationManager.isNotificationPolicyAccessGranted) {
            notificationManager.setInterruptionFilter(preferences.getInt(KEY_PREVIOUS_FILTER, NotificationManager.INTERRUPTION_FILTER_ALL))
        }
        MasjidModeScheduler.cancel(this)
        preferences.edit().clear().apply()
        if (wasActive && announce) speakCompletion()
    }

    private fun speakCompletion() {
        val recordedVoice = resources.getIdentifier("masjid_mode_completion", "raw", packageName)
        if (recordedVoice != 0) {
            val player = MediaPlayer.create(this, recordedVoice)
            player.setOnCompletionListener { completedPlayer -> completedPlayer.release() }
            player.setOnErrorListener { failedPlayer, _, _ ->
                failedPlayer.release()
                speakWithSystemVoice()
                true
            }
            player.start()
            return
        }
        speakWithSystemVoice()
    }

    private fun speakWithSystemVoice() {
        lateinit var speaker: TextToSpeech
        speaker = TextToSpeech(applicationContext) { state ->
            if (state != TextToSpeech.SUCCESS) return@TextToSpeech
            val iraqiArabic = Locale("ar", "IQ")
            val languageState = speaker.setLanguage(iraqiArabic)
            if (languageState == TextToSpeech.LANG_MISSING_DATA || languageState == TextToSpeech.LANG_NOT_SUPPORTED) speaker.language = Locale("ar")
            speaker.setSpeechRate(0.88f)
            speaker.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit
                override fun onDone(utteranceId: String?) = speaker.shutdown()
                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) = speaker.shutdown()
            })
            speaker.speak("تم إيقاف الوضع الصامت. تقبل الله صلاتكم.", TextToSpeech.QUEUE_FLUSH, null, "masjid_mode_finished")
        }
    }

    private fun buildNotification(): Notification {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            notificationManager.createNotificationChannel(NotificationChannel(CHANNEL_ID, "وضع الجامع", NotificationManager.IMPORTANCE_LOW))
            return Notification.Builder(this, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
                .setContentTitle("وضع الجامع مفعّل")
                .setContentText("سيعود الهاتف إلى وضعه السابق تلقائياً عند انتهاء الوقت.")
                .setOngoing(true)
                .build()
        }
        @Suppress("DEPRECATION")
        return Notification.Builder(this)
            .setSmallIcon(android.R.drawable.ic_lock_silent_mode)
            .setContentTitle("وضع الجامع مفعّل")
            .setContentText("سيعود الهاتف إلى وضعه السابق تلقائياً عند انتهاء الوقت.")
            .setOngoing(true)
            .build()
    }

    companion object {
        const val PREFERENCES_NAME = "masjid_mode"
        const val KEY_ACTIVE = "active"
        const val KEY_ENDS_AT = "ends_at"
        const val KEY_PREVIOUS_FILTER = "previous_filter"
        const val MAX_DURATION_SECONDS = 24 * 60 * 60
        const val ACTION_START = "com.devmhs.noor_quran.START"
        const val ACTION_CANCEL = "com.devmhs.noor_quran.CANCEL"
        const val ACTION_FINISH = "com.devmhs.noor_quran.FINISH"
        private const val CHANNEL_ID = "masjid_mode"
        private const val NOTIFICATION_ID = 704

        fun start(context: Context, action: String) {
            val intent = Intent(context, MasjidModeService::class.java).setAction(action)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
