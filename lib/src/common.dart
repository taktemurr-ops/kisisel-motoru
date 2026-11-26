/// Kişiselleştirme araçlarının ortak yardımcıları (arac-motoru'ndan
/// kopyalanıp sadeleştirildi): çeviri, liste düzeni, seçim alanları, ses
/// çalar, dosya kaydetme ve ekstraların kilidi.
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:studio_core/app/studio_ui.dart';
import 'package:studio_core/apps/apps.dart';

import 'platform/export.dart';
import 'tx.dart';

/// Araç etiketi (33 dil).
String L(ToolContext t, String key) => t.t(kKisL[key] ?? [key]);

/// Virgülle ayrılmış etiket listesi.
List<String> Ls(ToolContext t, String key) => L(t, key).split(',');

/// Aracın gövdesi: kaydırılabilir sütun.
class ToolList extends StatelessWidget {
  final List<Widget> children;
  const ToolList({super.key, required this.children});

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.only(top: 8, bottom: 32), children: children);
}

/// "Bu cihazda yok" bilgisi.
Widget notAvailable(ToolContext t) =>
    AppInfoCard(t.tx(kIsWeb ? 'web_unavailable' : 'not_available'), icon: Icons.sensors_off_rounded);

/// Büyük sayı göstergesi.
class BigReadout extends StatelessWidget {
  final String value;
  final String unit;
  final String? caption;
  const BigReadout(this.value, {super.key, this.unit = '', this.caption});

  @override
  Widget build(BuildContext context) {
    final s = AppLook.of(context);
    return AppPanel(
      child: Column(children: [
        if (caption != null) Text(caption!, style: const TextStyle(color: Colors.white70, fontSize: 15)),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(value, style: TextStyle(color: s.number, fontSize: 64, fontWeight: FontWeight.w900)),
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Seçenek düğmeleri (SegmentedButton) için kısa yol.
class Choice<T> extends StatelessWidget {
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;
  const Choice({super.key, required this.values, required this.labels, required this.selected, required this.onChanged});

  /// Onaylı tasarımın hap çipleri (seçili olan vurgu renginde).
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < values.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  widthFactor: 1,
                  child: StudioPill(
                    label: labels[i],
                    selected: values[i] == selected,
                    onTap: () => onChanged(values[i]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Açılır liste.
class Pick<T> extends StatelessWidget {
  final String label;
  final List<T> values;
  final String Function(T) text;
  final T value;
  final ValueChanged<T> onChanged;
  const Pick({
    super.key,
    required this.label,
    required this.values,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        dropdownColor: StudioLook.of(context).sheet,
        borderRadius: BorderRadius.circular(16),
        iconEnabledColor: StudioLook.of(context).accent,
        decoration: InputDecoration(
          labelText: label,
        ),
        items: [for (final v in values) DropdownMenuItem<T>(value: v, child: Text(text(v), overflow: TextOverflow.ellipsis))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// Düz metin alanı.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.onChanged,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        obscureText: obscure,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 17),
        decoration: InputDecoration(
          labelText: label,
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

/// Tarih seçme satırı.
class DateRow extends StatelessWidget {
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? first;
  final DateTime? last;
  const DateRow({super.key, required this.label, required this.value, required this.onChanged, this.first, this.last});

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event_rounded),
      title: Text(label),
      subtitle: Text(loc.formatFullDate(value)),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: first ?? DateTime(1800),
          lastDate: last ?? DateTime(2300),
        );
        if (d != null) onChanged(d);
      },
    );
  }
}

/// Tek bir ses çalar; kapanınca kaynakları bırakır.
class TonePlayer {
  final AudioPlayer _p = AudioPlayer();

  Future<void> play(Uint8List wav, {bool loop = false}) async {
    try {
      await _p.stop();
      await _p.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
      await _p.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {/* ses yoksa sessiz geç */}
  }

  Future<void> stop() async {
    try {
      await _p.stop();
    } catch (_) {}
  }

  void dispose() {
    unawaited(_p.dispose());
  }
}


// ------------------------------------------------------------ dosyalar

/// Baytları kullanıcının seçtiği yere kaydeder (sistem "Farklı kaydet"
/// penceresi; depolama izni gerekmez). Olmazsa uygulama klasörüne yazar.
/// Kaydedilen yolu ya da null döndürür ve sonucu kısa bir notla bildirir.
Future<String?> saveBytesAs(BuildContext context, ToolContext t, String name, Uint8List bytes) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  String? path;
  try {
    path = await FilePicker.platform.saveFile(fileName: name, bytes: bytes);
  } catch (_) {
    path = null;
  }
  if (path == null && Exporter.supported) {
    path = await Exporter.saveBytes(name, bytes);
  }
  messenger?.showSnackBar(SnackBar(content: Text(path == null ? L(t, 'save_failed') : '${L(t, 'saved_to')} $path')));
  return path;
}

/// Bir RepaintBoundary'nin görüntüsünü PNG olarak alır.
Future<Uint8List?> capturePng(GlobalKey key, {double pixelRatio = 3}) async {
  try {
    final b = key.currentContext?.findRenderObject();
    if (b is! RenderRepaintBoundary) return null;
    final img = await b.toImage(pixelRatio: pixelRatio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

// --------------------------------------------------------------- ekstra

/// Ekstra (Premium) içerik açık mı? Premium/reklamsız alanlar için her zaman,
/// diğerleri için ödüllü reklamla bugünlük.
Future<bool> extrasOpen(ToolContext t) => t.unlockedToday('extras');

/// Kilitli ekstra için düğme: ödüllü reklamla bugünlük açar.
class UnlockButton extends StatelessWidget {
  final ToolContext t;
  final VoidCallback onUnlocked;
  const UnlockButton({super.key, required this.t, required this.onUnlocked});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: StudioButton(
          tone: StudioButtonTone.gold,
          label: t.tx('unlock_ad'),
          icon: Icons.ondemand_video_rounded,
          onPressed: () async {
            if (await t.unlockForToday('extras')) onUnlocked();
          },
        ),
      );
}

/// Renk paletini seçme çipleri; kilitli olanlar asma kilitle görünür.
class PaletteRow extends StatelessWidget {
  final List<List<int>> palettes;
  final int selected;
  final int free;
  final bool unlocked;
  final ValueChanged<int> onChanged;
  const PaletteRow({
    super.key,
    required this.palettes,
    required this.selected,
    required this.free,
    required this.unlocked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (var i = 0; i < palettes.length; i++)
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: (i < free || unlocked) ? () => onChanged(i) : null,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [Color(palettes[i][1]), Color(palettes[i][2])]),
              border: Border.all(color: i == selected ? Colors.white : Colors.white24, width: i == selected ? 3 : 1),
            ),
            child: (i < free || unlocked) ? null : const Icon(Icons.lock_rounded, size: 18, color: Colors.white70),
          ),
        ),
    ]);
  }
}
