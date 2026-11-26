/// Android yerel köprüsü: canlı duvar kağıdı servisi, ana ekran widget'ları
/// ve ekran koruyucu (DreamService). Kotlin/Java tarafı bu paketin
/// android/ klasöründedir ve uygulamanın bildirimine (manifest) otomatik
/// birleşir. Bileşenler varsayılan olarak kapalıdır; kullanıcı ilgili aracı
/// açınca etkinleştirilir (ör. ikon paketi uygulamasında duvar kağıdı
/// seçicide görünmez).
///
/// Widget verisi home_widget paketiyle yazılır (SharedPreferences
/// "HomeWidgetPreferences"; iOS'ta App Group) ve widget'lar yenilenir.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Yerel bileşen grupları.
enum NativeFeature { wallpaper, widgets, dream, chargeDream, edge, island, call, aod }

/// Android widget sağlayıcı sınıfları (tam adlar; manifestle aynı).
const String kWidgetPackage = 'com.gamestudio100.kisisel_motoru';
const Map<String, String> kWidgetProviders = {
  'clock': '$kWidgetPackage.ClockWidget',
  'date': '$kWidgetPackage.DateWidget',
  'countdown': '$kWidgetPackage.CountdownWidget',
  'note': '$kWidgetPackage.NoteWidget',
  'battery': '$kWidgetPackage.BatteryWidget',
};

/// iOS WidgetKit uzantısının App Group kimliği ve widget türleri
/// (merkez uygulamada ios_widget/README.md: Xcode'da hedef eklenince kullanılır).
const String kIosAppGroup = 'group.com.gamestudio100.kisisel';
const String kIosWidgetKind = 'KisiselWidgets';

/// Başlatıcıda görünen bir uygulama.
class LauncherApp {
  final String label;
  final String package;
  final int category;
  const LauncherApp({required this.label, required this.package, this.category = -1});
}

class KisiselNative {
  KisiselNative._();

  static const MethodChannel _ch = MethodChannel('kisisel_motoru/native');

  /// Yerel servisler yalnız Android'de vardır.
  static bool get android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static Future<T?> _call<T>(String method, [Object? args]) async {
    if (!android) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }

  /// Bileşen grubunu etkinleştirir (duvar kağıdı seçicide, widget listesinde
  /// ya da ekran koruyucu ayarlarında görünür olur).
  static Future<void> enable(NativeFeature f) => _call<void>('enable', {'feature': f.name});

  /// Canlı duvar kağıdı servisinin sahnesi, renkleri (5 ARGB) ve hızı.
  static Future<void> setWallpaper(String scene, List<int> colors, double speed) =>
      _call<void>('setWallpaper', {'scene': scene, 'colors': colors, 'speed': speed});

  /// Sistem canlı duvar kağıdı önizlemesini açar. Açılamazsa false.
  static Future<bool> openLiveWallpaper() async => await _call<bool>('openLiveWallpaper') ?? false;

  /// Ekran koruyucu saat ayarları.
  static Future<void> setDream(Map<String, Object?> prefs) => _call<void>('setDream', prefs);

  /// Sistem ekran koruyucu ayarlarını açar. Açılamazsa false.
  /// [charge] true ise şarj animasyonu, değilse saat ekran koruyucusu etkinleştirilir.
  static Future<bool> openDreamSettings({bool charge = false, bool aod = false}) async =>
      await _call<bool>('openDreamSettings', {'charge': charge, 'aod': aod}) ?? false;

  /// Şarj animasyonu ekran koruyucusunun ayarları (biçim, renkler…).
  static Future<void> setCharge(Map<String, Object?> prefs) => _call<void>('setCharge', prefs);

  /// Kenar ışıklandırma ayarları (Android bildirim dinleyicisi okur).
  static Future<void> setEdge(Map<String, Object?> prefs) => _call<void>('setEdge', prefs);

  /// Kenar ışıklandırma izinleri: bildirim erişimi ve diğer uygulamaların
  /// üzerinde gösterme. Android dışında ikisi de false.
  static Future<({bool listener, bool overlay})> edgeStatus() async {
    final m = await _call<Map<Object?, Object?>>('edgeStatus');
    return (listener: m?['listener'] == true, overlay: m?['overlay'] == true);
  }

