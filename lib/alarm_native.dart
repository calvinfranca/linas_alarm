import 'dart:convert';
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
    // O lado Android (Kotlin) espera os nomes abaixo.
    // Mantemos também os nomes antigos (triggerAtMillis/paths) por compatibilidade.
    final pathsJson = jsonEncode(paths);
    await _ch.invokeMethod('scheduleAlarm', {
      'alarmId': alarmId,

      // Chave esperada no Kotlin
      'triggerAt': triggerAt.millisecondsSinceEpoch,
      // Compat: versões antigas do Kotlin (se existirem)
      'triggerAtMillis': triggerAt.millisecondsSinceEpoch,

      'label': label,
      'groupId': groupId,

      // Chave esperada no Kotlin
      'pathsJson': pathsJson,
      // Compat: versões antigas (se existirem)
      'paths': paths,

      'repeatDaysMask': repeatDaysMask,
      // Necessário para repetição semanal no lado Android
      'hour': triggerAt.hour,
      'minute': triggerAt.minute,
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
