/// Canlı duvar kağıdı: özgün, kodla çizilen hareketli sahneler. Uygulama
/// içinde tam ekran oynatılır ve istenen an PNG olarak kaydedilir.
/// Sistem canlı duvar kağıdı servisi (Android WallpaperService) bu sürümde
/// yoktur; ekranda açıkça yazılır.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';

/// Sahne anahtarları (sonuncular ekstra).
const List<String> kScenes = ['aurora', 'waves', 'bubbles', 'stars', 'orbits', 'rain'];
const int kFreeScenes = 4;

/// Bir sahneyi zamana göre çizer.
class ScenePainter extends CustomPainter {
  final String scene;
  final List<int> palette;
  final double time;
  ScenePainter(this.scene, this.palette, this.time);

  Color c(int i, [double a = 1]) => Color(palette[i % palette.length]).withValues(alpha: a);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c(0), c(1)]).createShader(rect),
    );
    switch (scene) {
      case 'aurora':
        _aurora(canvas, size);
      case 'waves':
        _waves(canvas, size);
      case 'bubbles':
        _bubbles(canvas, size);
      case 'stars':
        _stars(canvas, size);
      case 'orbits':
        _orbits(canvas, size);
      default:
        _rain(canvas, size);
    }
  }

  void _aurora(Canvas canvas, Size s) {
    for (var b = 0; b < 4; b++) {
      final path = Path()..moveTo(0, s.height);
      for (var x = 0.0; x <= s.width; x += 8) {
        final y = s.height * (0.28 + b * 0.08) +
            math.sin(x / s.width * 4 + time * (0.5 + b * 0.15) + b) * s.height * 0.06 +
            math.sin(x / s.width * 9 - time * 0.7) * s.height * 0.02;
        path.lineTo(x, y);
      }
      path
        ..lineTo(s.width, s.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c(2 + b, 0.35), c(1, 0)],
          ).createShader(Offset.zero & s)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
  }

  void _waves(Canvas canvas, Size s) {
    for (var b = 0; b < 5; b++) {
      final path = Path()..moveTo(0, s.height);
      final base = s.height * (0.45 + b * 0.11);
      for (var x = 0.0; x <= s.width; x += 6) {
        path.lineTo(x, base + math.sin(x / s.width * 2 * math.pi * (1 + b * 0.3) + time * (1 + b * 0.25)) * 18);
      }
      path
        ..lineTo(s.width, s.height)
        ..close();
      canvas.drawPath(path, Paint()..color = c(2 + b, 0.18 + b * 0.08));
    }
  }

  double _rnd(int i, int k) {
    final x = math.sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  void _bubbles(Canvas canvas, Size s) {
    for (var i = 0; i < 40; i++) {
      final speed = 0.03 + _rnd(i, 1) * 0.06;
      final y = (1.1 - ((time * speed + _rnd(i, 2)) % 1.2)) * s.height;
      final x = _rnd(i, 3) * s.width + math.sin(time + i) * 12;
      final r = 6 + _rnd(i, 4) * 26;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = c(2 + i % 3, 0.18));
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = c(3, 0.45),
      );
    }
  }

  void _stars(Canvas canvas, Size s) {
    for (var i = 0; i < 160; i++) {
      final x = (_rnd(i, 1) * s.width + time * 4 * _rnd(i, 5)) % s.width;
      final y = _rnd(i, 2) * s.height;
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(time * (1 + _rnd(i, 3) * 3) + i));
      canvas.drawCircle(Offset(x, y), 0.6 + _rnd(i, 4) * 1.8, Paint()..color = c(2 + i % 3, tw));
    }
    final m = Offset(s.width * 0.75, s.height * 0.2);
    canvas.drawCircle(m, 34, Paint()..color = c(4, 0.85));
    canvas.drawCircle(m.translate(12, -6), 30, Paint()..color = c(0));
  }

  void _orbits(Canvas canvas, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final r0 = math.min(s.width, s.height) * 0.08;
    canvas.drawCircle(center, r0, Paint()..color = c(4, 0.9));
    for (var k = 1; k <= 5; k++) {
      final r = r0 * (1.4 + k * 0.9);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = c(3, 0.25),
      );
      final a = time * (0.6 / k) + k;
      canvas.drawCircle(center + Offset(math.cos(a) * r, math.sin(a) * r), 4 + k * 1.5, Paint()..color = c(2 + k));
    }
  }

  void _rain(Canvas canvas, Size s) {
    final p = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 90; i++) {
      final speed = 0.25 + _rnd(i, 1) * 0.3;
      final y = ((time * speed + _rnd(i, 2)) % 1.0) * (s.height + 40) - 20;
      final x = _rnd(i, 3) * s.width;
      p.color = c(2 + i % 2, 0.25 + _rnd(i, 4) * 0.4);
      canvas.drawLine(Offset(x, y), Offset(x - 4, y + 18), p);
    }
  }

  @override
  bool shouldRepaint(ScenePainter old) => old.time != time || old.scene != scene || old.palette != palette;
}

