import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisisel_motoru/kisisel_motoru.dart';
import 'package:studio_core/apps/apps.dart';
import 'package:studio_core/app/services/ads.dart';
import 'package:studio_core/app/services/purchases.dart';
import 'package:studio_core/core/save_store.dart';

void main() {
  test('5 araç, 33 dilde ad ve açıklama', () {
    expect(kisiselTools.length, 5);
    expect(kisiselTools.map((t) => t.id).toSet().length, 5);
    for (final t in kisiselTools) {
      expect(t.title.length, 33, reason: t.id);
      expect(t.tagline.length, 33, reason: t.id);
      expect(t.id.startsWith('uyg-'), isTrue);
      expect(kisiselCategories.any((c) => c.id == t.category), isTrue, reason: t.id);
    }
    expect(kisiselHubTitle.length, 33);
  });

  test('sentez: geçerli WAV başlığı ve uzunluk', () {
    final p = kTones.first;
    final wav = synth(p.notes, p.timbre, rate: 8000);
    final b = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(b.getUint32(24, Endian.little), 8000);
    final samples = (wav.length - 44) ~/ 2;
    final ms = p.notes.fold<int>(0, (a, n) => a + n.ms);
    expect(samples, (8000 * ms / 1000).round() + (8000 * 0.08).round());
    // Hız iki katına çıkınca süre yarıya iner, tekrar sayısı uzatır.
    final fast = synth(p.notes, p.timbre, rate: 8000, tempo: 2);
    expect(fast.length, lessThan(wav.length));
    final twice = synth(p.notes, p.timbre, rate: 8000, repeat: 2);
    expect(twice.length, greaterThan(wav.length));
    // Tepe değer ses seviyesini aşmaz.
    var peak = 0;
    for (var i = 44; i < wav.length; i += 2) {
      peak = b.getInt16(i, Endian.little).abs() > peak ? b.getInt16(i, Endian.little).abs() : peak;
    }
    expect(peak, lessThanOrEqualTo((0.8 * 32767).round() + 1));
    expect(peak, greaterThan(1000));
  });

  test('her hazır ses üretilir; anahtarlar benzersiz', () {
    expect(kTones.map((e) => e.key).toSet().length, kTones.length);
    for (final p in kTones) {
      expect(synth(p.notes, p.timbre, rate: 4000).length, greaterThan(44), reason: p.key);
    }
    expect(kTones.where((e) => e.ringtone).length, greaterThanOrEqualTo(5));
    expect(kTones.where((e) => !e.ringtone).length, greaterThanOrEqualTo(5));
  });

  test('frekans, yanma koruması, geri sayım, paletler', () {
    expect(freqOf(0), 440);
    expect(freqOf(12), closeTo(880, 1e-9));
    for (var m = 0; m < 2000; m += 37) {
      final o = burnInOffset(m);
      expect(o.$1.abs(), lessThanOrEqualTo(0.8));
      expect(o.$2.abs(), lessThanOrEqualTo(0.8));
    }
    expect(countdown(DateTime(2026, 1, 1), DateTime(2026, 1, 3, 5, 30)), (2, 5, 30));
    expect(countdown(DateTime(2026, 1, 3, 12), DateTime(2026, 1, 3)).$1, -1);
    for (final p in kPalettes) {
      expect(p.length, 5);
    }
    expect(kFreePalettes, lessThan(kPalettes.length));
    expect(iconFileName('phone', 'circle', 2), 'icon_phone_circle_p2.png');
    expect(kIconKeys.toSet().length, 16);
  });

  test('pano ve saat ayarları kaydedilip geri okunur', () {
    final b = BoardItem(id: 'x', type: 'countdown', palette: 2, title: 'Tatil', date: DateTime(2027, 6, 1));
    final r = BoardItem.fromJson(b.toJson())!;
    expect(r.type, 'countdown');
    expect(r.date, DateTime(2027, 6, 1));
    expect(BoardItem.fromJson({'id': 'y', 'type': 'reklam'}), isNull);
    const c = ClockPrefs(analog: true, palette: 4, dim: 0.5);
    final c2 = ClockPrefs.fromJson(c.toJson());
    expect(c2.analog, isTrue);
    expect(c2.palette, 4);
    expect(c2.dim, 0.5);
    expect(ClockPrefs.fromJson({'dim': 9}).dim, 0.8);
  });

  testWidgets('ikon PNG çizilir', (tester) async {
    final png = await tester.runAsync(() => renderIconPng('camera', 'squircle', kPalettes[0], px: 64));
    expect(png, isNotNull);
    expect(png!.sublist(1, 4), [0x50, 0x4E, 0x47]); // "PNG"
  });

  // Ses paketi testte açılmaz: ses çalar eklentisi test ortamında yok (pilotta da aynı).
  for (final t in ['uyg-canli-duvar-kagidi', 'uyg-widget-paketi', 'uyg-ozgun-ikon-paketi', 'uyg-kilit-ekrani-saati']) {
    testWidgets('araç ekranı açılır: $t', (tester) async {
      final s = AppServices(hubId: 'm', backend: MemoryBackend(), ads: NoAdsService(), purchases: NoPurchaseService());
      final tool = kisiselTool(t);
      final ctx = ToolContext(toolId: t, lang: 'tr', store: s.storeFor(t), services: s);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: AppLook(style: kisiselHubStyle, child: Scaffold(body: Builder(builder: (c) => tool.builder(c, ctx)))),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
