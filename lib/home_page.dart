import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:linas_alarm/create_alarm_page.dart';
import 'package:uuid/uuid.dart';

import 'alarm_service.dart';
import 'models.dart';
import 'storage.dart';
import 'player_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _uuid = const Uuid();
  List<MusicGroup> _groups = [];
  List<AlarmItem> _alarms = [];

  // ---- NOVO: controle de "modo deletar" por item ----
  String? _groupIdShowingDelete;
  int? _alarmIdShowingDelete;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await Storage.loadGroups();
    final a = await Storage.loadAlarms();
    setState(() {
      _groups = g;
      _alarms = a;
    });
  }

  Future<void> _saveAll() async {
    await Storage.saveGroups(_groups);
    await Storage.saveAlarms(_alarms);
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Novo grupo"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Nome do grupo"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text("Criar")),
        ],
      ),
    );

    if (ok != true) return;
    final name = controller.text.trim();
    if (name.isEmpty) return;

    setState(() {
      _groups.add(MusicGroup(id: _uuid.v4(), name: name, paths: []));
    });
    await _saveAll();
  }

  Future<void> _addSongsToGroup(MusicGroup group) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["mp3", "m4a", "wav", "ogg", "flac"],
    );
    if (result == null) return;

    final paths = result.files.map((f) => f.path).whereType<String>().toList();

    setState(() {
      final idx = _groups.indexWhere((g) => g.id == group.id);
      final current = _groups[idx];
      final merged = {...current.paths, ...paths}.toList();
      _groups[idx] = MusicGroup(id: current.id, name: current.name, paths: merged);
    });
    await _saveAll();
  }

  Future<void> _openCreateAlarm() async {
    if (_groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Crie um grupo primeiro.")),
      );
      return;
    }

    final result = await Navigator.push<CreateAlarmResult>(
      context,
      MaterialPageRoute(builder: (_) => CreateAlarmPage(groups: _groups)),
    );

    if (result == null) return;

    setState(() => _alarms.add(result.alarm));
    await _saveAll();

    await AlarmService.schedule(
      alarm: result.alarm,
      paths: _groups.firstWhere((g) => g.id == result.alarm.groupId).paths,
    );

    final msg = buildNextAlarmMessage(
      hour: result.alarm.hour,
      minute: result.alarm.minute,
      repeatDaysMask: result.alarm.repeatDaysMask,
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _toggleAlarm(AlarmItem a, bool enabled) async {
    final idx = _alarms.indexWhere((x) => x.alarmId == a.alarmId);

    final updated = AlarmItem(
      alarmId: a.alarmId,
      label: a.label,
      hour: a.hour,
      minute: a.minute,
      groupId: a.groupId,
      enabled: enabled,
      repeatDaysMask: a.repeatDaysMask,
    );

    setState(() => _alarms[idx] = updated);
    await _saveAll();

    if (enabled) {
      final group = _groups.firstWhere((g) => g.id == updated.groupId);
      await AlarmService.schedule(alarm: updated, paths: group.paths);
      
      final msg = buildNextAlarmMessage(
        hour: updated.hour,
        minute: updated.minute,
        repeatDaysMask: updated.repeatDaysMask,
      );

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    } else {
      await AlarmService.cancel(updated.alarmId);
    }
  }

  static String buildNextAlarmMessage({
    required int hour,
    required int minute,
    required int repeatDaysMask,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();

    final nextTrigger = AlarmService.computeNextTrigger(
      hour: hour,
      minute: minute,
      repeatDaysMask: repeatDaysMask,
      now: n,
    );

    final diff = nextTrigger.difference(n);

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (hours <= 0 && minutes <= 0) {
      return "O alarme vai tocar em instantes.";
    } else if (hours <= 0) {
      return "O alarme vai tocar daqui a $minutes minuto${minutes == 1 ? '' : 's'}.";
    } else if (minutes == 0) {
      return "O alarme vai tocar daqui a $hours hora${hours == 1 ? '' : 's'}.";
    } else {
      return "O alarme vai tocar daqui a $hours hora${hours == 1 ? '' : 's'} "
          "e $minutes minuto${minutes == 1 ? '' : 's'}.";
    }
  }


  void _testPlay(AlarmItem alarm) {
    final group = _groups.firstWhere((g) => g.id == alarm.groupId);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerPage(alarm: alarm, group: group)),
    );
  }

  // -------------------------
  // NOVO: Confirmar exclusão
  // -------------------------

  Future<bool> _confirmDelete({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteAlarm(AlarmItem alarm) async {
    final ok = await _confirmDelete(
      title: "Excluir alarme",
      message: "Tem certeza que deseja excluir o alarme \"${alarm.label}\"?",
      confirmText: "Excluir",
    );
    if (!ok) return;

    // Cancela agendamento e remove da lista
    await AlarmService.cancel(alarm.alarmId);

    setState(() {
      _alarms.removeWhere((a) => a.alarmId == alarm.alarmId);
      _alarmIdShowingDelete = null;
    });

    await _saveAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alarme excluído.")),
    );
  }

  Future<void> _deleteGroup(MusicGroup group) async {
    // remove alarmes que usam esse grupo
    final alarmsUsingGroup = _alarms.where((a) => a.groupId == group.id).toList();

    final ok = await _confirmDelete(
      title: "Excluir grupo",
      message: alarmsUsingGroup.isEmpty
          ? "Tem certeza que deseja excluir o grupo \"${group.name}\"?"
          : "Esse grupo está sendo usado por ${alarmsUsingGroup.length} alarme(s). "
              "Ao excluir o grupo, esses alarmes também serão excluídos.\n\n"
              "Deseja continuar?",
      confirmText: "Excluir",
    );
    if (!ok) return;

    // cancela alarmes relacionados (se houver)
    for (final a in alarmsUsingGroup) {
      await AlarmService.cancel(a.alarmId);
    }

    setState(() {
      _groups.removeWhere((g) => g.id == group.id);
      _alarms.removeWhere((a) => a.groupId == group.id);
      _groupIdShowingDelete = null;
    });

    await _saveAll();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Grupo excluído.")),
    );
  }

  void _hideDeleteIcons() {
    if (_groupIdShowingDelete == null && _alarmIdShowingDelete == null) return;
    setState(() {
      _groupIdShowingDelete = null;
      _alarmIdShowingDelete = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _hideDeleteIcons, // toca fora para esconder a lixeira
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Lina's Alarm"),          
        ),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [

            // Titulo grupos
            Row(
              children: [
                const Text(
                  "Grupos",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _createGroup,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.playlist_add, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "Criar grupo",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),


            // Lista de grupos
            ..._groups.map((g) {
              final showTrash = _groupIdShowingDelete == g.id;

              return Card(
                color: showTrash ? const Color.fromARGB(169, 255, 0, 38) : Color.fromARGB(74, 86, 204, 39),
                child: InkWell(
                  onTap: () => _addSongsToGroup(g),
                  onLongPress: () {
                    setState(() {
                      _alarmIdShowingDelete = null;
                      _groupIdShowingDelete = g.id;
                    });
                  },
                  child: ListTile(
                    title: Text(g.name),
                    subtitle: Text("${g.paths.length} músicas"),
                    trailing: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: showTrash
                            ? () => _deleteGroup(g)
                            : () => _addSongsToGroup(g),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            showTrash
                                ? Icons.delete_outline
                                : Icons.library_music,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            const Divider(height: 32, thickness: 1.2, color: Colors.black26),

            // Titulo alarmes
            Row(
              children: [
                const Text(
                  "Alarmes",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _openCreateAlarm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.alarm_add, size: 18),
                          SizedBox(width: 6),
                          Text(
                            "Criar alarme",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Lista de alarmes
            ..._alarms.map((a) {
              final groupName = _groups
                      .where((g) => g.id == a.groupId)
                      .map((g) => g.name)
                      .firstOrNull ??
                  "Grupo?";
              final hh = a.hour.toString().padLeft(2, "0");
              final mm = a.minute.toString().padLeft(2, "0");
              final showTrash = _alarmIdShowingDelete == a.alarmId;

              return Card(
                color: showTrash ? const Color.fromARGB(169, 255, 0, 38) : Color.fromARGB(76, 39, 105, 204),
                child: InkWell(
                  onTap: () => _testPlay(a),
                  onLongPress: () {
                    setState(() {
                      _groupIdShowingDelete = null;
                      _alarmIdShowingDelete = a.alarmId;
                    });
                  },
                  child: ListTile(
                    title: Text("${a.label} — $hh:$mm"),
                    subtitle: Text("Grupo: $groupName"),
                    leading: Switch(
                      value: a.enabled,
                      onChanged: (v) => _toggleAlarm(a, v),
                    ),
                    trailing: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: showTrash
                            ? () => _deleteAlarm(a)
                            : () => _testPlay(a),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(
                            8,
                          ), // controla o "tamanho clicável"
                          child: Icon(
                            showTrash ? Icons.delete_outline : Icons.play_arrow,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
