// ignore_for_file: unused_element

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'alarm_native.dart';
import 'models.dart';

class CreateAlarmResult {
  final AlarmItem alarm;
  final List<String> paths;
  final int volumePercent;
  final bool vibrationEnabled;
  final bool snoozeEnabled;
  final int snoozeMinutes;
  final int snoozeMaxTimes;

  CreateAlarmResult({
    required this.alarm,
    required this.paths,
    required this.volumePercent,
    required this.vibrationEnabled,
    required this.snoozeEnabled,
    required this.snoozeMinutes,
    required this.snoozeMaxTimes,
  });
}

class CreateAlarmPage extends StatefulWidget {
  final List<MusicGroup> groups;

  const CreateAlarmPage({
    super.key,
    required this.groups,
  });

  @override
  State<CreateAlarmPage> createState() => _CreateAlarmPageState();
}

class _CreateAlarmPageState extends State<CreateAlarmPage> {
  final _labelController = TextEditingController(text: "");

  DateTime _time = DateTime.now();
  MusicGroup? _selectedGroup;

  bool _vibration = true;
  bool _snooze = true;
  int _snoozeMinutes = 5;
  int _snoozeMaxTimes = 3;

  int _volume = 80;
  bool _loadingVolume = true;

  // 1 = Monday ... 7 = Sunday (DateTime.weekday)
  final Set<int> _repeatWeekdays = {};

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groups.isNotEmpty ? widget.groups.first : null;
    _loadVolume();
  }

  Future<void> _loadVolume() async {
    try {
      final v = await AlarmNative.getAlarmVolumePercent();
      if (!mounted) return;
      setState(() {
        _volume = v.clamp(0, 100);
        _loadingVolume = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingVolume = false;
      });
    }
  }

  Future<void> _setVolume(int v) async {
    final p = v.clamp(0, 100);
    setState(() => _volume = p);
    await AlarmNative.setAlarmVolumePercent(p);
  }

  void _pickGroup() async {
    if (widget.groups.isEmpty) return;

    final chosenId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF121323),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (c) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: widget.groups.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x22FFFFFF)),
            itemBuilder: (_, i) {
              final g = widget.groups[i];
              final selected = _selectedGroup?.id == g.id;
              return ListTile(
                title: Text(g.name, style: const TextStyle(color: Colors.white)),
                subtitle: Text("${g.paths.length} músicas", style: const TextStyle(color: Color(0xFFB8BBFF))),
                trailing: selected ? const Icon(Icons.check, color: Color(0xFF3F3DFF)) : null,
                onTap: () => Navigator.pop(c, g.id),
              );
            },
          ),
        );
      },
    );

    if (chosenId == null) return;
    final g = widget.groups.firstWhere((e) => e.id == chosenId);
    setState(() => _selectedGroup = g);
  }

  int _repeatMaskFromSelected() {
    int mask = 0;
    for (final wd in _repeatWeekdays) {
      // wd: 1..7; bit index: 0..6
      mask |= (1 << (wd - 1));
    }
    return mask;
  }

  void _save() {
    if (_selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Crie um grupo primeiro.")),
      );
      return;
    }

    final group = _selectedGroup!;
    if (group.paths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Esse grupo está vazio. Adicione músicas antes.")),
      );
      return;
    }

    final alarmId = 100000 + Random().nextInt(900000);
    final label = _labelController.text.trim().isEmpty ? "Alarme" : _labelController.text.trim();
    final repeatMask = _repeatMaskFromSelected();

    final item = AlarmItem(
      alarmId: alarmId,
      label: label,
      hour: _time.hour,
      minute: _time.minute,
      groupId: group.id,
      enabled: true,
      repeatDaysMask: repeatMask,
    );

    Navigator.pop(
      context,
      CreateAlarmResult(
        alarm: item,
        paths: group.paths,
        volumePercent: _volume,
        vibrationEnabled: _vibration,
        snoozeEnabled: _snooze,
        snoozeMinutes: _snoozeMinutes,
        snoozeMaxTimes: _snoozeMaxTimes,
      ),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0B0B12);
    final card = const Color(0xFF121323);
    final soft = const Color(0xFFB8BBFF);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                children: [
                  _TimeWheel(
                    initial: _time,
                    onChanged: (dt) => setState(() => _time = dt),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        
                        const Divider(height: 1, color: Color(0x22FFFFFF)),

                        // Botoes de repetição (semana)
                        _RepeatRow(
                          selectedWeekdays: _repeatWeekdays,
                          onToggle: (weekday) {
                            setState(() {
                              if (_repeatWeekdays.contains(weekday)) {
                                _repeatWeekdays.remove(weekday);
                              } else {
                                _repeatWeekdays.add(weekday);
                              }
                            });
                          },
                        ),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),

                        // Nome do alarme
                        _NameField(controller: _labelController),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),

                        // Seleção do grupo de músicas
                        ListTile(
                          title: const Text(
                            "Som do alarme",
                            style: TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            _selectedGroup?.name ?? "Selecione um grupo",
                            style: const TextStyle(color: Color(0xFF3F3DFF)),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF3F3DFF),
                          ),
                          onTap: _pickGroup,
                        ),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),

                        // Volume do alarme
                        _VolumeTile(
                          loading: _loadingVolume,
                          volume: _volume,
                          onChanged: _setVolume,
                        ),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),

                        // Vibração
                        ListTile(
                          title: const Text("Vibração", style: TextStyle(color: Colors.white)),
                          subtitle: Text(_vibration ? "Ativada" : "Desativada", style: TextStyle(color: soft)),
                          trailing: Switch(
                            value: _vibration,
                            onChanged: (v) => setState(() => _vibration = v),
                            activeColor: const Color(0xFF3F3DFF),
                          ),
                        ),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),

                        // Soneca
                        ListTile(
                          title: const Text("Adiar", style: TextStyle(color: Colors.white)),
                          subtitle: Text(
                            _snooze ? "$_snoozeMinutes minutos, $_snoozeMaxTimes vezes" : "Desativado",
                            style: TextStyle(color: soft),
                          ),
                          trailing: Switch(
                            value: _snooze,
                            onChanged: (v) => setState(() => _snooze = v),
                            activeColor: const Color(0xFF3F3DFF),
                          ),
                          onTap: !_snooze
                              ? null
                              : () async {
                                  final r = await showModalBottomSheet<_SnoozeCfg>(
                                    context: context,
                                    backgroundColor: const Color(0xFF121323),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                    ),
                                    builder: (c) => _SnoozeSheet(
                                      minutes: _snoozeMinutes,
                                      times: _snoozeMaxTimes,
                                    ),
                                  );
                                  if (r == null) return;
                                  setState(() {
                                    _snoozeMinutes = r.minutes;
                                    _snoozeMaxTimes = r.times;
                                  });
                                },
                        ),
                        if ((_selectedGroup?.paths.isEmpty ?? false))
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Esse grupo está vazio. Adicione músicas antes de salvar.",
                                style: TextStyle(color: Color(0xFFFFB4B4), fontSize: 12),
                              ),
                            ),
                          ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              color: bg,
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar", style: TextStyle(color: Color(0xFF3F3DFF), fontSize: 16)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: _save,
                      child: const Text("Salvar", style: TextStyle(color: Color(0xFF3F3DFF), fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowHeader(String label, Color soft) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: soft, fontSize: 14))),
          const Icon(Icons.calendar_today, color: Color(0xFFB8BBFF), size: 18),
        ],
      ),
    );
  }
}

