/// Tema ve renk paleti üretici: ana renkten uyumlu 5 renk (benzer,
/// tamamlayıcı, bölünmüş tamamlayıcı, üçlü, dörtlü, tek renk, rastgele),
/// renk sabitleme, WCAG kontrast denetimi, açık/koyu tema önizlemesi,
/// HEX/CSS/JSON kopyalama, PNG kaydetme ve kayıtlı paletler.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../style_core.dart';

/// Ücretsiz kayıtlı palet sayısı (fazlası ödüllü reklamla bugünlük ya da Premium).
const int kFreeSavedPalettes = 12;

class PaletteTool extends StatefulWidget {
  final ToolContext t;
  const PaletteTool(this.t, {super.key});
  @override
  State<PaletteTool> createState() => _PaletteState();
}

class _PaletteState extends State<PaletteTool> {
  ToolContext get t => widget.t;
  final math.Random _rnd = math.Random();
  final GlobalKey _shot = GlobalKey();
  final TextEditingController _hex = TextEditingController();
  Harmony _harmony = Harmony.analog;
  List<int> _colors = harmonyPalette(0xFF4F7CAC, Harmony.analog, math.Random(1));
  List<bool> _locked = List<bool>.filled(5, false);
  List<List<int>> _saved = [];
  int _fg = 4, _bg = 0;
  bool _dark = false;
  bool _extras = false;

