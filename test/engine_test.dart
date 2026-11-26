import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisisel_motoru/kisisel_motoru.dart';
import 'package:kisisel_motoru/src/platform/native.dart';
import 'package:kisisel_motoru/src/tools/widgets_pack.dart' show kWidgetTypes;
import 'package:kisisel_motoru/src/style_core.dart';
import 'package:kisisel_motoru/src/tx.dart';
import 'package:studio_core/apps/apps.dart';
import 'package:studio_core/app/services/ads.dart';
import 'package:studio_core/app/services/purchases.dart';
import 'package:studio_core/core/save_store.dart';

void main() {
  test('13 araç, 33 dilde ad ve açıklama', () {
    expect(kisiselTools.length, 13);
    expect(kisiselTools.map((t) => t.id).toSet().length, 13);
    for (final t in kisiselTools) {
      expect(t.title.length, 33, reason: t.id);
      expect(t.tagline.length, 33, reason: t.id);
      expect(t.id.startsWith('uyg-'), isTrue);
      expect(kisiselCategories.any((c) => c.id == t.category), isTrue, reason: t.id);
    }
    expect(kisiselHubTitle.length, 33);
  });

  test('Android yerel özellikleri: 33 dilde etiketler, widget sağlayıcıları', () {
    for (final k in ['set_live_wallpaper', 'add_home', 'screensaver_settings', 'wall_note_ios',
        'wall_note_android', 'widget_note_android', 'clock_note_android']) {
      final v = kKisL[k];
      expect(v, isNotNull, reason: k);
      expect(v!.length, 33, reason: k);
      expect(v.every((x) => x.trim().isNotEmpty), isTrue, reason: k);
    }
    // "Bu sürümde yok" bildirimi Android notlarında kalmamalı.
    expect(kKisL['wall_note_android']![0].contains('bu sürümde yok'), isFalse);
    expect(kKisL['widget_note_android']![1].contains('in this version'), isFalse);
    expect(kWidgetProviders.keys.toSet(), kWidgetTypes.toSet());
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
  test('renkler: HSL, HEX, kontrast, uyumlar, kilitler', () {
    for (final c in [0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF4F7CAC, 0xFF12AB34, 0xFFF6AD55]) {
      final (h, s, l) = argbToHsl(c);
      final back = hslToArgb(h, s, l);
      for (final sh in [16, 8, 0]) {
        expect((((back >> sh) & 0xFF) - ((c >> sh) & 0xFF)).abs(), lessThanOrEqualTo(1), reason: hexOf(c));
      }
    }
    expect(hexOf(0xFF4F7CAC), '#4F7CAC');
    expect(parseHex('#4f7cac'), 0xFF4F7CAC);
    expect(parseHex('fff'), 0xFFFFFFFF);
    expect(parseHex('#12'), isNull);
    expect(parseHex('zzzzzz'), isNull);
    expect(contrastRatio(0xFF000000, 0xFFFFFFFF), closeTo(21, 0.01));
    expect(contrastRatio(0xFF777777, 0xFF777777), closeTo(1, 1e-9));
    expect(wcagLevel(7.2), 'AAA');
    expect(wcagLevel(4.6), 'AA');
    expect(wcagLevel(3.1), 'AA+');
    expect(wcagLevel(2), '—');
    expect(readableOn(0xFF000000), 0xFFFFFFFF);
    expect(readableOn(0xFFFFFF00), 0xFF000000);
    final r = math.Random(3);
    for (final h in Harmony.values) {
      final p = harmonyPalette(0xFF4F7CAC, h, r);
      expect(p.length, 5, reason: h.name);
      expect(p.every((c) => (c >> 24) == 0xFF), isTrue, reason: h.name);
    }
    // Tamamlayıcı uyumda karşı ton (±180°) bulunur.
    final comp = harmonyPalette(hslToArgb(30, 0.7, 0.5), Harmony.complementary, r);
    expect(comp.any((c) => (argbToHsl(c).$1 - 210).abs() < 2), isTrue);
    final cur = [1, 2, 3, 4, 5].map((i) => 0xFF000000 | i * 0x111111).toList();
    final locked = [false, true, false, false, true];
    for (var k = 0; k < 20; k++) {
      final n = regenerate(cur, locked, Harmony.values[k % Harmony.values.length], r);
      expect(n.length, 5);
      expect(n[1], cur[1]);
      expect(n[4], cur[4]);
    }
    expect(paletteCss([0xFF112233]), contains('--color-1: #112233;'));
    expect(paletteJson([0xFF112233]), '{"colors":["#112233"]}');
    expect(paletteHex([0xFF112233, 0xFFAABBCC]), '#112233, #AABBCC');
  });

  test('şık yazı: Unicode stilleri, boşluklar, aksanlar, ters yazı', () {
    expect(fancy('Ab1', FancyStyle.bold), '𝐀𝐛𝟏');
    expect(fancy('BEh', FancyStyle.script), 'ℬℰ𝒽');
    expect(fancy('h', FancyStyle.italic), 'ℎ');
    expect(fancy('CR', FancyStyle.doubleStruck), 'ℂℝ');
    expect(fancy('Hz', FancyStyle.fraktur), 'ℌ𝔷');
    expect(fancy('a0', FancyStyle.circled), 'ⓐ⓪');
    expect(fancy('A1', FancyStyle.fullwidth), 'Ａ１');
    expect(fancy('a b', FancyStyle.fullwidth), 'ａ\u3000ｂ');
    expect(fancy('abc', FancyStyle.smallCaps), 'ᴀʙᴄ');
    expect(fancy('ab!', FancyStyle.upsideDown), '¡qɐ');
    expect(fancy('ç', FancyStyle.bold), '𝐜\u0327');
    expect(fancy('ab', FancyStyle.strike), 'a\u0336b\u0336');
    expect(fancy('a b', FancyStyle.spaced), 'a b');
    expect(fancy('abc', FancyStyle.spaced), 'a b c');
    expect(fancy('x', FancyStyle.squared), '🅇');
    // Karşılığı olmayan karakterler olduğu gibi kalır.
    expect(fancy('🙂 ü', FancyStyle.mono), '🙂 𝚞\u0308');
    for (final s in FancyStyle.values) {
      expect(fancy('Merhaba 2026', s).isNotEmpty, isTrue, reason: s.name);
    }
    for (final e in kSymbolSets) {
      expect(symbolsOf(e.$1).length, greaterThan(5), reason: e.$1);
    }
    expect(kDecorations.every((d) => d.contains('{t}')), isTrue);
    expect(decorate('X', 2), '【X】');
    expect(kFreeDecorations, lessThan(kDecorations.length));
  });

  test('kenar ışığı ve şarj animasyonu ayarları', () {
    const e = EdgePrefs(enabled: true, style: EdgeStyle.comet, palette: 2, thickness: 9, radius: 12, seconds: 7, speed: 2);
    final e2 = EdgePrefs.fromJson(e.toJson());
    expect(e2.enabled, isTrue);
    expect(e2.style, EdgeStyle.comet);
    expect(e2.thickness, 9);
    expect(EdgePrefs.fromJson({'thickness': 99, 'seconds': 0}).thickness, 16);
    expect(EdgePrefs.fromJson({'thickness': 99, 'seconds': 0}).seconds, 2);
    expect(EdgePrefs.fromJson({'style': 'yok'}).style, EdgeStyle.flow);
    for (var t = 0.0; t < 10; t += 0.37) {
      final p = edgePulse(t, 1.3);
      expect(p, inInclusiveRange(0.15, 1.0));
      expect(edgeCometPos(t, 1.3), inInclusiveRange(0.0, 1.0));
    }
    const c = ChargePrefs(style: ChargeStyle.bars, palette: 1, percent: false, clock: true, closeOnUnplug: true);
    final c2 = ChargePrefs.fromJson(c.toJson());
    expect(c2.style, ChargeStyle.bars);
    expect(c2.percent, isFalse);
    expect(c2.closeOnUnplug, isTrue);
    for (var lv = 0.0; lv <= 1.0; lv += 0.25) {
      for (var x = 0.0; x <= 1.0; x += 0.1) {
        expect((liquidSurface(lv, x, 3.3) - lv).abs(), lessThan(0.03));
      }
    }
    for (var i = 0; i < 30; i++) {
      final (x, y, r) = bubbleAt(i, 12.5);
      expect(x, inInclusiveRange(0.0, 1.0));
      expect(y, inInclusiveRange(0.0, 1.0));
      expect(r, greaterThan(0));
    }
  });

  test('2. tur etiketleri 33 dilde dolu', () {
    for (final k in ['h_analog', 'contrast_note', 'fancy_note', 'edge_note_android', 'edge_note_other', 'charge_note_android',
        'charge_note_other', 'notif_access', 'overlay_perm', 'c_liquid', 'e_comet']) {
      final v = kKisL[k];
      expect(v, isNotNull, reason: k);
      expect(v!.length, 33, reason: k);
      expect(v.every((x) => x.trim().isNotEmpty), isTrue, reason: k);
    }
    expect(kKisCat['cat_style']!.length, 33);
  });

  // Şarj animasyonu testte açılmaz: pil eklentisi (battery_plus) test ortamında yok.
  for (final t in ['uyg-canli-duvar-kagidi', 'uyg-widget-paketi', 'uyg-ozgun-ikon-paketi', 'uyg-kilit-ekrani-saati',
      'uyg-renk-paleti-uretici', 'uyg-sik-yazi-uretici', 'uyg-kenar-isiklandirma', 'uyg-dinamik-ada',
      'uyg-her-zaman-acik-ekran', 'uyg-arama-flasi', 'uyg-estetik-ana-ekran']) {
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
