/// Renk paleti üretici, şık yazı üretici, kenar ışıklandırma ve şarj
/// animasyonunun saf mantığı (arayüzden bağımsız, testli): HSL dönüşümü,
/// renk uyumları, WCAG kontrastı, Unicode yazı stilleri, semboller ve
/// animasyon ayarları.
library;

import 'dart:convert';
import 'dart:math' as math;

// ============================================================ renkler

/// ARGB → (ton 0–360, doygunluk 0–1, açıklık 0–1).
(double, double, double) argbToHsl(int argb) {
  final r = ((argb >> 16) & 0xFF) / 255, g = ((argb >> 8) & 0xFF) / 255, b = (argb & 0xFF) / 255;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  final l = (mx + mn) / 2;
  if (mx == mn) return (0.0, 0.0, l);
  final d = mx - mn;
  final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  double h;
  if (mx == r) {
    h = (g - b) / d + (g < b ? 6 : 0);
  } else if (mx == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  return (h * 60, s, l);
}

/// (ton, doygunluk, açıklık) → opak ARGB.
int hslToArgb(double h, double s, double l) {
  h = ((h % 360) + 360) % 360;
  s = s.clamp(0.0, 1.0);
  l = l.clamp(0.0, 1.0);
  final c = (1 - (2 * l - 1).abs()) * s;
  final x = c * (1 - ((h / 60) % 2 - 1).abs());
  final m = l - c / 2;
  double r, g, b;
  if (h < 60) {
    (r, g, b) = (c, x, 0.0);
  } else if (h < 120) {
    (r, g, b) = (x, c, 0.0);
  } else if (h < 180) {
    (r, g, b) = (0.0, c, x);
  } else if (h < 240) {
    (r, g, b) = (0.0, x, c);
  } else if (h < 300) {
    (r, g, b) = (x, 0.0, c);
  } else {
    (r, g, b) = (c, 0.0, x);
  }
  int ch(double v) => ((v + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | (ch(r) << 16) | (ch(g) << 8) | ch(b);
}

/// '#RRGGBB'.
String hexOf(int argb) => '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// '#abc', 'abc', '#aabbcc', 'aabbcc' → ARGB; geçersizse null.
int? parseHex(String s) {
  var h = s.trim();
  if (h.startsWith('#')) h = h.substring(1);
  if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(h)) return null;
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  return 0xFF000000 | int.parse(h, radix: 16);
}

/// Göreli parlaklık (WCAG 2.x).
double luminance(int argb) {
  double lin(int v) {
    final c = v / 255;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin((argb >> 16) & 0xFF) + 0.7152 * lin((argb >> 8) & 0xFF) + 0.0722 * lin(argb & 0xFF);
}

/// Kontrast oranı (1–21).
double contrastRatio(int a, int b) {
  final la = luminance(a), lb = luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// WCAG düzeyi: 'AAA', 'AA', 'AA+' (yalnız büyük metin) ya da '—'.
String wcagLevel(double ratio) {
  if (ratio >= 7) return 'AAA';
  if (ratio >= 4.5) return 'AA';
  if (ratio >= 3) return 'AA+';
  return '—';
}

/// Bir zemin üzerinde okunur yazı rengi (siyah ya da beyaz).
int readableOn(int bg) => contrastRatio(bg, 0xFFFFFFFF) >= contrastRatio(bg, 0xFF000000) ? 0xFFFFFFFF : 0xFF000000;

/// Renk uyumları.
enum Harmony { analog, complementary, split, triad, tetrad, mono, random }

/// Ana renkten 5 renklik uyumlu palet. [r] yalnız rastgele/ince ayar için.
List<int> harmonyPalette(int base, Harmony h, math.Random r) {
  final (hu, s0, l0) = argbToHsl(base);
  final s = s0 < 0.08 ? 0.55 : s0;
  final l = l0.clamp(0.2, 0.8).toDouble();
  int c(double dh, [double ds = 0, double dl = 0]) =>
      hslToArgb(hu + dh, (s + ds).clamp(0.05, 1.0).toDouble(), (l + dl).clamp(0.08, 0.95).toDouble());
  switch (h) {
    case Harmony.analog:
      return [c(-40, 0, -0.1), c(-20), base, c(20), c(40, 0, 0.1)];
    case Harmony.complementary:
      return [c(0, 0, -0.25), base, c(0, -0.2, 0.25), c(180), c(180, 0, -0.2)];
    case Harmony.split:
      return [c(0, 0, -0.2), base, c(150), c(210), c(210, -0.1, 0.25)];
    case Harmony.triad:
      return [base, c(120), c(240), c(0, -0.3, 0.3), c(120, 0, -0.25)];
    case Harmony.tetrad:
      return [base, c(90), c(180), c(270), c(0, -0.4, 0.35)];
    case Harmony.mono:
      return [c(0, 0, -0.32), c(0, 0, -0.16), base, c(0, -0.1, 0.16), c(0, -0.2, 0.3)];
    case Harmony.random:
      final out = <int>[base];
      var hue = hu;
      while (out.length < 5) {
        hue += 40 + r.nextDouble() * 100;
        out.add(hslToArgb(hue, 0.35 + r.nextDouble() * 0.55, 0.25 + r.nextDouble() * 0.55));
      }
      return out;
  }
}

/// Kilitli renkleri koruyarak yeni palet üretir. Ana renk: ilk kilitli renk,
/// yoksa rastgele (canlı) bir renk.
List<int> regenerate(List<int> current, List<bool> locked, Harmony h, math.Random r) {
  final li = locked.indexWhere((x) => x);
  final base = li >= 0 ? current[li] : hslToArgb(r.nextDouble() * 360, 0.45 + r.nextDouble() * 0.45, 0.35 + r.nextDouble() * 0.3);
  final fresh = harmonyPalette(base, h, r);
  final out = <int>[];
  var k = 0;
  for (var i = 0; i < current.length; i++) {
    if (locked[i]) {
      out.add(current[i]);
    } else {
      // Kilitli ana rengin kopyasını atla.
      if (li >= 0 && fresh[k % fresh.length] == base) k++;
      out.add(fresh[k % fresh.length]);
      k++;
    }
  }
  return out;
}

/// Dışa aktarma biçimleri.
String paletteHex(List<int> p) => p.map(hexOf).join(', ');

String paletteCss(List<int> p) =>
    ':root {\n${[for (var i = 0; i < p.length; i++) '  --color-${i + 1}: ${hexOf(p[i])};'].join('\n')}\n}';

String paletteJson(List<int> p) => jsonEncode({'colors': p.map(hexOf).toList()});

// ============================================================ şık yazı

/// Unicode yazı stilleri. Matematiksel harf blokları bazı harflerde boşluk
/// bıraktığından ([_holes]) eski "harf benzeri simgeler" kullanılır.
enum FancyStyle {
  bold, italic, boldItalic, script, boldScript, fraktur, boldFraktur, doubleStruck,
  sans, sansBold, sansItalic, sansBoldItalic, mono, circled, negCircled, squared, negSquared,
  fullwidth, parenthesized, smallCaps, superscript, upsideDown, strike, underline,
  doubleUnderline, slash, overline, spaced,
}

/// (büyük A, küçük a, rakam 0) başlangıçları; 0 = yok.
const Map<FancyStyle, (int, int, int)> _math = {
  FancyStyle.bold: (0x1D400, 0x1D41A, 0x1D7CE),
  FancyStyle.italic: (0x1D434, 0x1D44E, 0),
  FancyStyle.boldItalic: (0x1D468, 0x1D482, 0),
  FancyStyle.script: (0x1D49C, 0x1D4B6, 0),
  FancyStyle.boldScript: (0x1D4D0, 0x1D4EA, 0),
  FancyStyle.fraktur: (0x1D504, 0x1D51E, 0),
  FancyStyle.boldFraktur: (0x1D56C, 0x1D586, 0),
  FancyStyle.doubleStruck: (0x1D538, 0x1D552, 0x1D7D8),
  FancyStyle.sans: (0x1D5A0, 0x1D5BA, 0x1D7E2),
  FancyStyle.sansBold: (0x1D5D4, 0x1D5EE, 0x1D7EC),
  FancyStyle.sansItalic: (0x1D608, 0x1D622, 0),
  FancyStyle.sansBoldItalic: (0x1D63C, 0x1D656, 0),
  FancyStyle.mono: (0x1D670, 0x1D68A, 0x1D7F6),
};

/// Matematik bloklarındaki boşluklar (Letterlike Symbols karşılıkları).
const Map<FancyStyle, Map<String, int>> _holes = {
  FancyStyle.italic: {'h': 0x210E},
  FancyStyle.script: {
    'B': 0x212C, 'E': 0x2130, 'F': 0x2131, 'H': 0x210B, 'I': 0x2110, 'L': 0x2112, 'M': 0x2133, 'R': 0x211B,
    'e': 0x212F, 'g': 0x210A, 'o': 0x2134,
  },
  FancyStyle.fraktur: {'C': 0x212D, 'H': 0x210C, 'I': 0x2111, 'R': 0x211C, 'Z': 0x2128},
  FancyStyle.doubleStruck: {'C': 0x2102, 'H': 0x210D, 'N': 0x2115, 'P': 0x2119, 'Q': 0x211A, 'R': 0x211D, 'Z': 0x2124},
};

const String _smallCaps = 'ᴀʙᴄᴅᴇꜰɢʜɪᴊᴋʟᴍɴᴏᴘǫʀꜱᴛᴜᴠᴡxʏᴢ';
const String _superLower = 'ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿᵒᵖqʳˢᵗᵘᵛʷˣʸᶻ';
const String _superUpper = 'ᴬᴮᶜᴰᴱᶠᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾQᴿˢᵀᵁⱽᵂˣʸᶻ';
const String _superDigits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
const String _flipLower = 'ɐqɔpǝɟƃɥᴉɾʞlɯuodbɹsʇnʌʍxʎz';
const String _flipUpper = '∀ꓭƆꓷƎℲ⅁HIſꓘ˥WNOԀΌꓤS⊥∩ΛMX⅄Z';
const String _flipDigits = '0ƖᄅƐㄣϛ9ㄥ86';
const Map<String, String> _flipPunct = {
  '.': '˙', ',': '\'', '\'': ',', '?': '¿', '!': '¡', '(': ')', ')': '(', '[': ']', ']': '[', '{': '}', '}': '{',
  '<': '>', '>': '<', '_': '‾', '&': '⅋', '"': '„',
};

/// Aksanlı Latin harfleri: temel harf + birleşik işaret (NFD benzeri).
/// Böylece ç, ş, ğ, ö, ü gibi harfler de stillenir.
const Map<String, String> _decompose = {
  'ç': 'ç', 'Ç': 'Ç', 'ş': 'ş', 'Ş': 'Ş', 'ğ': 'ğ', 'Ğ': 'Ğ',
  'ö': 'ö', 'Ö': 'Ö', 'ü': 'ü', 'Ü': 'Ü', 'İ': 'İ', 'ä': 'ä', 'Ä': 'Ä',
  'ë': 'ë', 'ï': 'ï', 'ÿ': 'ÿ', 'á': 'á', 'é': 'é', 'í': 'í', 'ó': 'ó',
  'ú': 'ú', 'ý': 'ý', 'Á': 'Á', 'É': 'É', 'Í': 'Í', 'Ó': 'Ó', 'Ú': 'Ú',
  'à': 'à', 'è': 'è', 'ì': 'ì', 'ò': 'ò', 'ù': 'ù', 'À': 'À', 'È': 'È',
  'â': 'â', 'ê': 'ê', 'î': 'î', 'ô': 'ô', 'û': 'û', 'Â': 'Â', 'Ê': 'Ê',
  'Î': 'Î', 'Ô': 'Ô', 'Û': 'Û', 'ã': 'ã', 'õ': 'õ', 'ñ': 'ñ', 'Ñ': 'Ñ',
  'Ã': 'Ã', 'Õ': 'Õ', 'å': 'å', 'Å': 'Å', 'ů': 'ů', 'č': 'č', 'Č': 'Č',
  'š': 'š', 'Š': 'Š', 'ž': 'ž', 'Ž': 'Ž', 'ř': 'ř', 'Ř': 'Ř', 'ě': 'ě',
  'ň': 'ň', 'ď': 'ď', 'ť': 'ť', 'ă': 'ă', 'Ă': 'Ă', 'ș': 'ș', 'Ș': 'Ș',
  'ț': 'ț', 'Ț': 'Ț', 'ő': 'ő', 'ű': 'ű', 'Ő': 'Ő', 'Ű': 'Ű', 'ą': 'ą',
  'ę': 'ę', 'ś': 'ś', 'ź': 'ź', 'ż': 'ż', 'ć': 'ć', 'ń': 'ń', 'Ś': 'Ś',
  'Ź': 'Ź', 'Ż': 'Ż', 'Ć': 'Ć', 'Ń': 'Ń',
};

bool _isUpper(int c) => c >= 0x41 && c <= 0x5A;
bool _isLower(int c) => c >= 0x61 && c <= 0x7A;
bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

String _mapChar(String ch, FancyStyle s) {
  final c = ch.codeUnitAt(0);
  if (ch.length != 1) return ch;
  final m = _math[s];
  if (m != null) {
    final hole = _holes[s]?[ch];
    if (hole != null) return String.fromCharCode(hole);
    if (_isUpper(c)) return String.fromCharCode(m.$1 + c - 0x41);
    if (_isLower(c)) return String.fromCharCode(m.$2 + c - 0x61);
    if (_isDigit(c) && m.$3 != 0) return String.fromCharCode(m.$3 + c - 0x30);
    return ch;
  }
  switch (s) {
    case FancyStyle.circled:
      if (_isUpper(c)) return String.fromCharCode(0x24B6 + c - 0x41);
      if (_isLower(c)) return String.fromCharCode(0x24D0 + c - 0x61);
      if (c == 0x30) return '⓪';
      if (_isDigit(c)) return String.fromCharCode(0x2460 + c - 0x31);
      return ch;
    case FancyStyle.negCircled:
      if (_isUpper(c) || _isLower(c)) return String.fromCharCode(0x1F150 + (c | 0x20) - 0x61);
      if (c == 0x30) return '⓿';
      if (_isDigit(c)) return String.fromCharCode(0x2776 + c - 0x31);
      return ch;
    case FancyStyle.squared:
      if (_isUpper(c) || _isLower(c)) return String.fromCharCode(0x1F130 + (c | 0x20) - 0x61);
      return ch;
    case FancyStyle.negSquared:
      if (_isUpper(c) || _isLower(c)) return String.fromCharCode(0x1F170 + (c | 0x20) - 0x61);
      return ch;
    case FancyStyle.fullwidth:
      if (c == 0x20) return '　';
      if (c > 0x20 && c < 0x7F) return String.fromCharCode(0xFF01 + c - 0x21);
      return ch;
    case FancyStyle.parenthesized:
      if (_isUpper(c) || _isLower(c)) return String.fromCharCode(0x249C + (c | 0x20) - 0x61);
      if (_isDigit(c) && c != 0x30) return String.fromCharCode(0x2474 + c - 0x31);
      return ch;
    case FancyStyle.smallCaps:
      if (_isUpper(c) || _isLower(c)) return _smallCaps[(c | 0x20) - 0x61];
      return ch;
    case FancyStyle.superscript:
      if (_isUpper(c)) return _superUpper[c - 0x41];
      if (_isLower(c)) return _superLower[c - 0x61];
      if (_isDigit(c)) return _superDigits[c - 0x30];
      if (ch == '+') return '⁺';
      if (ch == '-') return '⁻';
      if (ch == '=') return '⁼';
      if (ch == '(') return '⁽';
      if (ch == ')') return '⁾';
      return ch;
    case FancyStyle.upsideDown:
      if (_isUpper(c)) return _flipUpper[c - 0x41];
      if (_isLower(c)) return _flipLower[c - 0x61];
      if (_isDigit(c)) return _flipDigits[c - 0x30];
      return _flipPunct[ch] ?? ch;
    default:
      return ch;
  }
}

/// Birleşik işaretli stiller (her karakterden sonra eklenir).
const Map<FancyStyle, String> _combining = {
  FancyStyle.strike: '̶',
  FancyStyle.underline: '̲',
  FancyStyle.doubleUnderline: '̳',
  FancyStyle.slash: '̸',
  FancyStyle.overline: '̅',
};

/// Metni bir stile çevirir. Aksanlı harfler temel harf + işaret olarak
/// stillenir; karşılığı olmayan karakterler olduğu gibi kalır.
String fancy(String text, FancyStyle s) {
  final mark = _combining[s];
  final runes = text.runes.map(String.fromCharCode).toList();
  if (mark != null) {
    return runes.map((c) => c == ' ' || c == '\n' ? c : '$c$mark').join();
  }
  if (s == FancyStyle.spaced) return runes.where((c) => c != ' ').join(' ');
  final out = StringBuffer();
  final seq = s == FancyStyle.upsideDown ? runes.reversed : runes;
  for (final ch in seq) {
    final d = _decompose[ch];
    if (d != null && s != FancyStyle.upsideDown) {
      out.write(_mapChar(d[0], s));
      out.write(d.substring(1));
    } else {
      out.write(_mapChar(ch, s));
    }
  }
  return out.toString();
}

/// Sembol kategorileri (simge adı, semboller). Hepsi standart Unicode.
const List<(String, String)> kSymbolSets = [
  ('star', '★☆✦✧✩✪✫✬✭✮✯✰⁂⁎✱✲✳✴✵✶✷✸✹✺✻✼✽✾✿❀❁❂❃❄❅❆❇❈❉❊❋⋆⭐'),
  ('heart', '♥♡❤❥❣❦❧ღ💕💖💗💘💙💚💛💜🖤🤍🤎🧡'),
  ('arrow', '←↑→↓↔↕↖↗↘↙⇐⇑⇒⇓⇔⇕➔➘➙➚➛➜➝➞➟➠➡➢➣➤➥➦➧➨⟵⟶⟷↩↪↺↻⤴⤵'),
  ('shape', '■□▢▣▤▥▦▧▨▩▪▫▬▭▮▯▰▱▲△▴▵▶▷▸▹►▻▼▽▾▿◀◁◂◃◄◅◆◇◈◉◊○◌◍◎●◐◑◒◓◔◕◖◗◘◙◢◣◤◥◦◯'),
  ('check', '✓✔✕✖✗✘☐☑☒⊕⊖⊗⊘⊙⊚⊛'),
  ('math', '±×÷√∛∜∞≈≠≡≤≥∑∏∫∂∆∇∈∉∩∪⊂⊃⊆⊇∧∨¬∀∃∅πΩµ°‰‱½⅓⅔¼¾⅛'),
  ('money', '¤¢£¥€₺₹₽₩₪₫₱₦₴₸₿\$'),
  ('music', '♩♪♫♬♭♮♯𝄞𝄢🎵🎶'),
  ('weather', '☀☁☂☃☄★☼☽☾♨⛅⛈⛄❄🌙🌈🌊🌸🌻🍀'),
  ('bracket', '「」『』【】〔〕〖〗〘〙〚〛《》〈〉‹›«»⟦⟧⟨⟩❨❩❪❫❬❭❮❯❰❱❲❳❴❵'),
  ('line', '─━│┃┄┅┆┇┈┉┊┋┌┐└┘├┤┬┴┼═║╔╗╚╝╠╣╦╩╬░▒▓█▀▄▌▐•‣◦⁃∙·…‥※'),
  ('face', '(◕‿◕)|(｡♥‿♥｡)|ʕ•ᴥ•ʔ|(ᵔᴥᵔ)|(✿◠‿◠)|(¬‿¬)|(◠‿◠)|٩(◕‿◕)۶|ヽ(•‿•)ノ|(＾▽＾)|(•‿•)|(◡‿◡✿)|(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧|(っ˘ω˘ς)|(ᵕᴗᵕ)|ʘ‿ʘ|(°ロ°)|(ಠ_ಠ)|¯\\_(ツ)_/¯|(╯°□°)╯|(^_^)|(T_T)|(>_<)|(o_O)'),
];

/// Sembol listesi: yüz ifadeleri '|' ile ayrılır, diğerleri karakter karakter.
List<String> symbolsOf(String key) {
  final s = kSymbolSets.firstWhere((e) => e.$1 == key).$2;
  if (key == 'face') return s.split('|');
  return s.runes.map(String.fromCharCode).toList();
}

/// Süsleme kalıpları ({t} = metin). İlk [kFreeDecorations] ücretsizdir.
const List<String> kDecorations = [
  '★ {t} ★',
  '꧁ {t} ꧂',
  '【{t}】',
  '『{t}』',
  '✿ {t} ✿',
  '•°• {t} •°•',
  '⋆｡°✩ {t} ✩°｡⋆',
  '❝ {t} ❞',
  '彡 {t} 彡',
  '〖{t}〗',
  '⟦ {t} ⟧',
  '◥ {t} ◤',
  '░▒▓█ {t} █▓▒░',
  '▁▂▄▅▆▇█ {t} █▇▆▅▄▂▁',
  '-·=»‡«=·- {t} -·=»‡«=·-',
  '♪♫•*¨*•.¸¸♥ {t} ♥¸¸.•*¨*•♫♪',
  '✧･ﾟ: *✧･ﾟ:* {t} *:･ﾟ✧*:･ﾟ✧',
  '.·´¯`·.·★ {t} ★·.·´¯`·.',
  '(っ◔◡◔)っ ♥ {t} ♥',
  '⫷ {t} ⫸',
];

const int kFreeDecorations = 8;

String decorate(String text, int i) => kDecorations[i].replaceAll('{t}', text);

// ============================================================ kenar ışığı

/// Kenar ışıklandırma biçimleri.
enum EdgeStyle { flow, pulse, rainbow, comet }

/// Kenar ışıklandırma ayarları (Android servisine de JSON olarak gider).
class EdgePrefs {
  final bool enabled;
  final EdgeStyle style;
  final int palette;
  final double thickness; // dp, 2–16
  final double radius; // dp, 0–60
  final double seconds; // görünme süresi, 2–15
  final double speed; // tur/saniye çarpanı, 0.3–3
  const EdgePrefs({
    this.enabled = false,
    this.style = EdgeStyle.flow,
    this.palette = 0,
    this.thickness = 6,
    this.radius = 32,
    this.seconds = 5,
    this.speed = 1,
  });

  Map<String, Object?> toJson() => {
        'enabled': enabled, 'style': style.name, 'palette': palette, 'thickness': thickness,
        'radius': radius, 'seconds': seconds, 'speed': speed,
      };

  static EdgePrefs fromJson(Map<String, Object?> j) => EdgePrefs(
        enabled: j['enabled'] == true,
        style: EdgeStyle.values.firstWhere((e) => e.name == j['style'], orElse: () => EdgeStyle.flow),
        palette: ((j['palette'] as num?)?.toInt() ?? 0),
        thickness: ((j['thickness'] as num?)?.toDouble() ?? 6).clamp(2.0, 16.0).toDouble(),
        radius: ((j['radius'] as num?)?.toDouble() ?? 32).clamp(0.0, 60.0).toDouble(),
        seconds: ((j['seconds'] as num?)?.toDouble() ?? 5).clamp(2.0, 15.0).toDouble(),
        speed: ((j['speed'] as num?)?.toDouble() ?? 1).clamp(0.3, 3.0).toDouble(),
      );

  EdgePrefs copy({bool? enabled, EdgeStyle? style, int? palette, double? thickness, double? radius, double? seconds, double? speed}) =>
      EdgePrefs(
        enabled: enabled ?? this.enabled,
        style: style ?? this.style,
        palette: palette ?? this.palette,
        thickness: thickness ?? this.thickness,
        radius: radius ?? this.radius,
        seconds: seconds ?? this.seconds,
        speed: speed ?? this.speed,
      );
}

/// Nabız biçiminde parlaklık (0.15–1), t saniye.
double edgePulse(double t, double speed) => 0.15 + 0.85 * (0.5 + 0.5 * math.sin(t * speed * 2 * math.pi * 0.8));

/// Kuyruklu yıldızın çevre üzerindeki konumu (0–1).
double edgeCometPos(double t, double speed) => (t * speed * 0.5) % 1.0;

// ============================================================ şarj animasyonu

/// Şarj animasyonu biçimleri.
enum ChargeStyle { liquid, ring, bubbles, bars }

class ChargePrefs {
  final ChargeStyle style;
  final int palette;
  final bool percent, clock, closeOnUnplug;
  const ChargePrefs({
    this.style = ChargeStyle.liquid,
    this.palette = 0,
    this.percent = true,
    this.clock = true,
    this.closeOnUnplug = false,
  });

  Map<String, Object?> toJson() => {
        'style': style.name, 'palette': palette, 'percent': percent, 'clock': clock, 'closeOnUnplug': closeOnUnplug,
      };

  static ChargePrefs fromJson(Map<String, Object?> j) => ChargePrefs(
        style: ChargeStyle.values.firstWhere((e) => e.name == j['style'], orElse: () => ChargeStyle.liquid),
        palette: ((j['palette'] as num?)?.toInt() ?? 0),
        percent: j['percent'] != false,
        clock: j['clock'] != false,
        closeOnUnplug: j['closeOnUnplug'] == true,
      );

  ChargePrefs copy({ChargeStyle? style, int? palette, bool? percent, bool? clock, bool? closeOnUnplug}) => ChargePrefs(
        style: style ?? this.style,
        palette: palette ?? this.palette,
        percent: percent ?? this.percent,
        clock: clock ?? this.clock,
        closeOnUnplug: closeOnUnplug ?? this.closeOnUnplug,
      );
}

/// Sıvı yüzeyinin yüksekliği (0 alt … 1 üst) x konumunda (0–1), t saniye.
double liquidSurface(double level, double x, double t) {
  final l = level.clamp(0.0, 1.0);
  final amp = 0.018 * (1 - (2 * l - 1).abs() * 0.6);
  return l + amp * math.sin(2 * math.pi * (x * 1.6 + t * 0.45)) + amp * 0.6 * math.sin(2 * math.pi * (x * 3.1 - t * 0.7));
}

/// Kabarcıklar: i. kabarcığın t anındaki konumu (x, y; 0–1) ve yarıçapı (oran).
(double, double, double) bubbleAt(int i, double t) {
  final r = math.Random(i * 7919 + 13);
  final x = 0.1 + r.nextDouble() * 0.8;
  final speed = 0.06 + r.nextDouble() * 0.1;
  final phase = r.nextDouble();
  final y = 1 - ((t * speed + phase) % 1.0);
  final rad = 0.012 + r.nextDouble() * 0.03;
  return (x + 0.03 * math.sin(t * 1.3 + i), y, rad);
}
