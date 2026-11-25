/// Şarjda ekran koruyucu saat (eski adıyla "kilit ekranı saati"). Üçüncü
/// taraf kilit ekranı değiştirmek Play politikalarına aykırı olduğundan
/// uygulama kilit ekranına dokunmaz: tam ekran bir saat gösterir, şarjdayken
/// ekranı açık tutar ve ekran yanığına karşı konumunu yavaşça kaydırır.
/// Sistemin "ekran koruyucu" (Android DreamService) kaydı bu sürümde yoktur.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studio_core/apps/apps.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../common.dart';
import '../core.dart';

/// Saat ayarları.
class ClockPrefs {
  final bool analog, seconds, date, battery, night, onlyCharging;
  final int palette;
  final double dim;
  const ClockPrefs({
    this.analog = false,
    this.seconds = false,
    this.date = true,
    this.battery = true,
    this.night = false,
    this.onlyCharging = true,
    this.palette = 0,
    this.dim = 0.0,
  });

  Map<String, Object?> toJson() => {
        'analog': analog, 'seconds': seconds, 'date': date, 'battery': battery, 'night': night,
        'onlyCharging': onlyCharging, 'palette': palette, 'dim': dim,
      };

  static ClockPrefs fromJson(Map<String, Object?> j) => ClockPrefs(
        analog: j['analog'] == true,
        seconds: j['seconds'] == true,
        date: j['date'] != false,
        battery: j['battery'] != false,
        night: j['night'] == true,
        onlyCharging: j['onlyCharging'] != false,
        palette: ((j['palette'] as num?)?.toInt() ?? 0).clamp(0, kPalettes.length - 1),
        dim: ((j['dim'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 0.8),
      );

  ClockPrefs copy({bool? analog, bool? seconds, bool? date, bool? battery, bool? night, bool? onlyCharging, int? palette, double? dim}) =>
      ClockPrefs(
        analog: analog ?? this.analog,
        seconds: seconds ?? this.seconds,
        date: date ?? this.date,
        battery: battery ?? this.battery,
        night: night ?? this.night,
        onlyCharging: onlyCharging ?? this.onlyCharging,
        palette: palette ?? this.palette,
        dim: dim ?? this.dim,
      );
}

/// Analog kadran.
class DialPainter extends CustomPainter {
  final DateTime now;
  final Color fg, accent;
  final bool seconds;
  DialPainter(this.now, this.fg, this.accent, this.seconds);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 * 0.92;
    final tick = Paint()
      ..color = fg.withValues(alpha: 0.6)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final d = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + d * r * 0.86, c + d * r, tick..strokeWidth = i % 3 == 0 ? r * 0.035 : r * 0.015);
    }
    void hand(double turns, double len, double w, Color col) {
      final a = turns * 2 * math.pi;
      canvas.drawLine(
        c,
        c + Offset(math.sin(a), -math.cos(a)) * r * len,
        Paint()
          ..color = col
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }

    final m = now.minute + now.second / 60;
    hand((now.hour % 12 + m / 60) / 12, 0.5, r * 0.06, fg);
    hand(m / 60, 0.75, r * 0.04, fg);
    if (seconds) hand(now.second / 60, 0.82, r * 0.015, accent);
    canvas.drawCircle(c, r * 0.04, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(DialPainter old) => old.now != now || old.fg != fg || old.seconds != seconds;
}

/// Saat yüzü (önizleme ve tam ekran ortak).
class ClockFace extends StatelessWidget {
  final ToolContext t;
  final ClockPrefs p;
  final DateTime now;
  final int? battery;
  final bool charging;
  const ClockFace({super.key, required this.t, required this.p, required this.now, this.battery, this.charging = false});

  @override
  Widget build(BuildContext context) {
    final pal = kPalettes[p.palette];
    final fg = p.night ? const Color(0xFFB71C1C) : Color(pal[3]);
    final accent = p.night ? const Color(0xFF7F0000) : Color(pal[2]);
    final loc = MaterialLocalizations.of(context);
    final use24 = MediaQuery.alwaysUse24HourFormatOf(context);
    final time = loc.formatTimeOfDay(TimeOfDay.fromDateTime(now), alwaysUse24HourFormat: use24);
    final sec = now.second.toString().padLeft(2, '0');
    return LayoutBuilder(builder: (context, box) {
      final h = math.min(box.maxWidth, box.maxHeight);
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (p.analog)
          SizedBox(width: h * 0.7, height: h * 0.7, child: CustomPaint(painter: DialPainter(now, fg, accent, p.seconds)))
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(time,
                  style: TextStyle(color: fg, fontSize: h * 0.3, fontWeight: FontWeight.w300, fontFeatures: const [FontFeature.tabularFigures()])),
              if (p.seconds)
                Text(' $sec', style: TextStyle(color: accent, fontSize: h * 0.1, fontWeight: FontWeight.w400)),
            ]),
          ),
        if (p.date)
          Text(loc.formatFullDate(now), style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: math.max(14.0, h * 0.05))),
        if (p.battery && battery != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(charging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded, color: accent, size: math.max(16.0, h * 0.05)),
              Text(' %$battery', style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: math.max(14.0, h * 0.045))),
            ]),
          ),
      ]);
    });
  }
}

