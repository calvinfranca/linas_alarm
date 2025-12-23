package com.example.linas_alarm.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent

object AlarmScheduler {

    fun schedule(
        context: Context,
        alarmId: Int,
        triggerAtMillis: Long,
        label: String,
        groupId: String,
        pathsJson: String,
        repeatDaysMask: Int = 0,
        hour: Int = -1,
        minute: Int = -1
    ) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        val intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra("label", label)
            putExtra("groupId", groupId)
            putExtra("pathsJson", pathsJson)
            putExtra("alarmId", alarmId)

            putExtra("repeatDaysMask", repeatDaysMask)
            putExtra("hour", hour)
            putExtra("minute", minute)
        }

        val pi = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        am.setExactAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            triggerAtMillis,
            pi
        )
    }

    fun cancel(context: Context, alarmId: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java)

        val pi = PendingIntent.getBroadcast(
            context,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        am.cancel(pi)
    }
}
