/// Estetik ana ekran: seçtiğin uygulama için temalı kısayol simgesi.
/// Android'de başlatıcıya "ana ekrana sabitle" isteği gönderilir
/// (ShortcutManager.requestPinShortcut, izin gerekmez); kısayol seçilen
/// uygulamayı açar, uygulamanın kendisi değişmez. Uygulama listesi yalnız
/// başlatıcı uygulamalarıdır (<queries> LAUNCHER; QUERY_ALL_PACKAGES yok) ve
/// cihazdan çıkmaz. Simgeler genel kategori çizimleri ya da baş harftir:
/// hiçbir markanın logosu yoktur. iOS ve web: PNG kaydet + Kestirmeler
/// uygulamasıyla ana ekrana ekleme adımları.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';
import '../ek4_core.dart';
import '../platform/native.dart';
import 'icons.dart' show drawGlyph;

/// Temalı kısayol simgesini [size] kutusuna çizer.
void paintAesthetic(Canvas canvas, double size, AestheticTheme th, String shape, String glyph, String letter) {
  final r = Rect.fromLTWH(0, 0, size, size);
  final bg = Paint();
  if (th.fill == ThemeFill.gradient) {
    bg.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(th.bg), Color(th.bg2)],
    ).createShader(r);
  } else {
    bg.color = Color(th.bg);
  }
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.04
    ..color = Color(th.fg);
  final inner = r.deflate(size * 0.02);
  void draw(Paint p, Rect box) {
    switch (shape) {
      case 'circle':
        canvas.drawCircle(box.center, box.width / 2, p);
      case 'squircle':
        canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.32)), p);
      case 'square':
        canvas.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(box.width * 0.12)), p);
      default:
        break;
    }
  }

  draw(bg, r);
  if (th.fill == ThemeFill.outline) draw(outline, inner);
  final fg = Color(th.fg);
  final box = r.deflate(size * 0.25);
  if (glyph == 'letter') {
    final tp = TextPainter(
      text: TextSpan(text: letter, style: TextStyle(color: fg, fontSize: size * 0.46, fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  } else {
    drawGlyph(canvas, glyph, box, fg, Color(th.accent));
  }
}

class AestheticPainter extends CustomPainter {
  final AestheticTheme th;
  final String shape, glyph, letter;
  AestheticPainter(this.th, this.shape, this.glyph, this.letter);

  @override
  void paint(Canvas canvas, Size size) => paintAesthetic(canvas, math.min(size.width, size.height), th, shape, glyph, letter);

  @override
  bool shouldRepaint(AestheticPainter old) =>
      old.th != th || old.shape != shape || old.glyph != glyph || old.letter != letter;
}

/// Simgeyi [px] boyutunda PNG'ye çizer.
Future<Uint8List?> renderAestheticPng(AestheticTheme th, String shape, String glyph, String letter, {int px = 432}) async {
  try {
    final rec = ui.PictureRecorder();
    paintAesthetic(Canvas(rec), px.toDouble(), th, shape, glyph, letter);
    final img = await rec.endRecording().toImage(px, px);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

class HomeIconsTool extends StatefulWidget {
  final ToolContext t;
  const HomeIconsTool(this.t, {super.key});
  @override
  State<HomeIconsTool> createState() => _HomeIconsState();
}

class _HomeIconsState extends State<HomeIconsTool> {
  ToolContext get t => widget.t;
  int _theme = 0;
  String _shape = 'squircle';
  String _glyph = 'letter';
  bool _extras = false, _canPin = false;
  List<LauncherApp> _apps = const [];
  LauncherApp? _app;
  final TextEditingController _label = TextEditingController();

  AestheticTheme get _th => kAestheticThemes[_theme];

  String get _letter => initialOf(_label.text.isEmpty ? (_app?.label ?? '') : _label.text);

  @override
  void initState() {
    super.initState();
    () async {
      final m = await t.store.readMap('home_icons');
      final ex = await extrasOpen(t);
      final apps = await KisiselNative.listApps();
      final pin = await KisiselNative.canPinShortcuts();
      if (!mounted) return;
      setState(() {
        _theme = ((m['theme'] as num?)?.toInt() ?? 0).clamp(0, kAestheticThemes.length - 1);
        _shape = kIconShapes.contains(m['shape']) ? m['shape'] as String : _shape;
        _extras = ex;
        if (!_extras && _theme >= kFreeThemes) _theme = 0;
        _apps = apps;
        _canPin = pin;
      });
    }();
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _save() => t.store.writeMap('home_icons', {'theme': _theme, 'shape': _shape});

  Future<void> _pickApp() async {
    final picked = await showModalBottomSheet<LauncherApp>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _AppPicker(t: t, apps: _apps),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _app = picked;
      _label.text = picked.label;
      _glyph = suggestGlyph(picked.package, picked.category);
    });
  }

  Future<void> _pin() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final app = _app;
    if (app == null) {
      messenger?.showSnackBar(SnackBar(content: Text(L(t, 'ah_no_app'))));
      return;
    }
    final png = await renderAestheticPng(_th, _shape, _glyph, _letter);
    if (png == null) return;
    final label = _label.text.trim().isEmpty ? app.label : _label.text.trim();
    final ok = await KisiselNative.pinShortcut(app.package, label, png);
    messenger?.showSnackBar(SnackBar(content: Text(L(t, ok ? 'ah_added' : 'ah_unsupported'))));
  }

  Future<void> _savePng() async {
    final png = await renderAestheticPng(_th, _shape, _glyph, _letter, px: 512);
    if (png == null || !mounted) return;
    final name = _label.text.trim().isEmpty ? (_app?.label ?? 'app') : _label.text.trim();
    await saveBytesAs(context, t, homeIconFileName(name, _th.key), png);
  }

  Widget _icon(AestheticTheme th, String glyph, double size) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: AestheticPainter(th, _shape, glyph, _letter)),
      );

  @override
  Widget build(BuildContext context) {
    final label = _label.text.trim().isEmpty ? (_app?.label ?? L(t, 'ah_label')) : _label.text.trim();
    return ToolList(children: [
      AppPanel(
        child: Column(children: [
          _icon(_th, _glyph, 120),
          const SizedBox(height: 8),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          // Aynı temayla küçük bir ana ekran örneği.
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            for (final g in const ['phone', 'message', 'camera', 'music', 'map', 'settings']) _icon(_th, g, 44),
          ]),
        ]),
      ),
      if (KisiselNative.android)
        AppButton(
          label: _app == null ? L(t, 'ah_pick_app') : '${L(t, 'ah_pick_app')}: ${_app!.label}',
          icon: Icons.apps_rounded,
          onPressed: _apps.isEmpty ? null : _pickApp,
        ),
      AppTextField(controller: _label, label: L(t, 'ah_label'), onChanged: (_) => setState(() {})),
      AppHeading(L(t, 'ah_theme'), icon: Icons.palette_rounded),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < kAestheticThemes.length; i++)
            _ThemeChip(
              label: L(t, 'th_${kAestheticThemes[i].key}'),
              icon: _icon(kAestheticThemes[i], _glyph, 40),
              selected: i == _theme,
              locked: i >= kFreeThemes && !_extras,
              onTap: () {
                setState(() => _theme = i);
                _save();
              },
            ),
        ]),
      ),
      if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      Choice<String>(
        values: kIconShapes,
        labels: [for (final s in kIconShapes) L(t, 'shape_$s')],
        selected: _shape,
        onChanged: (s) {
          setState(() => _shape = s);
          _save();
        },
      ),
      AppHeading(L(t, 'ah_symbol'), icon: Icons.category_rounded),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in kHomeGlyphs)
            Tooltip(
              message: g == 'letter' ? L(t, 'ah_letter') : L(t, 'icon_$g'),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _glyph = g),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: g == _glyph ? Colors.white : Colors.white12, width: g == _glyph ? 2 : 1),
                  ),
                  child: _icon(_th, g, 40),
                ),
              ),
            ),
        ]),
      ),
      if (KisiselNative.android && _canPin)
        AppButton(label: L(t, 'add_home'), icon: Icons.add_to_home_screen_rounded, onPressed: _pin),
      if (KisiselNative.android && !_canPin) AppInfoCard(L(t, 'ah_unsupported'), icon: Icons.info_outline_rounded),
      AppButton(label: L(t, 'save_png'), icon: Icons.download_rounded, onPressed: _savePng),
      AppInfoCard(L(t, KisiselNative.android ? 'ah_note_android' : 'ah_note_other'), icon: Icons.privacy_tip_outlined),
    ]);
  }
}

class _ThemeChip extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool selected, locked;
  final VoidCallback onTap;
  const _ThemeChip({required this.label, required this.icon, required this.selected, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: locked ? null : onTap,
        child: Container(
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? Colors.white : Colors.white12, width: selected ? 2 : 1),
          ),
          child: Column(children: [
            Stack(alignment: Alignment.center, children: [
              Opacity(opacity: locked ? 0.45 : 1, child: icon),
              if (locked) const Icon(Icons.lock_rounded, size: 18, color: Colors.white),
            ]),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      );
}

/// Uygulama seçici: arama alanı ve liste.
class _AppPicker extends StatefulWidget {
  final ToolContext t;
  final List<LauncherApp> apps;
  const _AppPicker({required this.t, required this.apps});
  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = q.isEmpty ? widget.apps : widget.apps.where((a) => a.label.toLowerCase().contains(q)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              autofocus: false,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), labelText: widget.t.tx('search')),
              onChanged: (s) => setState(() => _q = s),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(widget.t.tx('no_results')))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) => ListTile(
                      leading: const Icon(Icons.apps_rounded),
                      title: Text(list[i].label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.pop(context, list[i]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}
