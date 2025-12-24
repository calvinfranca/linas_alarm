package com.example.linas_alarm.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val label = intent.getStringExtra("label") ?: "Alarme"
        val groupId = intent.getStringExtra("groupId") ?: ""
        val pathsJson = intent.getStringExtra("pathsJson") ?: "[]"
        val alarmId = intent.getIntExtra("alarmId", -1)

        val repeatDaysMask = intent.getIntExtra("repeatDaysMask", 0)
        val hour = intent.getIntExtra("hour", -1)
        val minute = intent.getIntExtra("minute", -1)

        if (alarmId != -1 && repeatDaysMask != 0 && hour in 0..23 && minute in 0..59) {
            val nextTriggerAt = computeNextTriggerAtMillis(
                nowMillis = System.currentTimeMillis(),
                hour = hour,
                minute = minute,
                repeatDaysMask = repeatDaysMask
            )

            if (nextTriggerAt != null) {
                AlarmScheduler.schedule(
                    context = context,
                    alarmId = alarmId,
                    triggerAtMillis = nextTriggerAt,
                    label = label,
                    groupId = groupId,
                    pathsJson = pathsJson,
                    repeatDaysMask = repeatDaysMask,
                    hour = hour,
                    minute = minute
                )
            }
        }

        val svc = Intent(context, AlarmForegroundService::class.java).apply {
            putExtra("label", label)
            putExtra("groupId", groupId)
            putExtra("pathsJson", pathsJson)
            putExtra("alarmId", alarmId)

            // Repassa para o service (notificação/soneca precisa disso)
            putExtra("repeatDaysMask", repeatDaysMask)
            putExtra("hour", hour)
            putExtra("minute", minute)
        }

        ContextCompat.startForegroundService(context, svc)
    }

    private fun computeNextTriggerAtMillis(
        nowMillis: Long,
        hour: Int,
        minute: Int,
        repeatDaysMask: Int
    ): Long? {
        if (repeatDaysMask == 0) return null

        val now = Calendar.getInstance().apply { timeInMillis = nowMillis }

        val base = Calendar.getInstance().apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)

            if (timeInMillis <= nowMillis) {
                add(Calendar.DAY_OF_MONTH, 1)
            }
        }

        for (i in 0 until 7) {
            val candidate = (base.clone() as Calendar).apply {
                add(Calendar.DAY_OF_MONTH, i)
            }

            val idx = dayOfWeekToMaskIndex(candidate.get(Calendar.DAY_OF_WEEK))
            val enabled = ((repeatDaysMask shr idx) and 1) == 1

            if (enabled && candidate.timeInMillis > nowMillis) {
                return candidate.timeInMillis
            }
        }

        return null
    }

    private fun dayOfWeekToMaskIndex(dayOfWeek: Int): Int {
        return when (dayOfWeek) {
            Calendar.MONDAY -> 0
            Calendar.TUESDAY -> 1
            Calendar.WEDNESDAY -> 2
            Calendar.THURSDAY -> 3
            Calendar.FRIDAY -> 4
            Calendar.SATURDAY -> 5
            Calendar.SUNDAY -> 6
            else -> 0
        }
    }
}
