import 'alarm_native.dart';
import 'models.dart';

class AlarmService {
  static DateTime _nextForWeekdays({
    required int hour,
    required int minute,
    required int repeatDaysMask,
  }) {
    final now = DateTime.now();

    DateTime candidate = DateTime(now.year, now.month, now.day, hour, minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    if (repeatDaysMask == 0) {
      return candidate;
    }

    for (int i = 0; i < 14; i++) {
      final wd = candidate.weekday; // 1..7
      final bit = 1 << (wd - 1);
      if ((repeatDaysMask & bit) != 0) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
      candidate = DateTime(candidate.year, candidate.month, candidate.day, hour, minute);
    }

    return DateTime(now.year, now.month, now.day, hour, minute).add(const Duration(days: 1));
  }

  static Future<void> scheduleOneShot({
    required AlarmItem alarm,
    required List<String> paths,
  }) async {
    final triggerAt = _nextForWeekdays(
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

  // Se você usa scheduleDailyAlarm no seu projeto, aponta pra scheduleOneShot
  static Future<void> scheduleDailyAlarm(AlarmItem alarm, List<String> paths) async {
    await scheduleOneShot(alarm: alarm, paths: paths);
  }
}
