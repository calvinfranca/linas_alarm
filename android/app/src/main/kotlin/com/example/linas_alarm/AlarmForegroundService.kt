package com.example.linas_alarm.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.linas_alarm.MainActivity
import com.example.linas_alarm.R
import android.util.Log

class AlarmForegroundService : Service() {

    private var player: MediaPlayer? = null
    private val channelId = "alarm_channel"
    private val notifId = 9001

    companion object {
        private const val ACTION_STOP = "STOP_ALARM"
        private const val ACTION_SNOOZE_5 = "SNOOZE_5"

        private const val EXTRA_LABEL = "label"
        private const val EXTRA_GROUP_ID = "groupId"
        private const val EXTRA_PATHS_JSON = "pathsJson"
        private const val EXTRA_ALARM_ID = "alarmId"

        private const val EXTRA_REPEAT_DAYS_MASK = "repeatDaysMask"
        private const val EXTRA_HOUR = "hour"
        private const val EXTRA_MINUTE = "minute"
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        // Actions from notification buttons
        when (intent?.action) {
            ACTION_STOP -> {
                stopAlarm()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }

            ACTION_SNOOZE_5 -> {
                val alarmId = intent.getIntExtra(EXTRA_ALARM_ID, -1)
                val label = intent.getStringExtra(EXTRA_LABEL) ?: "Alarme"
                val groupId = intent.getStringExtra(EXTRA_GROUP_ID) ?: ""
                val pathsJson = intent.getStringExtra(EXTRA_PATHS_JSON) ?: "[]"

                val repeatDaysMask = intent.getIntExtra(EXTRA_REPEAT_DAYS_MASK, 0)
                val hour = intent.getIntExtra(EXTRA_HOUR, -1)
                val minute = intent.getIntExtra(EXTRA_MINUTE, -1)

                if (alarmId != -1) {
                    AlarmScheduler.schedule(
                        context = this,
                        alarmId = alarmId,
                        triggerAtMillis = System.currentTimeMillis() + 5 * 60 * 1000L,
                        label = label,
                        groupId = groupId,
                        pathsJson = pathsJson,
                        repeatDaysMask = repeatDaysMask,
                        hour = hour,
                        minute = minute
                    )
                }

                stopAlarm()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                return START_NOT_STICKY
            }
        }

        // Normal alarm trigger
        val label = intent?.getStringExtra(EXTRA_LABEL) ?: "Alarme"
        val groupId = intent?.getStringExtra(EXTRA_GROUP_ID) ?: ""
        val pathsJson = intent?.getStringExtra(EXTRA_PATHS_JSON) ?: "[]"
        val alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, -1) ?: -1

        val repeatDaysMask = intent?.getIntExtra(EXTRA_REPEAT_DAYS_MASK, 0) ?: 0
        val hour = intent?.getIntExtra(EXTRA_HOUR, -1) ?: -1
        val minute = intent?.getIntExtra(EXTRA_MINUTE, -1) ?: -1

        val pickedPath = AlarmStorage.pickNextNoRepeat(this, groupId, pathsJson)
        val locked = isDeviceLocked()

        Log.d(
            "ALARM_DEBUG",
            "onStartCommand locked=$locked alarmId=$alarmId label=$label repeatDaysMask=$repeatDaysMask hour=$hour minute=$minute"
        )

        // Important on Android 12+: must call startForeground quickly, always
        val notif: Notification = if (locked) {
            buildNotificationMinimal(
                title = label,
                body = pickedPath ?: "Grupo sem músicas",
                alarmId = alarmId,
                groupId = groupId,
                pathsJson = pathsJson,
                repeatDaysMask = repeatDaysMask,
                hour = hour,
                minute = minute
            )
        } else {
            buildNotificationHeadsUp(
                title = label,
                body = pickedPath ?: "Grupo sem músicas",
                alarmId = alarmId,
                groupId = groupId,
                pathsJson = pathsJson,
                repeatDaysMask = repeatDaysMask,
                hour = hour,
                minute = minute
            )
        }

        startForeground(notifId, notif)

        // If no music, stop right away. The UI (if locked) is handled by fullScreenIntent.
        if (pickedPath == null) {
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        // Volume is controlled by system slider set from Flutter
        setAlarmVolumeFromSystem()

        // Play sound
        startAlarmSound(pickedPath)

        return START_STICKY
    }