/// Zamanla akan sahne.
class LiveScene extends StatefulWidget {
  final String scene;
  final List<int> palette;
  final double speed;
  const LiveScene({super.key, required this.scene, required this.palette, this.speed = 1});
  @override
  State<LiveScene> createState() => _LiveSceneState();
}

class _LiveSceneState extends State<LiveScene> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final dt = (d - _last).inMicroseconds / 1e6;
      _last = d;
      setState(() => _t += dt * widget.speed);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: ScenePainter(widget.scene, widget.palette, _t), child: const SizedBox.expand());
}

class WallpaperTool extends StatefulWidget {
  final ToolContext t;
  const WallpaperTool(this.t, {super.key});
  @override
  State<WallpaperTool> createState() => _WallpaperState();
}

class _WallpaperState extends State<WallpaperTool> {
  ToolContext get t => widget.t;
  String _scene = kScenes.first;
  int _palette = 0;
  double _speed = 1;
  bool _extras = false;

  @override
  void initState() {
    super.initState();
    () async {
      final m = await t.store.readMap('wall');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _scene = kScenes.contains(m['scene']) ? m['scene'] as String : _scene;
        _palette = ((m['palette'] as num?)?.toInt() ?? 0).clamp(0, kPalettes.length - 1);
        _speed = ((m['speed'] as num?)?.toDouble() ?? 1.0).clamp(0.2, 3.0);
        _extras = ex;
        if (!_extras && (kScenes.indexOf(_scene) >= kFreeScenes || _palette >= kFreePalettes)) {
          _scene = kScenes.first;
          _palette = 0;
        }
      });
    }();
  }

  void _save() => t.store.writeMap('wall', {'scene': _scene, 'palette': _palette, 'speed': _speed});

  Future<void> _full() async {
    final key = GlobalKey();
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (c) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Positioned.fill(
            child: RepaintBoundary(key: key, child: LiveScene(scene: _scene, palette: kPalettes[_palette], speed: _speed)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                IconButton.filledTonal(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(c)),
                const Spacer(),
                IconButton.filledTonal(
                  icon: const Icon(Icons.download_rounded),
                  tooltip: L(t, 'save_png'),
                  onPressed: () async {
                    final png = await capturePng(key, pixelRatio: MediaQuery.of(c).devicePixelRatio);
                    if (png != null && c.mounted) await saveBytesAs(c, t, 'wallpaper_$_scene.png', png);
                  },
                ),
              ]),
            ),
          ),
        ]),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: GestureDetector(
              onTap: _full,
              child: LiveScene(scene: _scene, palette: kPalettes[_palette], speed: _speed),
            ),
          ),
        ),
      ),
      AppButton(label: L(t, 'fullscreen'), icon: Icons.fullscreen_rounded, onPressed: _full),
      AppHeading(L(t, 'scene'), icon: Icons.auto_awesome_rounded),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < kScenes.length; i++)
            ChoiceChip(
              avatar: i >= kFreeScenes && !_extras ? const Icon(Icons.lock_rounded, size: 16) : null,
              label: Text(L(t, 'scene_${kScenes[i]}')),
              selected: _scene == kScenes[i],
              onSelected: i >= kFreeScenes && !_extras
                  ? null
                  : (_) {
                      setState(() => _scene = kScenes[i]);
                      _save();
                    },
            ),
        ]),
      ),
      AppHeading(L(t, 'colors'), icon: Icons.palette_rounded),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: PaletteRow(
          palettes: kPalettes,
          selected: _palette,
          free: kFreePalettes,
          unlocked: _extras,
          onChanged: (i) {
            setState(() => _palette = i);
            _save();
          },
        ),
      ),
      if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      AppHeading(L(t, 'speed'), icon: Icons.speed_rounded),
      Slider(
        value: _speed,
        min: 0.2,
        max: 3,
        divisions: 14,
        label: '×${_speed.toStringAsFixed(1)}',
        onChanged: (v) => setState(() => _speed = v),
        onChangeEnd: (_) => _save(),
      ),
      AppInfoCard(L(t, kIsWeb ? 'wall_note_web' : 'wall_note'), icon: Icons.info_outline_rounded),
    ]);
  }
}
