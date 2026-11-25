/// Kişiselleştirme araçlarının saf mantığı (arayüzden bağımsız, testli):
/// ses sentezi (WAV), renk paletleri, ekran yanığı koruması ve geri sayım.
library;

import 'dart:math' as math;
import 'dart:typed_data';

// ------------------------------------------------------------- paletler

/// Özgün renk paletleri (ARGB). İlk iki renk zemin, sonrakiler vurgu.
const List<List<int>> kPalettes = [
  [0xFF0B1E3F, 0xFF1B3B6F, 0xFF4FD1C5, 0xFF9AE6B4, 0xFFF6E05E], // gece denizi
  [0xFF2D0A31, 0xFF5B1A5E, 0xFFFF7AB6, 0xFFFFC371, 0xFF8EC5FC], // gün batımı
  [0xFF0F2E1D, 0xFF1F5A3A, 0xFF9AE6B4, 0xFFF0FFF4, 0xFFFBD38D], // orman
  [0xFF1A1A1A, 0xFF2E2E2E, 0xFFEDEDED, 0xFFA0AEC0, 0xFFF56565], // grafit
  [0xFF3A1C00, 0xFF7B341E, 0xFFF6AD55, 0xFFFEEBC8, 0xFFE53E3E], // kehribar
  [0xFF101830, 0xFF283C64, 0xFFB794F4, 0xFF90CDF4, 0xFFFBB6CE], // lavanta
];

/// Ücretsiz paletler (diğerleri ödüllü reklamla günlük ya da Premium ile açılır).
const int kFreePalettes = 3;

// --------------------------------------------------------------- sentez

/// Ses rengi.
enum Timbre { sine, bell, soft, pluck }

/// Nota: yarım ton (A4 = 0, 440 Hz), süre (ms). [rest] true ise sessizlik.
class Note {
  final int semi;
  final int ms;
  final bool rest;
  const Note(this.semi, this.ms) : rest = false;
  const Note.rest(this.ms)
      : semi = 0,
        rest = true;
}

double freqOf(int semi) => 440 * math.pow(2, semi / 12).toDouble();

/// Özgün hazır sesler: ad anahtarı, tür (notification/ringtone), ses rengi,
/// notalar. Melodiler bu uygulama için yazıldı; bilinen bir esere dayanmaz.
class TonePreset {
  final String key;
  final bool ringtone;
  final Timbre timbre;
  final List<Note> notes;
  final bool premium;
  const TonePreset(this.key, this.ringtone, this.timbre, this.notes, {this.premium = false});
}

const List<TonePreset> kTones = [
  TonePreset('drop', false, Timbre.pluck, [Note(7, 90), Note(0, 160)]),
  TonePreset('glass', false, Timbre.bell, [Note(12, 120), Note(19, 260)]),
  TonePreset('ping', false, Timbre.sine, [Note(15, 140)]),
  TonePreset('bubble', false, Timbre.soft, [Note(3, 70), Note(10, 70), Note(15, 120)]),
  TonePreset('knock', false, Timbre.pluck, [Note(-12, 80), Note.rest(60), Note(-12, 80)]),
  TonePreset('rise', false, Timbre.sine, [Note(0, 80), Note(4, 80), Note(7, 80), Note(12, 160)]),
  TonePreset('chime', false, Timbre.bell, [Note(7, 150), Note(3, 150), Note(10, 300)], premium: true),
  TonePreset('spark', false, Timbre.soft, [Note(19, 60), Note(24, 60), Note(19, 60), Note(26, 160)], premium: true),
  TonePreset('morning', true, Timbre.bell, [
    Note(0, 220), Note(4, 220), Note(7, 220), Note(12, 440), Note.rest(220),
    Note(11, 220), Note(7, 220), Note(4, 440), Note.rest(440),
  ]),
  TonePreset('marimba', true, Timbre.pluck, [
    Note(5, 160), Note(9, 160), Note(12, 160), Note(9, 160), Note(5, 160), Note(0, 320), Note.rest(160),
    Note(5, 160), Note(9, 160), Note(14, 320), Note(12, 480), Note.rest(320),
  ]),
  TonePreset('calm', true, Timbre.soft, [
    Note(-5, 400), Note(0, 400), Note(2, 400), Note(7, 800), Note.rest(400),
    Note(5, 400), Note(2, 400), Note(0, 800), Note.rest(600),
  ]),
  TonePreset('retro', true, Timbre.soft, [
    Note(12, 110), Note(12, 110), Note.rest(110), Note(16, 110), Note(19, 220), Note.rest(110),
    Note(17, 110), Note(16, 110), Note(12, 330), Note.rest(330),
  ]),
  TonePreset('pulse', true, Timbre.sine, [
    Note(9, 120), Note.rest(80), Note(9, 120), Note.rest(80), Note(16, 240), Note.rest(500),
  ]),
  TonePreset('garden', true, Timbre.bell, [
    Note(2, 200), Note(9, 200), Note(14, 400), Note(12, 200), Note(9, 200), Note(7, 400),
    Note(9, 200), Note(5, 200), Note(2, 600), Note.rest(400),
  ], premium: true),
  TonePreset('steps', true, Timbre.pluck, [
    Note(0, 140), Note(2, 140), Note(4, 140), Note(5, 140), Note(7, 140), Note(9, 140), Note(11, 140),
    Note(12, 420), Note.rest(280),
  ], premium: true),
];

