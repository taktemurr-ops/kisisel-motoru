/// Özgün ikon paketi: telefon, mesaj, kamera gibi GENEL kategori ikonları,
/// kodla çizilen özgün şekiller. Marka eşlemesi (appfilter) ve hiçbir
/// markanın logosu yoktur. İkonlar PNG olarak kaydedilir; özel ikon
/// destekleyen başlatıcılarda elle atanabilir.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';
import '../platform/export.dart';

/// Bir ikonu [size] kutusuna çizer.
void paintIcon(Canvas canvas, double size, String key, String shape, List<int> pal) {
  final r = Rect.fromLTWH(0, 0, size, size);
  final bg = Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(pal[2]), Color(pal[1])],
    ).createShader(r);
  switch (shape) {
    case 'circle':
      canvas.drawCircle(r.center, size / 2, bg);
    case 'squircle':
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(size * 0.32)), bg);
    case 'square':
      canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(size * 0.12)), bg);
    default:
      break;
  }
  final fg = Color(shape == 'none' ? pal[2] : pal[3]);
  final g = r.deflate(size * 0.24);
  drawGlyph(canvas, key, g, fg, shape == 'none' ? Color(pal[4]) : Color(pal[1]));
}

/// Genel ikon çizimleri ([box] içinde, [fg] ana renk, [accent] ikinci renk).
void drawGlyph(Canvas c, String key, Rect box, Color fg, Color accent) {
  final s = box.width;
  final x = box.left, y = box.top;
  Offset p(double a, double b) => Offset(x + a * s, y + b * s);
  final fill = Paint()..color = fg;
  final line = Paint()
    ..color = fg
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.09
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final acc = Paint()..color = accent;
  switch (key) {
    case 'phone':
      final path = Path()
        ..moveTo(p(0.18, 0.1).dx, p(0.18, 0.1).dy)
        ..quadraticBezierTo(p(0.02, 0.2).dx, p(0.02, 0.2).dy, p(0.12, 0.42).dx, p(0.12, 0.42).dy)
        ..quadraticBezierTo(p(0.32, 0.8).dx, p(0.32, 0.8).dy, p(0.62, 0.92).dx, p(0.62, 0.92).dy)
        ..quadraticBezierTo(p(0.84, 0.98).dx, p(0.84, 0.98).dy, p(0.92, 0.82).dx, p(0.92, 0.82).dy)
        ..lineTo(p(0.74, 0.64).dx, p(0.74, 0.64).dy)
        ..lineTo(p(0.6, 0.72).dx, p(0.6, 0.72).dy)
        ..quadraticBezierTo(p(0.4, 0.6).dx, p(0.4, 0.6).dy, p(0.3, 0.42).dx, p(0.3, 0.42).dy)
        ..lineTo(p(0.38, 0.28).dx, p(0.38, 0.28).dy)
        ..close();
      c.drawPath(path, fill);
    case 'message':
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.02, 0.08), p(0.98, 0.74)), Radius.circular(s * 0.18)))
        ..moveTo(p(0.22, 0.7).dx, p(0.22, 0.7).dy)
        ..lineTo(p(0.14, 0.95).dx, p(0.14, 0.95).dy)
        ..lineTo(p(0.44, 0.72).dx, p(0.44, 0.72).dy)
        ..close();
      c.drawPath(path, fill);
      for (final dx in [0.28, 0.5, 0.72]) {
        c.drawCircle(p(dx, 0.41), s * 0.06, acc);
      }
    case 'camera':
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.0, 0.25), p(1, 0.9)), Radius.circular(s * 0.14)), fill);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.3, 0.12), p(0.6, 0.3)), Radius.circular(s * 0.05)), fill);
      c.drawCircle(p(0.5, 0.57), s * 0.22, acc);
      c.drawCircle(p(0.5, 0.57), s * 0.12, fill);
    case 'mail':
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0, 0.18), p(1, 0.84)), Radius.circular(s * 0.1)), fill);
      final flap = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07
        ..strokeJoin = StrokeJoin.round;
      c.drawPath(Path()..moveTo(p(0.08, 0.28).dx, p(0.08, 0.28).dy)..lineTo(p(0.5, 0.58).dx, p(0.5, 0.58).dy)..lineTo(p(0.92, 0.28).dx, p(0.92, 0.28).dy), flap);
    case 'music':
      c.drawOval(Rect.fromCenter(center: p(0.25, 0.8), width: s * 0.36, height: s * 0.26), fill);
      c.drawOval(Rect.fromCenter(center: p(0.8, 0.68), width: s * 0.36, height: s * 0.26), fill);
      c.drawLine(p(0.4, 0.8), p(0.4, 0.14), line);
      c.drawLine(p(0.95, 0.68), p(0.95, 0.04), line);
      c.drawPath(
          Path()
            ..moveTo(p(0.4, 0.14).dx, p(0.4, 0.14).dy)
            ..lineTo(p(0.95, 0.02).dx, p(0.95, 0.02).dy)
            ..lineTo(p(0.95, 0.2).dx, p(0.95, 0.2).dy)
            ..lineTo(p(0.4, 0.32).dx, p(0.4, 0.32).dy)
            ..close(),
          fill);
    case 'gallery':
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0, 0.1), p(1, 0.9)), Radius.circular(s * 0.1)), fill);
      c.drawCircle(p(0.72, 0.32), s * 0.1, acc);
      c.drawPath(
          Path()
            ..moveTo(p(0.06, 0.84).dx, p(0.06, 0.84).dy)
            ..lineTo(p(0.36, 0.42).dx, p(0.36, 0.42).dy)
            ..lineTo(p(0.58, 0.7).dx, p(0.58, 0.7).dy)
            ..lineTo(p(0.72, 0.56).dx, p(0.72, 0.56).dy)
            ..lineTo(p(0.94, 0.84).dx, p(0.94, 0.84).dy)
            ..close(),
          acc);
    case 'settings':
      final center = p(0.5, 0.5);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        c.drawLine(center, center + Offset(math.cos(a), math.sin(a)) * s * 0.48, line..strokeWidth = s * 0.16);
      }
      c.drawCircle(center, s * 0.36, fill);
      c.drawCircle(center, s * 0.15, acc);
    case 'calendar':
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.02, 0.12), p(0.98, 0.96)), Radius.circular(s * 0.1)), fill);
      c.drawRect(Rect.fromPoints(p(0.02, 0.3), p(0.98, 0.36)), acc);
      for (var r = 0; r < 3; r++) {
        for (var k = 0; k < 4; k++) {
          c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(x + (0.12 + k * 0.2) * s, y + (0.46 + r * 0.16) * s, s * 0.13, s * 0.1),
                  Radius.circular(s * 0.02)),
              acc);
        }
      }
      c.drawLine(p(0.28, 0.04), p(0.28, 0.2), line..strokeWidth = s * 0.08);
      c.drawLine(p(0.72, 0.04), p(0.72, 0.2), line);
    case 'clock':
      c.drawCircle(p(0.5, 0.5), s * 0.5, fill);
      final h = Paint()
        ..color = accent
        ..strokeWidth = s * 0.08
        ..strokeCap = StrokeCap.round;
      c.drawLine(p(0.5, 0.5), p(0.5, 0.2), h);
      c.drawLine(p(0.5, 0.5), p(0.72, 0.6), h);
      c.drawCircle(p(0.5, 0.5), s * 0.06, acc);
    case 'map':
      final pin = Path()
        ..moveTo(p(0.5, 0.98).dx, p(0.5, 0.98).dy)
        ..quadraticBezierTo(p(0.08, 0.5).dx, p(0.08, 0.5).dy, p(0.14, 0.34).dx, p(0.14, 0.34).dy)
        ..arcToPoint(p(0.86, 0.34), radius: Radius.circular(s * 0.37))
        ..quadraticBezierTo(p(0.92, 0.5).dx, p(0.92, 0.5).dy, p(0.5, 0.98).dx, p(0.5, 0.98).dy)
        ..close();
      c.drawPath(pin, fill);
      c.drawCircle(p(0.5, 0.36), s * 0.14, acc);
    case 'browser':
      c.drawCircle(p(0.5, 0.5), s * 0.5, fill);
      final m = Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05;
      c.drawOval(Rect.fromCenter(center: p(0.5, 0.5), width: s * 0.44, height: s), m);
      c.drawLine(p(0.02, 0.5), p(0.98, 0.5), m);
      c.drawLine(p(0.5, 0.0), p(0.5, 1.0), m);
      c.drawLine(p(0.1, 0.27), p(0.9, 0.27), m);
      c.drawLine(p(0.1, 0.73), p(0.9, 0.73), m);
    case 'notes':
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.1, 0.02), p(0.9, 0.98)), Radius.circular(s * 0.08)), fill);
      final l = Paint()
        ..color = accent
        ..strokeWidth = s * 0.06
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 4; i++) {
        c.drawLine(p(0.24, 0.22 + i * 0.18), p(i == 3 ? 0.56 : 0.76, 0.22 + i * 0.18), l);
      }
    case 'calculator':
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.1, 0.0), p(0.9, 1)), Radius.circular(s * 0.1)), fill);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.2, 0.1), p(0.8, 0.3)), Radius.circular(s * 0.03)), acc);
      for (var r = 0; r < 3; r++) {
        for (var k = 0; k < 3; k++) {
          c.drawCircle(p(0.3 + k * 0.2, 0.46 + r * 0.18), s * 0.065, acc);
        }
      }
    case 'weather':
      c.drawCircle(p(0.36, 0.36), s * 0.24, acc);
      final cloud = Path()
        ..addOval(Rect.fromCenter(center: p(0.42, 0.7), width: s * 0.5, height: s * 0.4))
        ..addOval(Rect.fromCenter(center: p(0.66, 0.6), width: s * 0.5, height: s * 0.5))
        ..addRRect(RRect.fromRectAndRadius(Rect.fromPoints(p(0.2, 0.66), p(0.96, 0.9)), Radius.circular(s * 0.12)));
      c.drawPath(cloud, fill);
    case 'files':
      final path = Path()
        ..moveTo(p(0, 0.2).dx, p(0, 0.2).dy)
        ..lineTo(p(0.36, 0.2).dx, p(0.36, 0.2).dy)
        ..lineTo(p(0.46, 0.32).dx, p(0.46, 0.32).dy)
        ..lineTo(p(1, 0.32).dx, p(1, 0.32).dy)
        ..lineTo(p(1, 0.88).dx, p(1, 0.88).dy)
        ..lineTo(p(0, 0.88).dx, p(0, 0.88).dy)
        ..close();
      c.drawPath(path, fill);
      c.drawRect(Rect.fromPoints(p(0, 0.42), p(1, 0.48)), acc);
    default: // contacts
      c.drawCircle(p(0.5, 0.3), s * 0.22, fill);
      c.drawPath(
        Path()
          ..moveTo(p(0.08, 0.98).dx, p(0.08, 0.98).dy)
          ..quadraticBezierTo(p(0.12, 0.56).dx, p(0.12, 0.56).dy, p(0.5, 0.56).dx, p(0.5, 0.56).dy)
          ..quadraticBezierTo(p(0.88, 0.56).dx, p(0.88, 0.56).dy, p(0.92, 0.98).dx, p(0.92, 0.98).dy)
          ..close(),
        fill,
      );
  }
}

