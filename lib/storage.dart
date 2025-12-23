import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class Storage {
  static const _kGroups = "groups";
  static const _kAlarms = "alarms";

  static Future<List<MusicGroup>> loadGroups() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kGroups) ?? const [];
    return list.map((e) => MusicGroup.fromJson(e)).toList();
  }

  static Future<void> saveGroups(List<MusicGroup> groups) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kGroups, groups.map((g) => g.toJson()).toList());
  }

  static Future<List<AlarmItem>> loadAlarms() async {
    final sp = await SharedPreferences.getInstance();
    final list = sp.getStringList(_kAlarms) ?? const [];
    return list.map((e) => AlarmItem.fromJson(e)).toList();
  }

  static Future<void> saveAlarms(List<AlarmItem> alarms) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(_kAlarms, alarms.map((a) => a.toJson()).toList());
  }
}
