package com.example.linas_alarm.alarm

import android.content.Context
import android.media.AudioManager
import kotlin.math.roundToInt

object VolumeCtl {
    fun setAlarmVolumePercent(context: Context, percent: Int) {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val vol = (max * (percent.coerceIn(0, 100) / 100.0)).roundToInt().coerceIn(0, max)
        am.setStreamVolume(AudioManager.STREAM_ALARM, vol, 0)
    }

    fun getAlarmVolumePercent(context: Context): Int {
        val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
        val cur = am.getStreamVolume(AudioManager.STREAM_ALARM)
        if (max == 0) return 0
        return ((cur * 100.0) / max).roundToInt().coerceIn(0, 100)
    }
}
