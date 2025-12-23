import 'package:flutter/services.dart';

class AlarmNative {
  static const _ch = MethodChannel('alarm_native');

  static Future<void> scheduleAlarm({
    required int alarmId,
    required DateTime triggerAt,
    required String label,
    required String groupId,
    required List<String> paths,
    required int repeatDaysMask,
  }) async {
    await _ch.invokeMethod('scheduleAlarm', {
      'alarmId': alarmId,
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,
      'label': label,
      'groupId': groupId,
      'paths': paths,
      'repeatDaysMask': repeatDaysMask,
    });
  }

  static Future<void> cancelAlarm(int alarmId) async {
    await _ch.invokeMethod('cancelAlarm', {'alarmId': alarmId});
  }

  static Future<int> getAlarmVolumePercent() async {
    final v = await _ch.invokeMethod<int>('getAlarmVolumePercent');
    return (v ?? 0).clamp(0, 100);
  }

  static Future<void> setAlarmVolumePercent(int percent) async {
    await _ch.invokeMethod('setAlarmVolumePercent', {'percent': percent.clamp(0, 100)});
  }
}