    private fun startAlarmSound(path: String) {
        stopAlarm()

        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        player = MediaPlayer().apply {
            setAudioAttributes(attrs)
            isLooping = true

            if (path.startsWith("content://")) {
                setDataSource(this@AlarmForegroundService, Uri.parse(path))
            } else {
                setDataSource(path)
            }

            prepare()
            start()
        }
    }

    private fun stopAlarm() {
        player?.run {
            try { stop() } catch (_: Exception) {}
            try { release() } catch (_: Exception) {}
        }
        player = null
    }

    private fun setAlarmVolumeFromSystem() {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        am.mode = AudioManager.MODE_NORMAL
    }

    private fun isDeviceLocked(): Boolean {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            km.isDeviceLocked
        } else {
            @Suppress("DEPRECATION")
            km.isKeyguardLocked
        }
    }

    private fun buildNotificationMinimal(
        title: String,
        body: String,
        alarmId: Int,
        groupId: String,
        pathsJson: String,
        repeatDaysMask: Int,
        hour: Int,
        minute: Int
    ): Notification {

        val fullIntent = Intent(this, AlarmActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(EXTRA_LABEL, title)
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_GROUP_ID, groupId)
            putExtra(EXTRA_PATHS_JSON, pathsJson)

            putExtra(EXTRA_REPEAT_DAYS_MASK, repeatDaysMask)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }

        val fullPending = PendingIntent.getActivity(
            this,
            2001,
            fullIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopPending = buildStopPending(
            alarmId = alarmId,
            label = title,
            groupId = groupId,
            pathsJson = pathsJson,
            repeatDaysMask = repeatDaysMask,
            hour = hour,
            minute = minute
        )

        Log.d("ALARM_DEBUG", "building minimal notification with fullScreenIntent alarmId=$alarmId")

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("⏰ $title")
            .setContentText("Tocando: $body")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(fullPending)
            .setFullScreenIntent(fullPending, true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .addAction(0, "PARAR", stopPending)
            .build()
    }

    private fun buildNotificationHeadsUp(
        title: String,
        body: String,
        alarmId: Int,
        groupId: String,
        pathsJson: String,
        repeatDaysMask: Int,
        hour: Int,
        minute: Int
    ): Notification {

        val openIntent = Intent(this, MainActivity::class.java)
        val openPending = PendingIntent.getActivity(
            this,
            1003,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopPending = buildStopPending(
            alarmId = alarmId,
            label = title,
            groupId = groupId,
            pathsJson = pathsJson,
            repeatDaysMask = repeatDaysMask,
            hour = hour,
            minute = minute
        )

        val snoozePending = buildSnoozePending(
            alarmId = alarmId,
            label = title,
            groupId = groupId,
            pathsJson = pathsJson,
            repeatDaysMask = repeatDaysMask,
            hour = hour,
            minute = minute
        )

        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("⏰ $title")
            .setContentText("Tocando: $body")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setContentIntent(openPending)
            .addAction(0, "SONECA 5", snoozePending)
            .addAction(0, "PARAR", stopPending)
            .build()
    }

    private fun buildStopPending(
        alarmId: Int,
        label: String,
        groupId: String,
        pathsJson: String,
        repeatDaysMask: Int,
        hour: Int,
        minute: Int
    ): PendingIntent {
        val stopIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = ACTION_STOP
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_LABEL, label)
            putExtra(EXTRA_GROUP_ID, groupId)
            putExtra(EXTRA_PATHS_JSON, pathsJson)

            putExtra(EXTRA_REPEAT_DAYS_MASK, repeatDaysMask)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }
        return PendingIntent.getService(
            this,
            1001,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun buildSnoozePending(
        alarmId: Int,
        label: String,
        groupId: String,
        pathsJson: String,
        repeatDaysMask: Int,
        hour: Int,
        minute: Int
    ): PendingIntent {
        val snoozeIntent = Intent(this, AlarmForegroundService::class.java).apply {
            action = ACTION_SNOOZE_5
            putExtra(EXTRA_ALARM_ID, alarmId)
            putExtra(EXTRA_LABEL, label)
            putExtra(EXTRA_GROUP_ID, groupId)
            putExtra(EXTRA_PATHS_JSON, pathsJson)

            putExtra(EXTRA_REPEAT_DAYS_MASK, repeatDaysMask)
            putExtra(EXTRA_HOUR, hour)
            putExtra(EXTRA_MINUTE, minute)
        }
        return PendingIntent.getService(
            this,
            1002,
            snoozeIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Alarmes",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarmes ativos"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }

            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        stopAlarm()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
