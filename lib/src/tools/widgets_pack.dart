/// Widget paketi: saat, tarih, geri sayım, not ve pil kutucuklarından oluşan
/// bir pano. Uygulama içinde (ör. tablette masa ekranı olarak) tam ekran
/// gösterilir; her kutucuk PNG olarak kaydedilebilir. Android'de her tür,
/// ana ekran widget'ı (AppWidget) olarak da eklenir ve panodaki kendi türünün
/// ilk kutucuğunu gösterir (veri home_widget ile aktarılır). iOS WidgetKit
/// uzantısının kaynakları merkez uygulamanın ios_widget/ klasöründedir.
library;

import 'dart:async';
import 'dart:convert';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:studio_core/apps/apps.dart';

import '../common.dart';
import '../core.dart';
import '../platform/native.dart';

const List<String> kWidgetTypes = ['clock', 'date', 'countdown', 'note', 'battery'];

class BoardItem {
  final String id;
  final String type;
  final int palette;
  final String title;
  final String text;
  final DateTime? date;
  const BoardItem({required this.id, required this.type, this.palette = 0, this.title = '', this.text = '', this.date});

  Map<String, Object?> toJson() =>
      {'id': id, 'type': type, 'palette': palette, 'title': title, 'text': text, 'date': date?.toIso8601String()};

  static BoardItem? fromJson(Map<String, Object?> j) {
    final type = j['type'];
    if (j['id'] is! String || type is! String || !kWidgetTypes.contains(type)) return null;
    return BoardItem(
      id: j['id'] as String,
      type: type,
      palette: ((j['palette'] as num?)?.toInt() ?? 0).clamp(0, kPalettes.length - 1),
      title: j['title'] as String? ?? '',
      text: j['text'] as String? ?? '',
      date: j['date'] is String ? DateTime.tryParse(j['date'] as String) : null,
    );
  }
}

/// Tek bir kutucuk (dakikada bir yenilenir).
class BoardTile extends StatelessWidget {
  final ToolContext t;
  final BoardItem item;
  final DateTime now;
  final int? battery;
  const BoardTile({super.key, required this.t, required this.item, required this.now, this.battery});

  @override
  Widget build(BuildContext context) {
    final p = kPalettes[item.palette];
    final loc = MaterialLocalizations.of(context);
    final fg = Color(p[3]);
    Widget big(String s) => FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(s, style: TextStyle(color: fg, fontSize: 56, fontWeight: FontWeight.w900, height: 1.05)),
        );
    Widget small(String s) => Text(s,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(color: fg.withValues(alpha: 0.8), fontSize: 15, fontWeight: FontWeight.w600));
    final List<Widget> body;
    switch (item.type) {
      case 'clock':
        body = [
          big(loc.formatTimeOfDay(TimeOfDay.fromDateTime(now), alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context))),
          small(loc.formatFullDate(now)),
        ];
      case 'date':
        body = [big('${now.day}'), small(loc.formatMonthYear(now))];
      case 'countdown':
        final d = item.date;
        if (d == null) {
          body = [small(L(t, 'pick_date'))];
        } else {
          final c = countdown(now, d);
          body = [
            small(item.title.isEmpty ? L(t, 'countdown') : item.title),
            big(c.$1 < 0 ? L(t, 'passed') : '${c.$1}'),
            if (c.$1 >= 0) small('${L(t, 'days')} · ${c.$2} ${L(t, 'hours_short')} ${c.$3} ${L(t, 'minutes_short')}'),
          ];
        }
      case 'note':
        body = [
          if (item.title.isNotEmpty) small(item.title),
          Text(item.text.isEmpty ? '…' : item.text,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700)),
        ];
      default:
        body = battery == null
            ? [small(t.tx(kIsWeb ? 'web_unavailable' : 'not_available'))]
            : [
                Icon(Icons.battery_std_rounded, color: fg, size: 34),
                big('%$battery'),
              ];
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(p[1]), Color(p[0])]),
        border: Border.all(color: Color(p[2]).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final w in body) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: w),
      ]),
    );
  }
}

class WidgetPackTool extends StatefulWidget {
  final ToolContext t;
  const WidgetPackTool(this.t, {super.key});
  @override
  State<WidgetPackTool> createState() => _WidgetPackState();
}