class _RepeatRow extends StatelessWidget {
  final Set<int> selectedWeekdays;
  final void Function(int weekday) onToggle;

  const _RepeatRow({
    required this.selectedWeekdays,
    required this.onToggle,
  });

  static const _labels = {
    1: "S",
    2: "T",
    3: "Q",
    4: "Q",
    5: "S",
    6: "S",
    7: "D",
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text("Repetir", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          Row(
            children: [
              _dayButton(context, 7),
              _dayButton(context, 1),
              _dayButton(context, 2),
              _dayButton(context, 3),
              _dayButton(context, 4),
              _dayButton(context, 5),
              _dayButton(context, 6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayButton(BuildContext context, int weekday) {
    final selected = selectedWeekdays.contains(weekday);
    final bg = selected ? const Color(0xFF3F3DFF) : const Color(0xFF1B1C2F);
    final fg = selected ? Colors.white : const Color(0xFFB8BBFF);

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onToggle(weekday),
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_labels[weekday] ?? "?", style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _TimeWheel extends StatelessWidget {
  final DateTime initial;
  final ValueChanged<DateTime> onChanged;

  const _TimeWheel({
    required this.initial,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final card = const Color(0xFF0B0B12);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        height: 200,
        child: CupertinoTheme(
          data: const CupertinoThemeData(brightness: Brightness.dark),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            initialDateTime: initial,
            use24hFormat: true,
            onDateTimeChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;

  const _NameField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: const InputDecoration(
          hintText: "Nome do alarme",
          hintStyle: TextStyle(color: Color(0x66FFFFFF)),
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _VolumeTile extends StatelessWidget {
  final bool loading;
  final int volume;
  final ValueChanged<int> onChanged;

  const _VolumeTile({
    required this.loading,
    required this.volume,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text("Volume", style: TextStyle(color: Colors.white)),
      subtitle: loading
          ? const Text("Carregando...", style: TextStyle(color: Color(0xFFB8BBFF)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$volume%", style: const TextStyle(color: Color(0xFFB8BBFF))),
                Slider(
                  value: volume.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ],
            ),
    );
  }
}

class _SnoozeCfg {
  final int minutes;
  final int times;

  const _SnoozeCfg(this.minutes, this.times);
}

class _SnoozeSheet extends StatefulWidget {
  final int minutes;
  final int times;

  const _SnoozeSheet({
    required this.minutes,
    required this.times,
  });

  @override
  State<_SnoozeSheet> createState() => _SnoozeSheetState();
}

class _SnoozeSheetState extends State<_SnoozeSheet> {
  late int _minutes = widget.minutes;
  late int _times = widget.times;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Configurar soneca", style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(child: Text("Minutos", style: TextStyle(color: Color(0xFFB8BBFF)))),
                DropdownButton<int>(
                  dropdownColor: const Color(0xFF121323),
                  value: _minutes,
                  items: const [3, 5, 10, 15]
                      .map((v) => DropdownMenuItem(value: v, child: Text("$v", style: TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) => setState(() => _minutes = v ?? _minutes),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text("Vezes", style: TextStyle(color: Color(0xFFB8BBFF)))),
                DropdownButton<int>(
                  dropdownColor: const Color(0xFF121323),
                  value: _times,
                  items: const [1, 2, 3, 5]
                      .map((v) => DropdownMenuItem(value: v, child: Text("$v", style: TextStyle(color: Colors.white))))
                      .toList(),
                  onChanged: (v) => setState(() => _times = v ?? _times),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar", style: TextStyle(color: Color(0xFF3F3DFF))),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _SnoozeCfg(_minutes, _times)),
                    child: const Text("OK", style: TextStyle(color: Color(0xFF3F3DFF))),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
