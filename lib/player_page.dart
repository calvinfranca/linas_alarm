import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'models.dart';

class PlayerPage extends StatefulWidget {
  final AlarmItem alarm;
  final MusicGroup group;

  const PlayerPage({
    super.key,
    required this.alarm,
    required this.group,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = AudioPlayer();
  String? _picked;

  @override
  void initState() {
    super.initState();
    _pickAndPlay();
  }

  Future<void> _pickAndPlay() async {
    if (widget.group.paths.isEmpty) {
      setState(() => _picked = null);
      return;
    }
    final path = widget.group.paths[Random().nextInt(widget.group.paths.length)];
    setState(() => _picked = path);

    await _player.setFilePath(path);
    await _player.setLoopMode(LoopMode.one); // alarme fica repetindo
    await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Alarme: ${widget.alarm.label}")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Grupo: ${widget.group.name}", style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text(
              _picked == null ? "Esse grupo não tem músicas." : "Tocando:\n$_picked",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _player.stop();
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text("PARAR"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickAndPlay,
                    child: const Text("PLAY"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
