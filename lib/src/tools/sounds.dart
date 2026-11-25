/// Bildirim ve zil sesi paketi: cihazda sentezlenen özgün sesler. Dinlenir,
/// perde ve hızı ayarlanır, WAV olarak kaydedilir. Uygulama sistem zil
/// sesini kendisi DEĞİŞTİRMEZ (WRITE_SETTINGS izni istenmez); kullanıcı
/// kaydettiği dosyayı telefon ayarlarından seçer.
library;

import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';

class SoundPackTool extends StatefulWidget {
  final ToolContext t;
  const SoundPackTool(this.t, {super.key});
  @override
  State<SoundPackTool> createState() => _SoundPackState();
}

class _SoundPackState extends State<SoundPackTool> {
  ToolContext get t => widget.t;
  final TonePlayer _player = TonePlayer();
  bool _ring = false;
  int _transpose = 0;
  double _tempo = 1;
  String? _playing;
  bool _extras = false;

  @override
  void initState() {
    super.initState();
    extrasOpen(t).then((v) {
      if (mounted) setState(() => _extras = v);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  bool _locked(TonePreset p) => p.premium && !_extras;

  Future<void> _play(TonePreset p) async {
    if (_playing == p.key) {
      await _player.stop();
      setState(() => _playing = null);
      return;
    }
    setState(() => _playing = p.key);
    await _player.play(synth(p.notes, p.timbre, transpose: _transpose, tempo: _tempo, repeat: p.ringtone ? 2 : 1));
  }

  Future<void> _save(TonePreset p) async {
    final wav = synth(p.notes, p.timbre, transpose: _transpose, tempo: _tempo, repeat: p.ringtone ? 3 : 1);
    final shift = _transpose == 0 ? '' : '_${_transpose > 0 ? '+' : ''}$_transpose';
    await saveBytesAs(context, t, '${p.ringtone ? 'ringtone' : 'notification'}_${p.key}$shift.wav', wav);
  }

  @override
  Widget build(BuildContext context) {
    final list = kTones.where((p) => p.ringtone == _ring).toList();
    return ToolList(children: [
      Choice<bool>(
        values: const [false, true],
        labels: [L(t, 'notification_sounds'), L(t, 'ringtones')],
        selected: _ring,
        onChanged: (b) async {
          await _player.stop();
          setState(() {
            _ring = b;
            _playing = null;
          });
        },
      ),
      AppPanel(
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(L(t, 'pitch'))),
            Text('${_transpose > 0 ? '+' : ''}$_transpose', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          Slider(
            value: _transpose.toDouble(),
            min: -6,
            max: 6,
            divisions: 12,
            onChanged: (v) => setState(() => _transpose = v.round()),
          ),
          Row(children: [
            Expanded(child: Text(L(t, 'speed'))),
            Text('×${_tempo.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          Slider(value: _tempo, min: 0.5, max: 2, divisions: 6, onChanged: (v) => setState(() => _tempo = v)),
        ]),
      ),
      if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      for (final p in list)
        Card(
          child: ListTile(
            leading: IconButton.filledTonal(
              icon: Icon(_playing == p.key ? Icons.stop_rounded : Icons.play_arrow_rounded),
              onPressed: _locked(p) ? null : () => _play(p),
            ),
            title: Text(L(t, 'tone_${p.key}')),
            subtitle: Text(L(t, 'timbre_${p.timbre.name}')),
            trailing: _locked(p)
                ? const Icon(Icons.lock_rounded)
                : IconButton(icon: const Icon(Icons.download_rounded), tooltip: L(t, 'save_wav'), onPressed: () => _save(p)),
          ),
        ),
      AppInfoCard(L(t, 'sound_note'), icon: Icons.info_outline_rounded),
    ]);
  }
}
