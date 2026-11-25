/// Şık yazı ve sembol üretici: yazılan metni 28 Unicode stiline çevirir
/// (kalın, eğik, el yazısı, gotik, çift çizgili, daire, kare, ters…),
/// süsleme kalıpları ekler ve kategorili sembol kataloğu sunar. Dokununca
/// kopyalanır. Hepsi standart Unicode karakterlerdir; yazı tipi indirilmez.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../style_core.dart';

const Map<String, IconData> _setIcons = {
  'star': Icons.star_rounded,
  'heart': Icons.favorite_rounded,
  'arrow': Icons.arrow_forward_rounded,
  'shape': Icons.category_rounded,
  'check': Icons.check_box_rounded,
  'math': Icons.calculate_rounded,
  'money': Icons.payments_rounded,
  'music': Icons.music_note_rounded,
  'weather': Icons.wb_sunny_rounded,
  'bracket': Icons.data_array_rounded,
  'line': Icons.horizontal_rule_rounded,
  'face': Icons.emoji_emotions_rounded,
};

class FancyTextTool extends StatefulWidget {
  final ToolContext t;
  const FancyTextTool(this.t, {super.key});
  @override
  State<FancyTextTool> createState() => _FancyTextState();
}

class _FancyTextState extends State<FancyTextTool> {
  ToolContext get t => widget.t;
  final TextEditingController _text = TextEditingController();
  int _tab = 0;
  String _set = 'star';
  List<String> _recent = [];
  bool _extras = false;

  @override
  void initState() {
    super.initState();
    _text.text = L(t, 'fancy_sample');
    () async {
      final m = await t.store.readMap('fancy');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _extras = ex;
        if (m['text'] is String && (m['text'] as String).isNotEmpty) _text.text = m['text'] as String;
        if (m['recent'] is List) _recent = (m['recent'] as List).whereType<String>().toList();
      });
    }();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _persist() => t.store.writeMap('fancy', {'text': _text.text, 'recent': _recent});

  void _copy(String s, {bool symbol = false}) {
    Clipboard.setData(ClipboardData(text: s));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('${t.tx('copied')}  $s'), duration: const Duration(seconds: 1)));
    if (symbol) {
      setState(() {
        _recent.remove(s);
        _recent.insert(0, s);
        if (_recent.length > 24) _recent = _recent.sublist(0, 24);
      });
    }
    _persist();
  }

  /// Seçilen sembolü metnin sonuna ekler.
  void _append(String s) {
    _text.text = '${_text.text}$s';
    _copy(s, symbol: true);
  }

  Widget _resultTile(String s, {bool locked = false}) => Card(
        child: ListTile(
          title: Text(s, style: const TextStyle(fontSize: 20), maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: locked ? const Icon(Icons.lock_rounded) : const Icon(Icons.copy_rounded),
          onTap: locked ? null : () => _copy(s),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = _text.text.isEmpty ? L(t, 'fancy_sample') : _text.text;
    return ToolList(children: [
      AppTextField(controller: _text, label: L(t, 'type_text'), maxLines: 2, onChanged: (_) => setState(() {})),
      Choice<int>(
        values: const [0, 1, 2],
        labels: [L(t, 'letter_styles'), L(t, 'decorations'), L(t, 'symbols')],
        selected: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
      if (_tab == 0) ...[
        for (final s in FancyStyle.values) _resultTile(fancy(text, s)),
      ] else if (_tab == 1) ...[
        for (var i = 0; i < kDecorations.length; i++)
          _resultTile(decorate(text, i), locked: i >= kFreeDecorations && !_extras),
        if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      ] else ...[
        if (_recent.isNotEmpty) ...[
          AppHeading(t.tx('recent'), icon: Icons.history_rounded),
          _grid(_recent),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in kSymbolSets)
              ChoiceChip(
                label: Icon(_setIcons[e.$1], size: 20),
                selected: _set == e.$1,
                onSelected: (_) => setState(() => _set = e.$1),
              ),
          ]),
        ),
        _grid(symbolsOf(_set)),
      ],
      AppInfoCard(L(t, 'fancy_note'), icon: Icons.info_outline_rounded),
    ]);
  }

  Widget _grid(List<String> items) => Wrap(spacing: 6, runSpacing: 6, children: [
        for (final s in items)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _append(s),
            onLongPress: () => _copy(s, symbol: true),
            child: Container(
              constraints: const BoxConstraints(minWidth: 46, minHeight: 46),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
              child: Text(s, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ]);
}
