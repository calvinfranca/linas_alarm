import 'alarm_native.dart';
import 'models.dart';

class AlarmService {
  /// Calcula o próximo disparo para:
  /// - one-shot (repeatDaysMask == 0): hoje no horário, ou amanhã se já passou
  /// - semanal (repeatDaysMask != 0): próximo dia da semana marcado, no horário
  static DateTime computeNextTrigger({
    required int hour,
    required int minute,
    required int repeatDaysMask,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();

    // Base: hoje no horário escolhido
    DateTime base = DateTime(n.year, n.month, n.day, hour, minute);

    // Se já passou, começa a busca a partir de amanhã
    if (!base.isAfter(n)) {
      base = base.add(const Duration(days: 1));
      base = DateTime(base.year, base.month, base.day, hour, minute);
    }

    // One-shot: próximo horário (hoje ou amanhã)
    if (repeatDaysMask == 0) {
      return base;
    }

    // Semanal: procurar no máximo 7 dias (inclusive o "base")
    for (int i = 0; i < 7; i++) {
      final candidate = base.add(Duration(days: i));
      final wd = candidate.weekday; // 1=Mon .. 7=Sun
      final bit = 1 << (wd - 1);    // 0..6

      final enabled = (repeatDaysMask & bit) != 0;
      if (enabled && candidate.isAfter(n)) {
        return DateTime(candidate.year, candidate.month, candidate.day, hour, minute);
      }
    }

    // Se a máscara estiver inválida, cai pra "one-shot amanhã" (fail-safe)
    final tomorrow = DateTime(n.year, n.month, n.day, hour, minute).add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
  }

  /// Agenda um alarme. Se repeatDaysMask==0, toca uma vez.
  /// Se repeatDaysMask!=0, toca no próximo dia selecionado e o nativo reagenda semanalmente.
  static Future<void> schedule({
    required AlarmItem alarm,
    required List<String> paths,
  }) async {
    final triggerAt = computeNextTrigger(
      hour: alarm.hour,
      minute: alarm.minute,
      repeatDaysMask: alarm.repeatDaysMask,
    );

    await AlarmNative.scheduleAlarm(
      alarmId: alarm.alarmId,
      triggerAt: triggerAt,
      label: alarm.label,
      groupId: alarm.groupId,
      paths: paths,
      repeatDaysMask: alarm.repeatDaysMask,
    );
  }

  static Future<void> cancel(int alarmId) async {
    await AlarmNative.cancelAlarm(alarmId);
  }

  // Compat com código antigo:
  static Future<void> scheduleOneShot({
    required AlarmItem alarm,
    required List<String> paths,
  }) async {
    await schedule(alarm: alarm, paths: paths);
  }

  // Compat com código antigo:
  static Future<void> scheduleDailyAlarm(AlarmItem alarm, List<String> paths) async {
    await schedule(alarm: alarm, paths: paths);
  }
}
