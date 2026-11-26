/// 4. tur Kişiselleştirme araçlarının saf mantığı (arayüzden bağımsız,
/// testli): bildirim adası ayarları ve geometrisi, her zaman açık ekran
/// ayarları, arama flaşı ritimleri, estetik ana ekran temaları ve uygulama
/// türüne göre simge önerisi.
library;

import 'dart:math' as math;

import 'core.dart';

double _d(Object? v, double def, double lo, double hi) => ((v as num?)?.toDouble() ?? def).clamp(lo, hi).toDouble();

int _i(Object? v, int def, int lo, int hi) => ((v as num?)?.toInt() ?? def).clamp(lo, hi);

// ---------------------------------------------------------------- ada

/// Dinamik bildirim adası ayarları (Android IslandOverlay aynı anahtarları okur).
class IslandPrefs {
  final bool enabled, showTitle, charging, idle;
  final double width, height, offset, seconds;
  final int palette;
  const IslandPrefs({
    this.enabled = false,
    this.showTitle = false,
    this.charging = true,
    this.idle = false,
    this.width = 120,
    this.height = 34,
    this.offset = 10,
    this.seconds = 4,
    this.palette = 0,
  });

  Map<String, Object?> toJson() => {
        'enabled': enabled, 'showTitle': showTitle, 'charging': charging, 'idle': idle,
        'width': width, 'height': height, 'offset': offset, 'seconds': seconds, 'palette': palette,
      };

  static IslandPrefs fromJson(Map<String, Object?> j) => IslandPrefs(
        enabled: j['enabled'] == true,
        showTitle: j['showTitle'] == true,
        charging: j['charging'] != false,
        idle: j['idle'] == true,
        width: _d(j['width'], 120, 80, 220),
        height: _d(j['height'], 34, 24, 48),
        offset: _d(j['offset'], 10, 0, 60),
        seconds: _d(j['seconds'], 4, 2, 10),
        palette: _i(j['palette'], 0, 0, kPalettes.length - 1),
      );

  IslandPrefs copy({
    bool? enabled,
    bool? showTitle,
    bool? charging,
    bool? idle,
    double? width,
    double? height,
    double? offset,
    double? seconds,
    int? palette,
  }) =>
      IslandPrefs(
        enabled: enabled ?? this.enabled,
        showTitle: showTitle ?? this.showTitle,
        charging: charging ?? this.charging,
        idle: idle ?? this.idle,
        width: width ?? this.width,
        height: height ?? this.height,
        offset: offset ?? this.offset,
        seconds: seconds ?? this.seconds,
        palette: palette ?? this.palette,
      );

  /// Yerel servise giden ayarlar: paletin vurgu rengiyle.
  Map<String, Object?> native() => {...toJson(), 'accent': kPalettes[palette][2]};
}

/// Genişlemiş adanın boyutu (Android ile aynı kural): kısa hapın 2,6 katı
/// (en az 260), ekran genişliğinin %92'sini aşmaz; yükseklik iki katı (en az 64).
(double, double) islandExpanded(double pillW, double pillH, double screenW) =>
    (math.min(screenW * 0.92, math.max(pillW * 2.6, 260)), math.max(pillH * 2, 64));

// ---------------------------------------------------------------- AOD

/// Her zaman açık ekranın yüzleri.
enum AodFace { stacked, ring, minimal }

class AodPrefs {
  final AodFace face;
  final bool date, battery, alarm, shift;
  final double dim;
  final int stopBelow, palette;
  final String note;
  const AodPrefs({
    this.face = AodFace.stacked,
    this.date = true,
    this.battery = true,
    this.alarm = true,
    this.shift = true,
    this.dim = 0.3,
    this.stopBelow = 20,
    this.palette = 0,
    this.note = '',
  });

  Map<String, Object?> toJson() => {
        'face': face.name, 'date': date, 'battery': battery, 'alarm': alarm, 'shift': shift,
        'dim': dim, 'stopBelow': stopBelow, 'palette': palette, 'note': note,
      };

  static AodPrefs fromJson(Map<String, Object?> j) => AodPrefs(
        face: AodFace.values.firstWhere((f) => f.name == j['face'], orElse: () => AodFace.stacked),
        date: j['date'] != false,
        battery: j['battery'] != false,
        alarm: j['alarm'] != false,
        shift: j['shift'] != false,
        dim: _d(j['dim'], 0.3, 0, 0.8),
        stopBelow: _i(j['stopBelow'], 20, 0, 50),
        palette: _i(j['palette'], 0, 0, kPalettes.length - 1),
        note: ((j['note'] as String?) ?? '').trim(),
      );

