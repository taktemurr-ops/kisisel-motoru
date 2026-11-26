// 4. tur: dinamik ada, her zaman açık ekran, arama flaşı, estetik ana ekran.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kisisel_motoru/kisisel_motoru.dart';
import 'package:kisisel_motoru/src/core.dart' show kIconKeys, kPalettes;
import 'package:kisisel_motoru/src/ek4_core.dart';
import 'package:kisisel_motoru/src/tools/home_icons.dart';
import 'package:kisisel_motoru/src/tools/island.dart';
import 'package:kisisel_motoru/src/tx.dart';

void main() {
  test('yeni araçlar kayıtlı, 33 dilde etiketler dolu', () {
    for (final id in ['uyg-dinamik-ada', 'uyg-her-zaman-acik-ekran', 'uyg-arama-flasi', 'uyg-estetik-ana-ekran']) {
      final t = kisiselTool(id);
      expect(t.title.length, 33, reason: id);
      expect(t.title.every((x) => x.trim().isNotEmpty), isTrue, reason: id);
    }
    for (final k in [
      'isl_enable', 'isl_title_note', 'isl_note_android', 'isl_note_other', 'aod_note_android', 'aod_note_other',
      'aod_stacked', 'aod_ring', 'aod_minimal', 'cf_note_android', 'cf_note_other', 'cf_no_flash', 'ah_note_android',
      'ah_note_other', 'ah_added', 'ah_unsupported', 'th_pastel', 'th_neon',
    ]) {
      final v = kKisL[k];
      expect(v, isNotNull, reason: k);
      expect(v!.length, 33, reason: k);
      expect(v.every((x) => x.trim().isNotEmpty), isTrue, reason: k);
    }
    for (final th in kAestheticThemes) {
      expect(kKisL['th_${th.key}'], isNotNull, reason: th.key);
    }
    // Apple'ın adı kullanılmaz.
    for (final x in kisiselTool('uyg-dinamik-ada').title) {
      expect(x.toLowerCase().contains('dynamic island'), isFalse);
    }
  });

  test('ada ayarları sınırlanır ve geri okunur', () {
    const p = IslandPrefs(enabled: true, showTitle: true, idle: true, width: 150, height: 40, offset: 20, seconds: 6, palette: 2);
    final p2 = IslandPrefs.fromJson(p.toJson());
    expect(p2.toJson(), p.toJson());
    final bad = IslandPrefs.fromJson({'width': 999, 'height': 1, 'offset': -5, 'seconds': 99, 'palette': 99});
    expect(bad.width, 220);
    expect(bad.height, 24);
    expect(bad.offset, 0);
    expect(bad.seconds, 10);
    expect(bad.palette, kPalettes.length - 1);
    expect(const IslandPrefs().showTitle, isFalse, reason: 'başlık varsayılan olarak kapalı');
    final (w, h) = islandExpanded(120, 34, 400);
    expect(w, 312);
    expect(h, 68);
    expect(islandExpanded(200, 30, 300).$1, closeTo(276, 1e-9));
    expect(p.native()['accent'], kPalettes[2][2]);
  });

  test('AOD: ayarlar, pil eşiği, rakamlar', () {
    const p = AodPrefs(face: AodFace.ring, alarm: false, dim: 0.5, stopBelow: 30, palette: 1, note: 'Merhaba');
    expect(AodPrefs.fromJson(p.toJson()).toJson(), p.toJson());
    expect(AodPrefs.fromJson({'face': 'yok'}).face, AodFace.stacked);
    expect(AodPrefs.fromJson({'dim': 5, 'stopBelow': 99}).dim, 0.8);
    expect(AodPrefs.fromJson({'stopBelow': 99}).stopBelow, 50);
    expect(aodShouldStop(10, false, 20), isTrue);
    expect(aodShouldStop(10, true, 20), isFalse);
    expect(aodShouldStop(10, false, 0), isFalse);
    expect(aodShouldStop(null, false, 20), isFalse);
    expect(aodDigits(DateTime(2026, 1, 1, 7, 5), true), ('07', '05'));
    expect(aodDigits(DateTime(2026, 1, 1, 0, 30), false), ('12', '30'));
    expect(aodDigits(DateTime(2026, 1, 1, 13, 0), false), ('1', '00'));
    expect(p.native()['fg'], kPalettes[1][3]);
  });

  test('arama flaşı ritimleri Android ile aynı', () {
    expect(flashCycle(FlashPattern.steady, 1), [300, 300]);
    expect(flashCycle(FlashPattern.heart, 1), [120, 120, 120, 600]);
    expect(flashCycle(FlashPattern.fast, 2), [40, 40]);
    expect(flashCycle(FlashPattern.steady, 9), [150, 150], reason: 'hız en çok 2');
    expect(flashCycle(FlashPattern.fast, 0.1), [160, 160], reason: 'hız en az 0,5');
    final c = flashCycle(FlashPattern.heart, 1);
    expect(flashOnAt(c, 0), isTrue);
    expect(flashOnAt(c, 130), isFalse);
    expect(flashOnAt(c, 250), isTrue);
    expect(flashOnAt(c, 400), isFalse);
    expect(flashOnAt(c, 960), isTrue, reason: 'döngü başa sarar');
    const f = CallFlashPrefs(enabled: true, screen: true, pattern: FlashPattern.fast, speed: 1.5, minBattery: 30, palette: 3);
    expect(CallFlashPrefs.fromJson(f.toJson()).toJson(), f.toJson());
    expect(CallFlashPrefs.fromJson({}).skipSilent, isTrue);
    expect(CallFlashPrefs.fromJson({'minBattery': 80}).minBattery, 50);
    // Java tarafındaki çarpanlar ve sınırlar aynı kalmalı.
    final java = File('android/src/main/java/com/gamestudio100/kisisel_motoru/CallFlasher.java').readAsStringSync();
    expect(java, contains('{120, 120, 120, 600}'));
    expect(java, contains('{80, 80}'));
    expect(java, contains('{300, 300}'));
  });

  test('en az yetki: manifestte arama/kişi/kamera/paket izni yok', () {
    final m = File('android/src/main/AndroidManifest.xml').readAsStringSync();
    final perms = RegExp(r'<uses-permission android:name="([^"]+)"').allMatches(m).map((x) => x.group(1)).toSet();
    expect(perms, {'android.permission.SYSTEM_ALERT_WINDOW'});
    for (final bad in ['READ_PHONE_STATE', 'READ_CALL_LOG', 'READ_CONTACTS', 'ANSWER_PHONE_CALLS', 'CAMERA"',
        'QUERY_ALL_PACKAGES', 'BIND_ACCESSIBILITY_SERVICE', 'FOREGROUND_SERVICE']) {
      expect(m.contains('android.permission.$bad'), isFalse, reason: bad);
    }
    expect(m, contains('android.intent.category.LAUNCHER'));
    for (final cls in ['IslandNotificationService', 'CallFlashService', 'AodDreamService']) {
      expect(m, contains('kisisel_motoru.$cls'));
    }
  });

  test('estetik: simge önerisi, baş harf, temalar, dosya adı', () {
    expect(suggestGlyph('com.android.dialer', -1), 'phone');
    expect(suggestGlyph('com.example.camera2', -1), 'camera');
    expect(suggestGlyph('org.example.notes', -1), 'notes');
    expect(suggestGlyph('com.example.unknown', 6), 'map');
    expect(suggestGlyph('com.example.unknown', 1), 'music');
    expect(suggestGlyph('com.example.unknown', -1), 'letter');
    for (final g in kHomeGlyphs) {
      expect(g == 'letter' || kIconKeys.contains(g), isTrue);
    }
    expect(initialOf('  çay'), 'Ç');
    expect(initialOf(''), '?');
    expect(kAestheticThemes.map((t) => t.key).toSet().length, kAestheticThemes.length);
    expect(kFreeThemes, lessThan(kAestheticThemes.length));
    expect(homeIconFileName('Hava Durumu!', 'neon'), 'shortcut_hava_durumu_neon.png');
    expect(homeIconFileName('Ç', 'mono'), 'shortcut_app_mono.png');
  });

  testWidgets('estetik simge PNG çizilir', (tester) async {
    await tester.runAsync(() async {
      for (final g in ['letter', 'phone']) {
        final png = await renderAestheticPng(kAestheticThemes[4], 'circle', g, 'A', px: 64);
        expect(png, isNotNull);
        expect(png!.sublist(1, 4), 'PNG'.codeUnits);
      }
    });
  });

  testWidgets('ada önizlemesi genişler', (tester) async {
    Future<void> show(bool e) => tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Center(
              child: IslandPreview(p: const IslandPrefs(), expanded: e, label: 'Mesaj', title: 'Yeni', screenWidth: 400),
            ),
          ),
        ));
    await show(false);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(IslandPreview)).width, 120);
    await show(true);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(IslandPreview)).width, 312);
    expect(find.text('Mesaj'), findsOneWidget);
    expect(find.text('Yeni'), findsNothing, reason: 'başlık varsayılan olarak gizli');
  });
}
