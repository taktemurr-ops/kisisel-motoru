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

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

/// Yerel bileşen grupları.
enum NativeFeature { wallpaper, widgets, dream }

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
  static Future<bool> openDreamSettings() async => await _call<bool>('openDreamSettings') ?? false;

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