  AodPrefs copy({
    AodFace? face,
    bool? date,
    bool? battery,
    bool? alarm,
    bool? shift,
    double? dim,
    int? stopBelow,
    int? palette,
    String? note,
  }) =>
      AodPrefs(
        face: face ?? this.face,
        date: date ?? this.date,
        battery: battery ?? this.battery,
        alarm: alarm ?? this.alarm,
        shift: shift ?? this.shift,
        dim: dim ?? this.dim,
        stopBelow: stopBelow ?? this.stopBelow,
        palette: palette ?? this.palette,
        note: note ?? this.note,
      );

  /// Android ekran koruyucusuna giden ayarlar ve renkler.
  Map<String, Object?> native() => {...toJson(), 'fg': kPalettes[palette][3], 'accent': kPalettes[palette][2]};
}

/// Pil eşiğin altına indiyse ve şarjda değilse AOD kapanmalı.
bool aodShouldStop(int? level, bool charging, int stopBelow) =>
    stopBelow > 0 && level != null && level < stopBelow && !charging;

/// Saatin rakamları (24 saat ya da 12 saat), "alt alta" yüz için ayrı ayrı.
(String, String) aodDigits(DateTime t, bool use24) {
  final h = use24 ? t.hour : (t.hour % 12 == 0 ? 12 : t.hour % 12);
  return (use24 ? h.toString().padLeft(2, '0') : '$h', t.minute.toString().padLeft(2, '0'));
}

// ---------------------------------------------------------------- flaş

/// Arama flaşının ritmi.
enum FlashPattern { steady, heart, fast }

/// Bir döngünün süreleri (ms): çift sıra açık, tek sıra kapalı. Hız 0,5–2.
/// Android CallFlasher.cycle ile aynı.
List<int> flashCycle(FlashPattern p, double speed) {
  final base = switch (p) {
    FlashPattern.steady => const [300, 300],
    FlashPattern.heart => const [120, 120, 120, 600],
    FlashPattern.fast => const [80, 80],
  };
  final s = speed.clamp(0.5, 2.0);
  return [for (final ms in base) (ms / s).round().clamp(30, 2000)];
}

/// Başlangıçtan [ms] sonra fener açık mı.
bool flashOnAt(List<int> cycle, int ms) {
  final total = cycle.fold<int>(0, (a, b) => a + b);
  if (total <= 0) return false;
  var t = ms % total;
  for (var i = 0; i < cycle.length; i++) {
    if (t < cycle[i]) return i.isEven;
    t -= cycle[i];
  }
  return false;
}

class CallFlashPrefs {
  final bool enabled, skipSilent, screen;
  final FlashPattern pattern;
  final double speed;
  final int minBattery, palette;
  const CallFlashPrefs({
    this.enabled = false,
    this.skipSilent = true,
    this.screen = false,
    this.pattern = FlashPattern.steady,
    this.speed = 1,
    this.minBattery = 15,
    this.palette = 0,
  });

  Map<String, Object?> toJson() => {
        'enabled': enabled, 'skipSilent': skipSilent, 'screen': screen, 'pattern': pattern.name,
        'speed': speed, 'minBattery': minBattery, 'palette': palette,
      };

  static CallFlashPrefs fromJson(Map<String, Object?> j) => CallFlashPrefs(
        enabled: j['enabled'] == true,
        skipSilent: j['skipSilent'] != false,
        screen: j['screen'] == true,
        pattern: FlashPattern.values.firstWhere((f) => f.name == j['pattern'], orElse: () => FlashPattern.steady),
        speed: _d(j['speed'], 1, 0.5, 2),
        minBattery: _i(j['minBattery'], 15, 0, 50),
        palette: _i(j['palette'], 0, 0, kPalettes.length - 1),
      );

  CallFlashPrefs copy({
    bool? enabled,
    bool? skipSilent,
    bool? screen,
    FlashPattern? pattern,
    double? speed,
    int? minBattery,
    int? palette,
  }) =>
      CallFlashPrefs(
        enabled: enabled ?? this.enabled,
        skipSilent: skipSilent ?? this.skipSilent,
        screen: screen ?? this.screen,
        pattern: pattern ?? this.pattern,
        speed: speed ?? this.speed,
        minBattery: minBattery ?? this.minBattery,
        palette: palette ?? this.palette,
      );

