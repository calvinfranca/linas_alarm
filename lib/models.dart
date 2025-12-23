import 'dart:convert';

class MusicGroup {
  final String id;
  final String name;
  final List<String> paths; // paths locais no storage do Android

  MusicGroup({
    required this.id,
    required this.name,
    required this.paths,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "paths": paths,
      };

  factory MusicGroup.fromMap(Map<String, dynamic> map) => MusicGroup(
        id: map["id"],
        name: map["name"],
        paths: List<String>.from(map["paths"] ?? const []),
      );

  String toJson() => jsonEncode(toMap());
  factory MusicGroup.fromJson(String s) => MusicGroup.fromMap(jsonDecode(s));
}

class AlarmItem {
  final int alarmId; // precisa ser int pro AndroidAlarmManager
  final String label;
  final int hour;
  final int minute;
  final String groupId;
  final bool enabled;
  // Bitmask: 0 = sem repetição (toca só na próxima ocorrência)
  // Bits: 1<<0 = Mon, 1<<1 = Tue, ... 1<<6 = Sun
  final int repeatDaysMask;

  AlarmItem({
    required this.alarmId,
    required this.label,
    required this.hour,
    required this.minute,
    required this.groupId,
    required this.enabled,
    this.repeatDaysMask = 0,
  });

  Map<String, dynamic> toMap() => {
        "alarmId": alarmId,
        "label": label,
        "hour": hour,
        "minute": minute,
        "groupId": groupId,
        "enabled": enabled,
        "repeatDaysMask": repeatDaysMask,
      };

  factory AlarmItem.fromMap(Map<String, dynamic> map) => AlarmItem(
        alarmId: map["alarmId"],
        label: map["label"],
        hour: map["hour"],
        minute: map["minute"],
        groupId: map["groupId"],
        enabled: map["enabled"] ?? false,
        repeatDaysMask: (map["repeatDaysMask"] ?? 0) as int,
      );

  String toJson() => jsonEncode(toMap());
  factory AlarmItem.fromJson(String s) => AlarmItem.fromMap(jsonDecode(s));
}