  /// Sistem "Bildirim erişimi" ayarını açar.
  static Future<bool> openNotificationAccess() async => await _call<bool>('openNotificationAccess') ?? false;

  /// Sistem "Diğer uygulamaların üzerinde göster" ayarını açar.
  static Future<bool> openOverlaySettings() async => await _call<bool>('openOverlaySettings') ?? false;

  /// Kenar ışığını hemen bir kez gösterir (izin varsa). Gösterildiyse true.
  static Future<bool> testEdge() async => await _call<bool>('testEdge') ?? false;

  /// Bir özelliğin bildirim dinleyicisi (kenar, ada, arama) izni, kaplama
  /// izni ve fener var mı. Android dışında hepsi false.
  static Future<({bool listener, bool overlay, bool torch})> featureStatus(NativeFeature f) async {
    final m = await _call<Map<Object?, Object?>>('featureStatus', {'feature': f.name});
    return (listener: m?['listener'] == true, overlay: m?['overlay'] == true, torch: m?['torch'] == true);
  }

  /// Bu özelliğin dinleyicisi için sistem "Bildirim erişimi" sayfasını açar.
  static Future<bool> openListenerAccess(NativeFeature f) async =>
      await _call<bool>('openNotificationAccess', {'feature': f.name}) ?? false;

  /// Ada, arama flaşı ya da AOD ayarlarını yerel servise yazar.
  static Future<void> setPrefs(NativeFeature f, Map<String, Object?> prefs) =>
      _call<void>('setPrefs', {'key': f.name, 'prefs': prefs});

  /// Adayı örnek bir bildirimle hemen gösterir (kaplama izni varsa).
  static Future<bool> testIsland(String sample) async => await _call<bool>('testIsland', {'text': sample}) ?? false;

  /// Arama flaşını birkaç saniye dener.
  static Future<bool> testFlash(int seconds) async => await _call<bool>('testFlash', {'seconds': seconds}) ?? false;

  /// Sonraki alarmın zamanı (izin gerekmez); yoksa null.
  static Future<DateTime?> nextAlarm() async {
    final ms = await _call<int>('nextAlarm');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Başlatıcıdaki uygulamalar (ad, paket, kategori). Android dışında boş.
  static Future<List<LauncherApp>> listApps() async {
    final list = await _call<List<Object?>>('listApps');
    if (list == null) return const [];
    return [
      for (final e in list)
        if (e is Map)
          LauncherApp(
            label: '${e['label'] ?? ''}',
            package: '${e['package'] ?? ''}',
            category: (e['category'] as num?)?.toInt() ?? -1,
          ),
    ];
  }

  /// Başlatıcı kısayol sabitlemeyi destekliyor mu (Android 8+).
  static Future<bool> canPinShortcuts() async => await _call<bool>('canPinShortcuts') ?? false;

  /// Seçilen uygulamayı açan özel simgeli kısayol isteği gönderir.
  static Future<bool> pinShortcut(String package, String label, Uint8List png) async =>
      await _call<bool>('pinShortcut', {'package': package, 'label': label, 'png': png}) ?? false;

  /// Başlatıcı "ana ekrana sabitle" isteğini destekliyor mu (Android 8+).
  static Future<bool> canPinWidgets() async => await _call<bool>('canPinWidgets') ?? false;

  /// Bir widget türünü ana ekrana sabitleme isteği gönderir.
  static Future<bool> pinWidget(String type) async => await _call<bool>('pinWidget', {'type': type}) ?? false;

  /// Widget verilerini yazar ve tüm widget'ları yeniler (home_widget).
  static Future<void> pushWidgets(Map<String, String> data) async {
    if (!android && !ios) return;
    try {
      if (ios) await HomeWidget.setAppGroupId(kIosAppGroup);
      for (final e in data.entries) {
        await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      if (android) {
        for (final name in kWidgetProviders.values) {
          await HomeWidget.updateWidget(qualifiedAndroidName: name);
        }
      } else {
        for (final type in kWidgetProviders.keys) {
          await HomeWidget.updateWidget(iOSName: '$kIosWidgetKind.$type');
        }
      }
    } catch (_) {
      // Eklenti yoksa (test ortamı) ya da iOS uzantısı eklenmemişse sessizce geç.
    }
  }
}
