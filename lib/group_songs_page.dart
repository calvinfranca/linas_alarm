import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models.dart';

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

  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() {
        _isPlaying = s == PlayerState.playing;
        if (!_isPlaying) {
          _playingPath = null;
        }
      });
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String path) async {
    try {
      if (_playingPath == path && _isPlaying) {
        await _player.stop();
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _playingPath = null;
        });
        return;
      }

      await _player.stop();
      await _player.play(DeviceFileSource(path));

      if (!mounted) return;
      setState(() {
        _playingPath = path;
        _isPlaying = true;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Não foi possível tocar essa música.")),
      );
    }
  }

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

    if (_playingPath == path && _isPlaying) {
      await _player.stop();
      _playingPath = null;
      _isPlaying = false;
    }

    setState(() {
      final next = _group.paths.where((p) => p != path).toList();
      _group = MusicGroup(id: _group.id, name: _group.name, paths: next);
    });
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
            onPressed: () async {
              await _player.stop();
              if (!mounted) return;
              Navigator.pop(context, _group);
            },
            child: const Text("Salvar", style: TextStyle(color: Colors.black)),
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
                final isThisPlaying = _playingPath == path && _isPlaying;

                return ListTile(
                  title: Text(_fileName(path)),
                  subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                  leading: IconButton(
                    tooltip: isThisPlaying ? "Stop" : "Play",
                    icon: Icon(isThisPlaying ? Icons.stop : Icons.play_arrow),
                    onPressed: () => _togglePlay(path),
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
