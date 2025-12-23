package com.example.linas_alarm.alarm

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import com.example.linas_alarm.R
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.util.Log


class AlarmActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d("ALARM_DEBUG", "AlarmActivity onCreate called")


        // Mostrar por cima da lockscreen e ligar a tela
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            km.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        setContentView(R.layout.activity_alarm)

        val label = intent.getStringExtra("label") ?: "Alarme"
        val alarmId = intent.getIntExtra("alarmId", -1)
        val groupId = intent.getStringExtra("groupId") ?: ""
        val pathsJson = intent.getStringExtra("pathsJson") ?: "[]"

        findViewById<TextView>(R.id.tvLabel).text = label

        val fmtTime = SimpleDateFormat("HH:mm", Locale.getDefault())
        val fmtDate = SimpleDateFormat("EEE, d MMM.", Locale.getDefault())
        findViewById<TextView>(R.id.tvTime).text = fmtTime.format(Date())
        findViewById<TextView>(R.id.tvDate).text = fmtDate.format(Date())

        // Parar
        findViewById<Button>(R.id.btnStop).setOnClickListener {
            stopAlarmService()
            finish()
        }

        // Soneca +5 min
        findViewById<Button>(R.id.btnSnooze).setOnClickListener {
            if (alarmId != -1) {
                val repeatDaysMask = intent.getIntExtra("repeatDaysMask", 0)
                val hour = intent.getIntExtra("hour", -1)
                val minute = intent.getIntExtra("minute", -1)

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
            stopAlarmService()
            finish()
        }
    }

    private fun stopAlarmService() {
        val intent = Intent(this, AlarmForegroundService::class.java).apply {
            action = "STOP_ALARM"
        }
        startService(intent)
    }
}