class _WidgetPackState extends State<WidgetPackTool> {
  ToolContext get t => widget.t;
  List<BoardItem> _items = [];
  DateTime _now = DateTime.now();
  Timer? _timer;
  int? _battery;
  bool _extras = false;
  bool _canPin = false;
  final Map<String, GlobalKey> _keys = {};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    () async {
      final l = await t.store.readList('board');
      final ex = await extrasOpen(t);
      int? b;
      if (!kIsWeb) {
        try {
          b = await Battery().batteryLevel.timeout(const Duration(seconds: 2));
        } catch (_) {
          b = null;
        }
      }
      if (!mounted) return;
      setState(() {
        _items = l.map(BoardItem.fromJson).whereType<BoardItem>().toList();
        if (_items.isEmpty) {
          _items = [
            BoardItem(id: 'c', type: 'clock'),
            BoardItem(id: 'd', type: 'date', palette: 1),
          ];
        }
        _battery = b;
        _extras = ex;
      });
      if (KisiselNative.android) {
        await KisiselNative.enable(NativeFeature.widgets);
        final pin = await KisiselNative.canPinWidgets();
        if (mounted) setState(() => _canPin = pin);
      }
      await _pushNative();
    }();
  }

  /// Ana ekran widget'larına veri: her türün ilk kutucuğu.
  Future<void> _pushNative() {
    if (!KisiselNative.android && !KisiselNative.ios) return Future<void>.value();
    final data = <String, String>{};
    for (final type in kWidgetTypes) {
      final it = _items.where((x) => x.type == type).firstOrNull;
      final p = kPalettes[it?.palette ?? 0];
      data['w_$type'] = jsonEncode({
        'c0': p[0], 'c1': p[1], 'c2': p[2], 'fg': p[3],
        'title': it?.title ?? '',
        'text': it?.text ?? '',
        'date': it?.date?.millisecondsSinceEpoch ?? 0,
        'days': L(t, 'days'),
        'hours': L(t, 'hours_short'),
        'passed': L(t, 'passed'),
        'pick': L(t, 'pick_date'),
        'label': L(t, 'w_$type'),
      });
    }
    return KisiselNative.pushWidgets(data);
  }

  Future<void> _pin(BoardItem it) async {
    // Bu kutucuk kendi türünün ilki değilse başa alınır (widget ilkini gösterir).
    final first = _items.firstWhere((x) => x.type == it.type);
    if (first.id != it.id) {
      _set([it, for (final x in _items) if (x.id != it.id) x]);
    }
    await _pushNative();
    final ok = await KisiselNative.pinWidget(it.type);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(t.tx('not_available'))));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _set(List<BoardItem> l) {
    setState(() => _items = l);
    t.store.writeList('board', [for (final x in l) x.toJson()]);
    unawaited(_pushNative());
  }

  Future<void> _edit([BoardItem? e]) async {
    var type = e?.type ?? 'clock';
    var palette = e?.palette ?? 0;
    var date = e?.date ?? DateTime.now().add(const Duration(days: 30));
    final title = TextEditingController(text: e?.title ?? '');
    final text = TextEditingController(text: e?.text ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(L(t, e == null ? 'add' : 'edit')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Pick<String>(
                  label: L(t, 'widget_type'),
                  values: kWidgetTypes,
                  text: (k) => L(t, 'w_$k'),
                  value: type,
                  onChanged: (k) => set(() => type = k),
                ),
                if (type == 'countdown' || type == 'note') AppTextField(controller: title, label: L(t, 'title')),
                if (type == 'countdown')
                  DateRow(label: L(t, 'pick_date'), value: date, onChanged: (x) => set(() => date = x), first: DateTime(2000)),
                if (type == 'note') AppTextField(controller: text, label: L(t, 'note_text'), maxLines: 4),
                const SizedBox(height: 8),
                PaletteRow(
                  palettes: kPalettes,
                  selected: palette,
                  free: kFreePalettes,
                  unlocked: _extras,
                  onChanged: (i) => set(() => palette = i),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t.core('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(t.core('ok'))),
          ],
        ),
      ),
    );
    if (ok == true) {
      final n = BoardItem(
        id: e?.id ?? '${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        palette: palette,
        title: title.text.trim(),
        text: text.text.trim(),
        date: type == 'countdown' ? date : null,
      );
      _set([for (final x in _items) x.id == n.id ? n : x, if (e == null) n]);
    }
    title.dispose();
    text.dispose();
  }

  Future<void> _full() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (c) => _FullBoard(t: t, items: _items, battery: _battery),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 700;
    return ToolList(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: wide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            for (final it in _items)
              GestureDetector(
                onTap: () => _edit(it),
                onLongPress: () => _menu(it),
                child: RepaintBoundary(
                  key: _keys.putIfAbsent(it.id, GlobalKey.new),
                  child: BoardTile(t: t, item: it, now: _now, battery: _battery),
                ),
              ),
          ],
        ),
      ),
      AppButton(label: L(t, 'add'), icon: Icons.add_rounded, onPressed: () => _edit()),
      AppButton(label: L(t, 'fullscreen'), icon: Icons.fullscreen_rounded, onPressed: _items.isEmpty ? null : _full),
      if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      AppInfoCard(L(t, KisiselNative.android ? 'widget_note_android' : 'widget_note'), icon: Icons.info_outline_rounded),
    ]);
  }

  Future<void> _menu(BoardItem it) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_canPin)
            ListTile(leading: const Icon(Icons.add_to_home_screen_rounded), title: Text(L(t, 'add_home')), onTap: () => Navigator.pop(c, 'pin')),
          ListTile(leading: const Icon(Icons.download_rounded), title: Text(L(t, 'save_png')), onTap: () => Navigator.pop(c, 'png')),
          ListTile(leading: const Icon(Icons.delete_outline_rounded), title: Text(L(t, 'delete')), onTap: () => Navigator.pop(c, 'del')),
        ]),
      ),
    );
    if (!mounted) return;
    if (a == 'del') _set([for (final x in _items) if (x.id != it.id) x]);
    if (a == 'pin') await _pin(it);
    if (a == 'png') {
      final png = await capturePng(_keys[it.id]!);
      if (png != null && mounted) await saveBytesAs(context, t, 'widget_${it.type}.png', png);
    }
  }
}

class _FullBoard extends StatefulWidget {
  final ToolContext t;
  final List<BoardItem> items;
  final int? battery;
  const _FullBoard({required this.t, required this.items, this.battery});
  @override
  State<_FullBoard> createState() => _FullBoardState();
}

class _FullBoardState extends State<_FullBoard> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cols = size.width > size.height ? 3 : 2;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: cols,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [for (final it in widget.items) BoardTile(t: widget.t, item: it, now: _now, battery: widget.battery)],
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filledTonal(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
          ),
        ]),
      ),
    );
  }
}
