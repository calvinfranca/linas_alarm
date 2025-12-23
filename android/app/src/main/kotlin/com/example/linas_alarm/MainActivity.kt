package com.example.linas_alarm

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.linas_alarm.alarm.AlarmScheduler
import com.example.linas_alarm.alarm.VolumeCtl

class MainActivity : FlutterActivity() {

    private val CHANNEL = "alarm_native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {

                        "scheduleAlarm" -> {
                            val alarmId = call.argument<Int>("alarmId")
                                ?: return@setMethodCallHandler result.error("ARG", "alarmId faltando", null)

                            val triggerAt = call.argument<Long>("triggerAt")
                                ?: return@setMethodCallHandler result.error("ARG", "triggerAt faltando", null)

                            val label = call.argument<String>("label") ?: "Alarme"
                            val groupId = call.argument<String>("groupId") ?: ""
                            val pathsJson = call.argument<String>("pathsJson") ?: "[]"

                            // NOVO: repetição semanal
                            val repeatDaysMask = call.argument<Int>("repeatDaysMask") ?: 0
                            val hour = call.argument<Int>("hour") ?: -1
                            val minute = call.argument<Int>("minute") ?: -1

                            AlarmScheduler.schedule(
                                context = this,
                                alarmId = alarmId,
                                triggerAtMillis = triggerAt,
                                label = label,
                                groupId = groupId,
                                pathsJson = pathsJson,
                                repeatDaysMask = repeatDaysMask,
                                hour = hour,
                                minute = minute
                            )

                            result.success(true)
                        }

                        "cancelAlarm" -> {
                            val alarmId = call.argument<Int>("alarmId")
                                ?: return@setMethodCallHandler result.error("ARG", "alarmId faltando", null)

                            AlarmScheduler.cancel(this, alarmId)
                            result.success(true)
                        }

                        "setAlarmVolumePercent" -> {
                            val percent = call.argument<Int>("percent")
                                ?: return@setMethodCallHandler result.error("ARG", "percent faltando", null)

                            VolumeCtl.setAlarmVolumePercent(this, percent)
                            result.success(true)
                        }

                        "getAlarmVolumePercent" -> {
                            val percent = VolumeCtl.getAlarmVolumePercent(this)
                            result.success(percent)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_ERR", e.message ?: "Erro nativo", null)
                }
            }
    }
}