class IconPainter extends CustomPainter {
  final String keyName;
  final String shape;
  final List<int> pal;
  IconPainter(this.keyName, this.shape, this.pal);

  @override
  void paint(Canvas canvas, Size size) => paintIcon(canvas, math.min(size.width, size.height), keyName, shape, pal);

  @override
  bool shouldRepaint(IconPainter old) => old.keyName != keyName || old.shape != shape || old.pal != pal;
}

/// İkonu [px] boyutunda PNG'ye çizer.
Future<Uint8List?> renderIconPng(String key, String shape, List<int> pal, {int px = 512}) async {
  try {
    final rec = ui.PictureRecorder();
    paintIcon(Canvas(rec), px.toDouble(), key, shape, pal);
    final img = await rec.endRecording().toImage(px, px);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

class IconPackTool extends StatefulWidget {
  final ToolContext t;
  const IconPackTool(this.t, {super.key});
  @override
  State<IconPackTool> createState() => _IconPackState();
}

class _IconPackState extends State<IconPackTool> {
  ToolContext get t => widget.t;
  String _shape = kIconShapes.first;
  int _palette = 0;
  bool _extras = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    () async {
      final m = await t.store.readMap('icons');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _shape = kIconShapes.contains(m['shape']) ? m['shape'] as String : _shape;
        _palette = ((m['palette'] as num?)?.toInt() ?? 0).clamp(0, kPalettes.length - 1);
        _extras = ex;
        if (!_extras && _palette >= kFreePalettes) _palette = 0;
      });
    }();
  }

  void _save() => t.store.writeMap('icons', {'shape': _shape, 'palette': _palette});

  Future<void> _one(String key) async {
    final png = await renderIconPng(key, _shape, kPalettes[_palette]);
    if (png != null && mounted) await saveBytesAs(context, t, iconFileName(key, _shape, _palette), png);
  }

  Future<void> _all() async {
    setState(() => _busy = true);
    String? dir;
    var n = 0;
    for (final k in kIconKeys) {
      final png = await renderIconPng(k, _shape, kPalettes[_palette]);
      if (png == null) continue;
      final path = await Exporter.saveBytes(iconFileName(k, _shape, _palette), png);
      if (path != null) {
        n++;
        dir = path.substring(0, path.lastIndexOf(RegExp(r'[/\\]')));
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(n == 0 ? L(t, 'save_failed') : '${L(t, 'saved_to')} $dir ($n)'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 700;
    return ToolList(children: [
      Choice<String>(
        values: kIconShapes,
        labels: [for (final s in kIconShapes) L(t, 'shape_$s')],
        selected: _shape,
        onChanged: (s) {
          setState(() => _shape = s);
          _save();
        },
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      AppPanel(
        child: GridView.count(
          crossAxisCount: wide ? 6 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          children: [
            for (final k in kIconKeys)
              Tooltip(
                message: L(t, 'icon_$k'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _one(k),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: CustomPaint(painter: IconPainter(k, _shape, kPalettes[_palette])),
                  ),
                ),
              ),
          ],
        ),
      ),
      AppInfoCard(L(t, 'icons_tap'), icon: Icons.touch_app_rounded),
      if (Exporter.supported)
        AppButton(label: L(t, 'save_all'), icon: Icons.download_rounded, onPressed: _busy ? null : _all),
      AppInfoCard(L(t, 'icons_note'), icon: Icons.info_outline_rounded),
    ]);
  }
}