  @override
  void initState() {
    super.initState();
    () async {
      final m = await t.store.readMap('palette');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _extras = ex;
        final c = (m['colors'] as List?)?.whereType<num>().map((e) => e.toInt()).toList();
        if (c != null && c.length == 5) _colors = c;
        _harmony = Harmony.values.firstWhere((h) => h.name == m['harmony'], orElse: () => Harmony.analog);
        final s = m['saved'];
        if (s is List) {
          _saved = [
            for (final p in s)
              if (p is List && p.length == 5) p.whereType<num>().map((e) => e.toInt()).toList(),
          ];
        }
      });
    }();
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _persist() => t.store.writeMap('palette', {'colors': _colors, 'harmony': _harmony.name, 'saved': _saved});

  void _generate() {
    setState(() => _colors = regenerate(_colors, _locked, _harmony, _rnd));
    _persist();
  }

  void _fromBase(int base) {
    setState(() {
      _colors = harmonyPalette(base, _harmony, _rnd);
      _locked = List<bool>.filled(5, false);
    });
    _persist();
  }

  int get _base {
    final i = _locked.indexWhere((x) => x);
    return _colors[i >= 0 ? i : 2];
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t.tx('copied'))));
  }

  Future<void> _save() async {
    if (_saved.length >= kFreeSavedPalettes && !_extras) {
      if (await t.unlockForToday('extras')) {
        setState(() => _extras = true);
      } else {
        return;
      }
    }
    setState(() => _saved.insert(0, List<int>.of(_colors)));
    _persist();
  }

  Future<void> _savePng() async {
    final png = await capturePng(_shot);
    if (png == null || !mounted) return;
    await saveBytesAs(context, t, 'palette_${_colors.map((c) => hexOf(c).substring(1)).join('_')}.png', png);
  }

  Future<void> _editColor(int i) async {
    final (h0, s0, l0) = argbToHsl(_colors[i]);
    var h = h0, s = s0, l = l0;
    _hex.text = hexOf(_colors[i]);
    final res = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final c = hslToArgb(h, s, l);
        Widget slider(String label, double v, double max, ValueChanged<double> on) => Row(children: [
              SizedBox(width: 110, child: Text(label)),
              Expanded(child: Slider(value: v, min: 0, max: max, onChanged: (x) => set(() => on(x)))),
            ]);
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(height: 72, decoration: BoxDecoration(color: Color(c), borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 8),
            slider(L(t, 'hue'), h, 360, (x) => h = x),
            slider(L(t, 'saturation'), s, 1, (x) => s = x),
            slider(L(t, 'lightness'), l, 1, (x) => l = x),
            TextField(
              controller: _hex,
              decoration: InputDecoration(labelText: L(t, 'hex_code'), border: const OutlineInputBorder()),
              onSubmitted: (v) {
                final p = parseHex(v);
                if (p != null) {
                  set(() {
                    final x = argbToHsl(p);
                    h = x.$1;
                    s = x.$2;
                    l = x.$3;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(L(t, 'use_as_base')),
                  onPressed: () => Navigator.pop(ctx, -hslToArgb(h, s, l)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.check_rounded),
                  label: Text(t.core('ok')),
                  onPressed: () => Navigator.pop(ctx, hslToArgb(h, s, l)),
                ),
              ),
            ]),
          ]),
        );
      }),
    );
    if (res == null || !mounted) return;
    if (res < 0) {
      _fromBase(-res);
    } else {
      setState(() => _colors[i] = res);
      _persist();
    }
  }

  Widget _swatch(int i) {
    final c = _colors[i];
    final on = Color(readableOn(c));
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _locked[i] = !_locked[i]),
        onLongPress: () => _copy(hexOf(c)),
        onDoubleTap: () => _editColor(i),
        child: Container(
          height: 150,
          color: Color(c),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton(
              icon: Icon(Icons.edit_rounded, color: on, size: 18),
              onPressed: () => _editColor(i),
            ),
            Icon(_locked[i] ? Icons.lock_rounded : Icons.lock_open_rounded, color: on.withValues(alpha: _locked[i] ? 1 : 0.5)),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FittedBox(child: Text(hexOf(c).substring(1), style: TextStyle(color: on, fontWeight: FontWeight.w700))),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _preview() {
    final scheme = ColorScheme.fromSeed(seedColor: Color(_base), brightness: _dark ? Brightness.dark : Brightness.light);
    return Theme(
      data: ThemeData(colorScheme: scheme, useMaterial3: true),
      child: Builder(builder: (context) {
        final cs = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(L(t, 'sample_title'), style: TextStyle(color: cs.onSurface, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(L(t, 'sample_body'), style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: () {}, child: Text(L(t, 'sample_button'))),
              OutlinedButton(onPressed: () {}, child: Text(L(t, 'sample_button'))),
              Chip(label: Text(hexOf(_base)), backgroundColor: cs.secondaryContainer),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (final c in [cs.primary, cs.secondary, cs.tertiary, cs.primaryContainer, cs.surfaceContainerHighest])
                Expanded(
                  child: GestureDetector(
                    onLongPress: () => _copy(hexOf(c.toARGB32())),
                    child: Container(height: 28, color: c),
                  ),
                ),
            ]),
          ]),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ratio = contrastRatio(_colors[_fg], _colors[_bg]);
    final names = {
      Harmony.analog: 'h_analog', Harmony.complementary: 'h_complementary', Harmony.split: 'h_split',
      Harmony.triad: 'h_triad', Harmony.tetrad: 'h_tetrad', Harmony.mono: 'h_mono', Harmony.random: 'h_random',
    };
    return ToolList(children: [
      RepaintBoundary(
        key: _shot,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Row(children: [for (var i = 0; i < 5; i++) _swatch(i)]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(L(t, 'palette_hint'), style: const TextStyle(color: Colors.white60, fontSize: 13)),
      ),
      Pick<Harmony>(
        label: L(t, 'harmony'),
        values: Harmony.values,
        text: (h) => L(t, names[h]!),
        value: _harmony,
        onChanged: (h) {
          setState(() => _harmony = h);
          _generate();
        },
      ),
      AppButton(label: L(t, 'new_palette'), icon: Icons.casino_rounded, onPressed: _generate),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        OutlinedButton.icon(icon: const Icon(Icons.bookmark_add_rounded), label: Text(L(t, 'save_palette')), onPressed: _save),
        OutlinedButton.icon(icon: const Icon(Icons.image_rounded), label: Text(L(t, 'save_png')), onPressed: _savePng),
        OutlinedButton(onPressed: () => _copy(paletteHex(_colors)), child: const Text('HEX')),
        OutlinedButton(onPressed: () => _copy(paletteCss(_colors)), child: const Text('CSS')),
        OutlinedButton(onPressed: () => _copy(paletteJson(_colors)), child: const Text('JSON')),
      ]),
      AppHeading(L(t, 'contrast'), icon: Icons.contrast_rounded),
      AppPanel(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Color(_colors[_bg]), borderRadius: BorderRadius.circular(12)),
            child: Text(L(t, 'sample_body'), style: TextStyle(color: Color(_colors[_fg]), fontSize: 18, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(L(t, 'text_color'))),
            for (var i = 0; i < 5; i++) _dot(i, _fg, (v) => setState(() => _fg = v)),
          ]),
          Row(children: [
            Expanded(child: Text(L(t, 'background'))),
            for (var i = 0; i < 5; i++) _dot(i, _bg, (v) => setState(() => _bg = v)),
          ]),
          const SizedBox(height: 8),
          Text('${ratio.toStringAsFixed(2)} : 1   ·   ${wcagLevel(ratio)}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(L(t, 'contrast_note'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        ]),
      ),
      AppHeading(L(t, 'theme_preview'), icon: Icons.phone_android_rounded),
      Choice<bool>(
        values: const [false, true],
        labels: [L(t, 'light'), L(t, 'dark')],
        selected: _dark,
        onChanged: (b) => setState(() => _dark = b),
      ),
      _preview(),
      if (_saved.isNotEmpty) AppHeading(L(t, 'saved_palettes'), icon: Icons.bookmarks_rounded),
      for (var k = 0; k < _saved.length; k++)
        Card(
          child: ListTile(
            title: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(children: [for (final c in _saved[k]) Expanded(child: Container(height: 32, color: Color(c)))]),
            ),
            onTap: () {
              setState(() {
                _colors = List<int>.of(_saved[k]);
                _locked = List<bool>.filled(5, false);
              });
              _persist();
            },
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: L(t, 'delete'),
              onPressed: () {
                setState(() => _saved.removeAt(k));
                _persist();
              },
            ),
          ),
        ),
      if (!_extras && _saved.length >= kFreeSavedPalettes) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
    ]);
  }

  Widget _dot(int i, int sel, ValueChanged<int> on) => GestureDetector(
        onTap: () => on(i),
        child: Container(
          margin: const EdgeInsets.all(3),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Color(_colors[i]),
            shape: BoxShape.circle,
            border: Border.all(color: i == sel ? Colors.white : Colors.white24, width: i == sel ? 3 : 1),
          ),
        ),
      );
}

/// Test ve dışa aktarma için: kayıtlı paletleri JSON'dan okur.
List<List<int>> decodeSavedPalettes(String raw) {
  try {
    final j = jsonDecode(raw);
    if (j is! Map || j['saved'] is! List) return [];
    return [
      for (final p in j['saved'] as List)
        if (p is List && p.length == 5) p.whereType<num>().map((e) => e.toInt()).toList(),
    ];
  } catch (_) {
    return [];
  }
}