class ChargeClockTool extends StatefulWidget {
  final ToolContext t;
  const ChargeClockTool(this.t, {super.key});
  @override
  State<ChargeClockTool> createState() => _ChargeClockState();
}

class _ChargeClockState extends State<ChargeClockTool> {
  ToolContext get t => widget.t;
  ClockPrefs _p = const ClockPrefs();
  DateTime _now = DateTime.now();
  Timer? _timer;
  bool _extras = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    () async {
      final m = await t.store.readMap('clock');
      final ex = await extrasOpen(t);
      if (!mounted) return;
      setState(() {
        _p = ClockPrefs.fromJson(m);
        _extras = ex;
        if (!_extras && _p.palette >= kFreePalettes) _p = _p.copy(palette: 0);
      });
    }();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _set(ClockPrefs p) {
    setState(() => _p = p);
    t.store.writeMap('clock', p.toJson());
  }

  Widget _switch(String label, bool v, ValueChanged<bool> on) =>
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: v, onChanged: on);

  @override
  Widget build(BuildContext context) {
    return ToolList(children: [
      AppPanel(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            color: Colors.black,
            height: 220,
            child: ClockFace(t: t, p: _p, now: _now),
          ),
        ),
      ),
      AppButton(
        label: L(t, 'start_clock'),
        icon: Icons.nightlight_round,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _FullClock(t: t, p: _p),
        )),
      ),
      AppPanel(
        child: Column(children: [
          Choice<bool>(
            values: const [false, true],
            labels: [L(t, 'digital'), L(t, 'analog')],
            selected: _p.analog,
            onChanged: (b) => _set(_p.copy(analog: b)),
          ),
          _switch(L(t, 'show_seconds'), _p.seconds, (b) => _set(_p.copy(seconds: b))),
          _switch(L(t, 'show_date'), _p.date, (b) => _set(_p.copy(date: b))),
          _switch(L(t, 'show_battery'), _p.battery, (b) => _set(_p.copy(battery: b))),
          _switch(L(t, 'night_red'), _p.night, (b) => _set(_p.copy(night: b))),
          _switch(L(t, 'only_charging'), _p.onlyCharging, (b) => _set(_p.copy(onlyCharging: b))),
          Row(children: [
            Expanded(child: Text(L(t, 'dim'))),
            Expanded(
              flex: 2,
              child: Slider(value: _p.dim, min: 0, max: 0.8, divisions: 8, onChanged: (v) => _set(_p.copy(dim: v))),
            ),
          ]),
          const SizedBox(height: 8),
          PaletteRow(
            palettes: kPalettes,
            selected: _p.palette,
            free: kFreePalettes,
            unlocked: _extras,
            onChanged: (i) => _set(_p.copy(palette: i)),
          ),
        ]),
      ),
      if (!_extras) UnlockButton(t: t, onUnlocked: () => setState(() => _extras = true)),
      AppInfoCard(L(t, kIsWeb ? 'clock_note_web' : 'clock_note'), icon: Icons.info_outline_rounded),
    ]);
  }
}

class _FullClock extends StatefulWidget {
  final ToolContext t;
  final ClockPrefs p;
  const _FullClock({required this.t, required this.p});
  @override
  State<_FullClock> createState() => _FullClockState();
}

class _FullClockState extends State<_FullClock> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  int? _level;
  bool _charging = false;
  StreamSubscription<BatteryState>? _sub;
  final Battery _battery = Battery();
  bool _awake = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      if (_now.second == 0) unawaited(_readLevel());
    });
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    if (!kIsWeb) {
      try {
        _sub = _battery.onBatteryStateChanged.listen((s) {
          final c = s == BatteryState.charging || s == BatteryState.full || s == BatteryState.connectedNotCharging;
          if (mounted) setState(() => _charging = c);
          unawaited(_wake());
        }, onError: (Object _) {});
      } catch (_) {}
      unawaited(_readLevel());
    }
    unawaited(_wake());
  }

  Future<void> _readLevel() async {
    if (kIsWeb) return;
    try {
      final l = await _battery.batteryLevel.timeout(const Duration(seconds: 2));
      if (mounted) setState(() => _level = l);
    } catch (_) {}
  }

  /// Ekranı açık tut: her zaman, ya da "yalnız şarjdayken" seçiliyse şarjda.
  Future<void> _wake() async {
    final want = !widget.p.onlyCharging || _charging || kIsWeb;
    if (want == _awake) return;
    _awake = want;
    try {
      await WakelockPlus.toggle(enable: want);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_sub?.cancel());
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    if (_awake) {
      unawaited(WakelockPlus.disable().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final off = burnInOffset(_now.hour * 60 + _now.minute);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(context),
        child: Stack(children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment(off.$1 * 0.3, off.$2 * 0.3),
              child: FractionallySizedBox(
                widthFactor: 0.9,
                heightFactor: 0.8,
                child: ClockFace(t: widget.t, p: widget.p, now: _now, battery: _level, charging: _charging),
              ),
            ),
          ),
          if (widget.p.dim > 0) Positioned.fill(child: IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: widget.p.dim)))),
        ]),
      ),
    );
  }
}
