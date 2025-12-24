import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'player_page.dart';

class GroupSongsPage extends StatefulWidget {
  final MusicGroup group;

  const GroupSongsPage({
    super.key,
    required this.group,
  });

  @override
  State<GroupSongsPage> createState() => _GroupSongsPageState();
}

class _GroupSongsPageState extends State<GroupSongsPage> {
  late MusicGroup _group = widget.group;

  Future<void> _addSongs() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ["mp3", "m4a", "wav", "ogg", "flac"],
    );
    if (result == null) return;

    final picked = result.files.map((f) => f.path).whereType<String>().toList();
    if (picked.isEmpty) return;

    setState(() {
      final merged = {..._group.paths, ...picked}.toList();
      _group = MusicGroup(id: _group.id, name: _group.name, paths: merged);
    });
  }

  Future<void> _removeSong(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Excluir música"),
        content: const Text("Tem certeza que deseja remover essa música do grupo?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text("Excluir")),
        ],
      ),
    );

    if (ok != true) return;

    setState(() {
      final next = _group.paths.where((p) => p != path).toList();
      _group = MusicGroup(id: _group.id, name: _group.name, paths: next);
    });
  }

  void _playPreview(String path) {
    // Reaproveita sua PlayerPage: cria um AlarmItem "fake" só para preview.
    final previewAlarm = AlarmItem(
      alarmId: -1,
      label: "Preview",
      hour: 0,
      minute: 0,
      groupId: _group.id,
      enabled: false,
      repeatDaysMask: 0,
    );

    // Para tocar só essa música, montamos um grupo temporário com 1 path.
    final oneSongGroup = MusicGroup(id: _group.id, name: _group.name, paths: [path]);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerPage(alarm: previewAlarm, group: oneSongGroup)),
    );
  }

  String _fileName(String path) {
    final norm = path.replaceAll("\\", "/");
    final idx = norm.lastIndexOf("/");
    return idx >= 0 ? norm.substring(idx + 1) : norm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            tooltip: "Adicionar músicas",
            icon: const Icon(Icons.add),
            onPressed: _addSongs,
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _group),
            child: const Text("Salvar", style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
          ),
        ],
      ),
      body: _group.paths.isEmpty
          ? const Center(child: Text("Esse grupo está vazio. Adicione músicas."))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _group.paths.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final path = _group.paths[i];
                return ListTile(
                  title: Text(_fileName(path)),
                  subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    tooltip: "Play",
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playPreview(path),
                  ),
                  trailing: IconButton(
                    tooltip: "Excluir",
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeSong(path),
                  ),
                );
              },
            ),
    );
  }
}