/// Notaları 16 bit mono WAV'a çevirir. [transpose] yarım ton, [tempo] hız
/// çarpanı (1 = normal), [repeat] tekrar sayısı.
Uint8List synth(List<Note> notes, Timbre timbre,
    {int transpose = 0, double tempo = 1, int repeat = 1, int rate = 22050, double volume = 0.8}) {
  final seq = <Note>[for (var r = 0; r < math.max(1, repeat); r++) ...notes];
  final lens = [for (final n in seq) math.max<int>(1, (rate * n.ms / 1000 / tempo).round())];
  final tail = (rate * 0.08).round();
  final total = lens.fold<int>(0, (a, b) => a + b) + tail;
  final buf = Float64List(total);
  var o = 0;
  for (var k = 0; k < seq.length; k++) {
    final n = seq[k], len = lens[k];
    if (!n.rest) {
      final f = freqOf(n.semi + transpose);
      final ring = timbre == Timbre.bell || timbre == Timbre.pluck ? (len + tail) : len;
      for (var i = 0; i < ring && o + i < total; i++) {
        final t = i / rate;
        var v = 0.0;
        switch (timbre) {
          case Timbre.sine:
            v = math.sin(2 * math.pi * f * t);
          case Timbre.bell:
            v = 0.6 * math.sin(2 * math.pi * f * t) +
                0.25 * math.sin(2 * math.pi * f * 2.76 * t) +
                0.15 * math.sin(2 * math.pi * f * 5.4 * t);
          case Timbre.soft:
            v = 0.7 * math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * f * 3 * t) / 3;
          case Timbre.pluck:
            v = 0.8 * math.sin(2 * math.pi * f * t) + 0.2 * math.sin(2 * math.pi * f * 2 * t);
        }
        // Zarf: kısa atak; çan ve tel sesi üstel söner, diğerleri sonda kısılır.
        final attack = math.min(1.0, i / (rate * 0.005));
        double env;
        if (timbre == Timbre.bell || timbre == Timbre.pluck) {
          env = math.exp(-t * (timbre == Timbre.pluck ? 9 : 4));
        } else {
          final rel = (len - i) / (rate * 0.02);
          env = i < len ? math.min(1.0, rel) : 0.0;
        }
        buf[o + i] += v * attack * env;
      }
    }
    o += len;
  }
  var peak = 0.0;
  for (final x in buf) {
    peak = math.max(peak, x.abs());
  }
  final gain = peak > 0 ? volume / peak : 0.0;
  return pcmToWav([for (final x in buf) x * gain], rate);
}

/// [-1, 1] örneklerden WAV dosyası.
Uint8List pcmToWav(List<double> samples, int rate) {
  final n = samples.length;
  final data = ByteData(44 + n * 2);
  void str(int off, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(off + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    data.setInt16(44 + i * 2, (samples[i] * 32767).round().clamp(-32768, 32767), Endian.little);
  }
  return data.buffer.asUint8List();
}

// --------------------------------------------------- ekran yanığı koruması

/// Saatin konumu her dakika yavaşça kayar (OLED ekran yanığını önler).
/// [minute] çağrı anındaki dakika sayısı; dönen değer -1..1 aralığında.
(double, double) burnInOffset(int minute) {
  final a = minute * 0.37;
  return (math.sin(a) * 0.8, math.cos(a * 1.3) * 0.8);
}

// --------------------------------------------------------- geri sayım

/// [now]'dan [target]'a kalan (gün, saat, dakika); geçmişse negatif gün.
(int, int, int) countdown(DateTime now, DateTime target) {
  final d = target.difference(now);
  if (d.isNegative) return (-1 - (-d).inDays, 0, 0);
  return (d.inDays, d.inHours % 24, d.inMinutes % 60);
}

// --------------------------------------------------------------- ikonlar

/// Paketin genel kategori ikonları (marka eşlemesi YOK, logo YOK).
const List<String> kIconKeys = [
  'phone', 'message', 'camera', 'mail', 'music', 'gallery', 'settings', 'calendar',
  'clock', 'map', 'browser', 'notes', 'calculator', 'weather', 'files', 'contacts',
];

/// Ikon biçimleri: zemin şekli.
const List<String> kIconShapes = ['circle', 'squircle', 'square', 'none'];

/// Dosya adı (ASCII): ikon_bicim_palet.png
String iconFileName(String key, String shape, int palette) => 'icon_${key}_${shape}_p$palette.png';