  /// Yerel servise giden ayarlar: ekran kenarının rengiyle.
  Map<String, Object?> native() => {...toJson(), 'colors': [kPalettes[palette][4], kPalettes[palette][2]]};
}

// ------------------------------------------------------------ estetik

/// Zemin biçimi.
enum ThemeFill { solid, gradient, outline }

/// Estetik ana ekran teması (özgün renkler).
class AestheticTheme {
  final String key;
  final int bg, bg2, fg, accent;
  final ThemeFill fill;
  const AestheticTheme(this.key, this.bg, this.bg2, this.fg, this.accent, this.fill);
}

const List<AestheticTheme> kAestheticThemes = [
  AestheticTheme('pastel', 0xFFFADADD, 0xFFE6E6FA, 0xFF6B5B95, 0xFFFFB5A7, ThemeFill.gradient),
  AestheticTheme('mono', 0xFFFFFFFF, 0xFFE5E5E5, 0xFF111111, 0xFF888888, ThemeFill.solid),
  AestheticTheme('mint', 0xFFD8F3DC, 0xFFB7E4C7, 0xFF2D6A4F, 0xFF95D5B2, ThemeFill.solid),
  AestheticTheme('lavender', 0xFFE0C3FC, 0xFF8EC5FC, 0xFF4A3F75, 0xFFFFFFFF, ThemeFill.gradient),
  AestheticTheme('neon', 0xFF0A0A12, 0xFF0A0A12, 0xFF39FF14, 0xFFFF2BD6, ThemeFill.outline),
  AestheticTheme('earth', 0xFFC9A27E, 0xFFA47148, 0xFFFFF4E6, 0xFF5C3D2E, ThemeFill.gradient),
  AestheticTheme('ocean', 0xFF0F4C75, 0xFF3282B8, 0xFFBBE1FA, 0xFF1B262C, ThemeFill.gradient),
  AestheticTheme('sunset', 0xFFFF7E5F, 0xFFFEB47B, 0xFFFFFFFF, 0xFF8E2DE2, ThemeFill.gradient),
];

/// Ücretsiz temalar (diğerleri ödüllü reklamla günlük ya da Premium ile).
const int kFreeThemes = 4;

/// Simge seçenekleri: genel kategori çizimleri ve "baş harf".
const List<String> kHomeGlyphs = [...kIconKeys, 'letter'];

/// Etiketin baş harfi (büyük), boşsa '?'.
String initialOf(String label) {
  final s = label.trim();
  if (s.isEmpty) return '?';
  return String.fromCharCode(s.runes.first).toUpperCase();
}

/// Paket adı ve Android uygulama kategorisine göre genel simge önerisi.
/// Marka eşlemesi yoktur: yalnız genel sözcükler ve sistem kategorisi.
String suggestGlyph(String package, int category) {
  final p = package.toLowerCase();
  const rules = <(List<String>, String)>[
    (['dialer', 'incallui', '.phone', 'telecom'], 'phone'),
    (['contacts', 'people'], 'contacts'),
    (['messag', '.mms', '.sms', 'chat'], 'message'),
    (['camera'], 'camera'),
    (['mail', 'inbox'], 'mail'),
    (['music', 'audio', 'radio', 'podcast'], 'music'),
    (['gallery', 'photo'], 'gallery'),
    (['settings'], 'settings'),
    (['calendar'], 'calendar'),
    (['clock', 'alarm'], 'clock'),
    (['maps', 'navi'], 'map'),
    (['browser'], 'browser'),
    (['note', 'memo'], 'notes'),
    (['calc'], 'calculator'),
    (['weather'], 'weather'),
    (['files', 'filemanager', 'documentsui', 'download'], 'files'),
  ];
  for (final (words, glyph) in rules) {
    if (words.any(p.contains)) return glyph;
  }
  // android.content.pm.ApplicationInfo.CATEGORY_*
  return switch (category) {
    1 => 'music', // AUDIO
    2 || 3 => 'gallery', // VIDEO, IMAGE
    4 => 'message', // SOCIAL
    5 => 'browser', // NEWS
    6 => 'map', // MAPS
    7 => 'notes', // PRODUCTIVITY
    _ => 'letter',
  };
}

/// Kaydedilen PNG'nin ASCII dosya adı.
String homeIconFileName(String label, String theme) {
  final base = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  return 'shortcut_${base.isEmpty ? 'app' : base}_$theme.png';
}
